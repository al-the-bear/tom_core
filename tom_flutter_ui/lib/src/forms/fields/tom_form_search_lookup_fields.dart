/// Phase 4 — Search & Lookup fields.
///
/// `TomFormSearchField<T>` is the type-ahead autocomplete pattern: large
/// candidate set, filter as the user types, single-pick. `TomFormLookupField<T>`
/// is the modal-picker pattern: candidate browsing happens in a dialog so
/// the form row stays compact.
///
/// Both consume a [TomSelectableSource] for items. Search relies on the
/// source returning the full set up-front and filters in-process — for
/// truly remote / paged sources, callers can provide a custom source
/// whose `getItems()` returns the current chunk.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_dropdown_decoration_mixin.dart';
import '../decoration/tom_field_anatomy.dart';
import '../decoration/tom_string_input_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../style/form_style_enums.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ===========================================================================
// Abstract types
// ===========================================================================

/// Abstract base for search-style single-pick fields.
abstract class TomFormSearchField<T> extends TomField<T> {
  final String? labelTextOverride;
  final String? hintTextOverride;
  final String? descriptionTextOverride;

  TomFormSearchField(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

/// Abstract base for modal-picker lookup fields.
abstract class TomFormLookupField<T> extends TomField<T> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormLookupField(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

// ===========================================================================
// TomFormSearchInput<T> — Autocomplete-driven type-ahead picker
// ===========================================================================

@tomReflector
class TomFormSearchInput<T> extends TomFormSearchField<T>
    with TomStringInputDecorationMixin<T> {
  final TomSelectableSource<T> source;

  /// Custom search predicate. Defaults to substring (case-insensitive)
  /// match against `SelectableItem.label`.
  final bool Function(String query, SelectableItem<T> item)? searchPredicate;

  /// Map from selected value → display string. Required because the
  /// `TextEditingController` round-trips through string. Defaults to the
  /// matching item's label, or `value.toString()` if the value isn't in
  /// the source's snapshot.
  final String Function(T value)? labelOf;

  TomFormSearchInput(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.searchPredicate,
    this.labelOf,
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _SearchInputWidget<T>(field: this),
      );
}

class _SearchInputWidget<T> extends StatefulWidget {
  final TomFormSearchInput<T> field;
  const _SearchInputWidget({required this.field});

  @override
  State<_SearchInputWidget<T>> createState() => _SearchInputWidgetState<T>();
}

class _SearchInputWidgetState<T> extends State<_SearchInputWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = <SelectableItem<T>>[];
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormSearchInput<T> get field => widget.field;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadItems() async {
    final initial = await field.source.getItems();
    if (mounted) setState(() => _items = initial);
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) setState(() => _items = next);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  String _label(T v) {
    final fn = field.labelOf;
    if (fn != null) return fn(v);
    final hit = _items.firstWhere(
      (it) => it.value == v,
      orElse: () =>
          SelectableItem<T>(value: v, label: v?.toString() ?? ''),
    );
    return hit.label;
  }

  bool _match(String q, SelectableItem<T> it) {
    final pred = field.searchPredicate;
    if (pred != null) return pred(q, it);
    return it.label.toLowerCase().contains(q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final f = field;
    final style = f.resolveStyle(context);

    // `Autocomplete` seeds its internal `TextEditingController` from
    // `initialValue` exactly once, when its State is created, and never
    // reconsults it. That is a problem here for two reasons: the source
    // resolves asynchronously, so the first build has an empty `_items`
    // and `_label` falls back to `value.toString()` (for a non-String
    // value type, a visibly wrong display that never corrected itself);
    // and a programmatic `setValue` likewise left the old text in place.
    // Keying the widget by the resolved display forces a fresh State —
    // and therefore a re-seeded controller — whenever the label the model
    // implies actually changes. Same remedy as `TomFormDateCalendar`.
    //
    // Typing does not trigger it: the key tracks `f.get()`, which only
    // moves when an option is selected, and `onSelected` already rewrites
    // the controller to that option's display string.
    final display = _label(f.get());

    final autocomplete = Autocomplete<SelectableItem<T>>(
      key: ValueKey<String>(display),
      initialValue: TextEditingValue(text: display),
      displayStringForOption: (it) => it.label,
      optionsBuilder: (input) {
        final q = input.text;
        if (q.isEmpty) return _items.where((i) => i.enabled).take(50);
        return _items.where((i) => i.enabled && _match(q, i)).take(50);
      },
      onSelected: (it) => f.setValue(it.value),
      // Round-5 (f): the default `optionsViewBuilder` constrains the
      // popup to the field width, which clips long catalog labels in
      // narrow cells (e.g. Demo H-C item rows). Render the popup
      // ourselves so it sizes to the widest option (capped to a
      // reasonable max so off-screen labels don't blow it up) while
      // still pinning to the field via Autocomplete's internal
      // CompositedTransformFollower.
      optionsViewBuilder: (context, onSelected, options) {
        return _SearchOptionsPopup<T>(
          options: options,
          onSelected: onSelected,
          textStyle: style.inputStyle,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: f.isEditable,
          style: style.inputStyle,
          onSubmitted: (_) => onSubmit(),
          decoration: f.applyErrorVisualsTo(
            context,
            InputDecoration(
              labelText: f.labelText,
              hintText: f.hintText ?? 'Type to search…',
              suffixIcon: const Icon(Icons.search),
              contentPadding: style.fieldContentPadding,
              border: style.fieldBorder,
              focusedBorder: style.focusedBorder,
              errorBorder: style.errorBorder,
              enabledBorder: style.fieldBorder,
            ),
          ),
        );
      },
    );

    return f.decorateField(context, autocomplete);
  }
}

/// Material-styled popup for [Autocomplete] that sizes to the widest
/// option label rather than to the underlying text field. Capped to
/// `maxWidth` so a single very long label can't push the overlay
/// off-screen, and to `maxHeight` so a long candidate list scrolls
/// instead of overflowing the viewport.
///
/// The popup is built as `IntrinsicWidth(Column(options))` rather than
/// `IntrinsicWidth(ListView)`, because Flutter's
/// `RenderShrinkWrappingViewport` (used by `ListView(shrinkWrap: true)`)
/// throws on `computeMaxIntrinsicWidth` — the intrinsic width algorithm
/// would have to instantiate every child, defeating the viewport's
/// laziness. A `Column` happily reports its widest child's intrinsic
/// width, which is what we want here. The whole thing is wrapped in a
/// vertical `SingleChildScrollView` so long lists still scroll, capped
/// to `take(50)` upstream so the column never gets pathologically tall.
///
/// Wrapped in [Align(alignment: Alignment.topLeft)] because the
/// `Autocomplete` overlay stretches the popup to the follow-target
/// width by default; the alignment lets the inner [Material]
/// shrink-wrap to the intrinsic width instead.
class _SearchOptionsPopup<T> extends StatelessWidget {
  final Iterable<SelectableItem<T>> options;
  final void Function(SelectableItem<T>) onSelected;
  final TextStyle? textStyle;

  const _SearchOptionsPopup({
    required this.options,
    required this.onSelected,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final list = options.toList(growable: false);
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 240,
            maxWidth: 480,
          ),
          child: SingleChildScrollView(
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final it in list)
                    InkWell(
                      onTap: () => onSelected(it),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          it.label,
                          style: textStyle,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// TomFormLookupDialog<T> — Read-only field + "Browse" dialog
// ===========================================================================

@tomReflector
class TomFormLookupDialog<T> extends TomFormLookupField<T>
    with TomDropdownDecorationMixin<T> {
  final TomSelectableSource<T> source;

  /// Display string for the selected value. Defaults to lookup against
  /// the source snapshot (or `value.toString()` if not present).
  final String Function(T value)? labelOf;

  /// Title for the lookup dialog. Defaults to `labelText` or "Lookup".
  final String? dialogTitle;

  TomFormLookupDialog(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.labelOf,
    this.dialogTitle,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  // `TomDropdownDecorationMixin` declares `labelText`/`descriptionText`
  // returning null, and a mixin applied over a superclass wins over that
  // superclass's members — so without these overrides the mixin silently
  // shadowed `TomFormLookupField`'s implementations and both constructor
  // overrides were dead: no floating label on the row, and a dialog
  // titled "Lookup" instead of the field's label. `TomFormSearchInput`
  // already re-declares them for the same reason.
  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _LookupDialogWidget<T>(field: this),
      );
}

class _LookupDialogWidget<T> extends StatefulWidget {
  final TomFormLookupDialog<T> field;
  const _LookupDialogWidget({required this.field});

  @override
  State<_LookupDialogWidget<T>> createState() => _LookupDialogWidgetState<T>();
}

class _LookupDialogWidgetState<T> extends State<_LookupDialogWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = <SelectableItem<T>>[];
  late final TomFunctionObserver<TomObservable> _observer;

  /// Read-only controller mirrored from the bound field so the lookup
  /// row uses the same TextField anatomy (and therefore baseline,
  /// content-padding, and inputStyle) as every other text input. Was
  /// previously rendered through `InputDecorator` + `Text`, which left
  /// the display string visibly higher than other rows (round-4 item n).
  late final TextEditingController _displayController;

  TomFormLookupDialog<T> get field => widget.field;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController();
    _loadItems();
    _observer = field >> (_) {
      if (mounted) {
        _syncDisplay();
        setState(() {});
      }
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadItems() async {
    final initial = await field.source.getItems();
    if (mounted) {
      setState(() => _items = initial);
      _syncDisplay();
    }
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => _items = next);
          _syncDisplay();
        }
      });
    }
  }

  void _syncDisplay() {
    final next = _label(field.get());
    if (_displayController.text != next) _displayController.text = next;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    _displayController.dispose();
    super.dispose();
  }

  String _label(T v) {
    final fn = field.labelOf;
    if (fn != null) return fn(v);
    final hit = _items.firstWhere(
      (it) => it.value == v,
      orElse: () =>
          SelectableItem<T>(value: v, label: v?.toString() ?? ''),
    );
    return hit.label;
  }

  Future<void> _openDialog() async {
    // Capture the form's input style so the dialog's filter input + list
    // tile labels render with the same font as the rest of the form
    // (round-4 item p). Fall back to the ambient `bodyLarge` because
    // that's the same fallback Material's `TextField` uses when no
    // explicit `style:` is supplied — round-6 (i): the previous
    // `bodyMedium` (14 px) made the lookup row visibly smaller than a
    // sibling `TomFormStringInput` whose unspecified style resolved to
    // bodyLarge (16 px) via Flutter defaults.
    final inputStyle = field.resolveStyle(context).inputStyle ??
        Theme.of(context).textTheme.bodyLarge;
    final picked = await showDialog<T>(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final visible = filter.isEmpty
                ? _items
                : _items
                    .where((it) =>
                        it.label.toLowerCase().contains(filter.toLowerCase()))
                    .toList();
            return AlertDialog(
              title: Text(field.dialogTitle ?? field.labelText ?? 'Lookup'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      // Outlined border so the icon sits visibly inside
                      // the input box (round-4 item o — was previously a
                      // dense underline that drew the icon on the
                      // separator between input and result list).
                      autofocus: true,
                      style: inputStyle,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 22),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        hintText: 'Filter…',
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setLocal(() => filter = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (ctx, i) {
                          final it = visible[i];
                          return ListTile(
                            dense: true,
                            title: Text(it.label, style: inputStyle),
                            subtitle: it.description != null
                                ? Text(it.description!)
                                : null,
                            enabled: it.enabled,
                            onTap: () => Navigator.of(ctx).pop(it.value),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked != null && mounted) field.setValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);

    // Mirror the same composition `TomFormStringField` uses so the
    // lookup row's text baseline, font size, label placement and hint
    // styling are pixel-identical to a regular text input — round-5
    // (h)/(i): previously the row used a bare InputDecoration without
    // labelStyle/floatingLabelStyle/hintStyle, which let Flutter's
    // theme defaults (typically a larger subtitle1) leak in and shift
    // both the font size and the visible baseline.
    //
    // Use the same bodyLarge fallback as `_openDialog` (round-6 (i)) —
    // mirrors what Material's TextField does internally when no style
    // is supplied, so the lookup row matches a sibling
    // `TomFormStringInput` for which `style.inputStyle` is null. Test
    // (p) still passes because `style` and `style.fontSize` remain
    // non-null and identical between the field and the dialog.
    final inputStyle =
        style.inputStyle ?? Theme.of(context).textTheme.bodyLarge;
    final hintStyle = composeHintStyle(style, Theme.of(context));

    // Floating label, scaled to Material's 0.75× ratio so a custom
    // labelStyle font size doesn't overflow the floating slot. Same
    // logic as TomFormStringField.
    String? floatingLabel;
    if (style.labelPlacement == LabelPlacement.floating) {
      final resolved = f.labelText;
      if (resolved != null && resolved.isNotEmpty) floatingLabel = resolved;
    }
    const floatScale = 0.75;
    final labelFontSize = style.labelStyle?.fontSize;
    final floatingLabelStyle = style.labelStyle?.copyWith(
      fontSize: labelFontSize != null ? labelFontSize * floatScale : null,
    );

    final input = TextField(
      controller: _displayController,
      readOnly: true,
      enabled: f.isEditable,
      style: inputStyle,
      // Round-5 (h): align the read-only display text to the centre of
      // the input box; without this the text rides the top edge of the
      // content area, looking visibly higher than neighbouring fields.
      textAlignVertical: TextAlignVertical.center,
      mouseCursor: f.isEditable ? SystemMouseCursors.click : null,
      onTap: f.isEditable ? _openDialog : null,
      decoration: f.applyErrorVisualsTo(
        context,
        InputDecoration(
          labelText: floatingLabel,
          labelStyle: style.labelStyle,
          floatingLabelStyle: floatingLabelStyle,
          hintText: '—',
          hintStyle: hintStyle,
          // Round-5 (j): plain Icon (size 22 to match the dialog's
          // prefix icon) instead of an IconButton — the IconButton's
          // 48×48 minimum touch target was inflating the suffix slot
          // and pushing the input text up. The whole row is tappable
          // via the TextField's onTap, so the icon doesn't need its
          // own ripple — the wrapping Padding keeps the trailing
          // gutter visually balanced.
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search, size: 22),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
          contentPadding: style.fieldContentPadding,
          border: style.fieldBorder,
          focusedBorder: style.focusedBorder,
          errorBorder: style.errorBorder,
          enabledBorder: style.fieldBorder,
        ),
      ),
    );

    return f.decorateField(context, input);
  }
}
