# Resources & text externalization

*Part 08 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

This part covers the second headline rule of the sample: **no UI text is
hard-coded in the client.** Every label, hint, title and button caption a screen
renders is resolved at run time from a **server-delivered resource bundle**,
keyed by the same `basePath` the forms use to address themselves (part
[07 · Authorization](README_advanced_07_authorization.md) covered the *authorization*
half of that one-name-two-uses idea; this part covers the *text* half). The
deep dive on the scope/form/field key convention is appendix
[A2](README_advanced_A2_resource_scope_conventions.md).

## The no-hard-coded-labels rule

A Tom field never carries its own label string. It carries a `basePath`
(`<scopePath>.<formId>.<tomId>` — see [07](README_advanced_07_authorization.md))
and resolves its label *from resources* keyed off that path. The resolution is a
one-liner on `TomField`:

```dart
// tom_flutter_ui/.../tom_form.dart:855
String get resolvedLabel =>
    TomCtr.textOrNull(basePath, 'label') ?? tomId;
```

So the title field at `todo.item.title` looks up `todo.item.title.label`; if no
resource is installed for that key it falls back to the bare `tomId`
(`title`) — a *development* indicator, never a shipped string. The rule for this
sample is therefore: **every gradable/displayed field must have a resource, or
its label degrades to the raw key.** The client owns the *structure* of the
screen (which fields, in which order); the server owns the *words*.

This is why the same `basePath` that drives authorization (part 07) also drives
text: one name, addressed once, used for both the grade lookup and the label
lookup. That symmetry is the whole point — see A2.

## Server-delivered resources

The texts live on the servers and travel to the clients as a
`ResourceBundleDto` (`advanced_todo_contracts`), a thin wrapper over a
`Map<String, Object?>` of `key → text`. Three endpoints serve them:

| Bundle | Endpoint | Auth | Built by |
| --- | --- | --- | --- |
| Public login chrome | `GET /auth/resources/login` | none | `AuthResourceBundles.loginBundle()` |
| Admin console | `GET /admin/resources` | `admin` role | `AuthResourceBundles.adminConsoleBundle()` |
| App (board + item form) | `GET /app/resources` | authenticated | `AppResourceBundles.appBundle()` |

On the client, a bundle is installed as the process-wide singleton resource
provider; the **one place** that swap happens is `AppSession._installResources`:

```dart
// advanced_app_client/lib/app/app_session.dart:96
void _installResources(Map<String, dynamic> texts) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(texts),
  );
}
```

Once installed, `TomCtr.text(basePath, suffix)` resolves through that singleton
(`_provider.getText(...)`, `tom_construction_helpers.dart:61-70`), so every form
field, screen title and button caption reads its words from the bundle the
server sent. No screen reaches around the provider for a literal.

## Keying by `<basePath>.<suffix>`

`TomCtr` joins the field's `basePath` with a **suffix** to form the resource key:

```dart
// tom_flutter_ui/.../tom_construction_helpers.dart:67
static String? textOrNull(String? basePath, [String suffix = '']) =>
    basePath == null ? null : _provider.getTextOrNull(_key(basePath, suffix));
```

The suffix names *what about the field* you are addressing:

| Suffix | Resolves | Example key |
| --- | --- | --- |
| `label` | The field's display label | `todo.item.title.label` |
| `hint` | The input hint / placeholder | `login.username.hint` |
| `error.<code>` | A scoped validation message (falls back to a global key, then the raw key) | `todo.item.title.error.required` |

Screen-chrome keys that are not fields use the same flat-dotted shape without a
field segment — `login.title`, `login.submit`, `board.empty`, `grants.title`.
The wire bundle is a **flat** `Map<String, Object?>`: every served key is the
full dotted path, and the provider resolves it directly.

## Scope/form/field-structured JSON resource files

Before RC-24 these texts were Dart `const` maps built in code. They now live as
**nested JSON assets** structured along the client's `scope → form → field`
hierarchy, so a text file *mirrors the screen it describes*:

```jsonc
// advanced_app_server/assets/resources_app.json
{
  "todo":   { "item": { "title": { "label": "Title" }, "status": { "label": "Status" }, … } },
  "board":  { "title": "My Board", "empty": "No items yet", "item": { "save": "Save" }, … },
  "global": { "todostatus": { "inreview": "In review", … }, "projectrole": { "editor": "Editor", … }, … }
}
```

That tree carries exactly the information of the flat wire bundle — the path
`todo.item.title.label` is the nesting `todo → item → title → label`, and enum
display text (G-RES-5) lives under `global.<enumtype>.<value>` (e.g.
`global.todostatus.inreview`) so the domain enums hold no hardcoded strings. The
server
loads the asset once and **flattens** it to the flat `<basePath>.<suffix>` map
the bundle carries, so the wire contract is byte-equivalent to the old
in-code bundle and every resource-endpoint test is unchanged:

```dart
// advanced_app_server/lib/src/resources/app_resource_bundles.dart
static Map<String, Object?> texts() => _cache ??= loadFlatResourceAsset(assetPath);
// reads assets/resources_app.json (cwd-relative), jsonDecode, flattenResourceTree
```

