/// The committed clients are what the generator writes from the committed
/// documents, so neither can drift from the servers they call.
///
/// The documents themselves are held to the endpoint annotations by each
/// server's own `openapi_document_test.dart`; this closes the second link of
/// the chain, document → client.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_openapi/tom_core_openapi.dart';

void main() {
  for (final (document, client, name) in [
    (
      '../advanced_app_server/openapi/openapi.json',
      'lib/app_api.dart',
      'AppApi',
    ),
    (
      '../advanced_auth_server/openapi/openapi.json',
      'lib/auth_api.dart',
      'AuthApi',
    ),
  ]) {
    test('$client is what $document generates', () async {
      final generated =
          TomOpenApiDartClientGenerator(
            clientName: name,
            regenerateCommand:
                'dart run tom_core_openapi:openapi :dart-client --input $document '
                '--output $client --client-name $name',
          ).generate(
            jsonDecode(File(document).readAsStringSync())
                as Map<String, Object?>,
          );
      expect(
        File(client).readAsStringSync(),
        await formatDartSource(generated),
        reason:
            'regenerate with: dart run tom_core_openapi:openapi :dart-client '
            '--input $document --output $client --client-name $name',
      );
    });
  }
}
