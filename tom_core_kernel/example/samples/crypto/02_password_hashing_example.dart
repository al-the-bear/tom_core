/// Password Hashing Example
///
/// This example demonstrates secure password hashing using the Argon2
/// algorithm. Argon2 is the winner of the Password Hashing Competition
/// and is recommended for secure password storage.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: Basic password hashing
// =============================================================================

class BasicHashingExample {
  static String? password;
  static String? hash;
  static String? spec;
  static String? salt;
  static String? hashValue;
  static bool hashContainsSeparator = false;

  static void example1BasicHashing() {
    password = 'MySecurePassword123!';
    final (resultHash, resultSpec) = TomPasswordHasher.hashPassword(password!);
    hash = resultHash;
    spec = resultSpec;

    // The hash contains salt$hash
    final hashParts = hash!.split('\$');
    salt = hashParts[0];
    hashValue = hashParts[1];
    hashContainsSeparator = hash!.contains('\$');

    assert(hashContainsSeparator, 'Hash should contain salt\$hash separator');
    assert(salt!.isNotEmpty, 'Salt should not be empty');
    assert(hashValue!.isNotEmpty, 'Hash value should not be empty');
    assert(
      spec == TomPasswordHasher.globalSettingDefaultHashSpec,
      'Spec should match default',
    );
  }
}

// =============================================================================
// EXAMPLE 2: Password verification
// =============================================================================

class PasswordVerificationExample {
  static bool? correctResult;
  static bool? wrongResult;
  static String? storedHash;
  static String? storedSpec;

  static void example2PasswordVerification() {
    const password = 'MySecurePassword123!';
    final (hash, spec) = TomPasswordHasher.hashPassword(password);
    storedHash = hash;
    storedSpec = spec;

    const correctPassword = 'MySecurePassword123!';
    const wrongPassword = 'WrongPassword456';

    correctResult = TomPasswordHasher.verifyPassword(
      correctPassword,
      storedHash!,
      storedSpec!,
    );
    wrongResult = TomPasswordHasher.verifyPassword(
      wrongPassword,
      storedHash!,
      storedSpec!,
    );

    assert(correctResult == true, 'Correct password should verify');
    assert(wrongResult == false, 'Wrong password should not verify');
  }
}

// =============================================================================
// EXAMPLE 3: Understanding hash specification
// =============================================================================

class HashSpecificationExample {
  static String? defaultSpec;
  static String? algorithm;
  static String? variant;
  static String? version;
  static String? iterations;
  static String? memory;
  static String? lanes;
  static String? keyLength;

  static void example3HashSpecification() {
    defaultSpec = TomPasswordHasher.globalSettingDefaultHashSpec;
    final specParts = defaultSpec!.split(';');
    algorithm = specParts[0];
    final params = specParts[1].split(',');

    variant = params[0];
    version = params[1];
    iterations = params[2];
    memory = params[3];
    lanes = params[4];
    keyLength = params[5];

    assert(algorithm == 'Argon2', 'Algorithm should be Argon2');
    assert(variant == '2i', 'Variant should be 2i (Argon2i)');
    assert(version == '13', 'Version should be 13 (v1.3)');
    assert(int.parse(iterations!) > 0, 'Iterations should be positive');
    assert(int.parse(memory!) > 0, 'Memory should be positive');
    assert(int.parse(lanes!) > 0, 'Lanes should be positive');
  }
}

// =============================================================================
// EXAMPLE 4: Salt generation
// =============================================================================

class SaltGenerationExample {
  static String? salt16a;
  static String? salt16b;
  static String? salt32;
  static bool saltsAreUnique = false;
  static bool salt16HasCorrectLength = false;
  static bool salt32HasCorrectLength = false;

  static void example4SaltGeneration() {
    salt16a = TomPasswordHasher.generateSalt(16);
    salt16b = TomPasswordHasher.generateSalt(16);
    salt32 = TomPasswordHasher.generateSalt(32);

    saltsAreUnique = salt16a != salt16b;
    salt16HasCorrectLength = salt16a!.length == 32; // 16 bytes = 32 hex chars
    salt32HasCorrectLength = salt32!.length == 64; // 32 bytes = 64 hex chars

    assert(saltsAreUnique, 'Generated salts should be unique');
    assert(salt16HasCorrectLength, '16-byte salt should be 32 hex chars');
    assert(salt32HasCorrectLength, '32-byte salt should be 64 hex chars');
  }
}

