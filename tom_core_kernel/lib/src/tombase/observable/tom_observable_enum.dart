/// Observable enum cells whose display text is resolved from the text
/// resource bundle rather than hardcoded in Dart.
///
/// See [TomObservableEnum] for the full contract.
library;

import 'package:tom_basics/tom_basics.dart';

import '../resources/tom_resource_provider.dart';
import '../scope_ids/scope_ids.dart';
import 'tom_observable_objects.dart';

/// Declares an enum's resource segment explicitly, for enums whose segment
/// cannot be inferred.
///
/// [TomObservableEnum.enumTypeSegment] normally reads the enum's declared name
/// out of [Enum.toString], which is stable under a minifying or obfuscating
/// compile. An enum that **overrides `toString`** defeats that inference, and
/// rather than guess, the resolver rejects it. Implement this interface to
/// supply the segment yourself:
///
/// ```dart
/// enum Colour implements TomEnumResourceSegment {
///   red, green;
///
///   @override
///   String get resourceSegment => 'colour';
///
///   @override
///   String toString() => 'Colour($name)';
/// }
/// ```
///
/// The value is lower-cased before use, so `'Colour'` and `'colour'` address
/// the same bundle key.
abstract interface class TomEnumResourceSegment {
  /// The middle segment of this enum's resource keys, e.g. `todostatus` in
  /// `global.todostatus.inreview`.
  ///
  /// Must be a compile-time-stable literal — deriving it from `runtimeType`
  /// would reintroduce the very problem this interface exists to avoid.
  String get resourceSegment;
}

/// An observable [Enum] cell whose *display text* is derived from the
/// application text bundle instead of a Dart-side label table.
///
/// This is an ordinary [TomObject] holding an enum value — `|` to set, `~` to
/// read, `>>` to observe — with one addition: it also resolves the value to a
/// human-readable string through [TomTextResourceProvider], and it notifies
/// its observers when *either* the value or the installed bundle changes. That
/// second trigger is what makes a locale switch re-render a bound field
/// without the caller rebuilding anything.
///
/// ## Resource keys
///
/// The key for a value is `<scope>.<enumName>.<value>`, all lower case:
///
/// ```json
/// { "global": { "todostatus": { "inreview": "In review" } } }
/// ```
///
/// The scope segment is *implicit*: it is taken from the ambient [TomScope] at
/// construction time — scopes are never named at the call site, and there is
/// no class cataloguing resource keys as constants. Resolution walks the scope
/// chain from most specific to least specific and ends at [globalScopeId], so
/// a value declared once under `global` works everywhere while a single scope
/// can override just the labels it cares about:
///
/// ```dart
/// TomScope.withScope('checkout', () {
///   final status = TomObservableEnum(TodoStatus.inReview, values: TodoStatus.values);
///   status.displayText; // 'checkout.todostatus.inreview', else
///                       // 'global.todostatus.inreview', else 'inReview'
/// });
/// ```
///
/// The scope is captured when the cell is constructed, not when its text is
/// read — display resolution frequently happens inside a Flutter builder
/// callback, which runs outside the zone that installed the scope.
///
/// ## Missing keys
///
/// A value with no key in the bundle degrades to the raw enum name (`inReview`
/// — recognisable, never blank) and logs a warning naming the keys that were
/// tried. The warning is emitted once per key per bundle revision, so a
/// missing label in a list of a thousand rows does not flood the log, but a
/// locale switch reports it again. After a few hundred distinct missing keys
/// the warnings stop altogether — one message says so.
///
/// ## Example
///
/// ```dart
/// final status = TomObservableEnum(TodoStatus.open, values: TodoStatus.values);
///
/// // Retain the observer — observers are held weakly.
/// final observer = status >> (_) => print(status.displayText);
///
/// status | TodoStatus.inReview;                 // prints the localised label
/// TomTextResourceProvider.setAppResourceProvider(germanBundle); // prints it again
/// ```
@tomReflector
class TomObservableEnum<E extends Enum> extends TomObject<E> {
  /// Creates an observable enum cell holding [initialValue].
  ///
  /// [values] is the enum's value list (`MyEnum.values`); it is what a picker
  /// enumerates to build its options and defaults to just [initialValue] when
  /// omitted. [scope] overrides the ambient [TomScope] used for key
  /// resolution — pass it only when the cell is constructed outside the scope
  /// whose labels it should use.
  TomObservableEnum(E initialValue, {List<E>? values, TomScope? scope})
      : values = List<E>.unmodifiable(values ?? <E>[initialValue]),
        scope = scope ?? TomScope.current,
        super(initialValue) {
    _resourcesObserver = TomTextResourceProvider.appResourcesRevision >>
        (_) => notifyObservers();
  }

