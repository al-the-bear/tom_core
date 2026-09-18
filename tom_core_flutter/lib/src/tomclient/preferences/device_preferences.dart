/// Device-stored user preferences (C-14): the typed API an application reads
/// and writes machine-local settings through, on every platform.
///
/// ## Why the framework owns this
///
/// Some preferences must *not* follow the user. Which account was last used on
/// this device, whether this device's biometric unlock is enabled, a layout
/// choice that is right on a tablet and wrong on the phone in the same user's
/// pocket — storing those server-side gives every device the last one's answer.
/// Without a framework device store every application reaches for
/// `shared_preferences` (or `window.localStorage`, or a file) directly, which
/// puts a raw platform dependency at the application layer and makes the call
/// site branch on the platform. That is exactly what G-DI-3 / G-ENV-1 exist to
/// prevent.
///
/// So the shape here is the same one the framework uses everywhere else: one
/// platform-independent API, one backend per platform, and the backend chosen
/// by dependency injection rather than by an `if (kIsWeb)` where the value is
/// read.
///
/// ## The same shape as the server store
///
/// The method set deliberately mirrors `TomUserPreferences` (C-13,
/// `tom_core_server`): `all` / `read` / `get` / `getOr` / `set` / `remove`, all
/// asynchronous, all keyed by the same [TomUserPreferenceKeys] vocabulary and
/// all carrying the same [TomUserPreferenceDto] with the same
/// [TomUserPreferenceCodec] behind it. That is not incidental symmetry: it is
/// what lets a preference *move* between the two stores — a value that turns
/// out to belong to the user rather than the device — without a single call
/// site changing.
///
/// ## Whose preferences: the scope of one store
///
/// **A store is scoped to its location, not to a user.** Everything reached
/// through one [TomDevicePreferenceStore] — one JSON file, one `localStorage`
/// entry — is a single flat key space, and nothing in this module inspects who
/// is signed in. That is why the API takes no principal and there is no
/// `getFor`: a store holds no second user's values for one to select between.
///
/// So **the application separates users, and it does so by construction rather
/// than by a parameter**: an application on which more than one account can
/// sign in gives the store a `location` that names the signed-in account, and
/// installs a new store when that account changes.
///
/// ```dart
/// // On sign-in. One location per account, so two accounts on one machine
/// // keep two documents and never read each other's keys.
/// TomBean.withType(
///   TomDevicePreferences,
///   TomStoredDevicePreferences(
///     TomPlatformDevicePreferenceStore(
///       '$supportDirectory/preferences/$accountId.json',
///     ),
///   ),
/// );
/// ```
///
/// The account part must be **one path segment** (one `localStorage`
/// entry-name segment on the web) and stable for the life of the account: a
/// surrogate id, or an address percent-encoded or hashed — never a raw display
/// name. A value carrying a separator addresses a different store than the one
/// intended, silently.
///
/// Two consequences, stated rather than discovered:
///
/// - **A shared install that skips this shares its preferences.** Two people
///   signing into one copy of the application against one location write one
///   key space, so the second sees the first's last-used account, biometric
///   flag and layout. Nothing here detects it, because nothing here is told a
///   user changed.
/// - **Replacing the installed bean is the whole of the switch.**
///   [TomStoredDevicePreferences] keeps no in-memory cache — every read reaches
///   the store — so a store swapped at sign-in is in force from the next call,
///   with no invalidation step that can be forgotten.
///
/// In the four-scope configuration vocabulary (`codespecs_mapping.md` §11) that
/// makes this one class serve two scopes, decided entirely by the `location`
/// it is given: at a fixed location it is `(client app, machine)` — CE-CC's
/// scope, the same one `TomClientConfigurationStore` occupies — and at a
/// per-account location it is `(user, device)`, CE-DS. The user is bound the
/// same way the device already is: implicitly, by which store was opened.
///
/// The API stays principal-free under both, deliberately. It is what keeps the
/// method set identical to `TomUserPreferences` above, so a preference can move
/// between the two stores untouched; the user dimension lives in the store's
/// address, where it costs the call sites nothing.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/client_exceptions.dart';

