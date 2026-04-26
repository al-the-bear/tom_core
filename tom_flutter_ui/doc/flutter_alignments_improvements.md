# Flutter Alignments & Improvement Areas

Analysis of Flutter's built-in infrastructure and how it relates to the Tom Flutter UI form and widget frameworks.  Recorded 2026-04-26 as a reference for future development decisions.

---

## Flutter's built-in infrastructure

### 1. `Form` / `FormField<T>` — Flutter's own form layer

Flutter ships `Form` + `FormField<T>` + `TextFormField`. The contract:
- `Form` holds a `GlobalKey<FormState>`; you call `formState.validate()`, `.save()`, `.reset()` imperatively.
- `FormField<T>` carries a local value, a validator, an `onSaved` callback, and a `didChange()` method.
- Validation is **pull-based**: nothing happens until you call `validate()`.

TomForm deliberately differs: it is **push-based** (observables fire on every value change) and the form's `save`/`discard` cycle is explicit state management, not a one-shot save callback.  The two models are genuinely incompatible in philosophy, so replacing one with the other does not make sense.

**Worth revisiting:** Flutter's `FormField` has `AutovalidateMode` with three values (`disabled`, `always`, `onUserInteraction`). TomForm has `autoValidate: bool`, which is simpler but less granular.  The three-mode enum may be worth adopting.

---

### 2. `Actions` & `Intents` — the command pattern

Flutter's `Intent` + `Action<T>` + `Shortcuts` + `Actions` widget is a full command pattern:

```dart
// Somewhere in the widget tree:
Shortcuts(
  shortcuts: {
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
        SaveFormIntent(),
  },
  child: Actions(
    actions: {
      SaveFormIntent: CallbackAction<SaveFormIntent>(
          onInvoke: (_) => form.save()),
    },
    child: child,
  ),
)
```

`Actions.invoke(context, SaveFormIntent())` works from anywhere in the subtree, including buttons.  This decouples Save/Discard/Add/Delete buttons from a specific form instance — the tree wires the action.

**Current TomForm state:** Not used at all.

**Recommended:** Adopt Actions & Intents for toolbar commands (Save, Discard, Add row, Delete row).  The `TomListFormToolbar` and per-form Save/Discard buttons are natural candidates.  Defining standard Intents in `tom_flutter_ui` would allow apps to bind keyboard shortcuts without touching button code.

---

### 3. Undo / redo

Two distinct layers exist in Flutter:

**Text-level (already works for free):** `TextField` and `EditableText` have built-in undo/redo via `UndoHistoryController` (Flutter 3.7+).  Every keystroke in `TomFormDateTextInput`, `TomFormTimeTextInput`, and text string fields already has Ctrl+Z undo — no work needed.

**Form-level (no built-in support):** There is no Flutter mechanism for undoing a picker selection or reverting a slider move.  The `discard()` on `TomForm` is a coarse full-reset.  Granular form-level undo would require a value-snapshot stack per field.  Flutter provides `UndoHistory<T>` as a generic widget wrapper, but it is designed for single values, not coordinated multi-field rollback.  If granular undo matters it is custom work; Flutter will not help.

---

### 4. `FocusTraversalGroup` and `FocusTraversalPolicy`

Flutter has a rich focus traversal system: `FocusTraversalGroup` with pluggable policies (`ReadingOrderTraversalPolicy`, `OrderedTraversalPolicy`, `WidgetOrderTraversalPolicy`).

**Current TomForm state:** Tab order is not controlled; the default widget-order traversal applies.

**Gap:** For multi-column `AclContainer` layouts the reading-order traversal can jump between columns unexpectedly (left-column field → right-column field → next left-column field rather than down each column).  Worth wiring `OrderedTraversalPolicy` into the layout system for multi-column forms.

---

### 5. `TextInputFormatter` — masking and filtering

`TextInputFormatter` intercepts every keystroke before it reaches the controller.  Flutter provides `FilteringTextInputFormatter` (whitelist/blacklist characters) as a building block.

**Relevance:** A date mask formatter that auto-inserts separators (e.g. types `12` → inserts `.` → `12.`) and blocks non-digit input would make `TomFormDateTextInput` and related fields significantly more polished.  The auto-insert-separator logic is custom work on top of `FilteringTextInputFormatter`.  Not a gap in the current framework — an identified enhancement.

---

### 6. `AutofillGroup` / `AutofillHints`

`AutofillGroup` + `autofillHints` on `TextField` enables password managers and keyboard autofill (email, name, phone, postal code, etc.).  Currently not wired into any TomForm text field.

**Priority:** Low for business back-office forms; useful on consumer-facing name / email / phone fields.

---

### 7. `RestorableState` / `RestorationMixin`

Flutter's state restoration system lets widget state survive process death (Android back-stack, iOS memory pressure).  `RestorableValue<T>` wraps primitive values; `RestorationMixin` registers them with the engine.

**Current TomForm state:** Not implemented.  TomForm's observable state lives outside the widget tree, so restoration would need to snapshot field values into `RestorablePrimitive*` wrappers and restore on `initState`.

**Priority:** Out of scope for the current phase.

---

## Summary

| Flutter mechanism | Current TomForm state | Recommended action |
|---|---|---|
| `Form` / `FormField` | Parallel push-based approach (deliberate) | Consider adopting `AutovalidateMode` enum |
| `Actions` & `Intents` | Not used | **High value** — adopt for toolbar commands and keyboard shortcuts |
| Text-level undo (`UndoHistoryController`) | Works for free in TextFields | Nothing needed |
| Form-level undo | Not implemented | Custom work if required; no Flutter help available |
| `FocusTraversalGroup` | Not controlled | **Worth adding** for multi-column ACL layouts |
| `TextInputFormatter` | Not used in date/time fields | Enhancement — auto-separator insertion in date/time fields |
| `AutofillGroup` | Not wired | Low priority; useful for name / email / phone fields |
| `RestorableState` | Not implemented | Out of scope for current phase |

The two highest-value items that do not require large structural changes are:

1. **Actions & Intents for toolbar commands** — standard Intents in `tom_flutter_ui` + `Shortcuts` wiring in apps.
2. **`FocusTraversalGroup` for multi-column forms** — clean tab order in `AclContainer`-based layouts.
