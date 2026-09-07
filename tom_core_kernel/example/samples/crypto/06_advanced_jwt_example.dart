/// Advanced JWT Token Example
///
/// The advanced surface of [TomServerJwtToken] and [TomClientJwtToken], past
/// the creation and parsing that `05_jwt_token_example.dart` owns:
/// - [TomJwtTokenException] — raised by a real corrupt token, caught, and shown
///   not to fire when decryption is switched off
/// - a custom [TomJwtConfiguration] that signs and decrypts a real token
/// - validity windows (`notBefore`, `expiresIn`), read back off the token
/// - `decrypt: false`, and what the payload still carries
/// - `globalSettingShowContentInToString`
/// - `noIssueAt`, checked against the `iat` claim it controls
/// - the confidentiality property the encryption exists to provide
/// - expiry, checked on the client the way an application would
///
/// `05_jwt_token_example.dart` owns creation, parsing and the encrypted
/// round-trip, and nothing here repeats them.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class AdvancedJwtExample {
  // Captured results
  static String? exceptionKey;
  static Type? rootExceptionType;
  static bool corruptTokenReadsWithoutDecryption = false;
  static bool customConfigRoundTrips = false;
  static bool validityWindowWorks = false;
  static bool decryptDisabledWorks = false;
  static bool iatOmitted = false;
  static bool secretStaysConfidential = false;
  static bool expiryDetected = false;

  /// A token whose `encrypted` claim holds something RSA cannot decrypt.
  ///
  /// `_generateLoad` copies `publicData` into the payload before it writes the
  /// `encrypted` claim, and only writes that claim when `encryptedData` is
  /// non-empty. Passing the claim in as public data with no encrypted data is
  /// therefore a genuine corrupt token — signed, well-formed, and carrying
  /// ciphertext that is not ciphertext — built through the public API alone.
  static String _tokenWithUndecryptableSecret() => TomServerJwtToken({
    'userId': 'user-123',
    'encrypted': 'not-actually-ciphertext',
  }).getJWT('test-issuer');

  // --------------------------------------------------------------------------
  // Example 1: TomJwtTokenException, raised and caught
  // --------------------------------------------------------------------------
  static void example1DecryptionException() {
    print('1. TomJwtTokenException on decryption failure:');

    final corrupt = _tokenWithUndecryptableSecret();

    // Parsing with decryption on reaches the RSA step and fails there.
    TomJwtTokenException? caught;
    try {
      TomClientJwtToken(corrupt);
    } on TomJwtTokenException catch (e) {
      caught = e;
    }

    print('   - key             : ${caught?.key}');
    print('   - message         : ${caught?.defaultUserMessage}');
    print('   - rootException   : ${caught?.rootException.runtimeType}');
    print('   - uuid is set     : ${caught?.uuid != null}');

    exceptionKey = caught?.key;
    rootExceptionType = caught?.rootException.runtimeType;

    // The same token parses cleanly with decryption switched off, which is
    // what makes this a decryption failure rather than a malformed token.
    final withoutDecryption = TomClientJwtToken(corrupt, decrypt: false);
    corruptTokenReadsWithoutDecryption =
        withoutDecryption.payload?['userId'] == 'user-123';

    print(
      '   - same token with decrypt: false reads userId '
      '${withoutDecryption.payload?['userId']} and does not throw',
    );

    // Assertions
    assert(caught != null, 'A corrupt encrypted claim should throw');
    assert(
      caught!.key == 'jwt_token.error.decryption_failed',
      'Key should identify the decryption failure',
    );
    assert(
      caught!.rootException != null,
      'The underlying failure should be carried as rootException',
    );
    assert(
      corruptTokenReadsWithoutDecryption,
      'decrypt: false should skip the failing step entirely',
    );
  }

  // --------------------------------------------------------------------------
  // Example 2: A custom TomJwtConfiguration
  // --------------------------------------------------------------------------
  static void example2CustomConfiguration() {
    print('\n2. Custom TomJwtConfiguration:');

    final defaultConfig = TomJwtConfiguration.defaultSignConfiguration;
    print('   Default configuration:');
    print('   - isDummy   : ${defaultConfig.isDummy}');
    print('   - algorithm : ${defaultConfig.algorithm.name}');

    // A production configuration carries its own signing secret and declares
    // itself non-dummy, which is what silences the development-keys warning
    // the default configuration prints on every encrypt and decrypt.
    final customConfig = TomJwtConfiguration(
      SecretKey('a-secret-of-our-own'),
      JWTAlgorithm.HS512,
      TomJwtConfiguration.rsaPrivKey,
      TomJwtConfiguration.rsaPubKey,
      false, // not a dummy configuration
    );

    print('   Custom configuration:');
    print('   - isDummy   : ${customConfig.isDummy}');
    print('   - algorithm : ${customConfig.algorithm.name}');

    // Used per token, rather than installed over
    // TomJwtConfiguration.defaultSignConfiguration, so this example leaves no
    // global state behind for its siblings to trip over.
    final signed = TomServerJwtToken(
      {'userId': 'user-custom'},
      encryptedData: {'apiKey': 'k-9'},
      signingConfiguration: customConfig,
    ).getJWT('custom-issuer');

    final parsed = TomClientJwtToken(
      signed,
      signingConfiguration: customConfig,
    );

    print('   - issuer     : ${parsed.issuer}');
    print('   - secretData : ${parsed.secretData}');

    customConfigRoundTrips =
        parsed.issuer == 'custom-issuer' &&
        parsed.secretData?['apiKey'] == 'k-9';

    // Assertions
    assert(defaultConfig.isDummy, 'The shipped default is a development one');
    assert(!customConfig.isDummy, 'A configured one declares itself real');
    assert(
      customConfig.algorithm.name != defaultConfig.algorithm.name,
      'The custom configuration signs with a different algorithm',
    );
    assert(customConfigRoundTrips, 'A custom configuration should round-trip');
  }

  // --------------------------------------------------------------------------
  // Example 3: Token validity windows
  // --------------------------------------------------------------------------
  static void example3ValidityWindows() {
    print('\n3. Token validity windows (notBefore, expiresIn):');

    // Valid immediately, for two hours
    final immediateToken = TomServerJwtToken({
      'userId': 'user-1',
    }, expiresIn: Duration(hours: 2));

    // Valid only after five minutes
    final delayedToken = TomServerJwtToken(
      {'userId': 'user-2'},
      expiresIn: Duration(hours: 24),
      notBefore: Duration(minutes: 5),
    );

    final token1 = TomClientJwtToken(
      immediateToken.getJWT('issuer'),
      decrypt: false,
    );
    final token2 = TomClientJwtToken(
      delayedToken.getJWT('issuer'),
      decrypt: false,
    );

    final validFrom1 = DateTime.parse(token1.payload!['validFrom'] as String);
    final validUntil1 = DateTime.parse(token1.payload!['validUntil'] as String);
    final validFrom2 = DateTime.parse(token2.payload!['validFrom'] as String);

    print('   Immediate token:');
    print('     - validFrom  : $validFrom1');
    print('     - validUntil : $validUntil1');
    print('   Delayed token (notBefore: 5min):');
    print('     - validFrom  : $validFrom2');
    print(
      '     - opens ${validFrom2.difference(validFrom1).inMinutes} minutes later',
    );

    validityWindowWorks =
        validUntil1.difference(validFrom1).inMinutes == 120 &&
        validFrom2.difference(validFrom1).inMinutes == 5;

    // Assertions
    assert(
      validUntil1.difference(validFrom1).inMinutes == 120,
      'expiresIn should be the width of the window',
    );
    assert(
      validFrom2.isAfter(validFrom1),
      'notBefore should push validFrom into the future',
    );
    assert(validityWindowWorks, 'Validity windows should be set');
  }

  // --------------------------------------------------------------------------
  // Example 4: Disabling decryption
  // --------------------------------------------------------------------------
  static void example4DisableDecryption() {
    print('\n4. Disabling decryption with decrypt: false:');

    final serverToken = TomServerJwtToken(
      {'userId': 'user-abc'},
      encryptedData: {'sensitiveData': 'secret-value'},
    );
    final jwt = serverToken.getJWT('issuer');

    // Parsing without decryption needs no private key and skips the RSA work.
    final tokenNoDecrypt = TomClientJwtToken(jwt, decrypt: false);

    print('   - payload["userId"]  : ${tokenNoDecrypt.payload?["userId"]}');
    print(
      '   - carries "encrypted": '
      '${tokenNoDecrypt.payload?.containsKey("encrypted") == true}',
    );
    print('   - secretData         : ${tokenNoDecrypt.secretData}');

    decryptDisabledWorks =
        tokenNoDecrypt.secretData == null &&
        tokenNoDecrypt.payload?.containsKey('encrypted') == true;

    print('   Use decrypt: false when you only need the public claims, when');
    print('   the private key is not on the client, or when the RSA step is');
    print('   more than the request can afford.');

    // Assertions
    assert(
      tokenNoDecrypt.payload?['userId'] == 'user-abc',
      'Public claims are readable without decryption',
    );
    assert(
      tokenNoDecrypt.secretData == null,
      'Nothing is decrypted, so secretData stays null',
    );
    assert(decryptDisabledWorks, 'Decrypt disabled should work');
  }

  // --------------------------------------------------------------------------
  // Example 5: globalSettingShowContentInToString
  // --------------------------------------------------------------------------
  static void example5ToStringSettings() {
    print('\n5. globalSettingShowContentInToString:');

    final serverToken = TomServerJwtToken({'userId': 'user-xyz'});
    final clientToken = TomClientJwtToken(
      serverToken.getJWT('issuer'),
      decrypt: false,
    );

    TomClientJwtToken.globalSettingShowContentInToString = true;
    final withContent = clientToken.toString();

    TomClientJwtToken.globalSettingShowContentInToString = false;
    final withoutContent = clientToken.toString();

    // Restore the default for the examples that follow.
    TomClientJwtToken.globalSettingShowContentInToString = true;

    print('   - with content    : ${withContent.length} chars');
    print('   - without content : ${withoutContent.length} chars');
    print(
      '   - hidden form still names the issuer '
      '${withoutContent.contains('issuer')}, but not the userId '
      '${withoutContent.contains('user-xyz')}',
    );

    // Assertions
    assert(
      withContent.contains('user-xyz'),
      'The default form shows the payload',
    );
    assert(
      !withoutContent.contains('user-xyz'),
      'The hidden form is what makes this safe to log',
    );
    assert(
      withContent.length > withoutContent.length,
      'Hiding content should shorten the result',
    );
  }

  // --------------------------------------------------------------------------
  // Example 6: noIssueAt
  // --------------------------------------------------------------------------
  static void example6NoIssueAt() {
    print('\n6. noIssueAt and the "iat" claim:');

    final withIat = TomServerJwtToken({'data': 'test'}, noIssueAt: false);
    final withoutIat = TomServerJwtToken({'data': 'test'}, noIssueAt: true);

    final parsedWithIat = TomClientJwtToken(
      withIat.getJWT('issuer'),
      decrypt: false,
    );
    final parsedWithoutIat = TomClientJwtToken(
      withoutIat.getJWT('issuer'),
      decrypt: false,
    );

    print('   noIssueAt: false (default)');
    print('     - claims : ${parsedWithIat.payload?.keys.toList()}');
    print('     - iat    : ${parsedWithIat.payload?['iat']}');
    print('   noIssueAt: true');
    print('     - claims : ${parsedWithoutIat.payload?.keys.toList()}');
    print('     - iat    : ${parsedWithoutIat.payload?['iat']}');

    iatOmitted = parsedWithoutIat.payload?.containsKey('iat') == false;

    // Assertions
    assert(
      parsedWithIat.payload?['iat'] != null,
      'The default should stamp the token with its issue time',
    );
    assert(iatOmitted, 'noIssueAt: true should omit the claim entirely');
    assert(
      parsedWithoutIat.payload?['exp'] != null,
      'Only "iat" is dropped — the expiry claim survives',
    );
  }

  // --------------------------------------------------------------------------
  // Example 7: The claims a parsed token carries
  // --------------------------------------------------------------------------
  static void example7TokenClaims() {
    print('\n7. TomClientJwtToken claims:');

    final serverToken = TomServerJwtToken(
      {'userId': 'user-123'},
      encryptedData: {'key': 'value'},
    );
    final clientToken = TomClientJwtToken(serverToken.getJWT('my-issuer'));

    // The decoded token and its audience are readable as their own types,
    // not just as `var` — both are part of the exported surface.
    final JWT decoded = clientToken.token;
    final Audience? audience = clientToken.audience;

    print('   - issuer      : ${clientToken.issuer}');
    print('   - subject     : ${clientToken.subject}');
    print('   - jwtId       : ${clientToken.jwtId}');
    print('   - audience    : $audience');
    print('   - payload     : ${clientToken.payload?.keys.toList()}');
    print('   - secretData  : ${clientToken.secretData?.keys.toList()}');
    print('   - tokenString : ${clientToken.tokenString.length} chars');
    print('   - token       : ${decoded.runtimeType}');

    // Assertions
    assert(clientToken.issuer == 'my-issuer', 'The issuer is the "iss" claim');
    assert(
      decoded.issuer == clientToken.issuer,
      'The wrapper reads its claims off the decoded token',
    );
    assert(audience == null, 'No audience was set, so the claim is absent');
    assert(
      clientToken.secretData?['key'] == 'value',
      'Encrypted data is decrypted by default',
    );
    assert(
      clientToken.tokenString.split('.').length == 3,
      'A JWT is header.payload.signature',
    );
  }

  // --------------------------------------------------------------------------
  // Example 8: What the encryption actually buys
  // --------------------------------------------------------------------------
  static void example8EncryptionConfidentiality() {
    print('\n8. Public claims travel in the clear, encrypted ones do not:');

    print('''
   ┌─────────────────────────────────────────────────────────────┐
   │                    SERVER SIDE                              │
   │  TomServerJwtToken                                          │
   │  ┌─────────────────┐    ┌─────────────────────────────────┐ │
   │  │   publicData    │───►│ Visible in JWT payload          │ │
   │  │   {userId: 123} │    │                                 │ │
   │  └─────────────────┘    │                                 │ │
   │  ┌─────────────────┐    │  JWT Token                      │ │
   │  │ encryptedData   │───►│  header.payload.signature       │ │
   │  │ {secret: xyz}   │RSA │  └─ encrypted: "aB3x..."        │ │
   │  └─────────────────┘    └─────────────────────────────────┘ │
   └─────────────────────────────────────────────────────────────┘
                                │
                                ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                    CLIENT SIDE                              │
   │  TomClientJwtToken                                          │
   │  ┌─────────────────────────────────────────────────────────┐│
   │  │ payload: {userId: 123, encrypted: "aB3x..."}            ││
   │  └───────────────────────────────┬─────────────────────────┘│
   │  ┌─────────────────┐             │ RSA Decrypt              │
   │  │    payload      │◄────────────┤                          │
   │  │  {userId: 123}  │             │                          │
   │  └─────────────────┘             │                          │
   │  ┌─────────────────┐             │                          │
   │  │   secretData    │◄────────────┘                          │
   │  │  {secret: xyz}  │                                        │
   │  └─────────────────┘                                        │
   └─────────────────────────────────────────────────────────────┘''');

    // A JWT is signed, not sealed: anyone holding the string can base64-decode
    // the payload. That is the whole reason encryptedData exists, and it is
    // the one claim above worth checking rather than trusting.
    const publicClaim = 'user-123';
    const secretClaim = 'super-secret-value';

    final jwt = TomServerJwtToken(
      {'userId': publicClaim},
      encryptedData: {'apiKey': secretClaim},
    ).getJWT('issuer');

    // Read the payload the way an eavesdropper would: no keys, no library.
    final rawPayload = utf8.decode(
      base64Url.decode(base64Url.normalize(jwt.split('.')[1])),
    );

    final publicIsReadable = rawPayload.contains(publicClaim);
    final secretIsUnreadable = !rawPayload.contains(secretClaim);

    print('');
    print('   Decoding the payload segment with no key at all:');
    print('   - the public claim is there   : $publicIsReadable');
    print('   - the encrypted one is not    : $secretIsUnreadable');

    // ...and the holder of the private key gets it back.
    final recovered = TomClientJwtToken(jwt).secretData?['apiKey'] as String?;
    print('   - recovered with the key      : $recovered');

    secretStaysConfidential =
        publicIsReadable && secretIsUnreadable && recovered == secretClaim;

    // Assertions
    assert(publicIsReadable, 'publicData is not hidden and is not meant to be');
    assert(
      secretIsUnreadable,
      'encryptedData must not appear in the payload in the clear',
    );
    assert(recovered == secretClaim, 'The key holder still recovers it');
    assert(secretStaysConfidential, 'Encryption should keep secrets secret');
  }

  // --------------------------------------------------------------------------
  // Example 9: Checking expiry on the client
  // --------------------------------------------------------------------------
  static void example9ClientSideExpiry() {
    print('\n9. Checking validity on the client:');

    // `validUntil` is Tom's own ISO-8601 claim, next to the standard numeric
    // `exp`. It is a string a client can parse without a JWT library.
    final live = TomClientJwtToken(
      TomServerJwtToken({
        'userId': 'u',
      }, expiresIn: Duration(hours: 2)).getJWT('issuer'),
      decrypt: false,
    );
    final stale = TomClientJwtToken(
      TomServerJwtToken({
        'userId': 'u',
      }, expiresIn: Duration(seconds: -30)).getJWT('issuer'),
      decrypt: false,
    );

    bool hasExpired(TomClientJwtToken token) {
      final validUntil = token.payload?['validUntil'] as String?;
      if (validUntil == null) return false;
      return DateTime.now().isAfter(DateTime.parse(validUntil));
    }

    print('   - two-hour token has expired    : ${hasExpired(live)}');
    print('   - back-dated token has expired  : ${hasExpired(stale)}');

    expiryDetected = !hasExpired(live) && hasExpired(stale);

    // Assertions
    assert(!hasExpired(live), 'A token good for two hours is not expired');
    assert(hasExpired(stale), 'A token back-dated by 30s is expired');
    assert(expiryDetected, 'Client-side expiry checking should work');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('=== 06: Advanced JWT Token Example ===\n');

  AdvancedJwtExample.example1DecryptionException();
  AdvancedJwtExample.example2CustomConfiguration();
  AdvancedJwtExample.example3ValidityWindows();
  AdvancedJwtExample.example4DisableDecryption();
  AdvancedJwtExample.example5ToStringSettings();
  AdvancedJwtExample.example6NoIssueAt();
  AdvancedJwtExample.example7TokenClaims();
  AdvancedJwtExample.example8EncryptionConfidentiality();
  AdvancedJwtExample.example9ClientSideExpiry();

  // Final assertions
  assert(
    AdvancedJwtExample.exceptionKey == 'jwt_token.error.decryption_failed',
    'A corrupt token should raise TomJwtTokenException',
  );
  assert(
    AdvancedJwtExample.rootExceptionType != null,
    'The cause should be carried on the exception',
  );
  assert(
    AdvancedJwtExample.corruptTokenReadsWithoutDecryption,
    'decrypt: false should skip the failing step',
  );
  assert(
    AdvancedJwtExample.customConfigRoundTrips,
    'A custom configuration should round-trip',
  );
  assert(
    AdvancedJwtExample.validityWindowWorks,
    'Validity windows should work',
  );
  assert(
    AdvancedJwtExample.decryptDisabledWorks,
    'Decrypt disabled should work',
  );
  assert(AdvancedJwtExample.iatOmitted, 'noIssueAt should omit "iat"');
  assert(
    AdvancedJwtExample.secretStaysConfidential,
    'Encrypted data should not travel in the clear',
  );
  assert(AdvancedJwtExample.expiryDetected, 'Expiry should be detectable');

  print('\n✓ All advanced JWT examples passed!\n');
}

void main() {
  prepareSampleProcess();
  run();
}
