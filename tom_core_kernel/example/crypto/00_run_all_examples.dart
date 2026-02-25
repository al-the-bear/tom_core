/// Crypto Examples Runner
///
/// This file runs all crypto examples in sequence.
/// Demonstrates RSA encryption, password hashing, key generation, and JWT tokens.
///
/// To run this file:
/// ```bash
/// dart run example/tombase/crypto/00_run_all_examples.dart
/// ```
library;

// Import all example files
import '01_rsa_encryption_example.dart' as rsa_encryption;
import '02_password_hashing_example.dart' as password_hashing;
import '03_key_generation_example.dart' as key_generation;
import '04_digital_signatures_example.dart' as digital_signatures;
import '05_jwt_token_example.dart' as jwt_token;

void main() {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                  Tom Crypto System Examples                      ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  rsa_encryption.run();
  password_hashing.run();
  key_generation.run();
  digital_signatures.run();
  jwt_token.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Examples Complete!                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
