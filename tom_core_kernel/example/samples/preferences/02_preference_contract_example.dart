/// The preference *contract* — the keys, the wire DTOs and the [TomApi] that a
/// client and a server both bind to.
///
/// The store itself is server-side (a table, a repository, a row scope), and
/// none of it appears here. What appears here is the part the two halves must
/// agree on, which is why it lives in the one package they both depend on.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: The framework's well-known keys
// =============================================================================

class PreferenceKeysExample {
  static String timezoneKey = '';
  static String languageKey = '';
  static bool allNamespaced = false;

  static void example1PreferenceKeys() {
    // A key's *text* is the contract, which is why the ones the framework
    // itself reads are declared once. A client writing "timezone" against a
    // server reading "timeZone" fails silently: the reader finds nothing and
    // falls back, forever.
    timezoneKey = TomUserPreferenceKeys.timezone;
    languageKey = TomUserPreferenceKeys.language;

    allNamespaced = [
      TomUserPreferenceKeys.timezone,
      TomUserPreferenceKeys.language,
      TomUserPreferenceKeys.country,
      TomUserPreferenceKeys.theme,
    ].every((key) => key.startsWith('tom.'));

    assert(timezoneKey == 'tom.timezone', 'The timezone key is stable text');
    assert(languageKey == 'tom.language', 'The language key is stable text');
    assert(allNamespaced, 'Framework keys are namespaced so apps can coexist');
  }
}

// =============================================================================
// EXAMPLE 2: What an application's own key may be
// =============================================================================

class PreferenceKeyRuleExample {
  static bool appKeyAccepted = false;
  static List<String> refusedCauses = <String>[];
  static int capEqualsColumnWidth = 0;

  static void example2PreferenceKeyRule() {
    // An application names its own keys, but not freely: a key is a URL path
    // segment on the way to the server and a unique-key column once it lands.
    // The rule is 1..maxLength characters, starting with an ASCII letter, then
    // letters, digits, '.', '_' and '-'.
    appKeyAccepted = TomUserPreferenceKeys.isValid('shop.cart.last_currency');

    // `isValid` is for deciding something — offering a name, filtering a list.
    // `validate` is for asserting it, and names the reason it refused.
    for (final key in <String>['', '1st', 'a/b', 'a' * 500]) {
      try {
        TomUserPreferenceKeys.validate(key);
      } on TomUserPreferenceKeyException catch (error) {
        refusedCauses.add(error.parameters!['cause']! as String);
      }
    }

    // The two least obvious clauses each buy something concrete. Requiring a
    // leading letter is what makes '.' and '..' illegal: both resolve away
    // from the preference they name — '.' onto the *list* endpoint's URI and
    // '..' out of the API's path altogether — and one rule handles them
    // instead of two special cases. Restricting to ASCII is about identity
    // rather than transport: 'ü' has a composed and a decomposed form that
    // render identically and compare unequal, so one visible key would be two
    // stored keys.
    capEqualsColumnWidth = TomUserPreferenceKeys.maxLength;

    assert(appKeyAccepted, 'A namespaced application key is a legal key');
    assert(
      refusedCauses.join(',') ==
              'empty,leading_character,'
                  'illegal_character,too_long' &&
          refusedCauses.length == 4,
      'The refusal names the reason, so a caller can branch on it',
    );
    assert(capEqualsColumnWidth == 191, "The cap is the column's own width");
  }
}

// =============================================================================
// EXAMPLE 3: The wire DTOs
// =============================================================================

class PreferenceDtoExample {
  static String dtoKey = '';
  static String dtoType = '';
  static String dtoValue = '';
  static DateTime? dtoUpdatedAt;
  static bool writeRequestHasNoTimestamp = false;

