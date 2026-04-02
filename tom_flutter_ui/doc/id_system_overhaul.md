# ID System Overhaul — Implementation Change Analysis

Date: 2026-04-01
Status: Analysis
Package: tom_flutter_ui
Reference: `_doc/tom/resource_and_authorization_ids.md`

---

## 1. Summary

This document analyses the changes required to implement the identity container / layout container design from the resource and authorization IDs specification. The core change: containers (and rows) gain an `idScope` flag that controls whether their ID propagates to descendant paths.

---

## 2. Files Requiring Changes

| # | File | Change scope |
|---|------|-------------|
| 1 | `widget_base/tom_node_base.dart` | Major — TomNodeScope path logic, appendContainer, layout self-path |
| 2 | `widget_base/tom_family_base.dart` | Medium — TomContainerBase.build scope propagation |
| 3 | `widget_base/tom_policy_node_base.dart` | Minor — no structural change, verify auth path usage |
| 4 | `resource_auth/tom_resources.dart` | Medium — fallback chain change |
| 5 | `resource_auth/tom_auth_state.dart` | None — no changes needed |
| 6 | `resource_auth/tom_id_prefix.dart` | None — no changes needed |
| 7 | `groups/tom_widget_mixin.dart` | Minor — verify resolveFullPath uses correct scope |
| 8 | `advanced_container_layout/acl_container.dart` | Major — path building, scope wrapping, row idScope |
| 9 | `advanced_container_layout/acl_builder.dart` | Medium — idScope on rows, propagation to _RowData |
| 10 | `advanced_container_layout/acl_scope.dart` | Minor — add idScope field |
| 11 | `widgets/containers/acl/tom_acl.dart` | Medium — idScope parameter, build method scope logic |

---

## 3. Change Details Per File

### 3.1 `tom_node_base.dart` — TomNodeScope

**Current state:**
- `TomNodeScope` has fields: `routeId`, `containerId`, `groupId`, `formId`, `fullIdPath`
- `appendContainer(String cId)` always appends `c-<cId>` to `fullIdPath`
- `appendWidget(String wId)` always appends `w-<wId>` to `fullIdPath`
- `extend()` factory always updates scope with provided IDs
- `TomNodeBase.resolveResourceBasePath()` walks scope and appends own prefixed ID

**Required changes:**

a) **`appendContainer` gains `idScope` parameter:**

```dart
// CURRENT
String appendContainer(String cId) {
  // always appends to fullIdPath
}

// NEW
String appendContainer(String cId, {bool idScope = false}) {
  if (!idScope) return fullIdPath ?? ''; // layout — path unchanged for descendants
  // identity — append c-<cId> to path
}
```

When `idScope: false`, the method returns the current `fullIdPath` unchanged. Layout containers do not modify the descendant path.

b) **Add `appendRow` with `idScope` parameter:**

```dart
String appendRow(String rowId, {bool idScope = false}) {
  if (!idScope) return fullIdPath ?? '';
  // identity — append rw-<rowId> to path
}
```

c) **Add self-path helper for layout containers:**

Layout containers need their own resource path (identity path + own ID) without modifying the scope. Add a method:

```dart
/// Returns the self-path for a layout container: current identity path + c-<id>.
/// Does NOT modify the scope.
String selfPathForContainer(String cId) {
  final base = fullIdPath ?? '';
  return base.isEmpty
      ? TomIdPrefix.prefixed(TomIdPrefix.container, cId)
      : '$base.${TomIdPrefix.container}$cId';
}

/// Returns the self-path for a layout row: current identity path + rw-<id>.
String selfPathForRow(String rowId) {
  final base = fullIdPath ?? '';
  return base.isEmpty
      ? TomIdPrefix.prefixed(TomIdPrefix.row, rowId)
      : '$base.${TomIdPrefix.row}$rowId';
}
```

d) **`extend()` factory gains `idScope` for containers:**