// =============================================================================
// EXAMPLE 5: Same password produces different hashes
// =============================================================================

class DifferentHashesExample {
  static String? hash1;
  static String? hash2;
  static String? spec1;
  static String? spec2;
  static bool hashesAreDifferent = false;
  static bool specsAreSame = false;
  static bool bothVerifyCorrectly = false;

  static void example5DifferentHashes() {
    const samePassword = 'TestPassword';
    final (resultHash1, resultSpec1) = TomPasswordHasher.hashPassword(
      samePassword,
    );
    final (resultHash2, resultSpec2) = TomPasswordHasher.hashPassword(
      samePassword,
    );

    hash1 = resultHash1;
    hash2 = resultHash2;
    spec1 = resultSpec1;
    spec2 = resultSpec2;

    hashesAreDifferent = hash1 != hash2;
    specsAreSame = spec1 == spec2;

    // Both should still verify correctly
    final verify1 = TomPasswordHasher.verifyPassword(
      samePassword,
      hash1!,
      spec1!,
    );
    final verify2 = TomPasswordHasher.verifyPassword(
      samePassword,
      hash2!,
      spec2!,
    );
    bothVerifyCorrectly = verify1 && verify2;

    assert(hashesAreDifferent, 'Same password should produce different hashes');
    assert(specsAreSame, 'Specs should be the same');
    assert(bothVerifyCorrectly, 'Both hashes should verify correctly');
  }
}

// =============================================================================
// EXAMPLE 6: User registration and login simulation
// =============================================================================

class RegistrationLoginExample {
  static bool registrationComplete = false;
  static bool loginWithCorrectPassword = false;
  static bool loginWithWrongPassword = false;
  static String? storedHash;
  static String? storedSpec;

  static void example6RegistrationLogin() {
    // Registration: hash password and store
    const userPassword = 'UserSecret456!';
    final (hash, spec) = TomPasswordHasher.hashPassword(userPassword);
    storedHash = hash;
    storedSpec = spec;
    registrationComplete = true;

    // Login attempt 1: correct password
    const loginAttempt1 = 'UserSecret456!';
    loginWithCorrectPassword = TomPasswordHasher.verifyPassword(
      loginAttempt1,
      storedHash!,
      storedSpec!,
    );

    // Login attempt 2: wrong password
    const loginAttempt2 = 'WrongSecret';
    loginWithWrongPassword = TomPasswordHasher.verifyPassword(
      loginAttempt2,
      storedHash!,
      storedSpec!,
    );

    assert(registrationComplete, 'Registration should complete');
    assert(loginWithCorrectPassword, 'Correct password should succeed');
    assert(!loginWithWrongPassword, 'Wrong password should fail');
  }
}

// =============================================================================
// EXAMPLE 7: Case sensitivity in passwords
// =============================================================================

class CaseSensitivityExample {
  static bool lowercaseVerifies = false;
  static bool uppercaseVerifies = false;
  static bool originalVerifies = false;

  static void example7CaseSensitivity() {
    const originalPassword = 'MyPassword';
    final (hash, spec) = TomPasswordHasher.hashPassword(originalPassword);

    originalVerifies = TomPasswordHasher.verifyPassword(
      originalPassword,
      hash,
      spec,
    );
    lowercaseVerifies = TomPasswordHasher.verifyPassword(
      'mypassword',
      hash,
      spec,
    );
    uppercaseVerifies = TomPasswordHasher.verifyPassword(
      'MYPASSWORD',
      hash,
      spec,
    );

    assert(originalVerifies, 'Original password should verify');
    assert(!lowercaseVerifies, 'Lowercase should not verify');
    assert(!uppercaseVerifies, 'Uppercase should not verify');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  BasicHashingExample.example1BasicHashing();
  PasswordVerificationExample.example2PasswordVerification();
  HashSpecificationExample.example3HashSpecification();
  SaltGenerationExample.example4SaltGeneration();
  DifferentHashesExample.example5DifferentHashes();
  RegistrationLoginExample.example6RegistrationLogin();
  CaseSensitivityExample.example7CaseSensitivity();
}

void main() {
  requireAsserts();
  run();
}
