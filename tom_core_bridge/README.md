# Tom Core Bridge

Extended VS Code bridge server with full Tom Framework D4rt bridges.

## Overview

This project provides an alternative bridge server binary (`core_bs`) for the
VS Code extension. While the base `tom_bs` (from `tom_vscode_bridge`) includes
only DCli and VS Code API bridges, `core_bs` adds the complete Tom Framework
bridge set via `tom_core_d4rt`:

- **tom_core_kernel** — Core framework types
- **tom_core_server** — Server-side components
- **tom_build** — Build system APIs
- **tom_dist_ledger** — Distributed ledger
- **tom_process_monitor** — Process monitoring
- **tom_basics** — Basic utilities
- **tom_reflection** — Reflection support

## Usage

Configure the VS Code extension to use `core_bs` instead of `tom_bs` for
full Tom Framework access in D4rt scripts.

## Architecture

```
tom_core_bridge (bin/core_bs.dart)
├── tom_vscode_bridge       — Base bridge server + VS Code API bridges
│   ├── tom_d4rt_dcli       — DCli bridges
│   └── tom_vscode_scripting_api — VS Code API wrappers
└── tom_core_d4rt            — Tom Framework bridges
    ├── tom_core_kernel
    ├── tom_core_server
    ├── tom_build
    ├── tom_dist_ledger
    ├── tom_process_monitor
    ├── tom_basics
    └── tom_reflection
```
