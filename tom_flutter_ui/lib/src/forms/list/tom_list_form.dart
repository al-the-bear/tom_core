import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../events/tom_form_event.dart';
import '../events/tom_form_event_listener.dart';
import '../events/tom_form_event_source.dart';
import '../tom_form.dart';
import '../tom_form_child_container.dart';
import '../validation/form_validation_error.dart';

// ---------------------------------------------------------------------------
// TomListForm
// ---------------------------------------------------------------------------

/// Container that manages an ordered collection of sub-forms — one per
/// list element of the bound business object.
///
/// `TomListForm` is the form-side mirror of [TomList]. Where [TomList]
/// observes the value channel of each contained [TomObject], `TomListForm`
/// owns one [TomForm] *instance* per row and fans the form lifecycle —
/// `bind` / `save` / `discard` / `validate` / dirty tracking — across every
/// sub-form. It also publishes structural changes (`add` / `remove` / `move`)
/// through the form event bus so [TomFormInspector] and logging UIs pick
/// them up alongside per-field events.
///
/// Identity / resources follow the spec convention: every sub-form created
/// by [formFactory] uses the same [listId] as its `formId` so resource
/// lookups (`order.items.quantity.label`) apply uniformly to every row,
/// rather than producing an indexed path per item.
///
/// Typical usage:
///
/// ```dart
/// class OrderForm extends TomForm<Order> {
///   OrderForm() : super(formId: 'order');
///
///   late final orderNumber = TomFormStringInput('orderNumber', '', form: this);
///
///   late final items = TomListForm<OrderItem, OrderItemForm>(
///     listId: 'items',
///     formFactory: (i) => OrderItemForm(),
///   );
///
///   @override
///   void onBound() {
///     items.bind((_binding! as Order).items);
///   }
/// }
/// ```
class TomListForm<TItem extends TomClass, TForm extends TomForm<TItem>>
    extends TomObservable
    implements TomFormEventSource, TomFormChildContainer,
        TomListLifecycleListener {
  TomListForm({
    required this.listId,
    required TForm Function(int index) formFactory,
    TomForm? parentForm,
  })  : _formFactory = formFactory,
        _parentForm = parentForm {
    // Auto-register so the parent's validate / save / discard / isDirty
    // / isValid / unbind fan out into this list. `TomListForm` extends
    // `TomObservable` (not `TomObject`), so the parent's reflectable
    // `getMembers()` can't discover it — explicit registration closes
    // that gap.
    parentForm?.registerChildContainer(this);
    // Forward every notification from the inner TomList — which already
    // observes each contained sub-form per the kernel chain
    // (field.notifyObservers → form.notifyObservers via TomClass member
    // observation → TomList.notifyObservers via element observation) — to
    // this list-form's own observers. That way row-level field edits
    // automatically wake up anything observing this list (Save buttons,
    // dirty chips, item-table builders), without each sub-form needing a
    // hand-rolled bubble listener.
    //
    // The returned observer MUST be retained: `TomObservable` holds its
    // observers by `WeakReference`, so discarding it leaves the forwarder
    // alive only until the next GC — after which row-level field edits stop
    // reaching this list's observers, with no error to notice.
    _formsForwarder = _forms >> (_) => notifyObservers();
  }

  /// Stable resource / event id for the list. Used as the `source` field
  /// on every list event and as the basePath segment for resources.
  final String listId;

  final TForm Function(int index) _formFactory;

  /// Optional parent form — when set, list events bubble up through the
  /// parent's event bus (so a single `parent.addListener(...)` sees both
  /// the per-field events AND the structural list events).
  final TomForm? _parentForm;
  TomForm? get parentForm => _parentForm;

  /// The sub-forms backing this list. Stored as a kernel [TomList] so
  /// element observation is automatic: every contained [TForm] is watched
  /// for value-channel notifications, which propagate up to this list-form
  /// via the forwarder installed in the constructor. Add / insert /
  /// removeAt / clear all use the standard [TomList] mutators so the
  /// add / remove observer wiring stays in sync.
  final TomList<TForm> _forms = TomList<TForm>();

  /// Keeps the constructor's `_forms` subscription alive. Observers are held
  /// weakly, so this reference *is* the subscription's lifetime: the field is
  /// load-bearing by existing, which is why it is never read.
  // ignore: unused_field
  late final TomObserver _formsForwarder;

  /// The bound list (back-reference for save push-back).
  TomList<TItem>? _binding;

  /// Snapshot of the bound elements at bind / save time. Used by
  /// [hasStructuralChanges] to detect adds / removes / reorders that
  /// per-sub-form `isDirty` cannot see.
  List<TItem> _initialOrder = const [];

  /// Local listeners registered when no [parentForm] is set — keeps the
  /// list usable as a standalone event source in tests.
  final List<TomFormEventListener> _localListeners = [];

  // --- Read-only views ---

  /// All currently mounted sub-forms in their list order.
  List<TForm> get forms => List<TForm>.unmodifiable(_forms);

  /// Number of sub-forms (== bound list length).
  int get length => _forms.length;

  bool get isEmpty => _forms.isEmpty;
  bool get isNotEmpty => _forms.isNotEmpty;

  TForm operator [](int index) => _forms[index];

  // --- Mutation ---

  /// Append a new, blank sub-form. The parent's bound list (if any) gets
  /// a fresh [TItem] as well, instantiated by [createItem]. Subclasses
  /// must override [createItem] before calling [add] against a bound list.
  TForm add() {
    final index = _forms.length;
    final form = _instantiate(index);
    _forms.add(form);
    final binding = _binding;
    if (binding != null) {
      final item = createItem();
      binding.add(item);
      form.bind(item);
    }
    notifyObservers();
    _fireEvent(ListItemAddedEvent(
      source: listId,
      index: index,
      itemFormId: form.formId,
    ));
    return form;
  }

  /// Insert a blank sub-form at [index]. Same binding semantics as [add].
  TForm insert(int index) {
    final form = _instantiate(index);
    _forms.insert(index, form);
    final binding = _binding;
    if (binding != null) {
      final item = createItem();
      binding.insert(index, item);
      form.bind(item);
    }
    notifyObservers();
    _fireEvent(ListItemAddedEvent(
      source: listId,
      index: index,
      itemFormId: form.formId,
    ));
    return form;
  }

  /// Remove the sub-form at [index] from this list and from the bound
  /// underlying list (if any).
  void removeAt(int index) {
    final form = _forms.removeAt(index);
    final binding = _binding;
    if (binding != null) {
      binding.removeAt(index);
    }
    notifyObservers();
    _fireEvent(ListItemRemovedEvent(
      source: listId,
      index: index,
      itemFormId: form.formId,
    ));
    form.dispose();
  }

  /// Convenience: remove a specific sub-form instance.
  bool remove(TForm form) {
    final index = _forms.indexOf(form);
    if (index < 0) return false;
    removeAt(index);
    return true;
  }

  /// Move the sub-form from index [from] to index [to]. The bound list
  /// is reordered to match.
  ///
  /// See [reorder] for the spec-canonical name; both forward to the same
  /// implementation and fire a [ListItemReorderedEvent].
  void move(int from, int to) {
    if (from == to) return;
    final form = _forms.removeAt(from);
    _forms.insert(to, form);
    final binding = _binding;
    if (binding != null) {
      final item = binding[from];
      binding.removeAt(from);
      binding.insert(to, item);
    }
    notifyObservers();
    _fireEvent(ListItemReorderedEvent(
      source: listId,
      fromIndex: from,
      toIndex: to,
      itemFormId: form.formId,
    ));
  }

  /// Spec-canonical alias of [move] (§16: "reorder via drag handles
  /// drives `.reorder`"). Forwards to [move] so existing callers and
  /// events keep working unchanged.
  void reorder(int from, int to) => move(from, to);

  /// Bind this list to a [TomList] of [TItem]. Tears down any sub-forms
  /// from a prior binding and re-instantiates one form per element.
  ///
  /// Registers [this] as a [TomListLifecycleListener] on [items] so that
  /// structural resets driven by an outer `TomClass.setValues()` call (e.g.
  /// when an outer form discards its snapshot) automatically tear down the
  /// old sub-forms ([onBeforeClear]) and rebuild them for the new elements
  /// ([onAfterReset]).
  void bind(TomList<TItem> items) {
    _binding?.removeLifecycleListener(this);
    for (final f in _forms) {
      f.dispose();
    }
    _forms.clear();
    _binding = items;
    items.addLifecycleListener(this);
    for (var i = 0; i < items.length; i++) {
      final form = _instantiate(i);
      form.bind(items[i]);
      _forms.add(form);
    }
    _initialOrder = List<TItem>.from(items.toList());
    notifyObservers();
  }

  /// Detach from the bound list. Sub-forms are unbound and disposed.
  @override
  void unbind() {
    _binding?.removeLifecycleListener(this);
    for (final f in _forms) {
      f.unbind();
      f.dispose();
    }
    _forms.clear();
    _binding = null;
    _initialOrder = const [];
    notifyObservers();
  }

  // --- TomListLifecycleListener ---

  /// Called by [TomList.resetWith] immediately before elements are removed.
  /// Disposes all current sub-forms so they are not left orphaned after the
  /// list contents are replaced (e.g. when an outer `TomForm.discard()`
  /// writes its snapshot back via `binding.setValues()`).
  @override
  void onBeforeClear(TomList list) {
    for (final f in _forms) {
      f.unbind();
      f.dispose();
    }
    _forms.clear();
  }

  /// Called by [TomList.resetWith] immediately after new elements are
  /// installed. Creates and binds fresh sub-forms for every element now in
  /// the list. Resets [_initialOrder] to the new contents so [isDirty] and
  /// [hasStructuralChanges] start from the correct baseline.
  @override
  void onAfterReset(TomList list) {
    final binding = _binding;
    if (binding == null) return;
    for (var i = 0; i < binding.length; i++) {
      final form = _instantiate(i);
      form.bind(binding[i]);
      _forms.add(form);
    }
    _initialOrder = List<TItem>.from(binding.toList());
    notifyObservers();
  }

  // --- Lifecycle propagation ---

  /// Validate every sub-form plus this list's own [validateList] hook.
  /// Returns the combined error list.
  ///
  /// After computing errors a [FormValidatedEvent] is fired through the
  /// event bus (bubbling to the parent form when [parentForm] is set).
  /// This lets [TomErrorView] widgets subscribed to the parent form's bus
  /// pick up list-level errors — e.g. "at least one item required" —
  /// without needing a separate imperative update call.
  @override
  Future<List<FormValidationError>> validate() async {
    final errors = <FormValidationError>[];
    for (final form in _forms) {
      errors.addAll(await form.validate());
    }
    final listErrors = await validateList();
    for (final key in listErrors) {
      errors.add(FormValidationError(
        errorKey: key,
        fields: const [],
      ));
    }
    _fireEvent(FormValidatedEvent(
      source: listId,
      errors: errors,
    ));
    return errors;
  }

  /// Optional list-level validation. Default returns an empty list.
  ///
  /// Override to enforce things like minimum / maximum row count or
  /// duplicate checks across rows. Returned strings are treated as
  /// resource keys for cross-field error display (`TomErrorView` etc.).
  Future<List<String>> validateList() async => const [];

  /// Save every sub-form. Returns `true` only when *every* sub-form
  /// saved successfully and [validateList] returned no errors.
  ///
  /// [commitBaselines] mirrors [TomForm.save]'s policy parameter — when
  /// `false`, the per-row sub-form saves cascade with the same flag and
  /// `_initialOrder` is left untouched so an outer ancestor can still
  /// roll back structural changes via `discard()`. When `null` (default
  /// for direct user calls), the policy is auto-detected from the parent
  /// chain: a list-form whose parent form has its own ancestor in the
  /// tree is considered nested and skips the baseline update.
  @override
  Future<bool> save({bool? commitBaselines}) async {
    final commit = commitBaselines ?? !_hasFormAncestor;
    final errors = await validate();
    if (errors.isNotEmpty) return false;
    for (final form in _forms) {
      final ok = await form.save(commitBaselines: commit);
      if (!ok) return false;
    }
    if (commit && _binding != null) {
      _initialOrder = List<TItem>.from(_binding!.toList());
    }
    return true;
  }

  /// `true` when this list-form sits below a parent form that itself
  /// has an ancestor in the form tree. A list-form whose parent form is
  /// the root of its tree (e.g. `OrderForm.items` when `OrderForm` is
  /// standalone) still commits baselines on save — only lists whose
  /// parent is nested further up (e.g. `OrderForm.items` when `OrderForm`
  /// lives inside a customer form's orders list) skip the baseline
  /// update so the outer transactional baseline is preserved.
  ///
  /// Read by [save]'s policy auto-detection.
  bool get _hasFormAncestor {
    final parent = _parentForm;
    return parent != null && parent.hasFormAncestor;
  }

  /// Discard edits in every sub-form AND restore the original list order
  /// / membership captured at bind / save time.
  ///
  /// The restoration is driven by [TomList.resetWith] so that the
  /// [TomListLifecycleListener] hooks ([onBeforeClear] / [onAfterReset])
  /// atomically dispose the current sub-forms and recreate fresh ones for
  /// the restored elements.
  ///
  /// Order matters: sub-form field values are reset BEFORE [resetWith] so
  /// that [onAfterReset]'s `bind()` captures the correct (initial) TomClass
  /// state in the new sub-form's snapshot.
  @override
  void discard() {
    // Step 1: reset every current sub-form's field values (and recurse into
    // any nested child containers they own, e.g. nested TomListForms).
    for (final form in _forms) {
      form.discard();
    }
    // Step 2: atomically restore list structure. onBeforeClear disposes the
    // current (already-discarded) sub-forms; onAfterReset creates fresh
    // sub-forms bound to the original elements whose TomClass values were
    // already reset in step 1.
    final binding = _binding;
    if (binding != null) {
      // resetWith fires notifyObservers() internally via onAfterReset.
      binding.resetWith(_initialOrder);
    } else {
      notifyObservers();
    }
  }

  // --- Aggregate state ---

  /// `true` when any sub-form is dirty OR the list membership / order has
  /// changed since the last [bind] / [save].
  @override
  bool get isDirty =>
      hasStructuralChanges || _forms.any((f) => f.isDirty);

  /// `true` when at least one add / remove / reorder happened since the
  /// last [bind] / [save].
  bool get hasStructuralChanges {
    final binding = _binding;
    if (binding == null) return false;
    if (binding.length != _initialOrder.length) return true;
    for (var i = 0; i < _initialOrder.length; i++) {
      if (!identical(binding[i], _initialOrder[i])) return true;
    }
    return false;
  }

  /// `true` when every sub-form currently passes its own validation.
  /// Pristine sub-forms count as NOT valid (matching [TomForm.isValid]).
  @override
  bool get isValid => _forms.every((f) => f.isValid);

  // --- Subclass extension points ---

  /// Override in subclasses to produce a fresh [TItem] when [add] /
  /// [insert] is called against a bound list. Default throws — only
  /// required if the demo / app uses [add] without pre-instantiating
  /// items in the bound list.
  TItem createItem() {
    throw UnsupportedError(
      'TomListForm.add / insert against a bound list requires '
      'createItem() to be overridden so a new $TItem can be produced.',
    );
  }

  // --- TomFormEventSource ---

  @override
  void addListener(TomFormEventListener listener) {
    final parent = _parentForm;
    if (parent != null) {
      parent.addListener(listener);
    } else {
      _localListeners.add(listener);
    }
  }

  @override
  void removeListener(TomFormEventListener listener) {
    final parent = _parentForm;
    if (parent != null) {
      parent.removeListener(listener);
    } else {
      _localListeners.remove(listener);
    }
  }

  @override
  void fireEvent(TomFormEvent event) => _fireEvent(event);

  void _fireEvent(TomFormEvent event) {
    final parent = _parentForm;
    if (parent != null) {
      parent.fireEvent(event);
    } else {
      for (final listener in _localListeners) {
        listener.handleEvent(event);
      }
    }
  }

  // --- Internals ---

  TForm _instantiate(int index) {
    final form = _formFactory(index);
    if (form.formId != listId) {
      // Spec convention: every sub-form keeps the listId so resources
      // are shared. We don't enforce — but log via assert in dev.
      assert(
        form.formId == listId,
        'TomListForm convention: sub-form formId should match listId '
        '("$listId") so resources are shared, got "${form.formId}".',
      );
    }
    // Record the form-tree topology on the new sub-form so its public
    // `save()` can detect it has an outer ancestor and skip baseline
    // updates accordingly. Without this, a user-initiated `subForm.save()`
    // would clobber the outer parent form's transactional baseline (the
    // root cause of the H-D nested-save bug).
    form.attachToEnclosingForm(_parentForm);
    return form;
  }

  /// Dispose every sub-form and clear listeners.
  void dispose() {
    _binding?.removeLifecycleListener(this);
    for (final f in _forms) {
      f.dispose();
    }
    _forms.clear();
    _localListeners.clear();
  }
}

