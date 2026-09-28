/// The app server's text resource bundle.
///
/// The app client's post-login screens — the board and the item editor — render
/// their labels and hints through the Tom Flutter UI resource system rather than
/// from client-side strings. This is the server-owned source of those texts.
///
/// The texts are a **nested JSON asset** (`assets/resources_app.json`)
/// structured along the client's scope → form → field hierarchy
/// (`todo.item.title.label`, `board.*`) rather than Dart `const` maps: the
/// authoring shape then mirrors the screen it describes. The asset is loaded
/// once and [flattenResourceTree]-ed into the flat `<basePath>.<suffix>` map the
/// `appResources` endpoint serves and the client installs via
/// `TomTextResourceProvider.from(dto.texts)` — so the nesting is an authoring
/// convenience only and never reaches the wire.
///
/// The item-form keys live under `todo.item.*` so a served label key tracks the
/// field's grade key: the field at `todo.item.title` is graded on
/// `todo.item.title` and labelled from `todo.item.title.label`. Board texts use
/// the `board.*` namespace, which has no grade counterpart (the board is not a
/// gradable form). Enum display text (G-RES-5) lives under `global.*` —
/// `global.todostatus.inreview`, `global.projectrole.editor`, … — so the domain
/// enums carry no hardcoded strings and the client resolves each value's text
/// from this bundle.
///
/// The framework's own file-field chrome is worded here too, at the **global**
/// level the framework resolves it from: `file.*` (choose / progress / retry /
/// cancel wording read by `TomFileLabels`), `file_transfer.*` (the transport's
/// stable error keys) and `error.file*` (the picker's rejection reasons, shared
/// with the form validators that raise the same keys). Global rather than
/// scoped, because one wording for every file field in the app is the point —
/// a per-field override remains possible by repeating the key under that
/// field's base path.
///
/// The `todo.item.*` texts label exactly the domain's gradable fields
/// (`gradableItemKeys`) — `test/resource_key_consistency_test.dart` holds the
/// two together in both directions. The item's attachment is worded under
/// `board.item.attachment.*` instead: it is not a graded field but a file slot,
/// authorized by the item's resource state, and a `todo.item.attachment.*` text
/// would be a label for a field the item form does not have.
///
/// **`share.grantee.hint` is a live id, and deliberately unlike the client's.**
/// A hint is an instruction to type something, so it has to name a value *this*
/// server accepts. `ShareRequest.granteeUserId` carries a `UserDto.id`, and
/// this stack's `UserDto.id` is the numeric `auth_db` surrogate rendered as a
/// string (alice `2` … erin `6`, via `userRecordToDto`) — `AppShareService
/// .share` parses it with `int.tryParse` and raises `app.share.invalid` on
/// anything else. So the bundle hints `4`.
///
/// The app client ships the same three `share.*` strings for its offline run
/// and hints `u-carol`, which is right for the backend *it* serves: the
/// in-memory fake keys its `UserDto.id`s `u-alice` … `u-erin`. The rule is the
/// same on both sides — hint the backend's own `UserDto.id` — and it is why
/// the two bundles say different things on purpose, and why neither may be
/// copied over the other.
library;

import 'dart:convert';
import 'dart:io';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

/// Builds the app client's full text bundle (board + item-form texts) from the
/// `assets/resources_app.json` resource tree.
class AppResourceBundles {
  const AppResourceBundles._();

  /// The nested resource asset, resolved relative to the process working
  /// directory (the package root under `dart test`, the server's `working_dir`
  /// at boot — the same convention the datasource/config YAML assets use).
  static const String assetPath = 'assets/resources_app.json';

  /// The flattened bundle, parsed once and memoised.
  static Map<String, Object?>? _cache;

  /// The flat `<basePath>.<suffix>` → text map the bundle carries, loaded from
  /// [assetPath] and flattened on first access.
  static Map<String, Object?> texts() =>
      _cache ??= loadFlatResourceAsset(assetPath);

  /// The app client's full bundle (board + item-form texts).
  static ResourceBundleDto appBundle() => ResourceBundleDto(texts());
}

/// Reads a nested JSON resource asset at [path] (working-directory-relative) and
/// flattens it to the flat `<basePath>.<suffix>` map the wire bundle carries.
///
/// Throws a [StateError] when the asset is missing, rather than silently serving
/// an empty bundle — an absent text asset would otherwise break the
/// no-hard-coded-strings property invisibly.
Map<String, Object?> loadFlatResourceAsset(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Resource asset not found: $path (cwd: ${Directory.current.path})',
    );
  }
  final tree = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return flattenResourceTree(tree);
}
