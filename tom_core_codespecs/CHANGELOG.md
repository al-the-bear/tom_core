# Changelog

## 0.5.0

- csra3: make CE-UP **single-moded** and close the second half of its gap.
  - Remove `TomUserSettingsPersistence` and the `persistence` / `isRoaming`
    members from `TomUserSettings`. They predate the settings re-cut and
    contradict `codespecs_mapping.md` §11, which splits configuration and
    settings into four parts — one per scope key, each single-moded, with the
    scope key alone deciding where a value lives. The old `local` arm is now
    CE-DS `@CsDeviceSetting` (a *reuse* verdict over existing `tom_core`
    property/settings classes, so it is deliberately **not** re-created here);
    the old `roaming` arm is the only meaning CE-UP has.
  - Add `TomUserSettingsStore` + `TomMemoryUserSettingsStore` — the
    **server-side per-user persistence** seam. §4.1 names the CE-UP gap as
    "typed user-settings holder **+** server-side per-user persistence", and
    only the holder existed; the reused kernel carrier
    (`TomGetSettingsMessage`/`TomGetSettingsResult`) is a read-only bootstrap
    payload with no write-back path, so a user's chosen preference had nowhere
    to be stored. The user key is in every method signature because it *is* the
    scope — the sibling `TomClientConfigurationStore` deliberately has no user
    parameter at all.
  - Add `TomUserSettings.effectiveValue`, encoding §5.16's intra-scope
    precedence for CE-UP (persisted user value → declared default). A `value` of
    `null` means *unset*, not *set to null*.
  - Correct the `TomClientConfiguration` doc-comment, which distinguished CE-CC
    from "CE-UP roaming". The discriminator is **user identity in the key**: no
    user → CE-CC; per signed-in user → CE-DS or CE-UP.

**Breaking:** `TomUserSettingsPersistence` is gone, and
`TomUserSettings(persistence: …)` / `.isRoaming` no longer compile.

## 0.4.0

- csra2: add the four remaining gap classes the §4.1 catalogue marks *gap*,
  each re-verified against the current `tom_core` before being written:
  - `TomLayoutModel` (CE-LO, §5.2/§5.12/§5.22) — the two-layer layout holder:
    a generated `base` tree of `TomLayoutContainerNode` / `TomLayoutSlotNode`
    over the closed nine `TomLayoutContainerKind`, plus an authored `overrides`
    layer of id-addressed `TomLayoutOverrideDelta` over the closed five
    `TomLayoutDeltaOp`. `reconcileWarnings()` **reports** a delta whose target
    id has vanished and never drops it, so manual layout survives regeneration.
    `tom_flutter_ui`'s `AclComponent` is a rendering leaf holding a live
    `Widget` — it has no base/override layering and no delta grammar.
  - `TomMessageKeyRegistry` (CE-TX, §5.8/§5.21) — the closed message-key
    catalogue: `TomMessageKey` with base copy, per-locale copy, declared
    parameters, the closed `TomMessageRole` five and `TomMessageCategory` pair.
    `resolve()` falls back to base copy and **never to the raw key**, and
    rejects an uncatalogued key as a generation-time spec error; error copy must
    name its CE-ER code, because that namespace *is* the code namespace.
    `tom_core_kernel`'s `TomTextResourceProvider` is an untyped runtime
    `Map<String, dynamic>` with no key vocabulary.
  - `TomRouteRegistry` (CE-NV, §5.11) — the route-id registry (`registerRoute`
    rejects a duplicate id; `danglingRouteReferences()` finds edges and
    assignments naming an unregistered route) plus the screen-flow model:
    `TomFormScreenAssignment` (replace vs popup) and `TomScreenFlowEdge`
    (per-`TomFlowOutcome` conditional targets). `tom_flutter_ui`'s
    `TomPageRoute` is a bare `MaterialPageRoute` subclass carrying no id.
  - `TomJobDeclaration` (CE-JB, §5.29) — the deployment/ownership envelope
    (`enabled`, `environments`, `serviceUnitId`, `targetRefs`, `runsIn()`).
    Deliberately **narrow**: `tom_core_kernel`'s scheduling module now supplies
    the whole runtime half (`TomJobDefinition`, `TomSchedule`, `TomScheduler`,
    `TomJobStore`, `TomLeaseLock`, `TomJobDispatcher`), which is reused as-is.
- CE-AC (Trigger) is confirmed **not** a gap and gets no class here — §4.1 /
  §5.10 / §5.20 record "no gap — full action implementation reused". Its closed
  five-kind taxonomy ships as `TriggerKind` on `@CsTrigger` in `tom_code_specs`
  0.5.0 instead.

## 0.3.0

- csm210-4-1 (wave-2 W10): add the CE-EN domain-enum gap class flagged *gap* by
  the csm4 code-basis survey (`codespecs_mapping.md` §5 — `tom_core_kernel`
  has only mechanical enums, no domain-enum/value-object framework):
  - `TomDomainEnum` — the holder a `@CsEnum` (CE-EN) CodeSpec is built on:
    `enumId`, `displayName`, an ordered `values` list, optional `defaultValueId`,
    and `hasValue(id)`.
  - `TomDomainEnumValue` — one member: stable `valueId` (wire/storage token)
    separated from display `label`, plus optional `description`.
- CE-DB stays a *reuse* verdict — `@CsTable`/`@CsColumn`/`@CsRepository` are built
  directly on `tom_core_server` persistence classes, so CE-DB needs no gap class.

## 0.2.0

- csm2r7: add the first concrete gap classes for the four new csm2r5 parts
  (survey `codespecs_mapping.md` §1.1b). CE-AU (Authentication) and CE-CF
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
