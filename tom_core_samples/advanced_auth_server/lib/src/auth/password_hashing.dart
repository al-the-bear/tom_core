/// The auth server's password helper — a thin adapter over the kernel crypto
/// [TomPasswordHasher] that speaks the `auth_db` [UserRecord] shape.
///
/// The kernel hasher returns a `(salt$hash, spec)` pair; `auth_db` stores those
/// two halves in [UserRecord.passwordHash] and [UserRecord.hashType]. This is the
/// one place plaintext is turned into stored credentials (the create-user path
/// in `endpoints/admin_endpoints.dart`) and checked against them
/// (`auth/authentication_service.dart`), so the column split lives here and
/// nowhere else.
///
/// The hash is salted (a fresh random salt per [hashPassword] call, embedded in
/// the stored value) and non-reversible (Argon2 key derivation): the same
/// plaintext hashes to a different value every time, and the plaintext cannot be
/// recovered from the stored hash — only re-derived and compared.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../persistence/auth_persistence_model.dart';

/// A hashed password ready for the `auth_db` columns: [hash] is the kernel's
/// `salt$hash` value for [UserRecord.passwordHash]; [hashType] is the algorithm
/// spec for [UserRecord.hashType] (the verifier needs it to re-derive).
typedef PasswordHash = ({String hash, String hashType});

/// Hashes [plaintext] with the kernel's default Argon2 configuration, returning
/// the `salt$hash` value and its algorithm spec. A fresh salt is generated per
/// call, so the same [plaintext] yields a different [PasswordHash.hash] each time.
PasswordHash hashPassword(String plaintext) {
  final (hash, spec) = TomPasswordHasher.hashPassword(plaintext);
  return (hash: hash, hashType: spec);
}

/// Returns `true` when [plaintext] re-derives to the stored [hash] under the
/// [hashType] spec — i.e. it is the original password. The comparison is
/// constant in the salt/spec, never reversing the hash.
bool verifyPassword(
  String plaintext, {
  required String hash,
  required String hashType,
}) => TomPasswordHasher.verifyPassword(plaintext, hash, hashType);

/// Hashes [plaintext] and writes both halves onto [record]'s credential columns
/// (the create-user / set-password path). Returns the same [record] for chaining.
UserRecord applyPassword(UserRecord record, String plaintext) {
  final hashed = hashPassword(plaintext);
  return record
    ..passwordHash = hashed.hash
    ..hashType = hashed.hashType;
}

/// Verifies [plaintext] against [record]'s stored credentials. A user with no
/// stored hash (e.g. a freshly seeded row) can never authenticate, so this
/// returns `false` rather than throwing when either column is absent.
bool verifyUserPassword(UserRecord record, String plaintext) {
  final hash = record.passwordHash;
  final hashType = record.hashType;
  if (hash == null || hashType == null) return false;
  return verifyPassword(plaintext, hash: hash, hashType: hashType);
}