  /// The scope segment used to resolve display keys.
  ///
  /// Root of the fallback chain described in the class documentation; the
  /// least specific candidate is always [globalScopeId].
  static const String globalScopeId = 'global';

  /// The enum's value list, in declaration order. Unmodifiable.
  final List<E> values;

  /// The scope captured at construction, used for key resolution.
  final TomScope scope;

  /// Keeps the bundle-revision subscription alive.
  ///
  /// [TomObservable] holds observers weakly, so this strong reference is what
  /// makes a locale change reach this cell; it dies with the cell.
  late final TomFunctionObserver<TomObservable> _resourcesObserver;

  // ---------------------------------------------------------------------------
  // Static resolution
  // ---------------------------------------------------------------------------

  /// Bundle revision the entries in [_warnedKeys] were recorded against.
  static int _warnedRevision = -1;

  /// Keys already reported missing for revision [_warnedRevision].
  static final Set<String> _warnedKeys = {};

  /// Upper bound on [_warnedKeys], so the dedupe set cannot grow without limit.
  ///
  /// The set is static and lives for the process, and the number of *distinct*
  /// keys is not bounded by the number of enums: a key carries the scope path,
  /// and scope ids are arbitrary strings, so an application that opens a scope
  /// per entity produces a new key per entity. Past this many distinct missing
  /// keys the point has been made — one more warning says so and the rest are
  /// dropped until the bundle changes.
  static const int _maxWarnedKeys = 512;

  /// Whether the [_maxWarnedKeys] cutoff has already been reported for the
  /// current bundle revision.
  static bool _warnLimitReported = false;

  /// The enum-name segment of a resource key: the enum type, lower case.
  ///
  /// Read out of [Enum.toString], **not** `runtimeType`. Both yield
  /// `TodoStatus` for a `TodoStatus` value in a debug build, but only
  /// `toString` survives a minifying or obfuscating compile: the declared name
  /// is baked into the enum as a string literal, whereas `runtimeType` is a
  /// class name the compiler is free to rewrite. Measured under
  /// `dart compile js -O4 --minify`, `runtimeType` reads `minified:y` while
  /// `toString` still reads `TodoStatus.inReview`. Since this segment addresses
  /// the text bundle, taking it from `runtimeType` would lose every label in a
  /// release build while working perfectly in development.
  ///
  /// An enum that overrides `toString` defeats the inference and must declare
  /// its segment by implementing [TomEnumResourceSegment]; one that does
  /// neither is rejected rather than resolved against an unstable name.
  static String enumTypeSegment(Enum value) {
    if (value case final TomEnumResourceSegment declared) {
      return declared.resourceSegment.toLowerCase();
    }
    // The default Enum.toString() is exactly '<EnumType>.<name>'. Matching the
    // '.<name>' suffix both extracts the type and confirms the default shape.
    final text = value.toString();
    final suffix = '.${value.name}';
    if (text.length > suffix.length && text.endsWith(suffix)) {
      return text.substring(0, text.length - suffix.length).toLowerCase();
    }
    throw TomObservableException(
      'TomObservableEnum.enum_segment_error.unstable_type_name',
      "Cannot derive a stable resource segment for enum value '${value.name}': "
          "its toString() returns '$text', not '<EnumType>.${value.name}'. "
          'Implement TomEnumResourceSegment on the enum to declare the segment '
          'explicitly.',
    );
  }

  /// The value segment of a resource key: the enum constant name, lower case.
  static String valueSegment(Enum value) => value.name.toLowerCase();

