# Changelog

## 0.2.0

- csm2r7: add the first concrete gap classes for the four new csm2r5 parts
  (survey `codespecs_new_parts_basis.md`). CE-AU (Authentication) and CE-CF
  (ServerConfiguration) reuse existing `tom_core` classes; the three parts with
  no `tom_core` holder land here:
  - `TomClientApplication` (CE-CL) — client-application descriptor.
  - `TomClientConfiguration` (CE-CC) — per-machine client config holder.
  - `TomUserSettings` + `enum TomUserSettingsPersistence { local, roaming }`
    (CE-UP) — user-settings holder with the `codespecs_mapping.md` §11
    `local`/`roaming` persistence split (default `roaming`).
- The package is no longer an empty stub.

## 0.1.0

- Initial scaffold (csm3). Empty gap-filler package under `tom_core`.
- Gap classes are added by later CodeSpecs waves (csm4 surveys tom_core per
  part and identifies which structures belong here).
