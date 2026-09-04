/// Tests for the security module's discovery annotation, `TomClient2FAAdaptor`.
///
/// The annotation is a `const` value object, but the thing worth pinning down
/// is not its shape — it is that **something reads it**. `Tom2FAClientRegistry`
/// scans the reflected program for annotated classes and registers each one
/// under the mechanism key it declares, which is what lets a mechanism ship as
/// a package that adds a server adaptor and a client mechanism and touches no
/// framework file. These tests hold both halves: the annotation still carries
/// its `type`, and annotating a real mechanism is genuinely enough to make the
/// flow able to render it.
///
/// Two kinds of candidate appear below, and the split is deliberate:
///
/// * [AnnotatedAdaptor] is a *real* reflected class, so the automatic scan
///   reaches it exactly as it would reach an application's own mechanism. It
///   must be a usable [Tom2FAClientMechanism] for that reason — a class
///   annotated `@TomClient2FAAdaptor` but unusable cannot live in a reflected
///   library, because the scan would then find it from every other test in this
///   process.
/// * The malformed cases therefore use [_CandidateMirror], a hand-built mirror
///   handed straight to `registerAnnotated`, which is the seam that exists so
///   the candidate set does not always have to be the whole program.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/security/security_example.dart' as example;
import 'security_test.reflection.dart';

/// A reflected, annotated, *usable* client mechanism.
///
/// Annotated `@tomReflector` so the generator emits a mirror, and
/// `@TomClient2FAAdaptor('totp')` so the scan finds it. It renders nothing
/// interesting — the panels are `two_factor_client_test.dart`'s subject; what
/// this class exists to prove is that the annotation alone put it in the
/// registry.
@tomReflector
@TomClient2FAAdaptor('totp')
class AnnotatedAdaptor extends Tom2FAClientMechanism {
  /// Creates the discovered mechanism. Unnamed and argument-free because that
  /// is the constructor the scan calls.
  const AnnotatedAdaptor() : super('totp');

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) => const SizedBox.shrink();

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) => const SizedBox.shrink();
}

/// A mechanism that answers for whatever key it is given, for the tests that
/// need a second, distinguishable registration.
class _NamedMechanism extends Tom2FAClientMechanism {
  const _NamedMechanism(super.type);

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) => const SizedBox.shrink();

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) => const SizedBox.shrink();
}

/// One candidate for the mechanism scan, standing in for a reflected class.
///
/// A hand-built mirror rather than a reflected fixture, for the reason the
/// library comment gives: a broken annotated class in a reflected library would
/// be found by every other test in this process. Only [metadata], [newInstance]
/// and the name the failure messages interpolate are needed; [noSuchMethod]
/// makes anything else a loud test bug rather than a silent `null`.
class _CandidateMirror implements ClassMirror<Object> {
  _CandidateMirror(
    this._name, {
    required List<Object> metadata,
    required Object Function() instantiate,
  }) : _metadata = metadata,
       _instantiate = instantiate;

  final String _name;
  final List<Object> _metadata;
  final Object Function() _instantiate;

  @override
  List<Object> get metadata => _metadata;

  @override
  Object newInstance(
    String constructorName,
    List<dynamic> positionalArguments, [
    Map<Symbol, dynamic> namedArguments = const {},
  ]) => _instantiate();

  @override
  String toString() => _name;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The candidate mirror was asked for ${invocation.memberName}, which '
    'the mechanism scan does not use. Implement it here if that changes.',
  );
}