/// A failure raised by the device-preferences module.
///
/// A thin semantic subtype of [TomClientException] so a caller can tell a
/// preference failure from any other client-side error with one `is` check.
/// The `key` is a stable dotted code, so callers branch on the code rather than
/// on message text:
///
/// | Key | Raised when |
/// | --- | ----------- |
/// | `device_preferences.unsupported_platform` | A platform store on a target with neither a filesystem nor a browser |
/// | `device_preferences.store.invalid_content` | The stored document is not a readable preference document |
/// | `device_preferences.store.wrong_owner` | The document belongs to a different owner than the store reading it |
/// | `device_preferences.store.conflict` | The document changed between this store's read and its write |
/// | `device_preferences.store.unreadable` | The platform refused the read — a permission, a disabled origin |
/// | `device_preferences.store.write_refused` | The platform refused the write — a full disk, an exhausted quota |
/// | `device_preferences.store.undecryptable` | An encrypting store's cipher would not read a stored value back |
/// | `device_preferences.store.reflection_not_initialised` | The application never called `initializeReflection()` |
///
/// The last two of the storage codes name **which operation** the platform
/// refused rather than why. A full disk, a read-only directory and an exhausted
/// browser quota are different events with different remedies, but each
/// platform reports them in its own vocabulary — an OS error number, a
/// `DOMException` name — so a cause classified here would be a guess wearing a
/// code. The original travels on `rootException` for a caller that wants it.
///
/// A *value* failure (a type mismatch, unparseable JSON) arrives as the kernel's
/// [TomUserPreferenceCodecException] instead, because it means the same thing in
/// both stores and is already named there. So does a refusal that belongs to the
/// preference vocabulary rather than to a store: an illegal key is
/// `preferences.key.invalid`, and a write past the account ceiling is
/// `preferences.limit.exceeded`.
class TomDevicePreferenceException extends TomClientException {
  /// Creates a device-preference exception. See [TomException] for the meaning
  /// of each argument.
  TomDevicePreferenceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Typed access to this device's machine-local preferences.
///
/// The interface, not an implementation: [TomStoredDevicePreferences] is the
/// one the framework ships, over a [TomDevicePreferenceStore] chosen per
/// platform. An application that already has a preferences mechanism can
/// implement this instead and every framework consumer keeps working.
///
/// Register it once at startup, then resolve it wherever a preference is
/// needed:
///
/// ```dart
/// TomBean.withType(
///   TomDevicePreferences,
///   TomStoredDevicePreferences(TomPlatformDevicePreferenceStore(path)),
/// );
///
/// final preferences = TomDevicePreferences.resolve()!;
/// await preferences.set('device.lastAccount', 'alex@example.com');
/// ```
///
/// That `path` is also what scopes the store: this interface knows nothing
/// about who is signed in, so on an installation where more than one account
/// can sign in it is the **application** that keeps them apart, by giving the
/// store a per-account location and installing a new one when the account
/// changes. A shared install that gives every account the same location gives
/// them the same preferences. See the library documentation for the worked
/// form and the constraints on the account part.
///
/// ## Precedence against the server store
///
/// A key normally belongs to exactly one store. Where the same key exists in
/// both — this device store and the server-side `TomUserPreferences` — **the
/// device value wins for as long as it exists**, and the server value answers
/// only a key this device has never written.
///
/// That ordering is the one that matches what a user did: writing a preference
/// on *this* device is a deliberate, later, more specific act than the value
/// that arrived with the account, so the account value behaves as a
/// cross-device default and the device value as this machine's override. It is
/// the same relationship the client-configuration module has between shipped
/// defaults and install overrides, and reversing it would make a setting a user
/// changed here revert the moment their other device wrote the same key.
///
/// The rule is stated once here and applied once in [getPreferred] — no caller
/// re-derives it, and no caller may quietly invert it.
///
/// ## Keys obey the same rule as the server's
///
/// [read], [get], [set] and [remove] reject a key that does not satisfy
/// [TomUserPreferenceKeys] with a [TomUserPreferenceKeyException]. A device
/// store never puts a key in a URL, so nothing *here* would break under a
/// looser rule — but the precedence above only means anything if both stores
/// answer to the same names, and a preference that can move from this store to
/// the server's must already carry a key the server would accept. One
/// vocabulary, one rule.
abstract class TomDevicePreferences {
  /// Allows `const` implementations.
  const TomDevicePreferences();

