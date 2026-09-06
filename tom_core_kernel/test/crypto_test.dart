import 'package:test/test.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // ============================================================================
  // TomPasswordHasher Tests
  // ============================================================================

  group('TomPasswordHasher', () {
    group('hashPassword', () {
      test('should return a tuple with hash and specification', () {
        final (hash, spec) = TomPasswordHasher.hashPassword('testPassword123');

        expect(hash, isNotNull);
        expect(hash, isNotEmpty);
        expect(spec, isNotNull);
        expect(spec, isNotEmpty);
      });

      test('should return hash in salt\$hash format', () {
        final (hash, _) = TomPasswordHasher.hashPassword('myPassword');

        expect(hash.contains('\$'), isTrue);
        final parts = hash.split('\$');
        expect(parts.length, equals(2));
        expect(parts[0], isNotEmpty); // salt
        expect(parts[1], isNotEmpty); // hash
      });

      test('should return default specification string', () {
        final (_, spec) = TomPasswordHasher.hashPassword('password');

        expect(spec, equals(TomPasswordHasher.globalSettingDefaultHashSpec));
        expect(spec, startsWith('Argon2;'));
      });

      test('should generate different salts for same password', () {
        final (hash1, _) = TomPasswordHasher.hashPassword('samePassword');
        final (hash2, _) = TomPasswordHasher.hashPassword('samePassword');

        final salt1 = hash1.split('\$')[0];
        final salt2 = hash2.split('\$')[0];

        expect(salt1, isNot(equals(salt2)));
      });

      test(
        'should generate different hashes for same password due to different salts',
        () {
          final (hash1, _) = TomPasswordHasher.hashPassword('samePassword');
          final (hash2, _) = TomPasswordHasher.hashPassword('samePassword');

          expect(hash1, isNot(equals(hash2)));
        },
      );

      test('should generate hex-encoded salt and hash', () {
        final (hash, _) = TomPasswordHasher.hashPassword('hexTest');

        final parts = hash.split('\$');
        // Verify both parts are valid hex strings (only contain 0-9, a-f)
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(parts[0]), isTrue);
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(parts[1]), isTrue);
      });
    });

    group('verifyPassword', () {
      test('should return true for correct password', () {
        final (hash, spec) = TomPasswordHasher.hashPassword('correctPassword');

        final isValid = TomPasswordHasher.verifyPassword(
          'correctPassword',
          hash,
          spec,
        );

        expect(isValid, isTrue);
      });

      test('should return false for incorrect password', () {
        final (hash, spec) = TomPasswordHasher.hashPassword('originalPassword');

        final isValid = TomPasswordHasher.verifyPassword(
          'wrongPassword',
          hash,
          spec,
        );

        expect(isValid, isFalse);
      });

      test('should return false for similar but different password', () {
        final (hash, spec) = TomPasswordHasher.hashPassword('Password123');

        // Test case sensitivity
        expect(
          TomPasswordHasher.verifyPassword('password123', hash, spec),
          isFalse,
        );
        // Test with extra whitespace
        expect(
          TomPasswordHasher.verifyPassword(' Password123', hash, spec),
          isFalse,
        );
        expect(
          TomPasswordHasher.verifyPassword('Password123 ', hash, spec),
          isFalse,
        );
      });

      test('should verify empty password correctly', () {
        final (hash, spec) = TomPasswordHasher.hashPassword('');

        expect(TomPasswordHasher.verifyPassword('', hash, spec), isTrue);
        expect(TomPasswordHasher.verifyPassword(' ', hash, spec), isFalse);
      });

      test('should verify password with special characters', () {
        final password = 'P@ssw0rd!#\$%^&*()_+-=[]{}|;:,.<>?';
        final (hash, spec) = TomPasswordHasher.hashPassword(password);

        expect(TomPasswordHasher.verifyPassword(password, hash, spec), isTrue);
      });

      test('should verify password with unicode characters', () {
        final password = '密码テスト🔐';
        final (hash, spec) = TomPasswordHasher.hashPassword(password);

        expect(TomPasswordHasher.verifyPassword(password, hash, spec), isTrue);
      });

      test('should verify very long password', () {
        final password = 'a' * 1000;
        final (hash, spec) = TomPasswordHasher.hashPassword(password);

        expect(TomPasswordHasher.verifyPassword(password, hash, spec), isTrue);
      });
    });

    group('generateSalt', () {
      test('should generate salt of specified length', () {
        final salt8 = TomPasswordHasher.generateSalt(8);
        final salt16 = TomPasswordHasher.generateSalt(16);
        final salt32 = TomPasswordHasher.generateSalt(32);

        // Each byte becomes 2 hex characters
        expect(salt8.length, equals(16));
        expect(salt16.length, equals(32));
        expect(salt32.length, equals(64));
      });

      test('should generate different salts on each call', () {
        final salts = List.generate(
          10,
          (_) => TomPasswordHasher.generateSalt(16),
        );
        final uniqueSalts = salts.toSet();

        expect(uniqueSalts.length, equals(salts.length));
      });

      test('should generate valid hex string', () {
        final salt = TomPasswordHasher.generateSalt(16);

        expect(RegExp(r'^[0-9a-f]+$').hasMatch(salt), isTrue);
      });
    });

    group('toHexString', () {
      test('should convert bytes to hex string', () {
        final bytes = Uint8List.fromList([0, 15, 16, 255]);
        final hex = TomPasswordHasher.toHexString(bytes);

        expect(hex, equals('000f10ff'));
      });

      test('should handle empty byte list', () {
        final bytes = Uint8List(0);
        final hex = TomPasswordHasher.toHexString(bytes);

        expect(hex, isEmpty);
      });

      test('should pad single digit hex values with leading zero', () {
        final bytes = Uint8List.fromList([0, 1, 2, 9, 10, 15]);
        final hex = TomPasswordHasher.toHexString(bytes);

        expect(hex, equals('000102090a0f'));
      });
    });

    group('toUint8List', () {
      test('should convert hex string to bytes', () {
        final bytes = TomPasswordHasher.toUint8List('000f10ff');

        expect(bytes, equals(Uint8List.fromList([0, 15, 16, 255])));
      });

      test('should handle empty hex string', () {
        final bytes = TomPasswordHasher.toUint8List('');

        expect(bytes.length, equals(0));
      });

      test('should round-trip with toHexString', () {
        final original = Uint8List.fromList([0, 127, 128, 255, 1, 2, 3]);
        final hex = TomPasswordHasher.toHexString(original);
        final roundTripped = TomPasswordHasher.toUint8List(hex);

        expect(roundTripped, equals(original));
      });
    });

    group('buildKeyDerivator', () {
      test('should build derivator with default spec', () {
        final derivator = TomPasswordHasher.buildKeyDerivator();

        expect(derivator, isNotNull);
        expect(derivator.keySize, greaterThan(0));
      });

      test('should build derivator with custom spec', () {
        final spec = 'Argon2;2i,13,2,32768,2,64';
        final salt = TomPasswordHasher.generateSalt(16);
        final derivator = TomPasswordHasher.buildKeyDerivator(spec, salt);

        expect(derivator, isNotNull);
        expect(derivator.keySize, equals(64));
      });

      test('should throw for invalid spec', () {
        expect(
          () => TomPasswordHasher.buildKeyDerivator('InvalidAlgo;params'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('makeArgon2Params', () {
      test('should create Argon2i parameters', () {
        final salt = TomPasswordHasher.generateSalt(16);
        final params = TomPasswordHasher.makeArgon2Params(
          '2i,13,4,65536,4,128',
          salt,
        );

        expect(params.desiredKeyLength, equals(128));
        expect(params.iterations, equals(4));
        expect(params.memory, equals(65536));
        expect(params.lanes, equals(4));
      });

      test('should create Argon2d parameters', () {
        final salt = TomPasswordHasher.generateSalt(16);
        final params = TomPasswordHasher.makeArgon2Params(
          '2d,13,4,65536,4,128',
          salt,
        );

        expect(params.desiredKeyLength, equals(128));
      });

      test('should create Argon2id parameters', () {
        final salt = TomPasswordHasher.generateSalt(16);
        final params = TomPasswordHasher.makeArgon2Params(
          '2id,13,4,65536,4,128',
          salt,
        );

        expect(params.desiredKeyLength, equals(128));
      });
    });

    group('parameterString', () {
      test('should convert params back to specification string', () {
        final salt = TomPasswordHasher.generateSalt(16);
        final originalSpec = '2i,13,4,65536,4,128';
        final params = TomPasswordHasher.makeArgon2Params(originalSpec, salt);

        final (specString, saltString) = TomPasswordHasher.parameterString(
          params,
        );

        expect(specString, equals(originalSpec));
        expect(saltString, equals(salt));
      });
    });
  });

  // ============================================================================
  // RSA Encryption Tests
  // ============================================================================

  group('RSA Encryption', () {
    late RSAPublicKey publicKey;
    late RSAPrivateKey privateKey;

    setUpAll(() {
      // Use the default development keys for testing
      publicKey = TomJwtConfiguration.rsaPubKey;
      privateKey = TomJwtConfiguration.rsaPrivKey;
    });

    group('rsaEncrypt', () {
      test('should encrypt data successfully', () {
        final plaintext = utf8.encode('Hello, World!');
        final encrypted = rsaEncrypt(publicKey, Uint8List.fromList(plaintext));

        expect(encrypted, isNotNull);
        expect(encrypted.length, greaterThan(0));
        // Encrypted data should be different from plaintext
        expect(encrypted, isNot(equals(Uint8List.fromList(plaintext))));
      });

      test(
        'should produce different ciphertext each time due to OAEP padding',
        () {
          final plaintext = Uint8List.fromList(utf8.encode('Test data'));

          final encrypted1 = rsaEncrypt(publicKey, plaintext);
          final encrypted2 = rsaEncrypt(publicKey, plaintext);

          // OAEP uses random padding, so same plaintext produces different ciphertext
          expect(encrypted1, isNot(equals(encrypted2)));
        },
      );

      test('should handle empty data', () {
        final encrypted = rsaEncrypt(publicKey, Uint8List(0));

        expect(encrypted, isNotNull);
      });

      test('should handle single byte', () {
        final encrypted = rsaEncrypt(publicKey, Uint8List.fromList([42]));

        expect(encrypted, isNotNull);
        expect(encrypted.length, greaterThan(0));
      });
    });

    group('rsaDecrypt', () {
      test('should decrypt encrypted data correctly', () {
        final plaintext = 'Secret message for RSA test';
        final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

        final encrypted = rsaEncrypt(publicKey, plaintextBytes);
        final decrypted = rsaDecrypt(privateKey, encrypted);

        expect(utf8.decode(decrypted), equals(plaintext));
      });

      test('should decrypt empty encrypted data', () {
        final encrypted = rsaEncrypt(publicKey, Uint8List(0));
        final decrypted = rsaDecrypt(privateKey, encrypted);

        expect(decrypted.length, equals(0));
      });

      test('should round-trip binary data correctly', () {
        final binaryData = Uint8List.fromList([0, 1, 127, 128, 255, 100, 50]);

        final encrypted = rsaEncrypt(publicKey, binaryData);
        final decrypted = rsaDecrypt(privateKey, encrypted);

        expect(decrypted, equals(binaryData));
      });

      test('should round-trip unicode text correctly', () {
        final text = '日本語テスト🔐中文测试';
        final plaintextBytes = Uint8List.fromList(utf8.encode(text));

        final encrypted = rsaEncrypt(publicKey, plaintextBytes);
        final decrypted = rsaDecrypt(privateKey, encrypted);

        expect(utf8.decode(decrypted), equals(text));
      });
    });

    group('rsaSign', () {
      test('should create signature for data', () {
        final data = Uint8List.fromList(utf8.encode('Data to sign'));
        final signature = rsaSign(privateKey, data);

        expect(signature, isNotNull);
        expect(signature.length, greaterThan(0));
      });

      test('should create deterministic signature for same data', () {
        final data = Uint8List.fromList(utf8.encode('Consistent data'));

        final signature1 = rsaSign(privateKey, data);
        final signature2 = rsaSign(privateKey, data);

        // RSA signatures with SHA-256 are deterministic (no random padding)
        expect(signature1, equals(signature2));
      });

      test('should create different signatures for different data', () {
        final data1 = Uint8List.fromList(utf8.encode('Data 1'));
        final data2 = Uint8List.fromList(utf8.encode('Data 2'));

        final signature1 = rsaSign(privateKey, data1);
        final signature2 = rsaSign(privateKey, data2);

        expect(signature1, isNot(equals(signature2)));
      });
    });

    group('rsaVerify', () {
      test('should verify valid signature', () {
        final data = Uint8List.fromList(utf8.encode('Signed data'));
        final signature = rsaSign(privateKey, data);

        final isValid = rsaVerify(publicKey, data, signature);

        expect(isValid, isTrue);
      });

      test('should reject signature for modified data', () {
        final originalData = Uint8List.fromList(utf8.encode('Original data'));
        final modifiedData = Uint8List.fromList(utf8.encode('Modified data'));
        final signature = rsaSign(privateKey, originalData);

        final isValid = rsaVerify(publicKey, modifiedData, signature);

        expect(isValid, isFalse);
      });

      test('should reject modified signature', () {
        final data = Uint8List.fromList(utf8.encode('Test data'));
        final signature = rsaSign(privateKey, data);

        // Modify the signature
        final modifiedSignature = Uint8List.fromList(signature);
        modifiedSignature[0] = (modifiedSignature[0] + 1) % 256;

        final isValid = rsaVerify(publicKey, data, modifiedSignature);

        expect(isValid, isFalse);
      });

      test('should verify empty data signature', () {
        final data = Uint8List(0);
        final signature = rsaSign(privateKey, data);

        final isValid = rsaVerify(publicKey, data, signature);

        expect(isValid, isTrue);
      });
    });
  });

  // ============================================================================
  // RsaKeyHelper Tests
  // ============================================================================

  group('RsaKeyHelper', () {
    group('getSecureRandom', () {
      test('should create a secure random generator', () {
        final random = RsaKeyHelper.getSecureRandom();

        expect(random, isNotNull);
      });

      test('should create generators that produce different values', () {
        final random1 = RsaKeyHelper.getSecureRandom();
        final random2 = RsaKeyHelper.getSecureRandom();

        // Generate some random bytes
        final bytes1 = random1.nextBytes(32);
        final bytes2 = random2.nextBytes(32);

        expect(bytes1, isNot(equals(bytes2)));
      });
    });

    group('parsePublicKeyFromPem', () {
      test('should parse PKCS#8 public key', () {
        final pemString = '''
-----BEGIN PUBLIC KEY-----
MIIBCgKCAQEApobMwJj9SxpZbk0fcG8Awv9PCiO4/GsPimeH398D+Qt1kUrrMqvm5+AYLh1PcIgE/V+QiFTgBv9Fpuu5YtrnF+oi/dg23MUKPA0yXzHjTyshm3P2uhIRN4c6fVru5HF3HXGh5POR1A6kGW9IGbeKhLCG1yyoNDGzHdrdwNEREw3N6KEKAN4swXOMau7rhaRXTkOWTSyPwhAEI+ZrwTnHBIDsVouqPQ0yAX7vTGK1UFNPGmh7itLECj8WgbxgElyrPgtDknmXmfCzrn3DMJeGbuq9dzl0z5DZysrR3nEqIQB8xnDLkkejjnmn1YOflaZMql3mKSJeJ9KxPUZ+u+6DcwIDAQAB
-----END PUBLIC KEY-----
''';
        final publicKey = RsaKeyHelper.parsePublicKeyFromPem(pemString);

        expect(publicKey, isNotNull);
        expect(publicKey.modulus, isNotNull);
        expect(publicKey.exponent, isNotNull);
      });

      test('should parse public key with extra whitespace', () {
        final pemString = '''
  -----BEGIN PUBLIC KEY-----
  MIIBCgKCAQEApobMwJj9SxpZbk0fcG8Awv9PCiO4/GsPimeH398D+Qt1kUrrMqvm5+AYLh1PcIgE/V+QiFTgBv9Fpuu5YtrnF+oi/dg23MUKPA0yXzHjTyshm3P2uhIRN4c6fVru5HF3HXGh5POR1A6kGW9IGbeKhLCG1yyoNDGzHdrdwNEREw3N6KEKAN4swXOMau7rhaRXTkOWTSyPwhAEI+ZrwTnHBIDsVouqPQ0yAX7vTGK1UFNPGmh7itLECj8WgbxgElyrPgtDknmXmfCzrn3DMJeGbuq9dzl0z5DZysrR3nEqIQB8xnDLkkejjnmn1YOflaZMql3mKSJeJ9KxPUZ+u+6DcwIDAQAB
  -----END PUBLIC KEY-----
  ''';
        final publicKey = RsaKeyHelper.parsePublicKeyFromPem(pemString);

        expect(publicKey, isNotNull);
      });
    });

    group('parsePrivateKeyFromPem', () {
      test('should parse PKCS#8 private key', () {
        final pemString = '''
-----BEGIN PRIVATE KEY-----
MIIFowIBAAKCAQEApobMwJj9SxpZbk0fcG8Awv9PCiO4/GsPimeH398D+Qt1kUrrMqvm5+AYLh1PcIgE/V+QiFTgBv9Fpuu5YtrnF+oi/dg23MUKPA0yXzHjTyshm3P2uhIRN4c6fVru5HF3HXGh5POR1A6kGW9IGbeKhLCG1yyoNDGzHdrdwNEREw3N6KEKAN4swXOMau7rhaRXTkOWTSyPwhAEI+ZrwTnHBIDsVouqPQ0yAX7vTGK1UFNPGmh7itLECj8WgbxgElyrPgtDknmXmfCzrn3DMJeGbuq9dzl0z5DZysrR3nEqIQB8xnDLkkejjnmn1YOflaZMql3mKSJeJ9KxPUZ+u+6DcwKCAQAvUp9dHBze+t3vOnt0uBa/U05i00P+d24zJri2Jeo7G8aNQ30TKUa1HjnA4RNyJzVDy6SHGZeQZXqltNc6AHsrkJ3hBVCR7Gy8JAPsiYDPPrKOOqYiun+qCAPXG8BHqvbupxwatBz85iw8DiOvKzlx+7hV7ZrfOkBse4YJBWCUySF/T+ZVdM3kqoMtfegnGa2AWmGa09qDoCBt1TAHVtNDAu/1UnbvjlHTJ6NFfboibortCRBicmhAu1jcbW6dn9/J9naXlkYxRK22uItXKunv/dqmDQ+lRE9KuKArexYweenHd3yuExuXGOR9XM8vJtgZqTR8WYRDbeWgNQMwXSoBAoIBAC9Sn10cHN763e86e3S4Fr9TTmLTQ/53bjMmuLYl6jsbxo1DfRMpRrUeOcDhE3InNUPLpIcZl5BleqW01zoAeyuQneEFUJHsbLwkA+yJgM8+so46piK6f6oIA9cbwEeq9u6nHBq0HPzmLDwOI68rOXH7uFXtmt86QGx7hgkFYJTJIX9P5lV0zeSqgy196CcZrYBaYZrT2oOgIG3VMAdW00MC7/VSdu+OUdMno0V9uiJuiu0JEGJyaEC7WNxtbp2f38n2dpeWRjFErba4i1cq6e/92qYND6VET0q4oCt7FjB56cd3fK4TG5cY5H1czy8m2BmpNHxZhENt5aA1AzBdKgECgYEA5QjshbsxGUmtMLSFXPn3Y2KW9e2K0r2itb5A2PRB+28aDiFArPmWVhvRujS8KG78NUBwWq/c2c8bET/6j1y0qIsy/2ZBWmoKTSyIbrxybzalMpOWQ5Y37CKypG73EQtigHmuZ6TN0Tr9vkY/q+o+wilVF+EIzcj39WAherAKHwcCgYEAuiHin+jukcxVNKy4bz8dRkHHbmCoCv12fNSihhemfrE/daCWCY1J+VkCrB1a5iuOx6huDAYHXMWl3jjfkvoTX1/YQjhb5f2bMqrHjkyw86k1j6yMdgfO+AG3sqhIz3fszMaVd6UfE7mwwaqE4QfppAJWBvKS9SQaY7KNN2+8cTUCgYB3qPHp7KL6U0Po7me+69oUUq4MTs74y5r22S+IKhVPB/zU5QqlVMD2vBIW9vZXKaUbLU+GEduQ8GNz37lIrWa1qAQ862+5jS1UpK+jK1GeSS6F/hXDuff9pyMuRctPXGNaPDiibbgaWHe5sXoSl4+yYWXT0/6FhToHOPJE5zRigQKBgQCpx2zTFgI+xVZXNNEK0FQgmLGT0eCWHbpthPs2Ou5ok77hyXfyAImgQvu4CRK37rVPEyhGGV2v1q1EdTYh96+iCGfXh1b0A48D+VkLSJMDvq2XfvmkU90KxW5NLUk0zRwXcXA28UvWj0NWc/a+2JvaOTNFJRC9QJA9rkk3btlBnQKBgQCTT4oMD16jRtyxwK+cczzxPX3P4FtZHuppBetUmuq+2xFTvdB/ivUARXcYhibG09+AC1heYtImy+pRXxMPnKXimFFvimJMT4edBq0w2XA33VDoG+xeYM6G0c3bHbk53DTNk+lr4GirKMSe6kYFV3Fo9kmnvW0N9ttLfFQqds+LUg==
-----END PRIVATE KEY-----
''';
        final privateKey = RsaKeyHelper.parsePrivateKeyFromPem(pemString);

        expect(privateKey, isNotNull);
        expect(privateKey.modulus, isNotNull);
        expect(privateKey.privateExponent, isNotNull);
        expect(privateKey.p, isNotNull);
        expect(privateKey.q, isNotNull);
      });
    });

    group('encodePublicKeyToPemPKCS1', () {
      test('should encode public key to PEM format', () {
        final publicKey = TomJwtConfiguration.rsaPubKey;
        final pem = RsaKeyHelper.encodePublicKeyToPemPKCS1(publicKey);

        expect(pem, startsWith('-----BEGIN PUBLIC KEY-----'));
        expect(pem, endsWith('-----END PUBLIC KEY-----'));
      });

      test('should round-trip public key through PEM encoding', () {
        final originalKey = TomJwtConfiguration.rsaPubKey;
        final pem = RsaKeyHelper.encodePublicKeyToPemPKCS1(originalKey);
        final parsedKey = RsaKeyHelper.parsePublicKeyFromPem(pem);

        expect(parsedKey.modulus, equals(originalKey.modulus));
        expect(parsedKey.exponent, equals(originalKey.exponent));
      });
    });

    group('encodePrivateKeyToPemPKCS1', () {
      test('should encode private key to PEM format', () {
        final privateKey = TomJwtConfiguration.rsaPrivKey;
        final pem = RsaKeyHelper.encodePrivateKeyToPemPKCS1(privateKey);

        expect(pem, startsWith('-----BEGIN PRIVATE KEY-----'));
        expect(pem, endsWith('-----END PRIVATE KEY-----'));
      });

      test('should round-trip private key through PEM encoding', () {
        final originalKey = TomJwtConfiguration.rsaPrivKey;
        final pem = RsaKeyHelper.encodePrivateKeyToPemPKCS1(originalKey);
        final parsedKey = RsaKeyHelper.parsePrivateKeyFromPem(pem);

        expect(parsedKey.modulus, equals(originalKey.modulus));
        expect(parsedKey.privateExponent, equals(originalKey.privateExponent));
        expect(parsedKey.p, equals(originalKey.p));
        expect(parsedKey.q, equals(originalKey.q));
      });
    });

    group('sign', () {
      test('should sign plain text and return base64 encoded signature', () {
        final privateKey = TomJwtConfiguration.rsaPrivKey;
        final signature = RsaKeyHelper.sign('Hello, World!', privateKey);

        expect(signature, isNotNull);
        expect(signature, isNotEmpty);
        // Should be valid base64
        expect(() => base64Decode(signature), returnsNormally);
      });

      test('should produce consistent signatures', () {
        final privateKey = TomJwtConfiguration.rsaPrivKey;
        final sig1 = RsaKeyHelper.sign('Test message', privateKey);
        final sig2 = RsaKeyHelper.sign('Test message', privateKey);

        expect(sig1, equals(sig2));
      });
    });

    group('createUint8ListFromString', () {
      test('should convert ASCII string to bytes', () {
        final bytes = RsaKeyHelper.createUint8ListFromString('Hello');

        expect(bytes, equals(Uint8List.fromList([72, 101, 108, 108, 111])));
      });

      test('should handle empty string', () {
        final bytes = RsaKeyHelper.createUint8ListFromString('');

        expect(bytes.length, equals(0));
      });

      test('should handle unicode string', () {
        final bytes = RsaKeyHelper.createUint8ListFromString('日本語');

        expect(bytes.length, greaterThan(3)); // UTF-8 encoded
      });
    });

    group('computeRSAKeyPair', () {
      test('should generate valid RSA key pair', () async {
        final random = RsaKeyHelper.getSecureRandom();
        final keyPair = await RsaKeyHelper.computeRSAKeyPair(random);

        final publicKey = keyPair.publicKey as RSAPublicKey;
        final privateKey = keyPair.privateKey as RSAPrivateKey;

        expect(publicKey, isNotNull);
        expect(privateKey, isNotNull);
        expect(publicKey.modulus, isNotNull);
        expect(privateKey.modulus, isNotNull);
        expect(publicKey.modulus, equals(privateKey.modulus));
      });

      test('should generate keys that can encrypt and decrypt', () async {
        final random = RsaKeyHelper.getSecureRandom();
        final keyPair = await RsaKeyHelper.computeRSAKeyPair(random);

        final publicKey = keyPair.publicKey as RSAPublicKey;
        final privateKey = keyPair.privateKey as RSAPrivateKey;

        final plaintext = Uint8List.fromList(utf8.encode('Test message'));
        final encrypted = rsaEncrypt(publicKey, plaintext);
        final decrypted = rsaDecrypt(privateKey, encrypted);

        expect(utf8.decode(decrypted), equals('Test message'));
      });

      test('should generate keys that can sign and verify', () async {
        final random = RsaKeyHelper.getSecureRandom();
        final keyPair = await RsaKeyHelper.computeRSAKeyPair(random);

        final publicKey = keyPair.publicKey as RSAPublicKey;
        final privateKey = keyPair.privateKey as RSAPrivateKey;

        final data = Uint8List.fromList(utf8.encode('Signed message'));
        final signature = rsaSign(privateKey, data);
        final isValid = rsaVerify(publicKey, data, signature);

        expect(isValid, isTrue);
      });
    });

    group('decodePEM', () {
      test('should decode PEM to raw bytes', () {
        final pem = '''
-----BEGIN PUBLIC KEY-----
AQAB
-----END PUBLIC KEY-----
''';
        final bytes = RsaKeyHelper.decodePEM(pem);

        expect(bytes, isNotNull);
        expect(bytes.length, greaterThan(0));
      });
    });

    group('removePemHeaderAndFooter', () {
      test('should remove public key headers', () {
        final pem =
            '-----BEGIN PUBLIC KEY-----\nAQAB\n-----END PUBLIC KEY-----';
        final content = RsaKeyHelper.removePemHeaderAndFooter(pem);

        expect(content, equals('AQAB'));
      });

      test('should remove private key headers', () {
        final pem =
            '-----BEGIN PRIVATE KEY-----\nAQAB\n-----END PRIVATE KEY-----';
        final content = RsaKeyHelper.removePemHeaderAndFooter(pem);

        expect(content, equals('AQAB'));
      });
    });
  });

  // ============================================================================
  // TomJwtConfiguration Tests
  // ============================================================================

  group('TomJwtConfiguration', () {
    group('defaultSignConfiguration', () {
      test('should have a default configuration', () {
        expect(TomJwtConfiguration.defaultSignConfiguration, isNotNull);
      });

      test('should use HMAC key by default', () {
        expect(TomJwtConfiguration.hmacKey, isNotNull);
      });

      test('should have RSA keys configured', () {
        expect(TomJwtConfiguration.rsaPrivKey, isNotNull);
        expect(TomJwtConfiguration.rsaPubKey, isNotNull);
      });
    });

    group('constructor', () {
      test('should create configuration with all parameters', () {
        final config = TomJwtConfiguration(
          TomJwtConfiguration.hmacKey,
          JWTAlgorithm.HS256,
          TomJwtConfiguration.rsaPrivKey,
          TomJwtConfiguration.rsaPubKey,
          false,
        );

        expect(config.key, equals(TomJwtConfiguration.hmacKey));
        expect(config.algorithm, equals(JWTAlgorithm.HS256));
        expect(config.isDummy, isFalse);
      });

      test('should default isDummy to true', () {
        final config = TomJwtConfiguration(
          TomJwtConfiguration.hmacKey,
          JWTAlgorithm.HS256,
          TomJwtConfiguration.rsaPrivKey,
          TomJwtConfiguration.rsaPubKey,
        );

        expect(config.isDummy, isTrue);
      });
    });

    group('encrypt', () {
      test('should encrypt string data', () {
        final config = TomJwtConfiguration.defaultSignConfiguration;
        final encrypted = config.encrypt('Hello, World!');

        expect(encrypted, isNotNull);
        expect(encrypted, isNotEmpty);
        // Should be valid base64
        expect(() => base64Decode(encrypted), returnsNormally);
      });

      test('should produce different ciphertext for same input', () {
        final config = TomJwtConfiguration.defaultSignConfiguration;
        final encrypted1 = config.encrypt('Test data');
        final encrypted2 = config.encrypt('Test data');

        // OAEP uses random padding
        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });

    group('decrypt', () {
      test('should decrypt encrypted data', () {
        final config = TomJwtConfiguration.defaultSignConfiguration;
        final original = 'Secret message for JWT test';
        final encrypted = config.encrypt(original);
        final decrypted = config.decrypt(encrypted);

        expect(decrypted, equals(original));
      });

      test('should round-trip JSON data', () {
        final config = TomJwtConfiguration.defaultSignConfiguration;
        final jsonData = jsonEncode({'userId': 123, 'role': 'admin'});
        final encrypted = config.encrypt(jsonData);
        final decrypted = config.decrypt(encrypted);

        expect(decrypted, equals(jsonData));
        expect(jsonDecode(decrypted), equals({'userId': 123, 'role': 'admin'}));
      });
    });
  });

  // ============================================================================
  // TomServerJwtToken Tests
  // ============================================================================

  group('TomServerJwtToken', () {
    group('constructor', () {
      test('should create token with public data', () {
        final token = TomServerJwtToken({'userId': '123', 'role': 'user'});

        expect(token.publicData, equals({'userId': '123', 'role': 'user'}));
        expect(token.encryptedData, isEmpty);
      });

      test('should create token with encrypted data', () {
        final token = TomServerJwtToken(
          {'userId': '123'},
          encryptedData: {'secret': 'value'},
        );

        expect(token.encryptedData, equals({'secret': 'value'}));
      });

      test('should use default expiration of 2 hours', () {
        final token = TomServerJwtToken({'test': 'data'});

        expect(token.expiresIn, equals(const Duration(hours: 2)));
      });

      test('should accept custom expiration', () {
        final token = TomServerJwtToken({
          'test': 'data',
        }, expiresIn: const Duration(days: 7));

        expect(token.expiresIn, equals(const Duration(days: 7)));
      });

      test('should accept custom not before duration', () {
        final token = TomServerJwtToken({
          'test': 'data',
        }, notBefore: const Duration(minutes: 5));

        expect(token.notBefore, equals(const Duration(minutes: 5)));
      });

      test('should accept noIssueAt flag', () {
        final token = TomServerJwtToken({'test': 'data'}, noIssueAt: true);

        expect(token.noIssueAt, isTrue);
      });
    });

    group('getJWT', () {
      test('should generate valid JWT string', () {
        final token = TomServerJwtToken({'userId': '123'});
        final jwtString = token.getJWT('test-issuer');

        expect(jwtString, isNotNull);
        expect(jwtString, isNotEmpty);
        // JWT has 3 parts separated by dots
        expect(jwtString.split('.').length, equals(3));
      });

      test('should include issuer in token', () {
        final token = TomServerJwtToken({'userId': '123'});
        final jwtString = token.getJWT('my-auth-server');

        // Decode and verify issuer
        final decoded = JWT.decode(jwtString);
        expect(decoded.issuer, equals('my-auth-server'));
      });

      test('should include public data in payload', () {
        final token = TomServerJwtToken({
          'userId': '123',
          'role': 'admin',
          'name': 'Test User',
        });
        final jwtString = token.getJWT('issuer');

        final decoded = JWT.decode(jwtString);
        final payload = decoded.payload as Map<String, dynamic>;

        expect(payload['userId'], equals('123'));
        expect(payload['role'], equals('admin'));
        expect(payload['name'], equals('Test User'));
      });

      test('should include validUntil and validFrom in payload', () {
        final token = TomServerJwtToken({'test': 'data'});
        final jwtString = token.getJWT('issuer');

        final decoded = JWT.decode(jwtString);
        final payload = decoded.payload as Map<String, dynamic>;

        expect(payload['validUntil'], isNotNull);
        expect(payload['validFrom'], isNotNull);
        // Should be ISO 8601 strings
        expect(() => DateTime.parse(payload['validUntil']), returnsNormally);
        expect(() => DateTime.parse(payload['validFrom']), returnsNormally);
      });

      test('should include encrypted field when encryptedData is provided', () {
        final token = TomServerJwtToken(
          {'userId': '123'},
          encryptedData: {'secret': 'hidden'},
        );
        final jwtString = token.getJWT('issuer');

        final decoded = JWT.decode(jwtString);
        final payload = decoded.payload as Map<String, dynamic>;

        expect(payload['encrypted'], isNotNull);
        expect(payload['encrypted'], isA<String>());
      });

      test(
        'should not include encrypted field when encryptedData is empty',
        () {
          final token = TomServerJwtToken({'userId': '123'});
          final jwtString = token.getJWT('issuer');

          final decoded = JWT.decode(jwtString);
          final payload = decoded.payload as Map<String, dynamic>;

          expect(payload.containsKey('encrypted'), isFalse);
        },
      );
    });
  });

  // ============================================================================
  // TomClientJwtToken Tests
  // ============================================================================

  group('TomClientJwtToken', () {
    group('constructor', () {
      test('should decode JWT string', () {
        final serverToken = TomServerJwtToken({'userId': '123'});
        final jwtString = serverToken.getJWT('test-issuer');

        final clientToken = TomClientJwtToken(jwtString);

        expect(clientToken, isNotNull);
        expect(clientToken.tokenString, equals(jwtString));
      });

      test('should skip decryption when decrypt is false', () {
        final serverToken = TomServerJwtToken(
          {'userId': '123'},
          encryptedData: {'secret': 'value'},
        );
        final jwtString = serverToken.getJWT('issuer');

        final clientToken = TomClientJwtToken(jwtString, decrypt: false);

        expect(clientToken.secretData, isNull);
      });
    });

    group('issuer', () {
      test('should return token issuer', () {
        final serverToken = TomServerJwtToken({'test': 'data'});
        final jwtString = serverToken.getJWT('my-issuer');
        final clientToken = TomClientJwtToken(jwtString);

        expect(clientToken.issuer, equals('my-issuer'));
      });
    });

    group('payload', () {
      test('should return public data from token', () {
        final serverToken = TomServerJwtToken({
          'userId': 'user123',
          'role': 'admin',
        });
        final jwtString = serverToken.getJWT('issuer');
        final clientToken = TomClientJwtToken(jwtString);

        final payload = clientToken.payload!;
        expect(payload['userId'], equals('user123'));
        expect(payload['role'], equals('admin'));
      });

      test('should include validity timestamps', () {
        final serverToken = TomServerJwtToken({'test': 'data'});
        final jwtString = serverToken.getJWT('issuer');
        final clientToken = TomClientJwtToken(jwtString);

        final payload = clientToken.payload!;
        expect(payload['validUntil'], isNotNull);
        expect(payload['validFrom'], isNotNull);
      });
    });

    group('secretData', () {
      test('should decrypt and return encrypted data', () {
        final serverToken = TomServerJwtToken(
          {'userId': '123'},
          encryptedData: {
            'permissions': ['read', 'write'],
            'apiKey': 'abc123',
          },
        );
        final jwtString = serverToken.getJWT('issuer');
        final clientToken = TomClientJwtToken(jwtString);

        expect(clientToken.secretData, isNotNull);
        expect(
          clientToken.secretData!['permissions'],
          equals(['read', 'write']),
        );
        expect(clientToken.secretData!['apiKey'], equals('abc123'));
      });

      test('should be null when no encrypted data in token', () {
        final serverToken = TomServerJwtToken({'userId': '123'});
        final jwtString = serverToken.getJWT('issuer');
        final clientToken = TomClientJwtToken(jwtString);

        expect(clientToken.secretData, isNull);
      });
    });

    group('round-trip', () {
      test('should round-trip complex data through JWT', () {
        final publicData = {
          'userId': 'user-uuid-12345',
          'email': 'test@example.com',
          'roles': ['admin', 'user'],
          'metadata': {'lastLogin': '2024-01-01T00:00:00Z'},
        };
        final encryptedData = {
          'sessionId': 'session-secret-xyz',
          'permissions': ['read', 'write', 'delete'],
          'tokens': {'access': 'token1', 'refresh': 'token2'},
        };

        final serverToken = TomServerJwtToken(
          publicData,
          encryptedData: encryptedData,
          expiresIn: const Duration(hours: 1),
        );
        final jwtString = serverToken.getJWT('auth-service');

        final clientToken = TomClientJwtToken(jwtString);

        expect(clientToken.issuer, equals('auth-service'));
        expect(clientToken.payload!['userId'], equals('user-uuid-12345'));
        expect(clientToken.payload!['email'], equals('test@example.com'));
        expect(clientToken.payload!['roles'], equals(['admin', 'user']));
        expect(
          clientToken.secretData!['sessionId'],
          equals('session-secret-xyz'),
        );
        expect(
          clientToken.secretData!['permissions'],
          equals(['read', 'write', 'delete']),
        );
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final serverToken = TomServerJwtToken({'userId': '123'});
        final jwtString = serverToken.getJWT('issuer');
        final clientToken = TomClientJwtToken(jwtString);

        final str = clientToken.toString();

        expect(str, contains('TomClientJwtToken'));
        expect(str, contains('I: issuer'));
      });

      test('should respect globalSettingShowContentInToString', () {
        final serverToken = TomServerJwtToken({'userId': 'secret'});
        final jwtString = serverToken.getJWT('issuer');

        TomClientJwtToken.globalSettingShowContentInToString = true;
        final clientToken = TomClientJwtToken(jwtString);
        final strWithContent = clientToken.toString();

        TomClientJwtToken.globalSettingShowContentInToString = false;
        final strWithoutContent = clientToken.toString();

        // Reset to default
        TomClientJwtToken.globalSettingShowContentInToString = true;

        expect(strWithContent.length, greaterThan(strWithoutContent.length));
      });
    });
  });

  // ============================================================================
  // TomJwtTokenException Tests
  // ============================================================================

  group('TomJwtTokenException', () {
    group('constructor', () {
      test('should create exception with key and message', () {
        final exception = TomJwtTokenException(
          'jwt.error.invalid',
          'The token is invalid',
        );

        expect(exception.key, equals('jwt.error.invalid'));
        expect(exception.defaultUserMessage, equals('The token is invalid'));
      });

      test('should store root exception', () {
        final rootError = FormatException('Bad format');
        final exception = TomJwtTokenException(
          'jwt.error.parse',
          'Failed to parse token',
          rootException: rootError,
        );

        expect(exception.rootException, equals(rootError));
      });
    });

    test('should be throwable', () {
      expect(
        () => throw TomJwtTokenException('key', 'message'),
        throwsA(isA<TomJwtTokenException>()),
      );
    });
  });

  // ============================================================================
  // Integration Tests
  // ============================================================================

  group('Crypto Integration', () {
    test('should encrypt, sign, and package data in JWT', () {
      // Create server token with both public and encrypted data
      final serverToken = TomServerJwtToken(
        {'publicField': 'visible'},
        encryptedData: {'privateField': 'hidden'},
      );
      final jwtString = serverToken.getJWT('integration-test');

      // Parse on client side
      final clientToken = TomClientJwtToken(jwtString);

      // Verify public data is accessible
      expect(clientToken.payload!['publicField'], equals('visible'));

      // Verify encrypted data is decrypted
      expect(clientToken.secretData!['privateField'], equals('hidden'));

      // Verify original encrypted data is not visible in raw payload
      expect(clientToken.payload!.containsKey('privateField'), isFalse);
    });

    test('should work with password hashing and JWT together', () {
      // Hash a password
      final (hash, spec) = TomPasswordHasher.hashPassword('userPassword123');

      // Store hash reference in JWT (but not the actual hash for security)
      final serverToken = TomServerJwtToken(
        {'userId': 'user123'},
        encryptedData: {'passwordHashSpec': spec, 'hasPasswordHash': true},
      );
      final jwtString = serverToken.getJWT('auth-server');

      // Client receives token
      final clientToken = TomClientJwtToken(jwtString);
      expect(clientToken.secretData!['hasPasswordHash'], isTrue);

      // Later, verify password using stored hash
      expect(
        TomPasswordHasher.verifyPassword('userPassword123', hash, spec),
        isTrue,
      );
    });
  });
}
