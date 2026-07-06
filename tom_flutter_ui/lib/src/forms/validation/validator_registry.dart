import 'validation_result.dart';
import 'validators.dart';

/// Produces a [Validator] from the argument list parsed out of a resource
/// declaration (C-11).
///
/// The returned validator is typed `Validator<Object?>` so that, by Dart's
/// function contravariance, it is assignable wherever a field expects a
/// `Validator<T>` — the field casts each stored validator to `Validator<T>`
/// before invoking it (`tom_form.dart`), and a `Function(Object?)` is a valid
/// `Function(T)`. Factories therefore accept the field value as `Object?` and
/// narrow internally.
///
/// [args] are the colon-separated arguments from a validator spec (see
/// [TomValidatorRegistry.parseSpec]): `minLength:5` yields `['5']`. A factory
/// that receives malformed or missing arguments must throw [ArgumentError].
typedef TomValidatorFactory = Validator<Object?> Function(List<String> args);

/// Resolves **named validators** declared in a field's resource bundle into
/// concrete [Validator] instances (C-11).
///
/// A field's resource bundle may declare its validators by name under the
/// `<basePath>.validators` key, e.g. `required,minLength:8,strongPassword`.
/// The registry maps each name to a [TomValidatorFactory] and produces the
/// validator instances the field runs. The built-in [Validators] are
/// pre-registered; applications add custom validators (e.g. `strongPassword`)
/// via [register].
///
/// The registry is **dependency-injected**: consumers read [instance] (a
/// process-wide default) and tests/applications swap it via the [instance]
/// setter, restoring with [resetInstance]. Error messages produced by the
/// resolved validators resolve as resource keys exactly like code-declared
/// validators (scoped `<basePath>.<key>` then global `<key>`), so no separate
/// message plumbing is needed.
class TomValidatorRegistry {
  /// Creates a registry pre-populated with the built-in validators.
  TomValidatorRegistry() {
    _registerBuiltins();
  }

  /// The process-wide registry used by fields to resolve resource-declared
  /// validators. Reassign it (e.g. in tests or to install a custom-configured
  /// registry) directly; restore the default with [resetInstance].
  static TomValidatorRegistry instance = TomValidatorRegistry();

  /// Restores the default registry (only the built-ins registered).
  static void resetInstance() => instance = TomValidatorRegistry();

  final Map<String, TomValidatorFactory> _factories = {};

  /// Registers [factory] under [name], replacing any existing factory.
  ///
  /// Custom validators referenced from resources (e.g. `strongPassword`) are
  /// registered here before any field that names them is validated.
  void register(String name, TomValidatorFactory factory) {
    _factories[name] = factory;
  }

  /// Whether a validator named [name] is registered.
  bool has(String name) => _factories.containsKey(name);

  /// The registered validator names, in insertion order.
  Iterable<String> get names => _factories.keys;

  /// Resolves the validator [name] with optional [args], or `null` when the
  /// name is unknown. Prefer [resolveOrThrow] when a missing name is an error.
  Validator<Object?>? resolve(String name, [List<String> args = const []]) {
    final factory = _factories[name];
    if (factory == null) return null;
    return factory(args);
  }

  /// Resolves the validator [name] with optional [args], throwing
  /// [ArgumentError] (listing the known names) when [name] is unregistered.
  Validator<Object?> resolveOrThrow(String name,
      [List<String> args = const []]) {
    final factory = _factories[name];
    if (factory == null) {
      throw ArgumentError(
        'Unknown validator "$name". Registered validators: '
        '${names.join(', ')}.',
      );
    }
    return factory(args);
  }

  /// Resolves a single validator spec of the form `name[:arg[:arg…]]`
  /// (e.g. `minLength:8`) into a validator instance.
  Validator<Object?> resolveSpec(String spec) {
    final (name, args) = parseSpec(spec);
    return resolveOrThrow(name, args);
  }

  /// Resolves a comma-separated [declaration] (the raw `<basePath>.validators`
  /// resource value, e.g. `required,minLength:8,strongPassword`) into the list
  /// of validators to run, in declaration order. Blank entries are ignored.
  List<Validator<Object?>> resolveDeclaration(String declaration) => [
        for (final spec in declaration.split(','))
          if (spec.trim().isNotEmpty) resolveSpec(spec.trim()),
      ];

  /// Splits a validator [spec] into its name and colon-separated arguments.
  ///
  /// `minLength:8` → `('minLength', ['8'])`; `required` → `('required', [])`.
  /// Whitespace around the name and each argument is trimmed.
  static (String, List<String>) parseSpec(String spec) {
    final parts = spec.split(':');
    final name = parts.first.trim();
    final args = parts.skip(1).map((a) => a.trim()).toList();
    return (name, args);
  }

  // --- Built-in validators -------------------------------------------------

  void _registerBuiltins() {
    register('required', (_) => (Object? value) => Validators.requiredInstance(value));
    register('email', (_) => _wrapString(Validators.email()));
    register('minLength',
        (args) => _wrapString(Validators.minLength(_intArg(args, 'minLength'))));
    register('maxLength',
        (args) => _wrapString(Validators.maxLength(_intArg(args, 'maxLength'))));
    register('pattern', (args) {
      final regex = _regexArg(args, 'pattern');
      return _wrapString(Validators.pattern(regex));
    });
    register('min', (args) => _wrapNum(Validators.min(_numArg(args, 'min'))));
    register('max', (args) => _wrapNum(Validators.max(_numArg(args, 'max'))));
  }

  /// Adapts a `Validator<String>` to `Validator<Object?>` by narrowing the
  /// incoming value. Fields declaring string validators always hold string
  /// values, so the cast is safe at the call site.
  static Validator<Object?> _wrapString(Validator<String> inner) =>
      (Object? value) => inner(value as String);

  /// Adapts a `Validator<num>` to `Validator<Object?>` by narrowing the value.
  static Validator<Object?> _wrapNum(Validator<num> inner) =>
      (Object? value) => inner(value as num);

  static int _intArg(List<String> args, String validatorName) {
    if (args.isEmpty) {
      throw ArgumentError('Validator "$validatorName" requires an integer '
          'argument (e.g. "$validatorName:8").');
    }
    final parsed = int.tryParse(args.first);
    if (parsed == null) {
      throw ArgumentError('Validator "$validatorName" argument "${args.first}" '
          'is not an integer.');
    }
    return parsed;
  }

  static num _numArg(List<String> args, String validatorName) {
    if (args.isEmpty) {
      throw ArgumentError('Validator "$validatorName" requires a numeric '
          'argument (e.g. "$validatorName:10").');
    }
    final parsed = num.tryParse(args.first);
    if (parsed == null) {
      throw ArgumentError('Validator "$validatorName" argument "${args.first}" '
          'is not a number.');
    }
    return parsed;
  }

  static RegExp _regexArg(List<String> args, String validatorName) {
    if (args.isEmpty) {
      throw ArgumentError('Validator "$validatorName" requires a regular-'
          'expression argument (e.g. "$validatorName:^[a-z]+\$").');
    }
    // Re-join on ':' so patterns containing colons survive parseSpec.
    return RegExp(args.join(':'));
  }
}
