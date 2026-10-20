/// An upload the retry policy re-sends is reported once.
///
/// The report naming an object is emitted before the request that uploads it,
/// and the retry happens inside that request. So a refusal the policy waits
/// out and re-sends must leave the reports as they would have been: one per
/// object, the counts unchanged. The live suite cannot show this without
/// earning a refusal from the real service on purpose; here the fake refuses
/// exactly the upload the report has just named.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/github.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_github_api/tom_github_api.dart';

import 'package:tom_github_api/testing.dart';

const locator = 'github:al-the-bear/docs/bundle.webwork';

void main() {
  for (final refusal in {
    'a server error': serverError,
    'a secondary rate limit': () =>
        secondaryRateLimited(retryAfter: const Duration(seconds: 1)),
  }.entries) {
    test(
      'STORAGE-PROGRESS-R: the second object\'s upload meets ${refusal.key}, is '
      're-sent, and is reported once [0930]',
      () async {
        final server = FakeGitHubServer();
        server.repo('al-the-bear/docs');
        final waited = <Duration>[];
        final storage = TomGitHubStorage.withClient(
          GitHubApiClient(
            token: 'test-token',
            httpClient: server.client,
            baseUrl: FakeGitHubServer.baseUrl,
            minMutativeInterval: Duration.zero,
            retryPolicy: GitHubRetryPolicy(
              sleep: (wait) async => waited.add(wait),
            ),
          ),
        );
        addTearDown(storage.close);

        final seen = <TomCommitProgress>[];
        await storage.commit(
          locator,
          TomChangeset(
            writes: {
              'one.bin': Uint8List(10),
              'two.bin': Uint8List(20),
              'three.bin': Uint8List(30),
            },
          ),
          onProgress: (progress) {
            seen.add(progress);
            // The next request is the upload of the object just named.
            if (progress.currentPath == 'two.bin') {
              server.canned.add(refusal.value());
            }
          },
        );

        expect(
          waited,
          hasLength(1),
          reason: 'the refusal was met, waited out and the upload re-sent',
        );
        // The fake logs what it serves and not what it refuses, so three
        // uploads served is three objects stored, the second at its re-send.
        final served = server.requestLog
            .where((r) => r.startsWith('POST') && r.contains('/git/blobs'))
            .length;
        expect(served, 3);

        expect(
          [for (final p in seen) p.currentPath],
          ['one.bin', 'two.bin', 'three.bin', null],
        );
        expect([for (final p in seen) p.objectsCompleted], [0, 1, 2, 3]);
        expect([for (final p in seen) p.bytesCompleted], [0, 10, 30, 60]);
      },
    );
  }
}