void main() {
  setUpAll(initializeReflection);

  // Every test starts from a bare registry with the scan re-armed, so one
  // test's discovery cannot answer the next one's question.
  setUp(Tom2FAClientRegistry.reset);
  tearDown(Tom2FAClientRegistry.reset);

  group('TomClient2FAAdaptor', () {
    test('exposes the type it was constructed with', () {
      const adaptor = TomClient2FAAdaptor('sms');
      expect(adaptor.type, 'sms');
    });

    test('is a compile-time constant (canonicalized)', () {
      const a = TomClient2FAAdaptor('totp');
      const b = TomClient2FAAdaptor('totp');
      expect(identical(a, b), isTrue);
    });

    test('is reflection-discoverable on an annotated class', () {
      // The metadata the scan reads. A regression in the @tomReflector
      // registration would make it vanish, and discovery would go quiet rather
      // than fail — so it is asserted directly as well as through the scan.
      final mirror = tomReflector.reflectType(AnnotatedAdaptor) as ClassMirror;
      final adaptors = mirror.metadata.whereType<TomClient2FAAdaptor>();
      expect(adaptors, isNotEmpty);
      expect(adaptors.first.type, 'totp');
    });
  });

  group('the mechanism scan', () {
    /// Asserts that scanning [candidate] alone fails with [key] and a message
    /// naming the candidate — the scan runs at start-up with nothing else in
    /// the frame, so a message that only said "a mechanism is unusable" would
    /// leave a developer grepping.
    void expectScanFailure(_CandidateMirror candidate, String key) {
      expect(
        () => Tom2FAClientRegistry.registerAnnotated([candidate]),
        throwsA(
          isA<Tom2FAClientException>()
              .having((e) => e.key, 'key', key)
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('$candidate'),
              ),
        ),
      );
    }

    test('registers a well-formed candidate under the annotated type', () {
      const mechanism = _NamedMechanism('carrier-pigeon');
      Tom2FAClientRegistry.registerAnnotated([
        _CandidateMirror(
          'GoodMechanism',
          metadata: const [TomClient2FAAdaptor('carrier-pigeon')],
          instantiate: () => mechanism,
        ),
      ]);
      expect(
        identical(Tom2FAClientRegistry.find('carrier-pigeon'), mechanism),
        isTrue,
      );
    });

    test('ignores a class with no @TomClient2FAAdaptor annotation', () {
      // The candidate set is the whole reflected program, so most of it is not
      // a mechanism and must be walked past without being constructed — the
      // scan may not instantiate arbitrary classes to find out what they are.
      expect(
        () => Tom2FAClientRegistry.registerAnnotated([
          _CandidateMirror(
            'OrdinaryClass',
            metadata: const [],
            instantiate: () => fail('an unannotated class must not be built'),
          ),
        ]),
        returnsNormally,
      );
    });

    test('refuses a mechanism that cannot be constructed', () {
      expectScanFailure(
        _CandidateMirror(
          'NeedsCollaboratorsMechanism',
          metadata: const [TomClient2FAAdaptor('sms')],
          instantiate: () => throw StateError('no no-argument constructor'),
        ),
        'two_factor_client.adaptor_instantiation_failed',
      );
    });

    test('refuses a class that is not a Tom2FAClientMechanism', () {
      // The annotation is the only thing declaring intent here, so a class
      // that carries it but cannot render has to be named at scan time —
      // otherwise it fails at the one moment a user is mid-login.
      expectScanFailure(
        _CandidateMirror(
          'NotAMechanism',
          metadata: const [TomClient2FAAdaptor('sms')],
          instantiate: Object.new,
        ),
        'two_factor_client.adaptor_does_not_implement_mechanism',
      );
    });

    test('refuses a mechanism whose own type contradicts the annotation', () {
      // The key is declared twice — on the annotation and on the mechanism —
      // because the annotation mirrors the server's `@Tom2FAAdaptor('sms')`
      // idiom and dropping the field would break that pairing. Duplication is
      // only safe while the two are checked against each other; a silent
      // disagreement would register a panel under a key it does not answer for,
      // and the mismatch would surface as a blank challenge screen.
      expect(
        () => Tom2FAClientRegistry.registerAnnotated([
          _CandidateMirror(
            'ConfusedMechanism',
            metadata: const [TomClient2FAAdaptor('sms')],
            instantiate: () => const _NamedMechanism('email'),
          ),
        ]),
        throwsA(
          isA<Tom2FAClientException>()
              .having(
                (e) => e.key,
                'key',
                'two_factor_client.adaptor_type_mismatch',
              )
              .having((e) => e.defaultUserMessage, 'message', contains('"sms"'))
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('"email"'),
              ),
        ),
      );
    });

    test('the mechanism the bad candidate claimed is named too', () {
      // Both halves of the wiring are in the message: which class, and which
      // mechanism it was going to answer for. The second is what says whether
      // the login that stopped working is this one.
      expect(
        () => Tom2FAClientRegistry.registerAnnotated([
          _CandidateMirror(
            'NotAMechanism',
            metadata: const [TomClient2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
        ]),
        throwsA(
          isA<Tom2FAClientException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('"sms"'),
          ),
        ),
      );
    });

    test('two annotated classes claiming one key are refused, naming both', () {
      // Unlike an explicit `register`, which *replaces* on purpose, two
      // annotations claiming one key is a wiring bug with no decision behind
      // it: nobody chose which of the two should win, and picking one silently
      // would make the winner depend on reflection ordering.
      expect(
        () => Tom2FAClientRegistry.registerAnnotated([
          _CandidateMirror(
            'FirstClaimant',
            metadata: const [TomClient2FAAdaptor('carrier-pigeon')],
            instantiate: () => const _NamedMechanism('carrier-pigeon'),
          ),
          _CandidateMirror(
            'SecondClaimant',
            metadata: const [TomClient2FAAdaptor('carrier-pigeon')],
            instantiate: () => const _NamedMechanism('carrier-pigeon'),
          ),
        ]),
        throwsA(
          isA<Tom2FAClientException>()
              .having(
                (e) => e.key,
                'key',
                'two_factor_client.duplicate_adaptor',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('FirstClaimant'),
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('SecondClaimant'),
              ),
        ),
      );
    });

    test('an explicit registration beats a discovered one', () {
      // The one place the client must diverge from the server. `register`
      // replaces by design, because substituting the shipped TOTP panel is a
      // documented normal case — so a hand-registered mechanism is a decision
      // already taken, and the scan must not undo it. Silently: the developer
      // who registered it asked for exactly this.
      const chosen = _NamedMechanism('carrier-pigeon');
      Tom2FAClientRegistry.register(chosen);

      Tom2FAClientRegistry.registerAnnotated([
        _CandidateMirror(
          'DiscoveredMechanism',
          metadata: const [TomClient2FAAdaptor('carrier-pigeon')],
          instantiate: () => const _NamedMechanism('carrier-pigeon'),
        ),
      ]);

      expect(
        identical(Tom2FAClientRegistry.find('carrier-pigeon'), chosen),
        isTrue,
      );
    });

    test('a scan that fails leaves nothing of itself behind', () {
      // "The registry is wrong at start-up, not at the login that happens to
      // need the missing mechanism" has to mean the registry a caller can still
      // see afterwards, not merely that the scan threw. It matters because a
      // failed scan is retried: leftovers from the first attempt would collide
      // with the second attempt's fresh instances.
      expect(
        () => Tom2FAClientRegistry.registerAnnotated([
          _CandidateMirror(
            'GoodMechanism',
            metadata: const [TomClient2FAAdaptor('carrier-pigeon')],
            instantiate: () => const _NamedMechanism('carrier-pigeon'),
          ),
          _CandidateMirror(
            'NotAMechanism',
            metadata: const [TomClient2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
        ]),
        throwsA(isA<Tom2FAClientException>()),
      );
      expect(
        Tom2FAClientRegistry.find('carrier-pigeon'),
        isNull,
        reason: 'the candidate registered before the failure is rolled back',
      );
    });

    test('a scan that fails leaves earlier registrations alone', () {
      // The converse, so the rollback cannot be implemented as "clear
      // everything": registrations that were already there are not the scan's
      // to undo.
      const hand = _NamedMechanism('hand-wired');
      Tom2FAClientRegistry.register(hand);

      expect(
        () => Tom2FAClientRegistry.registerAnnotated([
          _CandidateMirror(
            'NotAMechanism',
            metadata: const [TomClient2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
        ]),
        throwsA(isA<Tom2FAClientException>()),
      );
      expect(identical(Tom2FAClientRegistry.find('hand-wired'), hand), isTrue);
    });

    test('the scan stops at the first unusable candidate', () {
      // Carrying on past a broken mechanism is the tempting kindness that must
      // not be offered: it would turn a start-up wiring error into a login-time
      // one for whichever mechanism the developer did not exercise that day.
      var reached = false;
      expect(
        () => Tom2FAClientRegistry.registerAnnotated([
          _CandidateMirror(
            'NotAMechanism',
            metadata: const [TomClient2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
          _CandidateMirror(
            'GoodMechanism',
            metadata: const [TomClient2FAAdaptor('carrier-pigeon')],
            instantiate: () {
              reached = true;
              return const _NamedMechanism('carrier-pigeon');
            },
          ),
        ]),
        throwsA(isA<Tom2FAClientException>()),
      );
      expect(reached, isFalse);
      expect(Tom2FAClientRegistry.find('carrier-pigeon'), isNull);
    });
  });

  group('the automatic scan', () {
    // Here the candidate set is the real one: whatever the generated reflection
    // for this suite knows about, which includes `AnnotatedAdaptor`.

    test('find() discovers an annotated mechanism nobody registered', () {
      // The whole point of the todo this suite closes: annotating a class is
      // now enough. Before the scan existed, this returned null.
      expect(Tom2FAClientRegistry.find('totp'), isA<AnnotatedAdaptor>());
    });

    test('has() runs the scan too', () {
      expect(Tom2FAClientRegistry.has('totp'), isTrue);
    });

    test('types runs the scan too', () {
      expect(Tom2FAClientRegistry.types, contains('totp'));
    });

    test('a successful scan is not repeated', () {
      // Same instance on the second read, so the mechanism a panel is holding
      // mid-flow cannot be swapped for a fresh one underneath it — and the scan
      // does not pay for itself on every lookup.
      final first = Tom2FAClientRegistry.find('totp');
      Tom2FAClientRegistry.register(const _NamedMechanism('hand-wired'));
      expect(identical(Tom2FAClientRegistry.find('totp'), first), isTrue);
    });

    test('registerBuiltInMechanisms leaves a discovered totp in place', () {
      // The end-to-end shape. The flow asks `has` first, which runs the scan,
      // so an annotated custom TOTP beats the built-in with no ordering rule
      // written anywhere — the lazy scan is what makes that fall out.
      Tom2FAFlowPanel.registerBuiltInMechanisms();
      expect(Tom2FAClientRegistry.find('totp'), isA<AnnotatedAdaptor>());
    });

    test('reset() re-arms the scan', () {
      expect(Tom2FAClientRegistry.has('totp'), isTrue);
      Tom2FAClientRegistry.reset();
      // Not merely empty: a `reset` that dropped the registrations but left the
      // scan marked done would leave a permanently empty registry, which is the
      // failure mode hardest to recognise from the outside.
      expect(Tom2FAClientRegistry.find('totp'), isA<AnnotatedAdaptor>());
    });
  });

  group('the shipped example runs', () {
    test('security_example.run() completes its assertions', () async {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      //
      // Awaited rather than fired and forgotten: the example walks a
      // controller through the flow, and every move it makes is a `Future`.
      // Dropping the await would let this test pass before a single assertion
      // downstream of the first move had been evaluated.
      await example.run();
    });
  });
}