```dart
// CURRENT
factory TomNodeScope.extend(context, {containerId, groupId, formId, ...})
// → always sets containerId, always appends to path

// NEW
factory TomNodeScope.extend(context, {
  containerId, 
  bool containerIdScope = false,  // NEW
  groupId, 
  formId, 
  ...
})
```

When `containerIdScope: false` and `containerId` is provided, the factory creates a scope that does NOT append the container to `fullIdPath`. The container's ID is available via the scope for self-path resolution but does not propagate.

**Impact:** This is the most critical change. Every caller of `TomNodeScope.extend()` and `appendContainer()` must be reviewed to decide whether it passes `idScope: true`.

---

### 3.2 `tom_family_base.dart` — TomContainerBase

**Current state:**
- `TomContainerBase` extends `TomFamilyBase`
- `idPrefix` is overridden to `'c-'`
- `build()` resolves auth, wraps in `TomNodeScope.extend(context, containerId: tomId)`

**Required changes:**

a) **Add `idScope` property:**

```dart
class TomContainerBase extends TomFamilyBase {
  final bool idScope;  // NEW — default false
  
  const TomContainerBase({
    super.key,
    super.tomId,
    super.tomGroup,
    this.idScope = false,  // NEW
  });
}
```

b) **`build()` — path resolution and scope propagation:**

```dart
// CURRENT
build(context) {
  resourceKeyPath = resolveResourceBasePath(context);  // uses full path
  auth = resolveAuth(resourceKeyPath);
  // ... build content
  if (tomId != null) TomNodeScope.extend(context, containerId: tomId, child: content)
}
```

The problem: `resolveResourceBasePath()` (inherited from `TomNodeBase`) always appends the container ID to the parent path. For layout containers, we need:
- Auth and resource resolution against the **self-path** (identity path + own ID)
- Scope propagation that does NOT include own ID in descendant path

```dart
// NEW
build(context) {
  // Self-path: always includes own ID (for own resources and auth)
  final scope = TomNodeScope.of(context);
  final selfPath = scope?.selfPathForContainer(tomId!) 
      ?? TomIdPrefix.prefixed(TomIdPrefix.container, tomId!);
  
  auth = TomUIAuthorization.resolveAuth(selfPath);
  if (!auth.visible) return SizedBox.shrink();
  
  // ... build content using selfPath for own resources
  
  // Scope propagation: only if idScope is true
  if (tomId != null) {
    return TomNodeScope.extend(
      context, 
      containerId: tomId, 
      containerIdScope: idScope,  // NEW
      child: content,
    );
  }
  return content;
}
```

**Impact on `resolveResourceBasePath()`:** The base class method in `TomNodeBase` calls `scope.appendWidget(id)` or similar. For containers, this needs to use the self-path pattern instead. Two options:

- **Option A:** Override `resolveResourceBasePath` in `TomContainerBase` to use `selfPathForContainer`.
- **Option B:** Keep using `resolveResourceBasePath` unchanged (it already appends with the container prefix), but change `TomNodeScope.appendContainer` behavior so it's aware of `idScope`.

Option A is simpler and more explicit.

---

### 3.3 `tom_policy_node_base.dart`

**Current state:**
- `build()` calls `resolveResourceBasePath(context)` then `resolveAuth(path)`
- Only used by widgets that extend `TomNodeBase` (not containers — those use `TomContainerBase`)

**Required changes:** None. Widget-level auth uses `resolveFullPath` / `resolveResourceBasePath`, which already appends the widget's own ID to the parent scope. Since the parent scope's `fullIdPath` now correctly excludes layout containers, widget paths automatically become identity-only.

**Verification needed:** Confirm that `TomPolicyNodeBase` is not subclassed by any container classes other than through `TomContainerBase`.

---

### 3.4 `tom_resources.dart` — Fallback Chain

**Current state:**
- `resolveText(basePath, suffix)` returns `adapter.resolveText()` or `'$basePath.$suffix'` as fallback
- No multi-level fallback — single lookup or string fallback
- The fallback chain logic is in `TomUIResourceAdapter.resolveText()` (the adapter implementation, not in tom_flutter_ui itself)

