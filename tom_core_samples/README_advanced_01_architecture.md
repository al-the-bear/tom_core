# Full-stack architecture

*Part 01 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-4**. This file currently
> provides the section structure and navigation only.

## What this part covers

The shape of a two-server / two-database / two-client system; the layering
domain → contracts → client_core → servers/clients; the direction of dependency
arrows; the shared JWT signing key; and the end-to-end request + grant-
propagation loop.

## The shape: two servers, two databases, two clients

_TODO(RC-4): auth_server (:8081 / auth_db :3307) and app_server (:8080 / app_db :3308); app_client and authadmin_client._

## Layering and dependency arrows

_TODO(RC-4): domain → contracts → client_core → servers/clients; arrows point from higher-level to lower-level._

## The shared JWT signing key

_TODO(RC-4): a token minted by the auth server verifies at the app server._

## The end-to-end request + grant-propagation loop

_TODO(RC-4): admin grant edit → end-user field matrix → project share → second user sees it._

## Architecture diagram

_TODO(RC-4): reuse / refine the hub's ASCII diagram._

## Primary sources

- [`README_advanced_sample.md`](README_advanced_sample.md) (Architecture section + diagram)
- `advanced_example_specification_plan.md` — A.2 Components (`SPEC-029…044`)
- Package READMEs (all seven), for per-node detail

---

← Prev: [00 · Introduction](README_advanced_00_introduction.md) · Next: [02 · Project layout, packages & build](README_advanced_02_project_layout_build.md) →
