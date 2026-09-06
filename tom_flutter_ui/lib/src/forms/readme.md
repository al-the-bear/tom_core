# forms

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The declarative form system: the `TomForm<T>` data model, the `FormFieldFamily`
factory that picks the Material or Cupertino concrete per field, validators,
selectable option sources, the form event bus, and the `TomFormStyle` decoration
system. Fields bind to the kernel's `TomObject<T>` state and drive bind / save /
discard, validation, and authorization.

## Key types

> **Not an inventory.** The field catalogue is a parallel Material/Cupertino set
> running to dozens of classes, and the table below names the machinery a reader
> has to understand rather than every field. The readme states the rule and
> points at the list instead of copying it.
>
> **The rule:** a field is `TomForm<Kind><Variant>`, with `TomCupertinoForm…`
> for the Cupertino half of the pair, and you do not usually name either — you
> declare the field once and `FormFieldFamily` builds the concrete for the
> family in scope. Reach for a concrete only when a screen is deliberately
> single-family.
>
> **The complete list** is Appendix C of
> [`doc/tom_ui_widgets_forms.md`](../../../doc/tom_ui_widgets_forms.md), which
> is generated from `lib/src/forms/fields` and held to it by
> `tool/check_doc_class_inventories.py` in both directions — a class missing
> from the appendix and an appendix entry naming no class are both faults.

| Type | Responsibility |
| ---- | -------------- |
| `TomForm<T>` | The form base — bind / save / discard, validation, authorization |
| `FormFieldFamily` | Factory selecting the Material (`.material`) or Cupertino (`.cupertino`) concrete |
| `TomFormStyle` / `TomFormStyleScope` | Presets (`material3`, `compact`, `bordered`) + inherited scoping |
| `LabelPlacement` / `DescriptionPlacement` / `RequiredIndicator` | Field-chrome controls |
| `TomSelectableSource` / `StaticSelectableSource` / `SelectableItem` | Pluggable option sources |
| `TomEnumSelectableSource<E>` | Enum options labelled from the text bundle (`<scope>.<enumName>.<value>`), relabelled on a locale change |
| `FormValidationError` | Cross-field validation result keyed by a resource error key |
| `TomFormEvent` / `TomFormEventSource` / `TomFormEventListener` | The form event bus |
| `TomListForm` / `TomMasterDetailListForm` | Collection / master-detail forms |

The field catalogue spans a parallel Material/Cupertino set — string
(`TomFormStringInput`, `TomFormStringDropdown`, …), boolean, numeric, date/time,
enum/object, file, and nullable wrappers.

## Quick start

```dart
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void editName() {
  // The family hands back the platform concrete; the field owns its value.
  final family = FormFieldFamily.material; // or .cupertino
  final name = family.stringInput('user.name', 'Alice');

  name.set('Bob');
  name.commit(); // 'Bob' becomes the new initial value
  name.reset();  // reverts to the committed value → 'Bob'

  final countries = StaticSelectableSource<String>(const [
    SelectableItem(value: 'de', label: 'Germany'),
    SelectableItem(value: 'jp', label: 'Japan', enabled: false),
  ]);
  print(countries); // a sync option source for a dropdown/radio field
}
```

A real form subclasses `TomForm<T>`, declares its fields, and builds them in
`createFormElements()`; `TomFormStyleScope` applies a preset to the subtree.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