**Required changes:**

Two distinct fallback behaviors depending on resource type:

**Text resources** (`resolveText`) — for string attributes displayed to the user (text, label, title, hint):
1. Full identity path: `r-checkout.c-shipping.f-address.w-street.label`
2. Without route: `c-shipping.f-address.w-street.label`
3. Form + widget: `f-address.w-street.label`
4. Widget only: `w-street.label`
5. **Full key as value** — return the originally passed lookup key as string

Text resources always return `String` (never null). The final fallback is the full identity key itself, displayed as visible text. This preserves the current behavior where missing translations are immediately identifiable during development.

**Value resources** (`resolveColor`, `resolveDouble`, `resolveIcon`, `resolveEdgeInsets`, etc.) — for typed configuration attributes:
1. Full identity path
2. Without route
3. Form + widget
4. Widget only
5. **`null`** — widget uses its own coded default

Value resources return their typed result or `null`. Widgets fall back to theme defaults, hardcoded defaults, or "no value" (e.g., no icon). Resource files only need entries for overrides.

**Where to implement this:** Two options:

- **Option A (adapter-side):** The fallback chain is an adapter concern. The adapter receives the full path and suffix and internally tries progressively shorter lookups. `tom_flutter_ui` is unaware of the fallback logic. This keeps the framework thin.

- **Option B (framework-side):** `TomUIResources` implements the fallback chain itself by calling `adapter.resourceExists()` at each level, then calling the appropriate resolve method on the first hit. This ensures consistent fallback regardless of adapter implementation.

**Recommendation:** Option B — the fallback chain is part of the ID system contract, not an adapter-specific behavior. All adapters should follow the same chain.

**Implementation sketch for Option B:**

```dart
/// Text resource lookup — always returns a String.
/// Final fallback: the full lookup key as visible text.
static String resolveText(String basePath, String suffix) {
  if (_adapter == null) return '$basePath.$suffix';
  
  for (final path in _fallbackPaths(basePath)) {
    if (_adapter!.resourceExists(path, suffix)) {
      return _adapter!.resolveText(path, suffix);
    }
  }
  
  // Text fallback: return the full key as displayed value
  return '$basePath.$suffix';
}

/// Value resource lookup — returns typed value or null.
/// Final fallback: null (widget uses its own default).
static T? _resolveValue<T>(String basePath, String suffix,
    T? Function(TomUIResourceAdapter adapter, String path, String suffix) resolve) {
  if (_adapter == null) return null;
  
  for (final path in _fallbackPaths(basePath)) {
    if (_adapter!.resourceExists(path, suffix)) {
      return resolve(_adapter!, path, suffix);
    }
  }
  
  return null;
}

/// Generates fallback path sequence:
/// full path → without route → form+widget → widget only
static Iterable<String> _fallbackPaths(String basePath) sync* {
  yield basePath;
  final noRoute = _stripRoutePrefix(basePath);
  if (noRoute != null) yield noRoute;
  final formWidget = _extractFormWidget(basePath);
  if (formWidget != null) yield formWidget;
  final widgetOnly = _extractWidget(basePath);
  if (widgetOnly != null) yield widgetOnly;
}
```

**Impact on return types:**

| Method | Current return | New return | Change |
|--------|---------------|------------|--------|
| `resolveText` | `String` (fallback: `'$basePath.$suffix'`) | `String` (fallback: `'$basePath.$suffix'`) | **No change** — same type, same fallback behavior, just with intermediate lookups |
| `resolveColor` | `Color?` | `Color?` | No change — already nullable |
| `resolveDouble` | `double?` | `double?` | No change — already nullable |
| `resolveIcon` | `IconData?` | `IconData?` | No change — already nullable |
| `resolveEdgeInsets` | `EdgeInsets?` | `EdgeInsets?` | No change — already nullable |
| `resolveInt` | `int?` | `int?` | No change — already nullable |
| `resolveBool` | `bool?` | `bool?` | No change — already nullable |

