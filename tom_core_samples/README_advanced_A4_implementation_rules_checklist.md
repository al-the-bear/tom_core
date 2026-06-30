# Appendix A4 · Implementation-rules cheat-sheet

*Appendix A4 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-19**. This file currently
> provides the section structure and navigation only. This appendix is
> *synthesized* — it consolidates the rules stated across the spine docs into one
> copy-pasteable checklist, each rule carrying its enforcement anchor.

## What this appendix covers

The consolidated, copy-pasteable rule list for building a *new* tom_core app —
externalize texts, key auth by scope/form/field, install one adapter,
server-deliver resources, no label overrides, reflect every form, regen rules,
split migrations (schema vs data), serial Flutter tests, etc. — each with its
enforcement anchor.

## Resources & texts

_TODO(RC-19): externalize all UI texts; server-deliver; key by `<basePath>.<suffix>`; no label/hint overrides → anchor doc 08 / A2._

## Authorization

_TODO(RC-19): key auth by scope/form/field; install one adapter; per-field authorizers are narrowing overrides only; closed-safe default → anchor doc 07 / A1._

## Domain & reflection

_TODO(RC-19): reflect every entity and form; one seed; regen only on signature change → anchor doc 03 / 02._

## Forms & UI

_TODO(RC-19): bound reflected forms; unscoped `formId` is the base path; scope to match resource keys → anchor doc 09 / A2._

## Persistence & migrations

_TODO(RC-19): split schema-creation vs sample-data migrations; idempotent seeds → anchor doc 05._

## Servers & endpoints

_TODO(RC-19): bearer validation everywhere; per-endpoint access policy; role-gate admin routes → anchor doc 10._

## Testing

_TODO(RC-19): Flutter tests serial only; sentinel proof; cross-tier runner; green gate → anchor doc 12._

## Primary sources

- `readme_creation_plan.md` §1; `advanced_examples_alignment_plan.md`; all spine docs
- `advanced_example_completion.md` — the green gate

---

← Prev: [A3 · A secured request, end to end](README_advanced_A3_request_lifecycle.md) · Next: [A5 · Glossary & cross-reference](README_advanced_A5_glossary_crossref.md) →
