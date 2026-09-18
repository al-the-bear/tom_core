import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:web/web.dart';

import 'device_preference_json.dart';
import 'device_preference_store.dart';
import 'device_preferences.dart';

/// A [TomDevicePreferenceStore] backed by the browser's `localStorage` — the
/// web (`dart:js`) variant.
///
/// Reach for it through `platform_device_preference_store.dart`, which selects
/// this implementation in the browser and a different one elsewhere.
///
/// `localStorage` rather than `sessionStorage` or a cookie: a device preference
/// must survive the tab being closed (which `sessionStorage` does not), and it
/// is machine-local state that has no business being attached to every request
/// (which a cookie is).
///
/// The whole document is stored under **one** entry, holding the JSON described
/// by [TomDevicePreferenceJson] — the same text the file backend writes. One
/// entry rather than one per preference so that a write is atomic in the only
/// sense `localStorage` offers: a single `setItem` either happened or did not,
/// while a loop over keys can be interrupted by the tab closing and leave a
/// half-written set.
class TomPlatformDevicePreferenceStore extends TomDevicePreferenceStore
    with TomDevicePreferenceStoreConflictDetection {
  /// Creates a store over the `localStorage` entry named [location].
  ///
  /// The name is the caller's choice because a browser origin is shared by
  /// everything the app serves from it, and only the app knows which name is
  /// free.
  ///
  /// It is also what scopes the store: two entry names are two independent key
  /// spaces, which is how an application with more than one account on one
  /// machine keeps their preferences apart. See [TomDevicePreferences].
  ///
  /// The parameter is named `location` rather than `entryName` because it is
  /// the *same* parameter on every platform: a `localStorage` entry name here,
  /// a filesystem path on desktop and mobile. One name is what lets an
  /// application construct the store in one place without knowing which variant
  /// it got.
  ///
  /// Deliberately **not** `const`, even though this variant could be. The
  /// neutral variant cannot be — it throws from its constructor body, which is
  /// its entire purpose — and a conditional export is only worth using if one
  /// name means one signature on every target. A `const` here would make
  /// `const TomPlatformDevicePreferenceStore(location)` compile in the browser
  /// and fail to compile on the target that was supposed to fail *at run time*,
  /// turning a locatable startup diagnostic into a build break at an unrelated
  /// call site.
  ///
  /// [owner] names whose preferences these are — an opaque string the
  /// application chooses, and absent by default. When it is given, the document
  /// records it and a read refuses one written under a different owner (or
  /// under none) with `device_preferences.store.wrong_owner`. It does not
  /// replace [location] as the separation mechanism: two accounts still get two
  /// locations. What it adds is that getting that wrong fails loudly instead of
  /// serving one user the other's preferences.
  TomPlatformDevicePreferenceStore(this.location, {this.owner});

  /// Name of the `localStorage` entry holding this device's preferences.
  final String location;

  /// Whose preferences this entry holds, or `null` when the application names
  /// no owner.
  final String? owner;

  @override
  Future<List<TomUserPreferenceDto>> read() async {
    final String? content;
    try {
      content = window.localStorage.getItem(location);
    } on Object catch (error, stack) {
      // A browser may refuse to hand `localStorage` over at all — third-party
      // context, storage disabled for the origin — and it says so with its own
      // `DOMException`, which is not a Dart `Exception`.
      throw _storeUnreachable(
        'device_preferences.store.unreadable',
        'could not be read',
        error,
        stack,
      );
    }
    // Remembered before decoding: the identity is the text that is *there*, and
    // a document this build refuses to decode is still the one another tab
    // would be overwriting.
    rememberDocument(content);
    if (content == null) return [];
    return TomDevicePreferenceJson.decode(
      content,
      source: location,
      owner: owner,
    );
  }

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    final String? current;
    try {
      current = window.localStorage.getItem(location);
    } on Object catch (error, stack) {
      throw _storeUnreachable(
        'device_preferences.store.unreadable',
        'could not be read',
        error,
        stack,
      );
    }
    // Outside the `try`: a conflict is already a named failure of this module,
    // and wrapping it would bury the one code a caller is meant to branch on
    // under a code about the browser.
    requireUnchanged(current, source: location);
    if (values.isEmpty) {
      // Removed rather than set to `[]`, so that "never written" and "cleared"
      // are one state here exactly as they are in the file backend.
      _refusable(() => window.localStorage.removeItem(location));
      rememberDocument(null);
      return;
    }
    final document = TomDevicePreferenceJson.encode(values, owner: owner);
    _refusable(() => window.localStorage.setItem(location, document));
    rememberDocument(document);
  }

  /// Runs [write], reporting a browser refusal as this module's failure.
  ///
  /// The one storage failure a correctly configured web client actually meets:
  /// `setItem` throws when the origin's quota is exhausted, and the browser
  /// says so with a `DOMException` — not a Dart `Exception`, so `on Object` is
  /// what catches it.
  void _refusable(void Function() write) {
    try {
      write();
    } on Object catch (error, stack) {
      throw _storeUnreachable(
        'device_preferences.store.write_refused',
        'refused the write',
        error,
        stack,
      );
    }
  }

  /// The browser's refusal, as this module's failure.
  ///
  /// The cause travels on `rootException` rather than being classified here.
  /// Quota exhaustion and storage disabled for the origin are different events
  /// with different remedies, and a browser distinguishes them by the `name` of
  /// a `DOMException` — a value the interop type does not promise across
  /// engines, so a classification made here would be a guess wearing a code.
  /// What the caller gets is a code for *which operation* failed, which is the
  /// part this module can state truthfully, and the original to inspect.
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