All value resolvers already return nullable types. `resolveText` already returns `String` with a key fallback. **No call site changes needed for return type handling.** The only change is that the fallback chain now tries 4 levels before falling back, instead of 1.

---

### 3.5 `tom_widget_mixin.dart`

**Current state:**
- `resolveFullPath(context)` calls `scope.appendWidget(tomId!)`
- `getAuth(context)` calls `TomUIAuthorization.resolveAuth(resolveFullPath(context))`
- `getText(context, suffix)` calls `TomUIResources.resolveText(resolveFullPath(context), suffix)`

**Required changes:** None to the mixin itself. The path it resolves via `TomNodeScope.appendWidget()` will automatically be correct because the scope's `fullIdPath` now excludes layout container IDs. The mixin is downstream of the scope and benefits from the fix transparently.

**Verification needed:** Ensure `resolveFullPath` is the only path entry point. Confirm no mixin methods build paths independently.

---

### 3.6 `acl_container.dart` — AclContainer

**Current state:**
- `_buildComponentPolicyPath()` manually constructs paths from scope fields (routeId, containerId, etc.)
- `_buildRowPolicyPath()` similar manual construction
- `_wrapWithScope()` wraps components in both `AclScope` and `TomNodeScope`
- Row assembly loop checks row-level auth via `_buildRowPolicyPath`

**Required changes:**

a) **Add `idScope` to AclContainer widget:**

```dart
class AclContainer extends StatefulWidget {
  final String? aclId;
  final bool idScope;          // NEW
  // ... existing fields
  final List<AclRow> rows;
}
```

b) **Replace `_buildComponentPolicyPath` and `_buildRowPolicyPath`:**

These methods currently build paths manually by inspecting scope fields. With the new design, paths should come from `TomNodeScope.fullIdPath` directly. The manual path building is no longer needed because `TomNodeScope` already has the correct identity path.

```dart
// CURRENT (manual path construction)
String _buildComponentPolicyPath({required String componentId, ...}) {
  // manually builds r-route.c-outer.c-this.g-group.rw-row.w-component
}

// NEW (use scope directly)
String _resolveComponentPath(String componentId) {
  final scope = TomNodeScope.of(context);
  return scope?.appendWidget(componentId) 
      ?? TomIdPrefix.prefixed(TomIdPrefix.widget, componentId);
}
```

The scope already contains the correct identity path (layout containers excluded). There's no need to reconstruct it manually.

c) **Row `idScope` support:**

`AclRow` gains an `idScope` field. When building rows:

```dart
for (final row in widget.rows) {
  // Row self-path (for own resources and auth)
  if (row.id != null) {
    final rowSelfPath = scope.selfPathForRow(row.id!);
    final rowAuth = TomUIAuthorization.resolveAuth(rowSelfPath);
    if (!rowAuth.visible) continue;
  }
  
  // If identity row, push scope for descendant components
  if (row.id != null && row.idScope) {
    // Components in this row see rw-<rowId> in their paths
    currentScope = scope.appendRow(row.id!, idScope: true);
  }
}
```

d) **`_wrapWithScope` simplification:**

Currently wraps in both `AclScope` and `TomNodeScope` with manually constructed paths. Simplify:

```dart
Widget _wrapWithScope(Widget child, AclComponent comp, AclRow row, {String? groupName}) {
  final group = groupName ?? comp.group ?? row.group;
  
  // AclScope: ACL-specific metadata (unchanged)
  Widget result = AclScope(
    containerId: widget.aclId,
    componentId: comp.id,
    rowId: row.id,
    groupName: group,
    child: child,
  );
  
  // TomNodeScope: already correct from container-level propagation
  // No need to manually construct fullIdPath here
  return result;
}
```

The key insight: container-level scope propagation (in the container's build method) handles the identity path. Individual component wrapping only needs `AclScope` for ACL metadata.

**Impact:** This is a significant simplification of `acl_container.dart`. The manual path construction (~60 lines across two methods) gets replaced by scope-based resolution (~5 lines).

---

### 3.7 `acl_builder.dart` — AclBuilder

**Current state:**
- `_RowData` has `id` and `group` fields
- `_ComponentData` has `id` and `group` fields
- No `idScope` field on either

**Required changes:**

a) **Add `idScope` to `_RowData`:**

