/// Privacy without a database: the personal-data model and its refusals, the
/// subject keys of crypto-shredding, and the audit trail sealing personal
/// values — a shredded subject's values unreadable while the hash chain still
/// verifies.
///
/// `privacy_db_test.dart` runs erasure, subject-access export and retention
/// through real repositories.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

Matcher _refused(String key) =>
    throwsA(isA<TomPrivacyException>().having((e) => e.key, 'key', key));

TomSubjectKeys _keys() => TomSubjectKeys(
  store: TomMemorySubjectKeyStore(),
  keys: [TomAesKeyEncryptionKey('kek-1', List.filled(32, 5))],
);

void main() {
  setUpAll(initializeReflection);
  tearDown(() {
    TomPrivacy.reset();
    TomAuditTrail.uninstall();
  });

  group('the personal-data model', () {
    test('reads the subjects, the personal fields and the retention', () {
      final post = TomPersonalDataModel.of(FixturePost);
      expect(post.subjects.map((s) => s.name), ['authorId', 'editorId']);
      expect(post.subjects.map((s) => s.onErasure), [
        TomErasure.anonymize,
        TomErasure.unlink,
      ]);
      expect(post.personal.single.name, 'body');
      expect(post.personal.single.subject.name, 'authorId');
      expect(post.retention!.days, 30);
      expect(post.keys.single.declaredName, 'id');

      final member = TomPersonalDataModel.of(FixtureMember);
      expect(member.personal.single.subject.name, 'userId');
      expect(member.retention, isNull);
      expect(TomPersonalDataModel.of(FixtureTaskRecord).isEmpty, isTrue);
    });

    test("the framework's per-user entities declare their subjects", () {
      expect(
        TomPersonalDataModel.of(TomUserPreference).subjects.single.name,
        'principalId',
      );
      expect(
        TomPersonalDataModel.of(TomUserTwoFactorEnrolment).personal.single.name,
        'hint',
      );
      expect(
        TomPersonalDataModel.of(
          TomPrincipalResourceGrant,
        ).subjects.single.onErasure,
        TomErasure.delete,
      );
      expect(
        TomPersonalDataModel.of(
          TomPrincipalDelegation,
        ).subjects.map((s) => s.name),
        ['delegatorId', 'delegateId'],
      );
    });

    test('a personal field is sealed for the subject its row names', () {
      final post = FixturePost()
        ..authorId = 7
        ..editorId = 8
        ..body = 'hello';
      expect(TomPersonalDataModel.of(FixturePost).sealingSubjects(post), {
        'body': '7',
      });
      expect(
        TomPersonalDataModel.of(
          FixturePost,
        ).sealingSubjects(FixturePost()..body = 'orphan'),
        isEmpty,
        reason: 'no subject, no one to seal for',
      );
    });

    test('an empty subject id names nobody', () {
      expect(
        TomPersonalDataModel.of(
          TomUserPreference,
        ).sealingSubjects(TomUserPreference()),
        isEmpty,
      );
    });

    test('anonymizing clears the subject and its personal fields; unlinking '
        'only the subject', () {
      final model = TomPersonalDataModel.of(FixturePost);
      final post = FixturePost()
        ..authorId = 7
        ..editorId = 8
        ..body = 'hello'
        ..title = 'kept';
      expect(model.clear(post, model.subjects[1], anonymize: false), isTrue);
      expect(post.editorId, isNull);
      expect(post.body, 'hello');
      expect(model.clear(post, model.subjects[0], anonymize: true), isTrue);
      expect(post.authorId, isNull);
      expect(post.body, '[removed]');
      expect(post.title, 'kept');
      expect(model.clear(post, model.subjects[0], anonymize: true), isFalse);
    });

    test('a subject id binds as its column stores it', () {
      final field = TomPersonalDataModel.of(FixtureMember).subjects.single;
      expect(field.toColumnValue('42'), 42);
      expect(field.toColumnValue(42), 42);
    });

    test('a declaration the operations could not carry out is refused', () {
      expect(
        () => TomPersonalDataModel.of(FixtureAmbiguousPersonal),
        _refused('privacy.model.subject_ambiguous'),
      );
      expect(
        () => TomPersonalDataModel.of(FixtureDateSubject),
        _refused('privacy.model.subject_type'),
      );
      expect(
        () => TomPersonalDataModel.of(FixtureTextRetention),
        _refused('privacy.model.retention_field'),
      );
      expect(
        () => TomPrivacy.register(_Stub<FixtureAmbiguousPersonal>()),
        _refused('privacy.model.subject_ambiguous'),
      );
    });
  });

  group('subject keys', () {
    test('a sealed value opens while the key exists, and reads erased after '
        'it is shredded', () async {
      final keys = _keys();
      final sealed = await keys.seal('7', 'body', 'hello');
      expect(sealed, startsWith(TomSubjectKeys.prefix));
      expect(sealed, isNot(contains('hello')));
      expect(TomSubjectKeys.subjectOf(sealed), '7');
      expect(await keys.open(sealed, 'body'), 'hello');
      expect(await keys.has('7'), isTrue);

      expect(await keys.shred('7'), isTrue);
      expect(await keys.open(sealed, 'body'), TomSubjectKeys.erasedPlaceholder);
      expect(await keys.has('7'), isFalse);
      expect(await keys.shred('7'), isFalse);
    });

    test('a value sealed for one field does not open as another', () async {
      final keys = _keys();
      final sealed = await keys.seal('7', 'body', 'hello');
      await expectLater(
        keys.open(sealed, 'title'),
        _refused('privacy.seal.invalid'),
      );
    });

    test('each subject has a key of its own', () async {
      final keys = _keys();
      final a = await keys.seal('7', 'body', 'a');
      final b = await keys.seal('8', 'body', 'b');
      await keys.shred('7');
      expect(await keys.open(a, 'body'), TomSubjectKeys.erasedPlaceholder);
      expect(await keys.open(b, 'body'), 'b');
    });

    test('one subject id in two tenants is two subjects', () async {
      final keys = _keys();
      final acme = await TomTenantContext.run(
        'acme',
        () => keys.seal('7', 'body', 'acme words'),
      );
      final globex = await TomTenantContext.run(
        'globex',
        () => keys.seal('7', 'body', 'globex words'),
      );
      await TomTenantContext.run('acme', () => keys.shred('7'));
      expect(
        await TomTenantContext.run('acme', () => keys.open(acme, 'body')),
        TomSubjectKeys.erasedPlaceholder,
      );
      expect(
        await TomTenantContext.run('globex', () => keys.open(globex, 'body')),
        'globex words',
      );
    });

    test('a key shredded by another node stops opening here at once', () async {
      final store = TomMemorySubjectKeyStore();
      final kek = TomAesKeyEncryptionKey('kek-1', List.filled(32, 5));
      final here = TomSubjectKeys(store: store, keys: [kek]);
      final there = TomSubjectKeys(store: store, keys: [kek]);
      final sealed = await here.seal('7', 'body', 'words');
      expect(await here.open(sealed, 'body'), 'words');
      await there.shred('7');
      expect(await here.open(sealed, 'body'), TomSubjectKeys.erasedPlaceholder);
    });

    test('a key-encryption-key rotation re-wraps the subject keys', () async {
      final store = TomMemorySubjectKeyStore();
      final old = TomAesKeyEncryptionKey('kek-1', List.filled(32, 5));
      final next = TomAesKeyEncryptionKey('kek-2', List.filled(32, 6));
      final sealed = await TomSubjectKeys(
        store: store,
        keys: [old],
      ).seal('7', 'body', 'kept');
      final rotating = TomSubjectKeys(store: store, keys: [next, old]);
      expect(await rotating.rewrap(), 1);
      expect(await rotating.rewrap(), 0);
      expect((await store.all()).single.kekId, 'kek-2');
      // The old key-encryption key can go.
      expect(
        await TomSubjectKeys(store: store, keys: [next]).open(sealed, 'body'),
        'kept',
      );
    });

    test('values that are not sealed are answered as they are', () async {
      final keys = _keys();
      expect(await keys.open('plain', 'body'), 'plain');
      expect(await keys.open(null, 'body'), isNull);
      expect(await keys.seal('7', 'body', null), isNull);
    });

    test('without key-encryption keys nothing is sealed', () async {
      final keys = TomSubjectKeys(store: TomMemorySubjectKeyStore());
      await expectLater(
        keys.seal('7', 'body', 'x'),
        _refused('privacy.no_subject_keys'),
      );
    });
  });

  group('the audit trail', () {
    test('a personal value is sealed for its subject, and shredding the '
        'subject leaves the chain verifiable', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      final keys = _keys();
      TomPrivacy.installSubjectKeys(keys);
      await TomAuditTrail.recordMutation(
        entityType: FixturePost,
        action: TomAuditAction.update,
        target: 'FixturePost',
        targetKey: '1',
        before: {'body': 'old words', 'title': 'a'},
        after: {'body': 'new words', 'title': 'b'},
        beforeSubjects: {'body': '7'},
        afterSubjects: {'body': '7'},
      );
      final stored = sink.entries.single.record;
      expect(stored.after['body'], startsWith(TomSubjectKeys.prefix));
      expect(stored.after['title'], 'b', reason: 'not personal');
      expect(sink.verify().isValid, isTrue);

      final revealed = await TomPrivacy.reveal(stored);
      expect(revealed.before['body'], 'old words');
      expect(revealed.after['body'], 'new words');

      await keys.shred('7');
      final erased = await TomPrivacy.reveal(stored);
      expect(erased.after['body'], TomSubjectKeys.erasedPlaceholder);
      expect(erased.after['title'], 'b');
      expect(sink.verify().isValid, isTrue, reason: 'no entry was touched');
    });

    test('a value that cannot be sealed fails the record — the trail is '
        'fail-closed — and is never written in the clear', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      // Subject keys with no key-encryption keys to wrap them under.
      TomPrivacy.installSubjectKeys(
        TomSubjectKeys(store: TomMemorySubjectKeyStore()),
      );
      await expectLater(
        TomAuditTrail.recordMutation(
          entityType: FixturePost,
          action: TomAuditAction.create,
          target: 'FixturePost',
          after: {'body': 'secret words'},
          afterSubjects: {'body': '7'},
        ),
        _refused('privacy.no_subject_keys'),
      );
      expect(sink.entries, isEmpty);
    });

    test(
      'without subject keys personal values are recorded as they are',
      () async {
        final sink = TomMemoryAuditSink();
        TomAuditTrail.install(sink);
        await TomAuditTrail.recordMutation(
          entityType: FixturePost,
          action: TomAuditAction.create,
          target: 'FixturePost',
          after: {'body': 'words'},
          afterSubjects: {'body': '7'},
        );
        expect(sink.entries.single.record.after['body'], 'words');
        await expectLater(
          TomPrivacy.reveal(sink.entries.single.record),
          _refused('privacy.no_subject_keys'),
        );
      },
    );
  });

  group('configuration and registration', () {
    test('the configuration is checked', () async {
      expect(
        () => TomPrivacy.configure('nope'),
        _refused('privacy.config.invalid'),
      );
      expect(
        () => TomPrivacy.configure({}),
        _refused('privacy.config.invalid'),
      );
      expect(
        () => TomPrivacy.configure({'datasource': 'main', 'createSchema': 1}),
        _refused('privacy.config.invalid'),
      );
      // Subject keys are wrapped by the field-encryption keyring's keys.
      expect(
        () => TomPrivacy.configure({'datasource': 'main'}),
        _refused('privacy.config.invalid'),
      );
      expect(TomPrivacy.subjectKeys, isNull);
      await TomFieldEncryption.install(
        TomFieldKeyring(
          store: TomMemoryDataKeyStore(),
          keys: [TomAesKeyEncryptionKey('kek-1', List.filled(32, 5))],
        ),
      );
      addTearDown(TomFieldEncryption.reset);
      TomPrivacy.configure({'datasource': 'main'});
      expect(TomPrivacy.subjectKeys, isNotNull);
      expect(TomAuditTrail.personalValueSealer, isNotNull);
    });

    test(
      'an operation on an entity that is not registered is refused',
      () async {
        await expectLater(
          TomPrivacy.erase(7, entities: [FixturePost]),
          _refused('privacy.not_registered'),
        );
        await expectLater(
          TomPrivacy.subjectAccess(7),
          _refused('privacy.not_registered'),
        );
      },
    );

    test(
      'a SQL subject-key store naming an unregistered data source says so',
      () async {
        await expectLater(
          TomSqlSubjectKeyStore('no_such_source').prepare(),
          _refused('privacy.no_datasource'),
        );
      },
    );

    test(
      'the declared retention policies come from the registered entities',
      () {
        TomPrivacy.register(_Stub<FixturePost>());
        TomPrivacy.register(_Stub<FixtureVisit>());
        TomPrivacy.register(_Stub<FixtureMember>());
        expect(TomPrivacy.entities, [FixturePost, FixtureVisit, FixtureMember]);
        final policies = TomRetentionPolicy.declared();
        expect(policies.map((p) => p.entity), [FixturePost, FixtureVisit]);
        expect(policies.first.keep, const Duration(days: 30));
        expect(policies.first.action, TomErasure.anonymize);
        expect(policies.last.action, TomErasure.delete);
      },
    );
  });
}

/// A repository no operation reaches: registration only needs the type.
class _Stub<T extends Object> implements TomRepository<T, int> {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
