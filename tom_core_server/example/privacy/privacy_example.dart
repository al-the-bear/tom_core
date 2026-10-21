/// The privacy module without a database: the personal-data declarations,
/// subject keys, and the audit trail sealing a personal value that an erasure
/// then makes unreadable while the hash chain still verifies.
///
/// Run with `dart run example/privacy/privacy_example.dart`.
///
/// An erasure, a subject-access export and a retention run go through the
/// registered repositories, so they need a database and run in
/// `test/privacy_db_test.dart`. Everything that decides what the audit trail
/// holds for a person is visible without one: the model the framework's own
/// entities declare, which of a row's values are sealed for whom, the subject
/// keys that seal and open them, the trail writing them sealed into a memory
/// sink, and the shred that is the last step of every erasure. Every step
/// checks its own result, and the run fails when one does not hold.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';

// ignore_for_file: avoid_print

/// The key [refused] carries, or `null` when [action] did not refuse.
Future<String?> _refusal(Future<Object?> Function() action) async {
  try {
    await action();
  } on TomPrivacyException catch (refused) {
    return refused.key;
  }
  return null;
}

Future<void> main() async {
  initializeReflection();

  // 1. The framework's per-user entities declare who their rows are about. A
  //    preference belongs to its principal and holds their data; a delegation
  //    names two principals, each its own subject.
  final preference = TomPersonalDataModel.of(TomUserPreference);
  final delegation = TomPersonalDataModel.of(TomPrincipalDelegation);
  print(
    '1. TomUserPreference         : subject '
    '${preference.subjects.single.name}, personal '
    '${preference.personal.map((p) => p.name).join(', ')}',
  );
  print(
    '   TomPrincipalDelegation    : subjects '
    '${delegation.subjects.map((s) => s.name).join(', ')}',
  );
  check(
    preference.subjects.single.name == 'principalId' &&
        preference.subjects.single.onErasure == TomErasure.delete &&
        preference.personal.single.name == 'valueJson',
    'a preference is deleted with its principal, and its value is personal',
  );
  check(
    delegation.subjects.map((s) => s.name).join(',') ==
            'delegatorId,delegateId' &&
        delegation.personal.isEmpty,
    'a delegation names two subjects and holds no personal field',
  );

  // 2. For an audit record of a row, the model says which values are sealed
  //    for whom: the personal field, for the subject the row names.
  final row = TomUserPreference(
    principalId: 'tenant:acme/7',
    preferenceKey: 'ui.theme',
    valueType: 'String',
    valueJson: '"dark"',
  );
  final subjects = preference.sealingSubjects(row);
  print('2. sealed for               : $subjects');
  check(
    subjects.length == 1 && subjects['valueJson'] == 'tenant:acme/7',
    "the preference's value is sealed for the principal the row names",
  );

  // 3. A subject key seals a value: the subject's id travels in the clear, the
  //    value does not. The key is created on first use and kept wrapped.
  final store = TomMemorySubjectKeyStore();
  final keys = TomSubjectKeys(
    store: store,
    keys: [TomAesKeyEncryptionKey('kek-1', List.filled(32, 7))],
  );
  final sealed = await keys.seal('7', 'email', 'ada@example.com');
  final stored = await store.find('7');
  print('3. sealed                   : ${'$sealed'.substring(0, 24)}…');
  print('   stored key               : wrapped under ${stored?.kekId}');
  check(
    TomSubjectKeys.isSealed(sealed) &&
        TomSubjectKeys.subjectOf(sealed) == '7' &&
        !'$sealed'.contains('ada@example.com'),
    'the sealed value names its subject and hides its value',
  );
  check(
    await keys.open(sealed, 'email') == 'ada@example.com',
    'the value opens under its subject key',
  );
  check(
    stored != null && stored.kekId == 'kek-1' && stored.wrapped.isNotEmpty,
    'the store holds the key wrapped under the key-encryption key',
  );

  // 4. The field is authenticated with the value: moved to another field it
  //    does not open.
  final moved = await _refusal(() => keys.open(sealed, 'name'));
  print('4. opened as another field  : $moved');
  check(
    moved == 'privacy.seal.invalid',
    'a value sealed for one field does not open as another',
  );

  // 5. The audit trail seals a personal value once subject keys are
  //    installed, and the chain hashes the sealed text.
  final sink = TomMemoryAuditSink();
  TomAuditTrail.install(sink);
  TomPrivacy.installSubjectKeys(keys);
  await TomAuditTrail.recordMutation(
    entityType: TomUserPreference,
    action: TomAuditAction.create,
    target: 'TomUserPreference',
    targetKey: '1',
    after: {'preferenceKey': 'ui.theme', 'valueJson': '"dark"'},
    afterSubjects: preference.sealingSubjects(row),
  );
  await TomAuditTrail.recordMutation(
    entityType: TomUserPreference,
    action: TomAuditAction.create,
    target: 'TomUserPreference',
    targetKey: '2',
    after: {'preferenceKey': 'ui.theme', 'valueJson': '"light"'},
    afterSubjects: {'valueJson': 'tenant:acme/8'},
  );
  final first = sink.entries.first.record;
  print(
    '5. recorded                 : ${first.after['preferenceKey']}, '
    '${'${first.after['valueJson']}'.substring(0, 24)}…',
  );
  check(
    TomSubjectKeys.isSealed(first.after['valueJson']) &&
        first.after['preferenceKey'] == 'ui.theme',
    'the personal value is sealed, the rest of the record is not',
  );
  check(sink.verify().isValid, 'the chain verifies');

  // 6. An auditor reads the record revealed: the value opened while the key
  //    exists.
  final revealed = await TomPrivacy.reveal(first);
  print('6. revealed                 : ${revealed.after['valueJson']}');
  check(
    revealed.after['valueJson'] == '"dark"',
    'the sealed value opens for an auditor while the key exists',
  );

  // 7. Shredding the subject's key — the last step of every erasure — makes
  //    their values unreadable. No entry is touched: the chain still verifies,
  //    and another subject's values still read.
  final shredded = await keys.shred('tenant:acme/7');
  final erased = await TomPrivacy.reveal(first);
  final other = await TomPrivacy.reveal(sink.entries.last.record);
  print(
    '7. after the shred          : ${erased.after['valueJson']}, '
    'other subject ${other.after['valueJson']}, chain ${sink.verify()}',
  );
  check(shredded, 'the subject had a key, and it is gone');
  check(
    erased.after['valueJson'] == TomSubjectKeys.erasedPlaceholder,
    "the erased subject's value reads [erased]",
  );
  check(
    other.after['valueJson'] == '"light"',
    "another subject's value is untouched",
  );
  check(
    sink.verify().isValid,
    'the chain still verifies: the erasure deleted a key, not an entry',
  );

  // 8. The `privacy` configuration is checked before anything is installed.
  final invalid = await _refusal(
    () async => TomPrivacy.configure({'datasource': 'main', 'table': 3}),
  );
  print('8. table: 3                 : $invalid');
  check(
    invalid == 'privacy.config.invalid',
    'a configuration of the wrong shape is refused',
  );

  TomPrivacy.reset();
  TomAuditTrail.uninstall();
}