```dart
class _RowData {
  // ... existing fields
  String? id;
  String? group;
  bool idScope;  // NEW — default false
  List<AclRowBreakpoint> breakpoints;
}
```

b) **Update builder API to accept `idScope` on rows:**

```dart
void addRow({
  String? id,
  String? group,
  bool idScope = false,  // NEW
  // ... existing params
})
```

c) **`_ComponentData` does not need `idScope`** — components are widgets (leaf nodes), not containers/rows.

---

### 3.8 `acl_scope.dart` — AclScope

**Current state:**
- Fields: `containerId`, `componentId`, `rowId`, `groupName`, `fullIdPath`

**Required changes:**

Consider whether `AclScope` still needs `fullIdPath`. With the new design, the canonical path comes from `TomNodeScope`, not `AclScope`. `AclScope` becomes ACL-specific metadata only:

```dart
class AclScope extends InheritedWidget {
  final String? containerId;
  final String? componentId;
  final String? rowId;
  final String? groupName;
  // fullIdPath removed — use TomNodeScope.of(context).fullIdPath instead
}
```

**Impact:** Any code reading `AclScope.of(context)?.fullIdPath` must switch to `TomNodeScope.of(context)?.fullIdPath`. Search for all `AclScope` usages.

---

### 3.9 `tom_acl.dart` — TomAclBuilder

**Current state:**
- Constructor: `required String id` (no `idScope`)
- `build()`: `containerPath = parentScope?.appendContainer(id)`, checks auth, resolves resources, wraps in `TomNodeScope.extend(context, containerId: id)`

**Required changes:**

a) **Add `idScope` parameter:**

```dart
TomAclBuilder({
  required String id,
  bool idScope = false,  // NEW
  required T elementProvider,
  // ...
})
```

b) **`build()` — split self-path from propagated path:**

```dart
Widget build(BuildContext context) {
  final parentScope = TomNodeScope.of(context);
  
  // Self-path: always identity path + own ID (for own resources & auth)
  final selfPath = parentScope?.selfPathForContainer(id) 
      ?? TomIdPrefix.prefixed(TomIdPrefix.container, id);
  
  // Auth check on self-path
  final auth = TomUIAuthorization.resolveAuth(selfPath);
  if (!auth.visible) return const SizedBox.shrink();
  
  // Resolve own resources from selfPath (unchanged logic, different path source)
  _resolveResources(selfPath);
  
  // Build ACL
  final acl = _builder.build();
  
  // Apply readonly if needed
  Widget result = auth.readonly ? readonlyStyle.apply(acl) : acl;
  
  // Scope propagation: only include ID if idScope is true
  return TomNodeScope.extend(
    context, 
    containerId: id,
    containerIdScope: idScope,  // NEW — controls descendant path
    child: result,
  );
}
```

**Impact:** `TomAclBuilder` callers that want their container to be an identity boundary must now pass `idScope: true`. Default behavior (layout container) means the ID is available for own resource/auth resolution but does not affect descendant paths.

---

## 4. Change Dependencies

The changes must be implemented in this order:

```
1. TomIdPrefix (no change needed)
   TomAuthState (no change needed)

2. TomNodeScope (tom_node_base.dart)
   ├── appendContainer gains idScope
   ├── appendRow added with idScope  
   ├── selfPathForContainer added
   ├── selfPathForRow added
   └── extend() gains containerIdScope

3. TomUIResources (tom_resources.dart)
   └── Fallback chain implementation

4. TomContainerBase (tom_family_base.dart)     ← depends on 2
   ├── idScope property
   └── build() uses selfPath + conditional scope propagation

5. TomAclBuilder (tom_acl.dart)                ← depends on 2
   ├── idScope property  
   └── build() uses selfPath + conditional scope propagation

6. AclBuilder (acl_builder.dart)               ← depends on nothing
   └── idScope on _RowData

7. AclContainer (acl_container.dart)           ← depends on 2, 6
   ├── idScope property
   ├── Remove manual path construction
   ├── Row idScope handling
   └── Simplify _wrapWithScope

8. AclScope (acl_scope.dart)                   ← depends on 7
   └── Remove fullIdPath (optional, can defer)
```

