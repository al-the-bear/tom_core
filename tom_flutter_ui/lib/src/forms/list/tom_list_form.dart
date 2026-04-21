import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../events/tom_form_event.dart';
import '../events/tom_form_event_listener.dart';
import '../events/tom_form_event_source.dart';
import '../tom_form.dart';
import '../validation/form_validation_error.dart';

// ---------------------------------------------------------------------------
// TomListForm — Phase 2a / §13
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
    extends TomObservable implements TomFormEventSource {
  TomListForm({
    required this.listId,
    required TForm Function(int index) formFactory,
    TomForm? parentForm,
  })  : _formFactory = formFactory,
        _parentForm = parentForm;

  /// Stable resource / event id for the list. Used as the `source` field
  /// on every list event and as the basePath segment for resources.
  final String listId;

  final TForm Function(int index) _formFactory;

  /// Optional parent form — when set, list events bubble up through the
  /// parent's event bus (so a single `parent.addListener(...)` sees both
  /// the per-field events AND the structural list events).
  final TomForm? _parentForm;
  TomForm? get parentForm => _parentForm;

  final List<TForm> _forms = [];

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
  List<TForm> get forms => List.unmodifiable(_forms);

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
  void bind(TomList<TItem> items) {
    for (final f in _forms) {
      f.dispose();
    }
    _forms.clear();
    _binding = items;
    for (var i = 0; i < items.length; i++) {
      final form = _instantiate(i);
      form.bind(items[i]);
      _forms.add(form);
    }
    _initialOrder = List<TItem>.from(items.toList());
    notifyObservers();
  }

  /// Detach from the bound list. Sub-forms are unbound and disposed.
  void unbind() {
    for (final f in _forms) {
      f.unbind();
      f.dispose();
    }
    _forms.clear();
    _binding = null;
    _initialOrder = const [];
    notifyObservers();
  }

  // --- Lifecycle propagation ---

  /// Validate every sub-form plus this list's own [validateList] hook.
  /// Returns the combined error list.
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
  Future<bool> save() async {
    final errors = await validate();
    if (errors.isNotEmpty) return false;
    for (final form in _forms) {
      final ok = await form.save();
      if (!ok) return false;
    }
    if (_binding != null) {
      _initialOrder = List<TItem>.from(_binding!.toList());
    }
    return true;
  }

  /// Discard edits in every sub-form AND restore the original list order
  /// / membership captured at bind / save time.
  void discard() {
    for (final form in _forms) {
      form.discard();
    }
    final binding = _binding;
    if (binding != null && _initialOrder.isNotEmpty) {
      // Rebuild the bound list to match the snapshot.
      final desired = List<TItem>.from(_initialOrder);
      // Remove items that are not in the snapshot.
      final snapshotSet = Set<TItem>.identity()..addAll(desired);
      for (var i = binding.length - 1; i >= 0; i--) {
        if (!snapshotSet.contains(binding[i])) {
          binding.removeAt(i);
          if (i < _forms.length) {
            _forms.removeAt(i).dispose();
          }
        }
      }
      // Re-add missing items in snapshot order; reorder to match.
      for (var i = 0; i < desired.length; i++) {
        final item = desired[i];
        final currentIndex = binding.toList().indexOf(item);
        if (currentIndex < 0) {
          binding.insert(i, item);
          final form = _instantiate(i);
          form.bind(item);
          _forms.insert(i, form);
        } else if (currentIndex != i) {
          final f = _forms.removeAt(currentIndex);
          _forms.insert(i, f);
          binding.removeAt(currentIndex);
          binding.insert(i, item);
        }
      }
    }
    notifyObservers();
  }

  // --- Aggregate state ---

  /// `true` when any sub-form is dirty OR the list membership / order has
  /// changed since the last [bind] / [save].
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
    return form;
  }

  /// Dispose every sub-form and clear listeners.
  void dispose() {
    for (final f in _forms) {
      f.dispose();
    }
    _forms.clear();
    _localListeners.clear();
  }
}
