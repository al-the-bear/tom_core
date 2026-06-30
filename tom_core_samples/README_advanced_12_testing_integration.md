# Testing & cross-tier integration

*Part 12 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-15**. This file currently
> provides the section structure and navigation only.

## What this part covers

Test strategy across the seven packages; **Flutter tests serial only**; the
sentinel-`[srv]` render proof; the four-role render matrix; the **cross-tier
integration runner** (boots both DBs + servers, TC-37-01); the global green gate
(analyze-clean + serial suites + script exit 0); and the test counts.

## Test strategy across the seven packages

_TODO(RC-15)._

## Flutter tests serial only

_TODO(RC-15): `-j 1`; never parallel._

## The sentinel-`[srv]` render proof

_TODO(RC-15)._

## The four-role render matrix

_TODO(RC-15): owner / editor / viewer / commenter._

## The cross-tier integration runner

_TODO(RC-15): `run_cross_tier_integration.sh`; TC-37-01._

## The global green gate

_TODO(RC-15): analyze-clean + serial suites + script exit 0._

## Test counts

_TODO(RC-15): domain 27 / contracts 52 / client_core 44(+4) / auth_server 55 / app_server 77 / app_client 53 / authadmin_client 60._

## Primary sources

- `advanced_example_specification_plan.md` — A.13 Testing strategy, Phase 7
- `advanced_example_completion.md` — After Todos 11, 15; the green gate
- `*/test/`; `advanced_client_core/tool/run_cross_tier_integration.sh`
- `advanced_examples_alignment_plan_decisions.md` — D11 / D15, V4…V15

---

← Prev: [11 · The two Flutter clients](README_advanced_11_clients_app_admin.md) · Next: [A1 · Four-state authorization deep dive](README_advanced_A1_authorization_state_machine.md) →