---

## 5. Impact on Existing Widgets

### 5.1 Widgets extending TomNodeBase / TomPolicyNodeBase

**~130 widget classes** (TomButton, TomTextField, TomSwitch, etc.)

**Change required: None.** These widgets call `resolveResourceBasePath()` or use `TomWidgetMixin.resolveFullPath()`, both of which read from `TomNodeScope`. Since the scope now correctly excludes layout container IDs, all widget paths are automatically correct.

### 5.2 Widgets extending TomContainerBase

A handful of container widgets. Each gains `idScope` as an optional parameter (default `false`).

**Affected classes:**
- `TomContainerBase` itself (abstract — the change point)
- Any direct subclasses that override `build()` — must verify they use the new self-path pattern

### 5.3 Widgets using TomWidgetMixin

~10 widgets that extend Flutter directly (TomTab, TomNavigationDestination, etc.)

**Change required: None.** The mixin reads `TomNodeScope` which is already correct.

### 5.4 Test impact

All existing tests that assert on resolved paths will need updating if they involve containers, since layout containers no longer appear in descendant paths. However, since there is no significant test suite for path resolution yet, this is a greenfield implementation concern.

---

## 6. Form ID Override (Open Question #1)

The design specifies that forms should support ID override when inserted into a container context. This affects:

- **TomNodeScope.extend()** — needs a `formIdOverride` or similar mechanism
- **TomAclBuilder** — needs API for specifying form ID override when adding form components
- **Any container that embeds forms** — the override mechanism should be generic

Implementation sketch:

```dart
// When embedding a reusable form into a specific context:
TomAclBuilder(
  id: 'shipping',
  idScope: true,
  elementProvider: provider,
)..addForm(
    formId: 'shippingAddress',  // overrides the form's own f-address ID
    formBuilder: addressFormBuilder,
  );
```

The form builder internally uses `f-address`, but the container override replaces it with `f-shippingAddress` in the scope. Descendants see `f-shippingAddress.w-street` instead of `f-address.w-street`.

This requires `TomNodeScope.extend()` to support `formId` override (it already accepts `formId` — the override is just the caller passing a different value than the form's own ID).

---

## 7. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Layout containers accidentally left as `idScope: true` | Low | Default is `false` — safe default, opt-in for identity |
| Path collisions from convergent layout containers | Low | Intentional by design — convergence is a feature |
| `TomUIResources` return type change (`String` → `String?`) | Medium | Audit all call sites; provide `resolveTextOrDefault()` variant |
| `AclScope.fullIdPath` removal breaks downstream code | Low | Search all usages before removing; can deprecate first |
| `resolveResourceBasePath()` behavior change in `TomNodeBase` | Medium | Container override in `TomContainerBase` isolates the change from widgets |

---

## 8. Summary of Lines of Change (Estimate)

| File | Lines added | Lines removed | Lines modified |
|------|------------|--------------|----------------|
| `tom_node_base.dart` | ~40 | ~5 | ~15 |
| `tom_family_base.dart` | ~15 | ~5 | ~10 |
| `tom_resources.dart` | ~50 | ~5 | ~10 |
| `tom_widget_mixin.dart` | 0 | 0 | 0 |
| `tom_policy_node_base.dart` | 0 | 0 | 0 |
| `acl_container.dart` | ~30 | ~80 | ~20 |
| `acl_builder.dart` | ~10 | 0 | ~5 |
| `acl_scope.dart` | 0 | ~5 | ~3 |
| `tom_acl.dart` | ~10 | ~5 | ~15 |
| **Total** | **~155** | **~105** | **~78** |

Net effect: ~50 lines added, significant simplification of `acl_container.dart`.