Two design points are worth calling out, both about **where the code lives**:

- **`flattenResourceTree` is a pure function in `advanced_todo_contracts`.** It
  walks the nested map and joins keys with `.`, stopping at the first non-map
  value. It carries **no `dart:io`** because `contracts` is imported by the
  Flutter-free, web-targetable `advanced_client_core` — a `dart:io` import there
  would break a web build.
- **`loadFlatResourceAsset` (the `File` read) lives in each *server* package.**
  Servers never target web, so the `dart:io` asset read belongs with them, not
  in `contracts`. The six lines are duplicated across the two servers
  deliberately rather than dragging file-IO into the shared web-safe package.

The asset path is **working-directory-relative** (`assets/resources_app.json`),
the same convention the datasource/config YAML assets use: under `dart test` the
cwd is the package root; at boot it is the server's configured `working_dir`. A
missing asset throws a `StateError` rather than silently serving an empty bundle
— an absent text file would otherwise break the no-hard-coded-strings property
invisibly. The auth server follows the identical shape with two assets
(`resources_login.json`, `resources_admin.json`) behind `AuthResourceBundles`.

The full scope→form→field convention — why the JSON tree mirrors the form
hierarchy, and the one place a key (`estimate`) deliberately diverges from its
member name — is appendix [A2](README_advanced_A2_resource_scope_conventions.md).

## Login bundle vs full bundle bootstrap

A client needs *some* texts before anyone signs in (the login screen has a
title, a hint, a submit caption) but the full set of post-login texts is only
reachable *with* a session. The app client resolves this with a **two-stage
install** (D-A9):

1. **Pre-login.** The bootstrap awaits `loadLoginResources()` before the first
   frame: it fetches the *public* login bundle through the backend seam and
   installs it, so the sign-in screen renders server-delivered chrome.
2. **Post-login.** On a successful `login()`, `_installFullResources()` fetches
   the authenticated full bundle and installs it **merged over the current
   provider** (full-bundle keys win on overlap). The pre-login provider is
   captured first, so `logout()` restores it exactly and the login screen is
   resolvable again.

```dart
// advanced_app_client/lib/app/app_session.dart:108
Future<void> _installFullResources() async {
  final bundle = await backend.resources();
  final current = Map<String, dynamic>.of(
    TomTextResourceProvider.getAppResources().resources,
  );
  _preLoginTexts = current;               // captured for logout restore
  _installResources({...current, ...bundle.texts}); // full keys win
}
```

The login bundle is unauthenticated by design (it is served *before* a token
exists); the full and admin bundles sit behind the contract-declared
`TomAuthenticatedAccess()` / `TomRoleAccess(['admin'])`
(`TomApiEndpoint.access`) — see part [07](README_advanced_07_authorization.md)
and part [10](README_advanced_10_servers_endpoints.md).

## The sentinel-`[srv]` proof pattern

How do you *prove* a label came from the server bundle and not a hidden
client-side literal? The widget tests install a **sentinel** bundle whose every
value carries a `[srv]` suffix no client string could produce, then assert the
sentinel renders:

```dart
// advanced_app_client/test/form_label_resolution_test.dart
'login.username.label': 'Username [srv]',
'login.username.hint':  'alice, bob or val [srv]',
…
expect(find.textContaining('Username [srv]'), findsWidgets);
```

If the field were rendering a hard-coded `'Username'`, the `[srv]` text would be
absent and the test would fail. Because the assertion passes, the label is
provably resolved through `resolvedLabel` → `TomCtr.textOrNull(basePath, 'label')`
→ the installed bundle. The same pattern guards the admin console's
`user.*`/`role.*`/`group.*` form labels in `advanced_authadmin_client`. These
are the tests RC-24 had to keep green: the bundles now come from JSON assets, but
the served keys (and therefore the sentinels) are byte-identical.

## Primary sources

- `advanced_todo_contracts/lib/src/resource_bundle_dto.dart` — `ResourceBundleDto`, `flattenResourceTree`
- `advanced_app_server/lib/src/resources/app_resource_bundles.dart`, `advanced_auth_server/lib/src/resources/auth_resource_bundles.dart`; the `assets/resources_*.json` trees
- `advanced_app_client/lib/app/app_session.dart` (`loadLoginResources` / `_installFullResources`, D-A9)
- `tom_flutter_ui/.../tom_form.dart:855` (`resolvedLabel`); `tom_construction_helpers.dart:61-70` (`TomCtr.text`/`textOrNull`)
- `advanced_app_client/test/form_label_resolution_test.dart` (the `[srv]` sentinel proof)
- `advanced_examples_alignment_plan.md` — gaps 2–3, Key anatomy, D-A1, D-A9; appendix [A2](README_advanced_A2_resource_scope_conventions.md)

---

← Prev: [07 · Authorization](README_advanced_07_authorization.md) · Next: [09 · Forms & UI](README_advanced_09_forms_ui.md) →
