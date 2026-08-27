# Tom UI — List Forms

*Part of the [Tom Flutter UI documentation set](README.md).*

**Date:** 2026-04-25
**Status:** Active
**Package:** `tom_flutter_ui`
**Location:** `tom_flutter_ui/lib/src/forms/list/`

This document describes the **list-form** layer of the Tom Forms Framework: how lists of nested sub-forms are modelled (`TomListForm`), the three reusable widgets that render them (`TomInlineListForm`, `TomExpandableListForm`, `TomMasterDetailListForm`), the two helper widgets they share (`TomListFormToolbar`, `TomReorderHandle`), how list-of-list nesting works, and how dirty / structural-change propagation reaches the outer form's UI.

It is the practical companion to [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) Phase 2a §13–§16 — read that for the underlying form/field model; read this for the *list* dimension.

---

## Table of Contents

1. [Why a separate list-form layer](#1-why-a-separate-list-form-layer)
2. [TomListForm — the model](#2-tomlistform--the-model)
3. [Lifecycle and dirty propagation](#3-lifecycle-and-dirty-propagation)
4. [TomInlineListForm — flat row layout](#4-tominlinelistform--flat-row-layout)
5. [TomExpandableListForm — drill-down rows](#5-tomexpandablelistform--drill-down-rows)
6. [TomMasterDetailListForm — list ↔ detail layout](#6-tommasterdetaillistform--list--detail-layout)
7. [Reorder helpers — TomReorderHandle and TomListFormToolbar](#7-reorder-helpers--tomreorderhandle-and-tomlistformtoolbar)
8. [Nested lists (list inside a list inside a form)](#8-nested-lists-list-inside-a-list-inside-a-form)
9. [Choosing a renderer](#9-choosing-a-renderer)
10. [Patterns the components do NOT solve](#10-patterns-the-components-do-not-solve)
11. [Resources and authorization](#11-resources-and-authorization)

---

## 1. Why a separate list-form layer

A `TomForm<T>` binds to a single `TomClass` instance. When the bound class has a field of type `TomList<TItem>` (e.g. `Order.items: TomList<OrderItem>`), the form needs:

- **Per-row sub-forms** — one `TomForm<TItem>` per element, sharing the parent form's resources, validation lifecycle, and event bus.
- **Structural change tracking** — adds, removes, and reorders are first-class dirty operations.
- **Lifecycle propagation** — `parent.save()`, `parent.discard()`, and `parent.validate()` must fan out into every row.
- **Event surfacing** — list-level events (`ListItemAddedEvent`, `ListItemRemovedEvent`, `ListItemReorderedEvent`) and per-row form events must reach the parent's `TomFormInspector` listeners.

`TomListForm` is the model that owns this contract. The two list widgets — `TomInlineListForm` and `TomExpandableListForm` — render a `TomListForm` without re-implementing any of that machinery.

---

## 2. TomListForm — the model

**File:** `lib/src/forms/list/tom_list_form.dart`

```dart
class TomListForm<TItem extends TomClass, TForm extends TomForm<TItem>>
    extends TomObservable
    implements TomFormEventSource, TomFormChildContainer,
        TomListLifecycleListener
```

A `TomListForm` is declared inside a parent `TomForm` and bound to a `TomList<TItem>` member of the parent's bound class:

```dart
class OrderForm extends TomForm<Order> {
  OrderForm() : super(formId: 'order');

  late final items = TomListForm<OrderItem, OrderItemForm>(
    listId: 'items',
    formFactory: (index) => OrderItemForm(),
    parentForm: this,
  );

  @override
  void onBound() => items.bind(currentBinding!.items);
}
```

`parentForm` is not optional in practice. A `TomListForm` extends `TomObservable` rather than `TomObject`, so the parent's reflective member scan cannot discover it the way it discovers fields — passing `parentForm` registers it explicitly, and only then do the parent's `validate` / `save` / `discard` / `isDirty` / `unbind` fan out into the rows and the structural events bubble onto the parent's bus.

### Public API surface

| Member | Purpose |
| ------ | ------- |
| `int get length` | Current row count. |
| `TForm operator [](int index)` | Row sub-form at `index`. |
| `List<TForm> get forms` | Read-only view of all row sub-forms. |
| `bool get isEmpty` / `isNotEmpty` | Row-count predicates. |
| `TForm add()` | Append a new row. Against a bound list, creates a new `TItem` via `createItem` and binds it. |
| `TForm insert(int index)` | Insert at `index`; same binding semantics as `add`. |
| `void removeAt(int index)` | Remove the row at `index`. |
| `bool remove(TForm form)` | Remove a row by identity; `false` if it is not in the list. |
| `void move(int from, int to)` | Reorder. |
| `void reorder(int from, int to)` | Alias of `move`. |
| `void bind(TomList<TItem> items)` | Bind to the parent object's list; builds one sub-form per element. |
| `TItem createItem()` | **Override required** before `add`/`insert` against a bound list — the default throws `UnsupportedError`. |
| `bool get hasStructuralChanges` | True if the list membership/order differs from the snapshot. |
| `bool get isDirty` | True if any row is dirty OR `hasStructuralChanges`. |
| `bool get isValid` | True if every row sub-form is currently valid. |
| `Future<List<FormValidationError>> validate()` | Validate every row, then run `validateList`; fires `FormValidatedEvent`. |
| `Future<List<String>> validateList()` | List-level validation hook. Override for row-count or cross-row rules; returns resource keys. Default empty. |
| `Future<bool> save({bool? commitBaselines})` | Validate; on success, snapshot every row and `hasStructuralChanges → false`. `commitBaselines` mirrors `TomForm.save`'s policy; `null` auto-detects nesting. |
| `void discard()` | Restore membership, order, and per-row contents to the last save/bind snapshot. |
| `void unbind()` | Tear down all row sub-forms; reset state. |
| `void addListener(TomFormEventListener)` / `removeListener(...)` | Subscribe to this list's own event bus. |
| `void addObserver(TomObserver)` / `removeObserver(...)` | Receive notifications on any structural or per-row change. |
| `void dispose()` | Release sub-forms and observers. |

### Events on the parent's bus

`TomListForm` re-fires structural events through the parent form's event bus, so a single `TomFormInspector` attached to the parent sees the whole picture:

- `ListItemAddedEvent { itemFormId, index }`
- `ListItemRemovedEvent { itemFormId, index }`
- `ListItemReorderedEvent { itemFormId, fromIndex, toIndex }`
- `FormValidatedEvent { source, errors }` — one per row + one with `source == listId` aggregating list-level errors.

---

## 3. Lifecycle and dirty propagation

### Parent ↔ list ↔ row chain

```
TomForm.save() ─┬─▶ TomListForm.save() ─┬─▶ row[0].save()
                │                       ├─▶ row[1].save()
                │                       └─▶ snapshot membership
                ├─▶ other field save()
                └─▶ snapshot self
```

Discard is symmetric: `TomForm.discard()` calls `TomListForm.discard()`, which:

1. Restores the original membership (re-creates removed rows; drops added ones; restores order).
2. Calls `discard()` on every row sub-form.

### Dirty flags

`TomForm.isDirty` returns true when **any** of the following is true:
- A directly-owned field is dirty.
- Any child container (including any `TomListForm`) reports `isDirty`.
- A `TomListForm` reports `hasStructuralChanges`.

### External binding mutations (sibling-form propagation)

`TomForm._onBindingExternallyChanged` fires when the underlying `TomClass` mutates from outside the form (for example: another form bound to the same class, or imperative code touching `order.items.add(...)`). The fix in this iteration moved `_changes.fire()` **before** the `if (isDirty) return;` early-exit:

```dart
void _onBindingExternallyChanged() {
  if (_writingBackToBinding) return;
  final binding = _binding;
  if (binding == null) return;
  // Always notify dependent UI — external mutations may have flipped
  // isDirty (e.g. via a sibling TomListForm removing a nested element)
  // and the "Save / Discard" buttons must re-read aggregate state.
  _changes.fire();
  if (isDirty) return;
  // ... refresh field values from binding
}
```

Without this, a sibling form removing a row from a shared `TomList` would leave the outer form dirty but never notify its `_changes` channel, leaving Save/Discard buttons frozen.

---

## 4. TomInlineListForm — flat row layout

**File:** `lib/src/forms/list/tom_inline_list_form.dart`

Renders a `TomListForm` as a vertical column of always-visible row bodies. Use this when the natural editing UX is *"every row is always visible and always editable"* — order-items inline tables, contact-info lists, etc.

### Signature

```dart
class TomInlineListForm<TItem extends TomClass, TForm extends TomForm<TItem>>
    extends TomListBase {
  TomInlineListForm({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.listForm,
    required this.rowBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.toolbarBuilder,
    this.emptyBuilder,
    this.rowSeparatorBuilder,
    EdgeInsetsGeometry? padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.reorderable = false,
    this.onReorder,
    this.proxyDecorator,
  });

  final TomListForm<TItem, TForm> listForm;
  final Widget Function(BuildContext, int index, TForm rowForm) rowBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? headerBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? footerBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? toolbarBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final Widget Function(BuildContext, int index)? rowSeparatorBuilder;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;
  final bool reorderable;
  final void Function(int from, int to)? onReorder;
  final Widget Function(Widget child, int index, Animation<double> animation)?
      proxyDecorator;
}
```

### Render order

```
padding
└─ Column (mainAxisSize.min, crossAxisAlignment)
   ├─ headerBuilder?(ctx, listForm)
   ├─ rows (with rowSeparatorBuilder between consecutive rows)  OR  emptyBuilder?(ctx)
   ├─ footerBuilder?(ctx, listForm)
   └─ toolbarBuilder?(ctx, listForm)
```

### What the widget does for you

- Observes `listForm` and rebuilds on structural changes and per-row field edits.
- Re-wires the observer when `widget.listForm` identity changes across `didUpdateWidget`.
- Keeps an `mainAxisSize.min` Column so it can be embedded inside other scroll views.
- When `reorderable: true`, wraps rows in a shrink-wrapped `ReorderableListView` (no inner scrolling) and normalises the destination index to `TomListForm` semantics — `onReorder` receives `to` as the post-move position, **not** the pre-removal index that `ReorderableListView` reports natively.

### What you supply

- `rowBuilder` — the row body. Receives the row's own `TForm` (== `listForm[index]`). Wire delete buttons / drag handles per row inside this builder.
- The chrome around the list (header, footer, toolbar, empty state, row separators).
- For drag reordering: set `reorderable: true` and place a `TomReorderHandle(index: i)` somewhere in the row body so the user has a stable grab target. `rowSeparatorBuilder` is ignored in reorderable mode — put separator chrome inside the row body.

### Example

```dart
TomInlineListForm<OrderItem, OrderItemForm>(
  listForm: form.items,
  headerBuilder: (ctx, list) => Row(children: [
    Text('Items (${list.length})'),
    const Spacer(),
    Text('Total: \$${_orderTotal()}'),
  ]),
  emptyBuilder: (_) => const Text('No items yet.'),
  rowSeparatorBuilder: (_, _) => const Divider(height: 1),
  rowBuilder: (ctx, i, rowForm) => _ItemRow(
    form: rowForm,
    onRemove: () => form.items.removeAt(i),
  ),
  toolbarBuilder: (ctx, list) => FilledButton.tonalIcon(
    icon: const Icon(Icons.add),
    label: const Text('Add row'),
    onPressed: () => list.add(),
  ),
)
```

### Where it is used in the demo app

- `customer_hd_panes.dart` — `OrderDetailPane` uses it for the order-items inline table (refactored from a manual `DataTable` build).
- `demo_h_c_editable_table.dart` — Variant B uses it for the column-of-rows variant whose chrome (header row, fixed-width cells) is supplied by builders.

### Resources and authorization

| Key                  | Type        | Default                |
| -------------------- | ----------- | ---------------------- |
| `<basePath>.padding` | EdgeInsets  | (no padding)           |
| `<basePath>.empty`   | string      | (no auto-empty widget) |

The widget passes through the standard `TomPolicyNodeBase` gate at `<basePath>` — `none` hides the entire list, `disabled` greys it out and absorbs pointers, `read` applies the readonly visual treatment. Per-row authorization is **not** supported; the same auth applies to every row. Authorize the row's *fields* via the field widgets themselves (their tomId resolves under the row form's scope, not the list's). See [§11](#11-resources-and-authorization).

---

## 5. TomExpandableListForm — drill-down rows

**File:** `lib/src/forms/list/tom_expandable_list_form.dart`

Renders a `TomListForm` as a sequence of rows that toggle between a compact summary and a full editor body. Use this when rows are *individually heavy* (many fields, validation panels, sub-tables) and the natural UX is *"browse the list, drill into one row at a time"*.

### Expansion policy

```dart
enum TomExpansionPolicy {
  singleOpen,   // default — opening a row collapses any other open row
  multipleOpen, // multiple rows can be expanded concurrently
}
```

### Controller

```dart
class TomExpandableListFormController extends ChangeNotifier {
  TomExpandableListFormController({Set<int>? initialExpanded});

  Set<int> get expanded;             // unmodifiable view
  bool isExpanded(int index);

  // Programmatic — ALL three bypass the widget's onBeforeChange veto by
  // design, so code-driven flows like "after save, collapse open rows"
  // do not get gated by per-row validation.
  void expand(int index, {TomExpansionPolicy policy = TomExpansionPolicy.singleOpen});
  void collapse(int index);
  void collapseAll();
}
```

The widget creates an internal controller when you don't provide one. Pass your own when you need to drive expansion from the outside (e.g. `_expandController.collapseAll()` after `_form.save()` succeeds).

### Signature

```dart
class TomExpandableListForm<TItem extends TomClass, TForm extends TomForm<TItem>>
    extends TomListBase {
  TomExpandableListForm({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.listForm,
    required this.summaryBuilder,
    required this.bodyBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.toolbarBuilder,
    this.emptyBuilder,
    this.rowSeparatorBuilder,
    TomExpansionPolicy? policy,
    this.controller,
    this.initialExpanded,
    this.onBeforeChange,
    this.onExpansionChanged,
    EdgeInsetsGeometry? padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.reorderable = false,
    this.onReorder,
    this.proxyDecorator,
  });

  final TomListForm<TItem, TForm> listForm;
  final Widget Function(BuildContext, int index, TForm rowForm) summaryBuilder;
  final Widget Function(BuildContext, int index, TForm rowForm) bodyBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? headerBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? footerBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? toolbarBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final Widget Function(BuildContext, int index)? rowSeparatorBuilder;
  final TomExpansionPolicy policy;
  final TomExpandableListFormController? controller;
  final Set<int>? initialExpanded;
  final Future<bool> Function(int index, TForm rowForm, bool willOpen)? onBeforeChange;
  final void Function(Set<int> expanded)? onExpansionChanged;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;
  final bool reorderable;
  final void Function(int from, int to)? onReorder;
  final Widget Function(Widget child, int index, Animation<double> animation)?
      proxyDecorator;
}
```

### Veto contract — `onBeforeChange`

Called for **every row whose open state is about to flip** as part of a single user toggle, including (under `singleOpen`) the previously-open row that is about to close. Return `false` to cancel — the row stays in its current state.

For *"validate before switching away"*:

```dart
Future<bool> _onBeforeRowExpansionChange(
    int index, OrderItemForm form, bool willOpen) async {
  if (willOpen) return true;  // opens always allowed
  final errors = await form.validate();
  if (errors.isEmpty) return true;
  ScaffoldMessenger.of(context).showSnackBar(/* errors snackbar */);
  return false;
}
```

The veto is consulted on every row that needs to change state. For `singleOpen`: when row B is tapped while row A is open, the widget first runs `onBeforeChange(A, ..., false)`; if that returns true it then runs `onBeforeChange(B, ..., true)`. If either returns false, the toggle is fully cancelled.

### Render order

```
padding
└─ Column (mainAxisSize.min)
   ├─ headerBuilder?(ctx, listForm)
   ├─ rows (each row = summary tap-target + optional body) with optional separators  OR  emptyBuilder
   ├─ footerBuilder?(ctx, listForm)
   └─ toolbarBuilder?(ctx, listForm)
```

Each row is a `Column` with:
- `GestureDetector(onTap: toggle)` wrapping `summaryBuilder(...)`
- `if (isExpanded) bodyBuilder(...)`

The widget is **Material-free** — it uses `GestureDetector`, not `ExpansionTile`, so it lives in `flutter/widgets.dart` and works equally in Material and Cupertino apps.

### Drag-to-reorder

Pass `reorderable: true`. Each row's `summaryBuilder` should embed a `TomReorderHandle(index: index)` so the user has a stable grab target — long-pressing the handle starts a drag, while tapping anywhere else still toggles expansion. After a drop, the controller's expanded set is remapped so a previously-open row stays open at its new position. As with `TomInlineListForm`, `onReorder` arguments are normalised to `TomListForm` semantics (post-move `to`).

### Example

```dart
TomExpandableListForm<OrderItem, OrderItemForm>(
  listForm: form.items,
  controller: _expandController,
  onBeforeChange: _onBeforeRowExpansionChange,
  headerBuilder: (ctx, list) => Row(children: [
    Text('Items (${list.length})'),
    const Spacer(),
    Text('Total: \$${_orderTotal()}'),
  ]),
  rowSeparatorBuilder: (_, _) => const Divider(height: 1),
  summaryBuilder: (ctx, i, row) => _SummaryRow(form: row, onRemove: () => form.items.removeAt(i)),
  bodyBuilder: (ctx, i, row) => _EditorBody(form: row),
  toolbarBuilder: (ctx, list) => FilledButton.tonalIcon(
    icon: const Icon(Icons.add),
    label: const Text('Add row'),
    onPressed: () async {
      // Programmatic expand — bypasses veto, so run the same gate
      // by hand if you want it.
      list.add();
      _expandController.expand(list.length - 1);
    },
  ),
)
```

### Where it is used in the demo app

- `demo_h_b_expandable_rows.dart` — primary usage. Replaces a hand-rolled `ExpansionTile` + key-rotation + `_expandedRow: int?` state machine.

### Resources and authorization

| Key                  | Type        | Default                                                  |
| -------------------- | ----------- | -------------------------------------------------------- |
| `<basePath>.padding` | EdgeInsets  | (no padding)                                             |
| `<basePath>.empty`   | string      | (no auto-empty widget)                                   |
| `<basePath>.policy`  | string      | `'singleOpen'` — also accepts `'multipleOpen'`           |

Authorization gate is identical to `TomInlineListForm` — the whole list shares one auth state, per-row auth is not supported, per-field auth lives on the row form's own field widgets. See [§11](#11-resources-and-authorization).

---

## 6. TomMasterDetailListForm — list ↔ detail layout

**File:** `lib/src/forms/list/tom_master_detail_list_form.dart`

Renders a `TomListForm` as a two-pane scaffold: a master pane on the left builds the row index (typically a `TomInlineListForm` with selection callbacks), a detail pane on the right edits the **row's own sub-form** (`listForm[selectedIndex]`). There is **no sibling form** — the detail pane sees the same `TForm` instance the list owns, so dirty / structural changes propagate without the divergence problem `TomMasterDetailScaffold` had to work around.

### Signature

```dart
class TomMasterDetailListForm<TItem extends TomClass, TForm extends TomForm<TItem>>
    extends TomListBase {
  TomMasterDetailListForm({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.listForm,
    required this.masterBuilder,
    required this.detailBuilder,
    this.emptyDetailBuilder,
    double? masterPaneWidth,
    double? gap,
    EdgeInsetsGeometry? padding,
    this.guardUnsavedSelectionChange = true,
    this.initialSelectedIndex,
  });

  final TomListForm<TItem, TForm> listForm;

  /// Builds the master pane. Receives the list, the current selection,
  /// and the callback that mutates selection (consults the unsaved-changes
  /// guard when enabled).
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
    int? selectedIndex,
    Future<void> Function(int? index) selectIndex,
  ) masterBuilder;

  /// Builds the detail pane for the currently selected row. Receives the
  /// row's own [TForm].
  final Widget Function(BuildContext context, int selectedIndex, TForm rowForm)
      detailBuilder;

  /// Optional widget shown when no row is selected.
  final Widget Function(BuildContext context)? emptyDetailBuilder;

  final double masterPaneWidth;
  final double gap;
  final EdgeInsetsGeometry? padding;
  final bool guardUnsavedSelectionChange;
  final int? initialSelectedIndex;
}
```

> Note: `masterPaneWidth`, `gap`, and `padding` are resolved from resources when omitted (see [§11](#11-resources-and-authorization)). The `final` fields above show the *effective* values held by the widget after resolution.

### Selection lifecycle

- Selection is owned by the widget; the master pane reads it via `selectedIndex` and mutates it via `selectIndex(int?)`.
- `selectIndex` runs `guardUnsavedChanges(form: listForm[currentSelected], action: apply)` when `guardUnsavedSelectionChange` is true (default), so switching away from a dirty row pops Save / Discard / Cancel.
- After Save in the dialog the new selection is applied; after Discard the row is rolled back and the new selection is applied; after Cancel the existing selection stays.
- When the underlying list shrinks past the current selection (e.g. the user removes the selected row from the master pane's toolbar), the widget defensively clears the selection via `onNotify`.

### Master pane recipe

The canonical master pane is a stateless widget that combines `TomInlineListForm` (with `reorderable: true`) for the row index and `TomListFormToolbar` for Add / Remove / Move-up / Move-down — see `customer_hd_panes.dart` (`AddressMasterPane`, `OrderMasterPane`) and `demo_h_a_master_detail.dart` (`_CustomerMasterPane`):

```dart
class _CustomerMasterPane extends StatelessWidget {
  const _CustomerMasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<Customer, CustomerDetailForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget build(BuildContext context) => Column(children: [
    Expanded(
      child: TomInlineListForm<Customer, CustomerDetailForm>(
        listForm: listForm,
        reorderable: true,
        onReorder: (from, to) {
          // Keep selection on the dragged row.
          if (selectedIndex == from) selectIndex(to);
          else if (selectedIndex != null) {
            final cur = selectedIndex!;
            if (from < cur && cur <= to) selectIndex(cur - 1);
            else if (to <= cur && cur < from) selectIndex(cur + 1);
          }
        },
        rowBuilder: (ctx, i, rowForm) => _Tile(
          customer: rowForm.currentBinding,
          index: i,
          isSelected: i == selectedIndex,
          onTap: () => selectIndex(i),
        ),
      ),
    ),
    TomListFormToolbar<Customer, CustomerDetailForm>(
      listForm: listForm,
      selectedIndex: selectedIndex,
      onSelectionChanged: selectIndex,
    ),
  ]);
}
```

### Two scaffolds, one list

Multiple `TomMasterDetailListForm` instances may share the *same* `TomListForm` — selection is per-scaffold (a `TomNInt` owned by each widget's state), but structural mutations and field edits propagate through the shared list, so both detail panes redraw immediately and the toolbars stay in sync. Demo H-A renders two scaffolds side-by-side over one `CustomerListForm` to make this concrete.

### Where it is used in the demo app

- `demo_h_a_master_detail.dart` — two scaffolds over a shared customer list.
- `demo_h_d_customer_form.dart` and `demo_h_e_customer_form_ro.dart` — a single `CustomerHDForm` houses two `TomMasterDetailListForm`s, one for the customer's shipping addresses and one for the customer's orders. Each detail pane edits the row's own form (`ShippingAddressHDForm` / `OrderHDForm`); the orders detail pane in turn embeds a `TomInlineListForm` over the row form's `items` list.

### Resources and authorization

| Key                          | Type        | Default                       |
| ---------------------------- | ----------- | ----------------------------- |
| `<basePath>.padding`         | EdgeInsets  | (no padding)                  |
| `<basePath>.empty`           | string      | the built-in italic hint      |
| `<basePath>.masterPaneWidth` | double      | `280`                         |
| `<basePath>.gap`             | double      | `16`                          |

Authorization gate is identical to the other list-form widgets — `none` hides both panes, `disabled` greys the whole scaffold, `read` applies readonly styling. Per-row auth is not supported; per-field auth lives on the row form's own field widgets. See [§11](#11-resources-and-authorization).

---

## 7. Reorder helpers — TomReorderHandle and TomListFormToolbar

**Files:** `lib/src/forms/list/tom_reorder_handle.dart`, `lib/src/forms/list/tom_list_form_toolbar.dart`

These two stateless widgets keep list-mutation chrome consistent across the demos and apps. They are deliberately small — drop them in instead of hand-rolling a `Wrap` of `IconButton`s every time.

### TomReorderHandle

A drag handle that wraps a `ReorderableDragStartListener` so it works inside any of the three `reorderable: true` widgets. Add it anywhere inside the row body (typically at the start as a leading element) — long-pressing the handle starts the drag.

```dart
TomReorderHandle({
  Key? key,
  String? tomId,
  TomGroup? tomGroup,
  TomScope? scope,
  TomAuthorizer? authorizer,
  TomAuthorizerStrategy? authorizerStrategy,
  TomUiStateController? uiStateController,
  required int index,
  IconData? icon,
  double? size,
  Color? color,
  String? tooltip,
  EdgeInsetsGeometry? padding,
})
```

The handle uses a tooltip and a grab-cursor `MouseRegion` so the affordance is clear on every platform. It's the one piece of UI the row builder MUST supply — `TomInlineListForm` and `TomExpandableListForm` set `buildDefaultDragHandles: false` so long-pressing the row body doesn't accidentally start a drag (which would interfere with row taps, expansion toggles, and text selection inside fields).

**Resources** (resolved when `tomId` is set):

| Key                  | Type       | Default                |
| -------------------- | ---------- | ---------------------- |
| `<basePath>.icon`    | icon       | `Icons.drag_indicator` |
| `<basePath>.size`    | double     | `18`                   |
| `<basePath>.color`   | color      | ambient `IconTheme`    |
| `<basePath>.tooltip` | string     | `'Drag to reorder'`    |
| `<basePath>.padding` | EdgeInsets | `H4 / V6`              |

**Authorization** is per-handle (i.e. per *kind* of handle in a list, not per row — pass the same `tomId` to every row's handle). `none` hides the handle, `disabled`/`read` greys it out and absorbs the drag gesture so the row stays put.

### TomListFormToolbar

Add / Remove / Move up / Move down for a `TomListForm`. Each action is enabled only when meaningful for the current selection (e.g. *Move up* disabled at index 0; *Remove* disabled when nothing is selected). After Add the new row is selected; after Remove the selection clears; after Move the selection follows the moved row.

```dart
TomListFormToolbar<TItem, TForm>({
  Key? key,
  String? tomId,
  TomGroup? tomGroup,
  TomScope? scope,
  TomAuthorizer? authorizer,
  TomAuthorizerStrategy? authorizerStrategy,
  TomUiStateController? uiStateController,
  required TomListForm<TItem, TForm> listForm,
  int? selectedIndex,
  Future<void> Function(int? index)? onSelectionChanged,
  bool showAdd = true,
  bool showRemove = true,
  bool showMoveUp = true,
  bool showMoveDown = true,
  bool dense = true,
  String? addLabel,
  String? removeLabel,
  String? moveUpLabel,
  String? moveDownLabel,
  IconData? addIcon,
  IconData? removeIcon,
  IconData? moveUpIcon,
  IconData? moveDownIcon,
  double? iconSize,
  List<Widget>? beforeActions,
  List<Widget>? afterActions,
  Future<bool> Function()? beforeAdd,
  Future<bool> Function(int index)? beforeRemove,
  Future<bool> Function(int from, int to)? beforeMove,
})
```

**Per-button resources** (resolved when `tomId` is set; replace `<btn>` with `add` / `remove` / `moveUp` / `moveDown`):

| Key                       | Type   | Default                                  |
| ------------------------- | ------ | ---------------------------------------- |
| `<basePath>.<btn>.label`  | string | constructor arg, then per-button default |
| `<basePath>.<btn>.icon`   | icon   | constructor arg, then per-button default |
| `<basePath>.<btn>.tooltip`| string | (none)                                   |

The toolbar also resolves `<basePath>.iconSize` (double, default `16`).

**Authorization** is per-button — each button's effective auth is `TomAuthorization.resolveAuth('<basePath>.<btn>')` and is computed once at construction. `none` hides the button entirely, anything below `full` keeps it visible but the callback is null (rendered as disabled). The toolbar itself uses the standard `TomPolicyNodeBase` gate at `<basePath>` for the wrapping container, so authorising the toolbar as a whole disables the entire button row in one move.

The `beforeAdd` / `beforeRemove` / `beforeMove` veto callbacks are the toolbar's gate hook. They mirror `TomExpandableListForm.onBeforeChange` — return `false` to cancel the action. The canonical use is *"validate the open row before letting the user add a sibling"* (see `demo_h_b_expandable_rows.dart`):

```dart
TomListFormToolbar<OrderItem, OrderItemForm>(
  listForm: items,
  selectedIndex: _expandController.expanded.firstOrNull,
  beforeAdd: _guardSwitchAwayFromExpanded, // refuses if open row invalid
  onSelectionChanged: (i) async {
    if (i != null && i == items.length - 1) _expandController.expand(i);
  },
)
```

Use `showAdd: false` etc. to hide individual buttons, or `beforeActions` / `afterActions` to inject custom buttons around the standard set without losing the selection wiring.

---

## 8. Nested lists (list inside a list inside a form)

`TomListForm`s nest naturally: a row sub-form can itself declare a `TomListForm` member.

```
CustomerHDForm (TomForm<CustomerHD>)
├── orders (TomListForm<OrderHD, OrderHDForm>)
│   └── OrderHDForm
│       ├── orderId, orderDate, shippingLabel  (fields)
│       └── items (TomListForm<OrderItemHD, OrderItemHDForm>)
│           └── OrderItemHDForm
│               └── productName, quantity, unitPrice, notes  (fields)
└── shipping (TomListForm<ShippingAddressHD, ShippingAddressHDForm>)
```

Lifecycle propagation walks the whole tree:

- `customerForm.save()` ➜ saves `orders` (which saves each `OrderHDForm`, which saves each row's `items`, which saves each `OrderItemHDForm`).
- `customerForm.discard()` ➜ symmetric rollback all the way down.
- `customerForm.validate()` ➜ aggregates errors from every level into one event at the root, plus per-source events along the way.
- `customerForm.isDirty` ➜ true if anything in the whole tree is dirty or has structural changes.

Rendering a nested list is just a matter of dropping a `TomInlineListForm` or `TomExpandableListForm` inside the outer row's body builder:

```dart
TomInlineListForm<OrderHD, OrderHDForm>(
  listForm: customerForm.orders,
  rowBuilder: (ctx, i, orderForm) => Card(
    child: Column(children: [
      orderForm.orderId.widget,
      orderForm.orderDate.widget,
      // Nested list — no extra wiring needed.
      TomInlineListForm<OrderItemHD, OrderItemHDForm>(
        listForm: orderForm.items,
        rowBuilder: (ctx, j, itemForm) => _ItemRow(form: itemForm),
      ),
    ]),
  ),
)
```

Each nested widget observes its own `TomListForm`. Structural changes at any depth fire through the parent chain to the root form's `_changes` channel — outer Save/Discard buttons re-evaluate automatically.

---

## 9. Choosing a renderer

| Need | Use |
| ---- | --- |
| All rows always visible, all rows always editable. | `TomInlineListForm` (set `reorderable: true` for drag-and-drop) |
| Rows are heavy; only one is being edited at a time. | `TomExpandableListForm` (default `singleOpen` policy; set `reorderable: true` for drag-and-drop) |
| Rows are heavy; users compare/edit several in parallel. | `TomExpandableListForm` with `policy: multipleOpen` |
| Long left-pane "list of names" + right-pane "edit one". | `TomMasterDetailListForm` — the detail pane sees the row's own `TForm`, so there is no sibling form. |
| Standard Add / Remove / Move-up / Move-down chrome over any list. | `TomListFormToolbar` (slot it into a `toolbarBuilder` or beneath a master pane). |
| Drag-to-reorder. | Set `reorderable: true` on the inline / expandable / master pane and embed a `TomReorderHandle(index: i)` in each row. |
| You need a `DataTable`-specific feature (sortable columns, row stripes, native column alignment). | Hand-rolled `DataTable` over `TomListForm.length`, wrapped in a `ListenableBuilder` over a relay listener that fires on the list-form's event bus. |

> **`TomMasterDetailScaffold` was removed in this iteration.** It bound a sibling `TFormB` to the selected row, which forced every consumer to deal with the divergent-`_forms`-array problem (§3 talked about the dirty-propagation regression that change of contract created). `TomMasterDetailListForm` replaces it everywhere — the detail pane reads `listForm[selectedIndex]` directly, so there is exactly one `_forms` array per list and no propagation gap.

---

## 10. Patterns the components do NOT solve

The list-form widgets are deliberately layout-light. They do **not**:

- Render the surrounding card / panel chrome. Drop the widget inside whatever container fits the screen — see the demos for `Card` + `Padding` recipes.
- Provide a built-in "Are you sure?" before delete. Wrap the delete callback yourself — the components stay opinion-free on dialogs (the unsaved-changes guard in `TomMasterDetailListForm` is the one exception, and it's opt-out via `guardUnsavedSelectionChange: false`).
- Sync expansion state across `TomExpandableListForm` instances. If two widgets render the same `TomListForm`, give each its own controller; sharing one controller would cause both widgets to flip together.
- Sync selection across `TomMasterDetailListForm` instances. Each scaffold owns its own `TomNInt` so two panes over the same list edit independently. If you need a shared selection, lift it into a parent and pass an explicit selection observable.

---

## 11. Resources and authorization

The list-form widgets and their helpers participate in the standard Tom resource / scope / authorization pipeline — same `tomId`, `tomGroup`, `scope`, `authorizer`, `authorizerStrategy`, and `uiStateController` constructor parameters as every other Tom widget, same resolution semantics, same `TomPolicyNodeBase` gate at render time.

### Authorization model

There are exactly two levels of authorization for a list-form widget:

1. **The whole list-form widget.** Authorizes the entire renderer at `<basePath>`. `none` hides the list (and its toolbar / chrome), `disabled` greys it out and absorbs pointers, `read` applies the readonly visual treatment, `full` builds normally. This single auth state applies to *every* row — there is no per-row authorization by design.
2. **The fields inside the row's detail form.** Authorized normally via each `TomField`'s own `tomId` (resolved relative to the row form's scope). Because every row uses the *same* form factory, a given field's auth state is identical across every row of the list — checking the schema's `customer.shippingAddresses[*].postalCode` field once authorizes the postal-code field in every row.

This deliberately rules out per-row gating ("hide the delete button on the third row only"). If you need that, encode the predicate in the row sub-form's auth resolver — i.e. compute the per-row state inside the row form's scope, not the list widget's scope.

The two helpers (`TomListFormToolbar`, `TomReorderHandle`) follow the same pipeline. The toolbar is unique in that it adds *per-button* sub-paths (`<basePath>.add` etc.) so individual actions can be hidden or disabled while leaving the rest of the toolbar interactive.

### Resource resolution conventions

Every constructor argument that has a hard-coded default is *also* resource-resolvable. The resolution order is:

1. The constructor argument, if non-null.
2. The resource value at `<basePath>.<key>`, if defined.
3. The hard-coded default.

This matches the field widgets exactly — see [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) Phase 0b for the full pipeline.

Per-widget resource keys are listed in each widget's "Resources and authorization" subsection above. The conventions across the layer:

| Key suffix         | Used by                                          |
| ------------------ | ------------------------------------------------ |
| `padding`          | `TomInlineListForm`, `TomExpandableListForm`, `TomMasterDetailListForm` |
| `empty`            | `TomInlineListForm`, `TomExpandableListForm`, `TomMasterDetailListForm` (text fallback when no `emptyBuilder` is supplied) |
| `policy`           | `TomExpandableListForm` — `'singleOpen'` or `'multipleOpen'` |
| `masterPaneWidth`  | `TomMasterDetailListForm`                        |
| `gap`              | `TomMasterDetailListForm`                        |
| `<btn>.label`      | `TomListFormToolbar` per-button label            |
| `<btn>.icon`       | `TomListFormToolbar` per-button icon             |
| `<btn>.tooltip`    | `TomListFormToolbar` per-button tooltip          |
| `iconSize`         | `TomListFormToolbar`                             |
| `icon` / `size` / `color` / `tooltip` | `TomReorderHandle`            |

### Worked example

```dart
TomInlineListForm<OrderItem, OrderItemForm>(
  tomId: 'orderItems',
  scope: TomScope.current,             // resolves <scopePath>.orderItems
  authorizer: form.itemsAuthorizer,    // optional per-instance override
  listForm: form.items,
  rowBuilder: (ctx, i, row) => Row(children: [
    TomReorderHandle(tomId: 'reorderHandle', index: i),
    Expanded(child: row.label.widget), // row.label resolves under the row form's scope
    IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: () => form.items.removeAt(i),
    ),
  ]),
  toolbarBuilder: (ctx, list) => TomListFormToolbar(
    tomId: 'itemsToolbar',
    listForm: list,
  ),
  reorderable: true,
)
```

With this setup, declaring `<scopePath>.orderItems.empty = 'No items yet — add one to get started.'` in resources gives the inline list a default empty state text without touching any code, and the same `tomId`-driven auth state controls visibility of the entire renderer. Per-button resources like `<scopePath>.itemsToolbar.add.label = 'Add item'` rename only the Add button's label, leaving the others alone.

---

## See also

- [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) — full forms framework specification (Phases 0–6, field types, validation, auth, layout).
- [tom_observable_state_management.md](tom_observable_state_management.md) — the observable layer (`TomClass`, `TomList`, `TomObserver`) that `TomListForm` builds on.
- [tom_ui_design_architecture.md](tom_ui_design_architecture.md) — wrapping patterns, ACL layout, scope system.