  static void example3PreferenceDtos() {
    final dto = TomUserPreferenceDto(
      key: TomUserPreferenceKeys.timezone,
      valueType: TomUserPreferenceCodec.stringType,
      value: '"Europe/Berlin"',
      updatedAt: DateTime.utc(2026, 3, 4, 5, 6, 7),
    );

    dtoKey = dto.key;
    dtoType = dto.valueType;
    dtoValue = dto.value;
    dtoUpdatedAt = dto.updatedAt;

    // The write request is the result minus the timestamp: *when* a preference
    // was written is the server's answer, never the client's claim. There is
    // no timestamp field on the request to disagree with the server about.
    final write = TomUserPreferenceWriteRequest(
      key: TomUserPreferenceKeys.timezone,
      valueType: TomUserPreferenceCodec.stringType,
      value: '"Europe/Berlin"',
    );
    writeRequestHasNoTimestamp =
        write.key == dto.key && write.valueType == dto.valueType;

    assert(dtoKey == 'tom.timezone', 'The DTO carries its key');
    assert(dtoType == 'String', 'The DTO carries the stored type name');
    assert(dto.updatedAt!.isUtc, 'A wire timestamp is UTC');
    assert(writeRequestHasNoTimestamp, 'The write request mirrors the result');
  }
}

// =============================================================================
// EXAMPLE 4: Building a write request from a value
// =============================================================================

class BuildWriteRequestExample {
  static String requestType = '';
  static String requestJson = '';

  static void example4BuildWriteRequest() {
    // A client encodes once, with the same codec the server decodes with, and
    // hands the pair over as text. Two encoders that disagreed by one
    // convention would store successfully and read wrongly.
    //
    // `typeNameOf` is given the key too: for anything that is not a scalar it
    // asks the reflection registry for the name, and refuses a class the
    // registry does not know rather than inventing one — so it can throw, and
    // the exception should say which preference it was about.
    const value = 'Europe/Berlin';
    final request = TomUserPreferenceWriteRequest(
      key: TomUserPreferenceKeys.timezone,
      valueType: TomUserPreferenceCodec.typeNameOf(
        value,
        TomUserPreferenceKeys.timezone,
      ),
      value: TomUserPreferenceCodec.encodeValue(
        value,
        TomUserPreferenceKeys.timezone,
      ),
    );

    requestType = request.valueType;
    requestJson = request.value;

    // The server validates the pair before storing it; a client can run the
    // very same check locally and fail early.
    TomUserPreferenceCodec.validateEncoded(
      request.valueType,
      request.value,
      key: request.key,
    );

    assert(requestType == 'String', 'The declared type comes from the value');
    assert(requestJson == '"Europe/Berlin"', 'The value travels as JSON text');
  }
}

// =============================================================================
// EXAMPLE 5: The API declaration
// =============================================================================

class PreferencesApiExample {
  static String baseUri = '';
  static int endpointCount = 0;
  static String readUri = '';
  static String writeUri = '';
  static bool everyEndpointAuthenticated = false;
  static bool noPrincipalInAnyUri = false;

  static void example5PreferencesApi() {
    final api = tomUserPreferencesApi;

    baseUri = api.uri ?? '';
    endpointCount = api.endpoints.length;
    readUri = api[tomUserPreferencesReadEndpointId].uri ?? '';

    // The write is the exception, and deliberately: its request already has a
    // `key` field, so capturing the key from the path as well would let one
    // request name two preferences with no rule saying which is written. It is
    // a PUT at the collection, and the body is the single statement of the key.
    writeUri = api[tomUserPreferencesWriteEndpointId].uri ?? '';

    // There is no anonymous preference — a preference is per principal, and an
    // anonymous caller is not one. That is the only policy the *contract* can
    // state.
    everyEndpointAuthenticated = api.endpoints.values.every(
      (endpoint) => endpoint.access is TomAuthenticatedAccess,
    );

    // *Which* rows a caller reaches is not an endpoint-level question: the
    // server's entity declares a row scope on the principal column, so there is
    // nothing to ask for but your own — and hence no principal in any URI.
    noPrincipalInAnyUri = api.endpoints.values.every(
      (endpoint) => !(endpoint.uri ?? '').contains('principal'),
    );

    assert(baseUri == '/preferences', 'The API is mounted at /preferences');
    assert(endpointCount == 4, 'List, read, write and delete');
    assert(readUri == '/{key}', 'A preference is addressed by its key');
    assert(writeUri == '', 'A write states its key in the body only');
    assert(everyEndpointAuthenticated, 'Every endpoint requires a principal');
    assert(noPrincipalInAnyUri, 'No endpoint takes a principal parameter');
  }
}

