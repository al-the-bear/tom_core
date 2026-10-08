/// Runner for all crypto examples.
///
/// Execute this file to run all crypto module examples:
/// ```
/// dart run --enable-asserts example/samples/crypto/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_rsa_encryption_example.dart' as rsa_encryption;
import '02_password_hashing_example.dart' as password_hashing;
import '03_key_generation_example.dart' as key_generation;
import '04_digital_signatures_example.dart' as digital_signatures;
import '05_jwt_token_example.dart' as jwt_token;
import '06_advanced_jwt_example.dart' as advanced_jwt;

/// Standalone entry point for running crypto examples.
void main() {
  bootstrapSamples();
  run();
}

/// Run all crypto examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  sampleGroupHeader('Crypto');

  rsa_encryption.run();
  print('✓ RSA encryption examples passed\n');

  password_hashing.run();
  print('✓ Password hashing examples passed\n');

  key_generation.run();
  print('✓ Key generation examples passed\n');

  digital_signatures.run();
  print('✓ Digital signatures examples passed\n');

  jwt_token.run();
  print('✓ JWT token examples passed\n');

  advanced_jwt.run();
  print('✓ Advanced JWT examples passed\n');

  sampleGroupFooter('Crypto');
}
