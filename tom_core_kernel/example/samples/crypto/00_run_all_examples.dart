/// Runner for all crypto examples.
///
/// Execute this file to run all crypto module examples:
/// ```
/// dart run example/samples/crypto/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_rsa_encryption_example.dart' as rsa_encryption;
import '02_password_hashing_example.dart' as password_hashing;
import '03_key_generation_example.dart' as key_generation;
import '04_digital_signatures_example.dart' as digital_signatures;
import '05_jwt_token_example.dart' as jwt_token;
import '06_advanced_jwt_example.dart' as advanced_jwt;

/// Standalone entry point for running crypto examples.
void main() {
  initializeReflection();
  run();
}

/// Run all crypto examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('Running Crypto Examples...\n');
  print('=' * 60);

  print('\n01: RSA Encryption Example');
  print('-' * 40);
  rsa_encryption.run();
  print('✓ RSA encryption examples passed\n');

  print('02: Password Hashing Example');
  print('-' * 40);
  password_hashing.run();
  print('✓ Password hashing examples passed\n');

  print('03: Key Generation Example');
  print('-' * 40);
  key_generation.run();
  print('✓ Key generation examples passed\n');

  print('04: Digital Signatures Example');
  print('-' * 40);
  digital_signatures.run();
  print('✓ Digital signatures examples passed\n');

  print('05: JWT Token Example');
  print('-' * 40);
  jwt_token.run();
  print('✓ JWT token examples passed\n');

  print('06: Advanced JWT Example');
  print('-' * 40);
  advanced_jwt.run();
  print('✓ Advanced JWT examples passed\n');

  print('=' * 60);
  print('All crypto examples completed successfully!');
}