  /// The resource keys tried for [value], most specific first.
  ///
  /// One key per scope-chain prefix of [scope] (defaulting to the ambient
  /// [TomScope]), followed by the [globalScopeId] key. In the default root
  /// scope the list is the single entry `global.<enumName>.<value>`.
  static List<String> resourceKeysFor(Enum value, {TomScope? scope}) {
    final suffix = '${enumTypeSegment(value)}.${valueSegment(value)}';
    final path = (scope ?? TomScope.current).getScopePath();
    final segments = path.isEmpty ? const <String>[] : path.split('.');
    final keys = <String>[];
    for (var length = segments.length; length > 0; length--) {
      keys.add('${segments.take(length).join('.')}.$suffix');
    }
    final globalKey = '$globalScopeId.$suffix';
    if (!keys.contains(globalKey)) keys.add(globalKey);
    return keys;
  }

  /// The display text for [value], or `null` when no candidate key resolves.
  ///
  /// Use this when the caller wants to supply its own fallback; [resolveText]
  /// applies the standard one.
  static String? resolveTextOrNull(Enum value, {TomScope? scope}) {
    final resources = TomTextResourceProvider.getAppResources();
    for (final key in resourceKeysFor(value, scope: scope)) {
      final text = resources.getTextOrNull(key);
      if (text != null) return text;
    }
    return null;
  }

  /// The display text for [value], falling back to its raw enum name.
  ///
  /// When no candidate key resolves, logs a warning listing the keys that were
  /// tried (once per key per bundle revision) and returns `value.name`.
  static String resolveText(Enum value, {TomScope? scope}) {
    final resolved = resolveTextOrNull(value, scope: scope);
    if (resolved != null) return resolved;
    _warnMissing(resourceKeysFor(value, scope: scope));
    return value.name;
  }

  /// The key that [resolveText] would resolve for [value].
  ///
  /// Returns the first candidate present in the bundle, or — when none is —
  /// the [globalScopeId] key, which is the one an author should add.
  static String resourceKeyFor(Enum value, {TomScope? scope}) {
    final resources = TomTextResourceProvider.getAppResources();
    final keys = resourceKeysFor(value, scope: scope);
    for (final key in keys) {
      if (resources.exists(key)) return key;
    }
    return keys.last;
  }

  /// Logs a missing-label warning for [keys], at most once per bundle revision.
  ///
  /// Stops after [_maxWarnedKeys] distinct keys — see that constant for why the
  /// set needs a ceiling at all. Installing a new bundle resets both the set
  /// and the cutoff, so a locale switch reports its missing labels afresh.
  static void _warnMissing(List<String> keys) {
    final revision = ~TomTextResourceProvider.appResourcesRevision;
    if (revision != _warnedRevision) {
      _warnedRevision = revision;
      _warnedKeys.clear();
      _warnLimitReported = false;
    }
    // Membership is checked before insertion: adding first would keep growing
    // the set past the cap by one entry for every new key.
    if (_warnedKeys.contains(keys.first)) return;
    if (_warnedKeys.length >= _maxWarnedKeys) {
      if (_warnLimitReported) return;
      _warnLimitReported = true;
      tomLog.warn('More than $_maxWarnedKeys distinct enum label resources are '
          'missing — suppressing further warnings until the text resources '
          'change.');
      return;
    }
    _warnedKeys.add(keys.first);
    tomLog.warn('No enum label resource for ${keys.first} '
        '(tried: ${keys.join(', ')}) — rendering the raw enum name.');
  }

  // ---------------------------------------------------------------------------
  // Instance accessors
  // ---------------------------------------------------------------------------

  /// The display text of the current value. See [resolveText].
  String get displayText => displayTextOf(get());

  /// The resource key of the current value. See [resourceKeyFor].
  String get displayKey => displayKeyOf(get());

  /// The display text of [value], resolved in this cell's [scope].
  String displayTextOf(E value) => resolveText(value, scope: scope);

  /// The resource key of [value], resolved in this cell's [scope].
  String displayKeyOf(E value) => resourceKeyFor(value, scope: scope);

  /// The display texts of [values], in declaration order.
  List<String> get displayTexts => values.map(displayTextOf).toList();

  /// Stops this cell from reacting to bundle changes.
  ///
  /// Rarely needed — the subscription is weakly held by the revision counter
  /// and dies with this cell. Call it when a long-lived cell should freeze on
  /// the labels it has.
  void detachFromResources() {
    TomTextResourceProvider.appResourcesRevision
        .removeObserver(_resourcesObserver);
  }

  @override
  String toString() => '~${get().name} ($displayText)';
}
