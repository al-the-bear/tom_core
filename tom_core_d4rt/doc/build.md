# Build Instructions

To build the `tom_dartscript_bridges` (d4rt) tool, follow these steps:

1. **Build prerequisites**: ensure that `tom_d4rt_dcli` has been built first, as
   it contains the base bridges and VS Code integration required by this
   project.
2. **Generate the bridges**: the bridges are produced by the `d4rtgen` CLI from
   the `d4rtgen:` section of `buildkit.yaml` — *not* by `build_runner`, which
   this package configures only for the reflection root (see step 3). Run it
   from the package directory:

   ```bash
   d4rtgen --scan . --not-recursive
   ```

   Each `*.b.dart` output is rewritten in place, so there is nothing to delete
   beforehand. The generator reads sources out of the bridged packages
   themselves, so those must be present in the workspace and up to date.

3. **Generate the reflection root** (only when
   `lib/src/demo_persistence/` changes): `build.yaml` wires
   `tom_reflection_generator` to `lib/src/demo_persistence/reflection_root.dart`.

   ```bash
   dart run build_runner build
   ```

4. **Compile**: compile the tool using the workspace build tools.
