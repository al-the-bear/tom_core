import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart' show FixtureDocumentRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// C-4 (G-AUTHZ-4) column-level access-rights tests.
///
/// The done-bar is "a read masks unauthorized columns; a write to a read-only
/// column is rejected server-side; both tested". The repository's read-mask and
/// write-enforcement both delegate to the *pure* decision core in
/// [TomColumnAuthorization] ([maskedColumns], [decideWrites], [stateForKey]),
/// which takes value/key accessors as callbacks so it runs without a database
/// or the reflection runtime. Most of what follows exercises that core directly
/// over plain string column tokens with a stub [TomColumnAuthResolver],
/// asserting the same masking and write outcomes the repository relies on.
///
/// Two things cannot be said that way and are tested against the reflected
/// fixture instead: [TomColumnAuthorization.applyReadMask], which is the entry
/// point the repository actually calls and which writes through a column mirror
/// onto a live instance, and the default resolver — the behaviour of a
/// deployment that passes no resolver at all.

/// A stub resolver mapping resource keys to grades; any unmapped key denies
/// (state [TomAuthState.none]) so a test must opt a column into a grade.
TomColumnAuthResolver _resolver(Map<String, TomAuthState> grades) =>
    (key) => grades[key] ?? TomAuthState.none;

/// A partition sentinel: rejection means [onForbidden] fired.
Never _reject(String column, String authKey, TomAuthState grade) =>
    throw StateError('forbidden:$column:$authKey:${grade.name}');

/// The resource key [FixtureDocumentRecord.secretAttachment] is graded under.
const String _secretKey = 'fixture.document.secret_attachment';

/// An adapter that grades every key it is asked about the same way, so the
/// process-wide singleton can be observed being consulted at all.
class _FixedAdapter implements TomAuthorizationAdapter {
  final TomAuthState state;

  _FixedAdapter(this.state);

  @override
  TomAuthState resolveAuth(String resourceKeyPath) => state;
}

