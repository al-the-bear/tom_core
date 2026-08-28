/// Unit tests for the auth server's password helper. The helper is a
/// thin adapter over the kernel `TomPasswordHasher`, so these tests assert the
/// security properties that matter at the auth_db boundary: verify accepts the
/// right password and rejects the wrong one, the stored hash is salted (same
/// plaintext → different stored value) and non-reversible (the plaintext never
/// appears in the stored value), and a credential-less record can never log in.
///
/// No database and no reflection are needed — the helper is pure over plain
/// strings and the plain `UserRecord`.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:test/test.dart';

void main() {
  group('hashPassword / verifyPassword (string form)', () {
    test('verify accepts the right password and rejects the wrong one', () {
      final stored = hashPassword('correct horse battery staple');

      expect(
        verifyPassword('correct horse battery staple',
            hash: stored.hash, hashType: stored.hashType),
        isTrue,
      );
      expect(
        verifyPassword('Tr0ubador&3',
            hash: stored.hash, hashType: stored.hashType),
        isFalse,
      );
    });

    test('the same plaintext hashes to a different value each time (salted)', () {
      final a = hashPassword('repeat-me');
      final b = hashPassword('repeat-me');

      expect(a.hash, isNot(b.hash), reason: 'a fresh salt is used per call');
      // The algorithm spec is stable; only the salted hash differs.
      expect(a.hashType, b.hashType);
      // Both still verify — the salt travels inside the stored value.
      expect(verifyPassword('repeat-me', hash: a.hash, hashType: a.hashType),
          isTrue);
      expect(verifyPassword('repeat-me', hash: b.hash, hashType: b.hashType),
          isTrue);
    });

    test('the stored hash is non-reversible — the plaintext never appears', () {
      const plaintext = 'super-secret-passphrase';
      final stored = hashPassword(plaintext);

      expect(stored.hash, contains(r'$'),
          reason: 'stored value is salt\$hash');
      expect(stored.hash, isNot(contains(plaintext)));
    });

    test('a hash from one password never verifies another', () {
      final stored = hashPassword('alice-password');
      expect(
        verifyPassword('bob-password',
            hash: stored.hash, hashType: stored.hashType),
        isFalse,
      );
    });
  });

  group('applyPassword / verifyUserPassword (record form)', () {
    test('applyPassword populates both credential columns', () {
      final record = UserRecord()..username = 'ada';
      expect(record.passwordHash, isNull);
      expect(record.hashType, isNull);

      applyPassword(record, 's3cret');

      expect(record.passwordHash, isNotNull);
      expect(record.hashType, isNotNull);
      expect(record.passwordHash, isNot(contains('s3cret')));
    });

    test('verifyUserPassword round-trips a record credential', () {
      final record = applyPassword(UserRecord()..username = 'ada', 's3cret');

      expect(verifyUserPassword(record, 's3cret'), isTrue);
      expect(verifyUserPassword(record, 'wrong'), isFalse);
    });

    test('a record with no stored hash can never authenticate', () {
      // A freshly seeded row (the migrations leave password_hash NULL) must
      // reject every password rather than throw.
      final seeded = UserRecord()
        ..username = 'admin'
        ..passwordHash = null
        ..hashType = null;
      expect(verifyUserPassword(seeded, 'anything'), isFalse);
      expect(verifyUserPassword(seeded, ''), isFalse);
    });
  });
}
