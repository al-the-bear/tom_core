/// The preference *contract* — the keys, the wire DTOs and the [TomApi] that a
/// client and a server both bind to.
///
/// The store itself is server-side (a table, a repository, a row scope), and
/// none of it appears here. What appears here is the part the two halves must
/// agree on, which is why it lives in the one package they both depend on.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXAMPLE 1: The framework's well-known keys
// =============================================================================

class PreferenceKeysExample {
  static String timezoneKey = '';
  static String languageKey = '';
  static bool allNamespaced = false;

  static void example1PreferenceKeys() {
    // A key is just a string — which is exactly why the ones the framework
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
// EXAMPLE 2: The wire DTOs
// =============================================================================

class PreferenceDtoExample {
  static String dtoKey = '';
  static String dtoType = '';
  static bool writeRequestHasNoTimestamp = false;

  static void example2PreferenceDtos() {
    final dto = TomUserPreferenceDto(
      key: TomUserPreferenceKeys.timezone,
      valueType: TomUserPreferenceCodec.stringType,
      value: '"Europe/Berlin"',
      updatedAt: DateTime.utc(2026, 3, 4, 5, 6, 7),
    );

    dtoKey = dto.key;
    dtoType = dto.valueType;

    // The write request is the result minus the timestamp: *when* a preference
    // was written is the server's answer, never the client's claim. There is
    // no field on the request to disagree with the server about.
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
// EXAMPLE 3: Building a write request from a value
// =============================================================================

class BuildWriteRequestExample {
  static String requestType = '';
  static String requestJson = '';

  static void example3BuildWriteRequest() {
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
// EXAMPLE 4: The API declaration
// =============================================================================

class PreferencesApiExample {
  static String baseUri = '';
  static int endpointCount = 0;
  static String readUri = '';
  static bool everyEndpointAuthenticated = false;
  static bool noPrincipalInAnyUri = false;

  static void example4PreferencesApi() {
    final api = tomUserPreferencesApi;

    baseUri = api.uri ?? '';
    endpointCount = api.endpoints.length;
    readUri = api[tomUserPreferencesReadEndpointId].uri ?? '';

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
    assert(everyEndpointAuthenticated, 'Every endpoint requires a principal');
    assert(noPrincipalInAnyUri, 'No endpoint takes a principal parameter');
  }
}

// =============================================================================
// EXAMPLE 5: Registering the API
// =============================================================================

class RegisterApiExample {
  static bool registered = false;
  static bool idempotent = false;

  static void example5RegisterApi() {
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
  PreferenceKeysExample.example1PreferenceKeys();
  PreferenceDtoExample.example2PreferenceDtos();
  BuildWriteRequestExample.example3BuildWriteRequest();
  PreferencesApiExample.example4PreferencesApi();
  RegisterApiExample.example5RegisterApi();
}

void main() => run();
