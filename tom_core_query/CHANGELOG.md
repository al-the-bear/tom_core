# Changelog

## 0.1.0

### Added

- **Conditions.** `TomPropertyQuery`, a conjunction of `TomQueryTerm`s over a
  `TomPropertyLookup`; the predicates `TomAnyOf` (with segment-aware
  hierarchical matching through `tomCoversPath`), `TomDateWindow` and
  `TomUnset`; `TomPropertyPredicate` for an application's own.
- **Sorting.** `TomPropertySorter`, unset last in both directions and ties
  broken ascending.
- **The index contract.** `TomIndex`, `TomIndexEntry`, and `TomIndexQuery`,
  the one implementation of `query`.
- **Backlinks.** `TomBacklinkIndex` over a `TomRefSource`, with `TomRefSlot`
  and `TomBackref`.
