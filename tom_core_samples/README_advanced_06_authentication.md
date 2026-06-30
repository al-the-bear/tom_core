# Authentication (JWT)

*Part 06 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-9**. This file currently
> provides the section structure and navigation only.

## What this part covers

Token issuance at the auth server (`/auth/login|refresh|me|logout`); password
hashing; the bearer token; the shared signing key trusted by the app server; the
client auth layer (`auth_client.dart`, `authorized_http.dart`) and token refresh;
and the pre-login vs authenticated request paths.

## Token issuance at the auth server

_TODO(RC-9): `/auth/login`, `/auth/refresh`, `/auth/me`, `/auth/logout`._

## Password hashing

_TODO(RC-9)._

## The bearer token and the shared signing key

_TODO(RC-9): the app server trusts the auth server's signing key._

## The client auth layer

_TODO(RC-9): `auth_client.dart`, `authorized_http.dart`._

## Token refresh

_TODO(RC-9)._

## Pre-login vs authenticated request paths

_TODO(RC-9): cross-link doc 08 (login bundle) and A3._

## Primary sources

- [`advanced_auth_server/README.md`](advanced_auth_server/README.md), [`advanced_client_core/README.md`](advanced_client_core/README.md)
- `advanced_example_specification_plan.md` — A.5 Authentication & session flow, A.7, A.11, Phases 2 & 4

---

← Prev: [05 · Persistence & the two databases](README_advanced_05_persistence_database.md) · Next: [07 · Authorization](README_advanced_07_authorization.md) →
