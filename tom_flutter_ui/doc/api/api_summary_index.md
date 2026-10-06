# Tom Flutter UI API Reference: Index

Symbol-level API summaries for this package's larger modules, one file per
module, under `doc/api/`. Each lists every public type its module's barrel
exports, with a section per type, and names every public static member. Which
modules get one is a stated rule, below.

`test/module_readme_inventory_test.dart` holds that claim: it discovers the
summaries from this directory, derives the required set from each module's
barrel, and fails on a type that has no section or a static that is never
named. So a summary that exists is complete, and one that falls behind the code
fails rather than misleading.

## Summaries

| Module | Summary | Covers |
| ------ | ------- | ------ |
| `advanced_container_layout` | [api_summary_advanced_container_layout.md](api_summary_advanced_container_layout.md) | The row-based layout engine: the fluent builder, the row and component model, and the widgets that render them. |
| `actions` | [api_summary_actions.md](api_summary_actions.md) | Business logic as typed, stateless, authorizable objects with undo and redo. |
| `custom` | [api_summary_custom.md](api_summary_custom.md) | The eight composites that are not form fields: authorization guards, list states, and loading affordances. |
| `forms` | [api_summary_forms.md](api_summary_forms.md) | The declarative forms framework: form and field bases, the Material and Cupertino field catalogues, styling, validation, events, selection sources, file transfer, and the list containers. |
| `resource_auth` | [api_summary_resource_auth.md](api_summary_resource_auth.md) | Resource resolution: colour and icon names to Flutter objects, and the environment and platform configuration they resolve against. |
| `widget_base` | [api_summary_widget_base.md](api_summary_widget_base.md) | The foundation every Tom widget stands on: the node chain carrying identity and authorization, the family taxonomy, and the two static resolvers. |

## Which modules get one

**A module earns a summary at ten exported public types.** Below that its own
`lib/src/<module>/readme.md` is the mirror — and not by assertion: an inventory
readme is held to every public type and every public static by the same test,
so a small module is checked, just checked somewhere else. A summary for
`groups` would be a fourth document over 297 lines of code and a fourth copy of
a two-entry list.

Types, not lines. The two disagree and the type count sorts the package
correctly: `resource_auth` declares 13 of them across 11,352 lines and wants a
summary, `theme` declares 4 across 365 and does not. A line threshold would be
measuring the generated tables inside one of them.

A **catalogue** module is outside the rule, and `widgets` is the reason the
exemption is not a shortcut. Its 299 public types are kept, checked and
answerable without a summary, in a form a markdown mirror cannot match:

- **The names.** `test/widgets/widget_census.dart` derives them from the
  sources; `widget_conformance_test.dart` asserts that
  `widget_conformance_registry.dart` holds precisely that set, in both
  directions.
- **The signatures.** The registry *constructs* every one of the 299, so a
  wrapper whose constructor changed shape fails to compile rather than fails to
  match a document. The parameters they share are derived from the base itself
  by `test/widget_base/base_parameter_claims_test.dart`, which fails the
  documents that describe a different list.
- **The counts and the family catalogue.** `widget_family_claims_test.dart`
  asserts every three-digit number the kit's documents quote against the
  census, and checks each catalogue row against the class declarations it
  names.

A 299-section hand-written mirror would restate all of that in a form nothing
compiles and nothing checks. `forms` is a catalogue too and has a summary
anyway — a catalogue module may have one, it is simply not owed one.

The threshold is a constant in `test/module_readme_inventory_test.dart`, which
derives each module's type count from its barrel and fails when a module
reaches it without a summary. So the rule is enforced rather than described,
and lowering it is a code change somebody has to make deliberately.

## Modules without a summary

| Module | Types | Why it has none |
| ------ | ----: | --------------- |
| `groups` | 2 | Below the threshold — `lib/src/groups/readme.md` is the mirror. |
| `theme` | 4 | Below the threshold — `lib/src/theme/readme.md` is the mirror. |
| `widgets` | 299 | Catalogue — names, signatures and counts are all held by the suites named above. |

Nothing is outstanding: every module at or above the threshold has its summary.
The test still carries the backlog set, now empty and held exactly, so a module
that reaches the threshold without one fails rather than joining a list nobody
reads. The difference between "small" and "unwritten" is a fact here rather than
a reader's guess, which is the whole reason this section is not simply three
names in a sentence.