void main() {
  group('stateForKey', () {
    test('a null authKey is an unrestricted column (full)', () {
      expect(TomColumnAuthorization.stateForKey(null), TomAuthState.full);
    });

    test('a non-null key resolves through the provided resolver', () {
      final resolver = _resolver({'secret': TomAuthState.none});
      expect(
        TomColumnAuthorization.stateForKey('secret', resolver: resolver),
        TomAuthState.none,
      );
      // An unmapped key falls to the stub's deny default.
      expect(
        TomColumnAuthorization.stateForKey('other', resolver: resolver),
        TomAuthState.none,
      );
    });
  });

  group('stateForKey without a resolver (the default path)', () {
    // Every other test here hands in a resolver, which is what the repository
    // does when a call site has one. A caller that does not is the *deployment*
    // case, and it resolves through the process-wide singleton — so what an
    // unconfigured server does with a graded column is decided here and
    // nowhere else.
    tearDown(TomAuthorization.reset);

    test('an unconfigured process leaves a graded column unrestricted', () {
      // No adapter installed: development mode. A server that has not wired up
      // authorization must not silently blank out its own data, so the absence
      // of a policy grants rather than denies.
      TomAuthorization.reset();
      expect(TomColumnAuthorization.stateForKey(_secretKey), TomAuthState.full);
    });

    test('an installed adapter decides the grade', () {
      TomAuthorization.adapter = _FixedAdapter(TomAuthState.none);
      expect(TomColumnAuthorization.stateForKey(_secretKey), TomAuthState.none);
      // A null key is unrestricted *before* the resolver is reached, so the
      // adapter is never asked about a column that carries no key.
      expect(TomColumnAuthorization.stateForKey(null), TomAuthState.full);
    });
  });

  group('maskedColumns (read projection)', () {
    // salary is masked (none), ssn is masked (disabled), name is read, age full.
    final resolver = _resolver({
      'k.salary': TomAuthState.none,
      'k.ssn': TomAuthState.disabled,
      'k.name': TomAuthState.read,
      'k.age': TomAuthState.full,
    });
    final keys = {
      'salary': 'k.salary',
      'ssn': 'k.ssn',
      'name': 'k.name',
      'age': 'k.age',
      'note': null, // unrestricted column
    };

    test('masks exactly the columns whose grade lacks showsContent', () {
      final masked = TomColumnAuthorization.maskedColumns<String>(
        columns: keys.keys,
        keyOf: (c) => keys[c],
        resolver: resolver,
      );
      // none + disabled are masked; read + full + unrestricted are not.
      expect(masked, unorderedEquals(['salary', 'ssn']));
    });

    test('an all-unrestricted column set masks nothing', () {
      final masked = TomColumnAuthorization.maskedColumns<String>(
        columns: const ['a', 'b'],
        keyOf: (_) => null,
        resolver: resolver,
      );
      expect(masked, isEmpty);
    });
  });

  group('decideWrites (write enforcement)', () {
    // grade: full=writable, read=visible-not-editable, disabled/none=masked.
    final resolver = _resolver({
      'k.title': TomAuthState.full,
      'k.status': TomAuthState.read,
      'k.salary': TomAuthState.none,
      'k.ssn': TomAuthState.disabled,
    });
    final keys = {
      'title': 'k.title',
      'status': 'k.status',
      'salary': 'k.salary',
      'ssn': 'k.ssn',
      'note': null,
    };

    TomColumnWriteDecision<String> decide(Set<String> changed) {
      return TomColumnAuthorization.decideWrites<String>(
        columns: keys.keys,
        gradeOf: (c) => keys[c],
        changed: changed.contains,
        onForbidden: _reject,
        resolver: resolver,
      );
    }

    test('full and unrestricted columns are writable; the rest preserved', () {
      // Nothing changed → no rejection possible; partition is by grade only.
      final decision = decide(const {});
      expect(decision.writable, unorderedEquals(['title', 'note']));
      expect(decision.preserved, unorderedEquals(['status', 'salary', 'ssn']));
    });

    test('a changed visible (read) column is a rejectable violation', () {
      expect(
        () => decide({'status'}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'forbidden:status:k.status:read',
          ),
        ),
      );
    });

    test('an unchanged read column is preserved, not rejected', () {
      final decision = decide(const {});
      expect(decision.preserved, contains('status'));
    });

    test('a changed masked (none/disabled) column is preserved silently', () {
      // Round-tripped masked-null differs from the stored value, so it is
      // "changed" — but a masked column must never reject; it is overlaid.
      final decision = decide({'salary', 'ssn'});
      expect(decision.preserved, containsAll(['salary', 'ssn']));
      expect(decision.writable, unorderedEquals(['title', 'note']));
    });

    test('a changed full column is written without objection', () {
      final decision = decide({'title'});
      expect(decision.writable, contains('title'));
    });
  });

  group('applyReadMask (the reflected row projection)', () {
    // `maskedColumns` decides *which* columns are withheld; `applyReadMask` is
    // what the repository calls, and it does two further things the pure core
    // cannot be asked about: it writes `null` through the column mirror onto a
    // live entity, and it exempts columns whose grade is per-row.
    setUpAll(initializeReflection);
    tearDown(TomRowColumnAuthorization.reset);

    late List<TomColumnInformation> columns;

    setUp(() {
      columns = TomAnnotationAnalyzer.analysePersistentType(
        FixtureDocumentRecord,
      ).columnInfo;
    });

    FixtureDocumentRecord record() => FixtureDocumentRecord()
      ..id = 7
      ..title = 'quarterly report'
      ..attachment = 'fixture/attachment/2026/08/plain.pdf'
      ..secretAttachment = 'fixture/secret/2026/08/secret.pdf';

    test('a masked column is nulled in place on the same instance', () {
      final instance = record();
      final returned = TomColumnAuthorization.applyReadMask(
        instance,
        columns,
        resolver: _resolver({_secretKey: TomAuthState.none}),
      );
      // Returned for chaining, but the masking is a mutation: a caller holding
      // the original reference must not still see the withheld value.
      expect(identical(returned, instance), isTrue);
      expect(instance.secretAttachment, isNull);
    });

    test('unrestricted columns are left alone', () {
      final instance = record();
      TomColumnAuthorization.applyReadMask(
        instance,
        columns,
        resolver: _resolver({_secretKey: TomAuthState.none}),
      );
      expect(instance.id, 7);
      expect(instance.title, 'quarterly report');
      expect(instance.attachment, 'fixture/attachment/2026/08/plain.pdf');
    });

    test('a visible (read) grade withholds nothing', () {
      // `read` shows content; only the grades that fail `showsContent` mask.
      final instance = record();
      TomColumnAuthorization.applyReadMask(
        instance,
        columns,
        resolver: _resolver({_secretKey: TomAuthState.read}),
      );
      expect(instance.secretAttachment, isNotNull);
    });

    test('a column with a per-row resolver is not masked here', () {
      // The row projection has one synchronous answer for a whole result set,
      // so it has no authority over a grade that depends on which row is
      // addressed. Masking it would also be self-defeating: the value it would
      // blank out is the blob key the per-row gate needs in order to decide.
      TomRowColumnAuthorization.register(
        _secretKey,
        (principal, rowId) async => TomAuthState.none,
      );
      final instance = record();
      TomColumnAuthorization.applyReadMask(
        instance,
        columns,
        // The column-wide resolver denies outright — and is still not what
        // decides, because the key is registered.
        resolver: _resolver({_secretKey: TomAuthState.none}),
      );
      expect(instance.secretAttachment, isNotNull);
    });

    test('deregistering restores column-wide masking for the same key', () {
      // The exemption tracks the registry, not the column: the same entity and
      // the same resolver mask once the per-row gate is gone.
      TomRowColumnAuthorization.register(
        _secretKey,
        (principal, rowId) async => TomAuthState.full,
      );
      TomRowColumnAuthorization.reset();
      final instance = record();
      TomColumnAuthorization.applyReadMask(
        instance,
        columns,
        resolver: _resolver({_secretKey: TomAuthState.none}),
      );
      expect(instance.secretAttachment, isNull);
    });
  });

  group('TomRowColumnAuthorization (per-row grades)', () {
    tearDown(TomRowColumnAuthorization.reset);

    test('an unregistered key resolves to null so the caller keeps its own '
        'column-wide grade', () async {
      expect(
        await TomRowColumnAuthorization.resolve('k.attachment', '7'),
        isNull,
      );
    });

    test(
      'a null authKey resolves to null without consulting the registry',
      () async {
        TomRowColumnAuthorization.register(
          'k.attachment',
          (principal, rowId) async => throw StateError(
            'must not be consulted for an unrestricted column',
          ),
        );
        expect(await TomRowColumnAuthorization.resolve(null, '7'), isNull);
      },
    );

    test('a registered key resolves per row', () async {
      // The point of the registry: the *same* column grades differently on two
      // rows, because the caller holds a different role on each one.
      TomRowColumnAuthorization.register(
        'k.attachment',
        (principal, rowId) async =>
            rowId == '1' ? TomAuthState.full : TomAuthState.read,
      );
      expect(
        await TomRowColumnAuthorization.resolve('k.attachment', '1'),
        TomAuthState.full,
      );
      expect(
        await TomRowColumnAuthorization.resolve('k.attachment', '2'),
        TomAuthState.read,
      );
    });

    test('reset removes every registration', () async {
      TomRowColumnAuthorization.register(
        'k.attachment',
        (principal, rowId) async => TomAuthState.none,
      );
      TomRowColumnAuthorization.reset();
      expect(
        await TomRowColumnAuthorization.resolve('k.attachment', '1'),
        isNull,
      );
    });
  });
}