  /// The installed [TomDevicePreferences] bean, or `null` when none is
  /// registered.
  ///
  /// `null` rather than a throw, mirroring `TomUserPreferences.resolve`: a
  /// preference is optional by nature, and an application that has not wired a
  /// device store should fall back to its defaults rather than fail to start.
  static TomDevicePreferences? resolve() {
    final installed = TomBean.getBeanByType(TomDevicePreferences);
    return installed is TomDevicePreferences ? installed : null;
  }

  /// Every preference stored on this device, **ordered by key, ascending**.
  ///
  /// The same order the account store answers in — see
  /// [TomUserPreferencesApiService.listPreferences], where the rule and its
  /// reasons are stated once for both. That is the point of it: this method and
  /// `TomUserPreferencesClient.all()` are the two faces of one store surface, so
  /// an application that renders either list, or diffs one against the other to
  /// decide what to sync, must not have to know which face it is holding.
  ///
  /// The order a *backend* happens to hold its entries in is not the answer.
  /// [TomDevicePreferenceStore.read] lets an implementation answer from a cache,
  /// a keychain or a platform settings panel — none of which has an insertion
  /// order to preserve, and one of which may be rebuilt between two calls. The
  /// sequence is derived here, from the keys, so that it is the same one on
  /// every backend and for every document, however that document was produced.
  ///
  /// **Unmodifiable**, as `TomUserPreferencesClient.all` is. Both are snapshots
  /// of a store rather than handles on it, so a mutation would change nothing
  /// where it appeared to; and a caller moving a preference between the two
  /// holds both results at once, which is where a difference between them would
  /// be met.
  Future<List<TomUserPreferenceDto>> all();

  /// The preference stored under [key] as stored, or `null` when it has never
  /// been written.
  Future<TomUserPreferenceDto?> read(String key);

  /// The preference stored under [key], decoded as a [T].
  ///
  /// `null` when the preference does not exist. Throws a
  /// [TomUserPreferenceCodecException] when it exists but was written as a
  /// different type — see [TomUserPreferenceCodec.decode].
  Future<T?> get<T extends Object>(String key);

  /// [get], with [fallback] for a preference that has never been written.
  ///
  /// A type *mismatch* still throws: an unwritten preference is an ordinary
  /// state that a default answers, while a preference stored as the wrong type
  /// is a bug, and silently answering [fallback] would hide it.
  Future<T> getOr<T extends Object>(String key, T fallback);

  /// Writes [value] under [key], replacing any previous value, and returns the
  /// stored DTO.
  ///
  /// Scalars and `DateTime`s are written by [TomUserPreferenceCodec]; anything
  /// else must be a `@tomReflector` class, which is what makes a preference a
  /// typed object rather than a stringly-typed blob.
  Future<TomUserPreferenceDto> set<T extends Object>(String key, T value);

  /// Deletes the preference stored under [key].
  ///
  /// Answers whether a preference was removed, so a caller can tell "deleted"
  /// from "was never there" without a second read.
  Future<bool> remove(String key);

  /// Deletes every preference stored on this device.
  ///
  /// The operation a sign-out or a "reset this device" action performs. It is
  /// its own method rather than a loop over [all] because a backend can do it
  /// atomically and a loop cannot: a loop that fails half way leaves a device
  /// in a state no user asked for.
  Future<void> clear();

  /// Resolves [key] against this device store and the server store, applying
  /// the precedence documented on [TomDevicePreferences].
  ///
  /// [fromUserStore] reads the same key from the server-side store — through
  /// whatever client the application uses for `/preferences/*`. It is a
  /// callback rather than a dependency because this package must not depend on
  /// the server package, and because it is only consulted when this device has
  /// no answer: a device that has written the key never pays for the round
  /// trip.
  ///
  /// ```dart
  /// final theme = await preferences.getPreferred<String>(
  ///   TomUserPreferenceKeys.theme,
  ///   () => userPreferencesClient.get<String>(TomUserPreferenceKeys.theme),
  /// );
  /// ```
  Future<T?> getPreferred<T extends Object>(
    String key,
    Future<T?> Function() fromUserStore,
  ) async {
    return await get<T>(key) ?? await fromUserStore();
  }
}
