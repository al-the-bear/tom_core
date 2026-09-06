# tom_core_codespecs — documentation

The package documentation for `tom_core_codespecs`: how to use this package's
code. Which CodeSpecs parts are gaps and which are reuse verdicts — and why — is
the **subject-matter tier**, catalogued by
[`tom_specs_model/doc/index.md`](../../../ai_build/tom_specs_model/doc/index.md);
documents here cite it rather than restating it
([`tom_specs_documentation_standard.md`](../../../ai_build/tom_specs_model/doc/tom_specs_documentation_standard.md)
§1.2).

## Guides

| Document | Covers |
|----------|--------|
| [gap_classes.md](gap_classes.md) | The seven modules and their holders: the dependency-free invariant, the two-layer layout model, the message-key registry, the route registry and screen flow, the notification catalogue, and the report model — plus where each kind of error surfaces |

## API reference

| Document | Covers |
|----------|--------|
| [api/api_summary_tom_core_codespecs.md](api/api_summary_tom_core_codespecs.md) | Every class and enum, its constructor, properties and methods |

## Where to start

- **Building a CodeSpec on one of these holders?**
  [gap_classes.md](gap_classes.md) — start with the module table, which maps each
  `CE-*` part to its holder.
- **Wondering whether a new class belongs here?**
  [gap_classes.md § The dependency-free invariant](gap_classes.md#the-dependency-free-invariant).
  The short test: if it would need a `tom_core_*` type, it is not a gap class.
- **Debugging a validation failure?**
  [gap_classes.md § Error Handling](gap_classes.md#error-handling) says which
  errors throw at construction and which are reported by a named method.

## Beyond this package

| Where | What it decides |
|-------|-----------------|
| [`codespecs_mapping.md`](../../../ai_build/tom_specs_model/doc/codespecs_mapping.md) | The parts catalogue, the five-package `tom_core`-family basis, the attribute surfaces, and every reuse-versus-gap verdict |
| [`codespecs_derivation_contract.md`](../../../ai_build/tom_specs_model/doc/codespecs_derivation_contract.md) | What code comes out per marker, and which `tom_core`-family class it is built on |
| [`tom_specs_model/doc/index.md`](../../../ai_build/tom_specs_model/doc/index.md) | The catalogue of the whole subject-matter tier, and the `§` citation convention |

| Sibling | What it is |
|---------|-----------|
| [tom_code_specs](../../../ai_build/tom_code_specs) | The `Cs*` annotation family that marks a class built on one of these holders |