// =============================================================================
// EXAMPLE 6: Registering the API
// =============================================================================

class RegisterApiExample {
  static bool registered = false;
  static bool idempotent = false;

  static void example6RegisterApi() {
    // Explicit rather than implicit in a top-level initializer: a deployment
    // that stores no preferences should not carry the API in its registry.
    registerTomUserPreferencesApi();
    registered = tomRemoteApis.apis.containsKey(tomUserPreferencesApiId);

    // Keyed by API id, so calling it again costs nothing — which is what lets
    // both halves call it without coordinating.
    final countAfterFirst = tomRemoteApis.apis.length;
    registerTomUserPreferencesApi();
    idempotent = tomRemoteApis.apis.length == countAfterFirst;

    assert(registered, 'The API is in the registry');
    assert(idempotent, 'Registering twice registers once');
    assert(
      identical(tomRemoteApis[tomUserPreferencesApiId], tomUserPreferencesApi),
      'The registry holds the contract itself',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

/// Runs every contract example in this file.
void run() {
  print('=== 02: Preference Contract Example ===\n');

  PreferenceKeysExample.example1PreferenceKeys();
  print('1. The keys the framework itself reads are declared once:');
  print('   timezone key : ${PreferenceKeysExample.timezoneKey}');
  print('   language key : ${PreferenceKeysExample.languageKey}');
  print(
    '   every framework key is namespaced "tom.": '
    '${PreferenceKeysExample.allNamespaced}',
  );
  print('');

  PreferenceKeyRuleExample.example2PreferenceKeyRule();
  print('2. What an application may name its own key:');
  print(
    '   "shop.cart.last_currency" accepted: '
    '${PreferenceKeyRuleExample.appKeyAccepted}',
  );
  print(
    '   refusals for "", "1st", "a/b", "aaa…": '
    '${PreferenceKeyRuleExample.refusedCauses}',
  );
  print(
    '   maximum key length (the column width): '
    '${PreferenceKeyRuleExample.capEqualsColumnWidth}',
  );
  print('');

  PreferenceDtoExample.example3PreferenceDtos();
  print('3. The DTO the wire carries:');
  print('   key        : ${PreferenceDtoExample.dtoKey}');
  print('   value type : ${PreferenceDtoExample.dtoType}');
  print('   value      : ${PreferenceDtoExample.dtoValue}');
  print('   updatedAt  : ${PreferenceDtoExample.dtoUpdatedAt}');
  print(
    '   the write request mirrors it, minus the timestamp: '
    '${PreferenceDtoExample.writeRequestHasNoTimestamp}',
  );
  print('');

  BuildWriteRequestExample.example4BuildWriteRequest();
  print('4. A write request built from a value, with the shared codec:');
  print('   declared type : ${BuildWriteRequestExample.requestType}');
  print('   value as JSON : ${BuildWriteRequestExample.requestJson}');
  print('');

  PreferencesApiExample.example5PreferencesApi();
  print('5. The API both halves bind to:');
  print('   base URI       : ${PreferencesApiExample.baseUri}');
  print('   endpoint count : ${PreferencesApiExample.endpointCount}');
  print('   read URI       : ${PreferencesApiExample.readUri}');
  print(
    '   write URI      : "${PreferencesApiExample.writeUri}" '
    '(the key is stated in the body)',
  );
  print(
    '   every endpoint requires a principal: '
    '${PreferencesApiExample.everyEndpointAuthenticated}',
  );
  print(
    '   no endpoint takes a principal parameter: '
    '${PreferencesApiExample.noPrincipalInAnyUri}',
  );
  print('');

  RegisterApiExample.example6RegisterApi();
  print('6. Registering the API, explicitly and idempotently:');
  print(
    '   in the registry after registering : '
    '${RegisterApiExample.registered}',
  );
  print(
    '   registering twice registers once  : '
    '${RegisterApiExample.idempotent}',
  );
  print('');
}

void main() {
  requireAsserts();
  run();
}
