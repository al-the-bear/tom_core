import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preference_json.dart';
import 'device_preference_store.dart';
import 'device_preferences.dart';

/// A [TomDevicePreferenceStore] backed by a JSON file on the local filesystem —
/// the native (`dart:io`) variant, used on desktop and mobile.
///
/// Reach for it through `platform_device_preference_store.dart`, which selects
/// this implementation where `dart:io` exists and a different one elsewhere.
///
/// The file holds the JSON document described by [TomDevicePreferenceJson]. It
/// is written whole, never appended to, and **deleted** when the last
/// preference is removed — a device that has been reset should leave no file
/// behind, and "no file" and "empty array" must not be two ways to say the same
/// thing.
class TomPlatformDevicePreferenceStore extends TomDevicePreferenceStore
    with TomDevicePreferenceStoreConflictDetection {
  /// Creates a store over the file at [location].
  ///
  /// The path is the caller's choice because only the app knows where its
  /// machine-local state belongs — `path_provider`'s application-support
  /// directory on a Flutter client, a temporary directory in a test. Missing
  /// parent directories are created on the first [write].
  ///
  /// It is also what scopes the store: two locations are two independent key
  /// spaces, which is how an application with more than one account on one
  /// machine keeps their preferences apart. See [TomDevicePreferences].
  ///
  /// The parameter is named `location` rather than `path` because it is the
  /// *same* parameter on every platform: a filesystem path here, a
  /// `localStorage` entry name on the web. One name is what lets an application
  /// construct the store in one place without knowing which variant it got.
  ///
  /// Deliberately **not** `const`, even though this variant could be. The
  /// neutral variant cannot be — it throws from its constructor body, which is
  /// its entire purpose — and a conditional export is only worth using if one
  /// name means one signature on every target. A `const` here would make
  /// `const TomPlatformDevicePreferenceStore(location)` compile on desktop and
  /// mobile and fail to compile on the target that was supposed to fail *at run
  /// time*, turning a locatable startup diagnostic into a build break at an
  /// unrelated call site.
  ///
  /// [owner] names whose preferences these are — an opaque string the
  /// application chooses, and absent by default. When it is given, the document
  /// records it and a read refuses one written under a different owner (or
  /// under none) with `device_preferences.store.wrong_owner`. It does not
  /// replace [location] as the separation mechanism: two accounts still get two
  /// locations. What it adds is that getting that wrong fails loudly instead of
  /// serving one user the other's preferences.
  TomPlatformDevicePreferenceStore(this.location, {this.owner});

  /// Absolute path of the JSON file holding this device's preferences.
  final String location;

  /// Whose preferences this file holds, or `null` when the application names
  /// no owner.
  final String? owner;

  @override
  Future<List<TomUserPreferenceDto>> read() async {
    final file = File(location);
    final String content;
    try {
      if (!await file.exists()) {
        rememberDocument(null);
        return [];
      }
      content = await file.readAsString();
    } on Exception catch (error, stack) {
      throw _storeUnreachable(
        'device_preferences.store.unreadable',
        'could not be read',
        error,
        stack,
      );
    }
    // Remembered before decoding: the identity is the text that is *there*, and
    // a document this build refuses to decode is still the one a concurrent
    // writer would be overwriting.
    rememberDocument(content);
    return TomDevicePreferenceJson.decode(
      content,
      source: location,
      owner: owner,
    );
  }

  /// The file's current text, or `null` when there is no file.
  Future<String?> _currentDocument(File file) async =>
      await file.exists() ? file.readAsString() : null;

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    final file = File(location);
    final String? current;
    try {
      current = await _currentDocument(file);
    } on Exception catch (error, stack) {
      throw _storeUnreachable(
        'device_preferences.store.unreadable',
        'could not be read',
        error,
        stack,
      );
    }
    // Outside the `try`: a conflict is already a named failure of this module,
    // and wrapping it would bury the one code a caller is meant to branch on
    // under a code about the filesystem.
    requireUnchanged(current, source: location);
    try {
      if (values.isEmpty) {
        if (await file.exists()) await file.delete();
        rememberDocument(null);
        return;
      }
      await file.parent.create(recursive: true);
      // Write-then-rename: a rename within a directory is atomic, so a failure
      // part-way through leaves the previous content readable instead of a
      // truncated file — which the store contract requires, and which matters
      // here because a truncated document silently discards everything the user
      // chose on this device.
      final temporary = File('$location.part');
      final document = TomDevicePreferenceJson.encode(values, owner: owner);
      await temporary.writeAsString(document, flush: true);
      await temporary.rename(location);
      rememberDocument(document);
    } on TomDevicePreferenceException {
      // Already this module's: an unencodable document, or reflection that was
      // never initialised. Re-wrapping would say the filesystem refused a write
      // it was never asked to make.
      rethrow;
    } on Exception catch (error, stack) {
      throw _storeUnreachable(
        'device_preferences.store.write_refused',
        'refused the write',
        error,
        stack,
      );
    }
  }

  /// The platform's refusal, as this module's failure.
  ///
  /// The cause travels on `rootException` rather than being classified here. A
  /// full disk, a read-only support directory and a path that is not a file are
  /// different events with different remedies, but `dart:io` reports them as
  /// one exception type distinguished by an OS error number whose meaning is
  /// per-platform — so a classification made here would be a guess wearing a
  /// code. What the caller gets instead is a code for *which operation* failed,
  /// which is the part this module can state truthfully, and the original to
  /// inspect.
  TomDevicePreferenceException _storeUnreachable(
    String key,
    String what,
    Object error,
    StackTrace stack,
  ) => TomDevicePreferenceException(
    key,
    'The device preference store $location $what: $error',
    parameters: {'source': location},
    rootException: error,
    stack: stack,
  );
}
