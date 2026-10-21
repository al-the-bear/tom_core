# Changelog

## 0.1.0

### Added

- **Cells.** `CellAddress`, `FormulaCell` (a literal, a formula or an embedded
  object) and `FormulaCellKind`.
- **The grammar.** `FormulaParser` and its AST, dependency extraction within a
  sheet and across sheets, the printer `formulaSource`, and structural
  rewriting (`rewriteFormulaReferences`, `moveFormulaReference`, `CellRect`).
- **Values.** The sealed `FormulaValue` hierarchy and `FormulaErrorCode`, the
  one place the error tokens are written.
- **The function library.** `formulaCatalog` (24 functions), the operators,
  the coercion rules, and `FormulaNamespace`, the surface a script calls.
- **Recalculation.** `SheetEngine`: exact dependency tracking, one Tarjan pass
  per recalculation for cycles across sheets, and reads of other sheets
  through a `FormulaReferenceResolver`.
- **Lowering and backends.** `lowerFormula` with the `FormulaLowering` memo,
  the `FormulaEvaluationBackend` port and `NativeFormulaBackend`.
- **Testing.** `package:tom_core_formula/testing.dart`: the conformance corpus
  every backend must agree with native on, and the promotion-gate benchmark.
