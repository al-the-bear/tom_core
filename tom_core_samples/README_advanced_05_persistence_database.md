# Persistence & the two databases

*Part 05 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-8** (depends on **RC-23**,
> the migration split). This file currently provides the section structure and
> navigation only.

## What this part covers

The persistence model and `@TomDbColumn` mapping; CRUD repositories; the
two-database design (auth_db :3307, app_db :3308) and the cross-DB logical
references (no cross-DB FK); datasources YAML config; the **schema-creation vs
sample-data migration split** (post-RC-23); and idempotent seeding.

## The persistence model & `@TomDbColumn` mapping

_TODO(RC-8)._

## CRUD repositories

_TODO(RC-8)._

## The two-database design

_TODO(RC-8): auth_db :3307 and app_db :3308; cross-DB logical references, no cross-DB FK._

## Datasources YAML config

_TODO(RC-8): `assets/datasources_*.yaml`._

## Migrations: schema-creation vs sample-data

_TODO(RC-8, after RC-23): the schema-only migration set and the distinct sample-data set; idempotent `ON DUPLICATE KEY UPDATE`._

## Primary sources

- [`advanced_app_server/README.md`](advanced_app_server/README.md), [`advanced_auth_server/README.md`](advanced_auth_server/README.md)
- `advanced_example_specification_plan.md` — A.10 Persistence & databases, Phase 3
- `*/database_migrations/`, `*/persistence/`, `assets/datasources_*.yaml`
- RC-23 (migration split), RC-25 (initdb reference reconciliation)

---

← Prev: [04 · Wire contracts & DTOs](README_advanced_04_wire_contracts_dtos.md) · Next: [06 · Authentication (JWT)](README_advanced_06_authentication.md) →
