/// Password Hashing Example
///
/// This example demonstrates secure password hashing using the Argon2
/// algorithm. Argon2 is the winner of the Password Hashing Competition
/// and is recommended for secure password storage.
///
/// Topics covered:
/// - Hashing passwords with Argon2
/// - Verifying passwords against stored hashes
/// - Understanding hash specifications
/// - Salt generation
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 02: Password Hashing Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Basic password hashing
  // -------------------------------------------------------------------------
  print('1. Basic password hashing:');

  final password = 'MySecurePassword123!';
  final (hash, spec) = TomPasswordHasher.hashPassword(password);

  // The hash contains salt$hash
  final hashParts = hash.split('\$');
  final salt = hashParts[0];
  final hashValue = hashParts[1];

  print('   Password: $password');
  print('   Salt (first 16 chars): ${salt.substring(0, 16)}...');
  print('   Hash (first 32 chars): ${hashValue.substring(0, 32)}...');
  print('   Spec: $spec\n');

  // -------------------------------------------------------------------------
  // Example 2: Password verification
  // -------------------------------------------------------------------------
  print('2. Password verification:');

  final correctPassword = 'MySecurePassword123!';
  final wrongPassword = 'WrongPassword456';

  final correctResult = TomPasswordHasher.verifyPassword(correctPassword, hash, spec);
  final wrongResult = TomPasswordHasher.verifyPassword(wrongPassword, hash, spec);

  print('   Correct password verification: $correctResult');
  print('   Wrong password verification: $wrongResult\n');

  // -------------------------------------------------------------------------
  // Example 3: Understanding hash specification
  // -------------------------------------------------------------------------
  print('3. Understanding hash specification:');

  final defaultSpec = TomPasswordHasher.globalSettingDefaultHashSpec;
  final specParts = defaultSpec.split(';');
  final algorithm = specParts[0];
  final params = specParts[1].split(',');

  print('   Default spec: $defaultSpec');
  print('   Algorithm: $algorithm');
  print('   Variant: ${params[0]} (2i = Argon2i)');
  print('   Version: ${params[1]} (13 = v1.3)');
  print('   Iterations: ${params[2]}');
  print('   Memory (KB): ${params[3]}');
  print('   Lanes: ${params[4]}');
  print('   Key length: ${params[5]}\n');

  // -------------------------------------------------------------------------
  // Example 4: Salt generation
  // -------------------------------------------------------------------------
  print('4. Salt generation:');

  final salt1 = TomPasswordHasher.generateSalt(16);
  final salt2 = TomPasswordHasher.generateSalt(16);
  final salt3 = TomPasswordHasher.generateSalt(32);

  print('   Salt 1 (16 bytes): $salt1');
  print('   Salt 2 (16 bytes): $salt2');
  print('   Salt 3 (32 bytes): $salt3');
  print('   Salt 1 length: ${salt1.length} chars (hex)');
  print('   Salt 3 length: ${salt3.length} chars (hex)');
  print('   Salts are unique: ${salt1 != salt2}\n');

  // -------------------------------------------------------------------------
  // Example 5: Multiple password hashing (different salts)
  // -------------------------------------------------------------------------
  print('5. Same password, different hashes:');

  final samePassword = 'TestPassword';
  final (hash1, spec1) = TomPasswordHasher.hashPassword(samePassword);
  final (hash2, spec2) = TomPasswordHasher.hashPassword(samePassword);

  final hashesAreDifferent = hash1 != hash2;
  final specsAreSame = spec1 == spec2;

  print('   Password: $samePassword');
  print('   Hash 1 (first 40 chars): ${hash1.substring(0, 40)}...');
  print('   Hash 2 (first 40 chars): ${hash2.substring(0, 40)}...');
  print('   Hashes are different: $hashesAreDifferent');
  print('   Specs are same: $specsAreSame');

  // Both should still verify correctly
  final verify1 = TomPasswordHasher.verifyPassword(samePassword, hash1, spec1);
  final verify2 = TomPasswordHasher.verifyPassword(samePassword, hash2, spec2);

  print('   Both verify correctly: ${verify1 && verify2}\n');

  // -------------------------------------------------------------------------
  // Example 6: Simulating user registration and login
  // -------------------------------------------------------------------------
  print('6. User registration and login simulation:');

  // Registration: hash password and store
  final userPassword = 'UserSecret456!';
  final (storedHash, storedSpec) = TomPasswordHasher.hashPassword(userPassword);

  print('   [Registration] Password hashed and stored');

  // Login attempt 1: correct password
  final loginAttempt1 = 'UserSecret456!';
  final login1Success = TomPasswordHasher.verifyPassword(loginAttempt1, storedHash, storedSpec);
  print('   [Login] Attempt with correct password: ${login1Success ? "SUCCESS" : "FAILED"}');

  // Login attempt 2: wrong password
  final loginAttempt2 = 'WrongSecret';
  final login2Success = TomPasswordHasher.verifyPassword(loginAttempt2, storedHash, storedSpec);
  print('   [Login] Attempt with wrong password: ${login2Success ? "SUCCESS" : "FAILED"}\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Basic hashing
  assert(hash.contains('\$')); // Contains salt$hash separator
  assert(salt.isNotEmpty);
  assert(hashValue.isNotEmpty);
  assert(spec == TomPasswordHasher.globalSettingDefaultHashSpec);

  // Example 2: Password verification
  assert(correctResult == true);
  assert(wrongResult == false);

  // Example 3: Hash specification
  assert(algorithm == 'Argon2');
  assert(params[0] == '2i'); // Argon2i variant
  assert(params[1] == '13'); // Version 1.3

  // Example 4: Salt generation
  assert(salt1.length == 32); // 16 bytes = 32 hex chars
  assert(salt2.length == 32);
  assert(salt3.length == 64); // 32 bytes = 64 hex chars
  assert(salt1 != salt2); // Unique salts

  // Example 5: Different hashes for same password
  assert(hashesAreDifferent == true);
  assert(specsAreSame == true);
  assert(verify1 == true);
  assert(verify2 == true);

  // Example 6: Login simulation
  assert(login1Success == true);
  assert(login2Success == false);
}
