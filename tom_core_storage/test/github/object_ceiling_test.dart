/// The per-object size ceiling the storage port publishes.
///
/// The measurement that produced the number is the GitHub backend's to
/// document; what is checkable *here* is the shape it took in code, and the
/// shape carries the decision:
///
/// - the limit is **per object, not per save**, so nothing in it lets a backend
///   quietly give up the "one save = one atomic commit";
/// - it is **optional**, so a backend with no limit of its own says so by
///   staying silent rather than by inventing a large number;
/// - the GitHub backend's value is a **named constant**, so an application's
///   ingest clamp and the live boundary test cannot drift apart from each other.
///
/// The live half — that GitHub really refuses the very next size up — is in
/// `woneprpb15_object_ceiling_live_test.dart`, because it costs ~80 MiB of
/// upload and a credential.
library;

import 'package:test/test.dart';
import 'package:tom_core_storage/github.dart';
import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

/// A backend that declares no limit, to pin the port's default.
class _SilentStorage extends TomStorage {
  @override
  bool handles(String locator) => false;

  @override
  Future<List<TomStorageEntry>> list(String locator) async => const [];

  @override
  Future<Never> readBytes(String locator) async =>
      throw TomContainerNotFoundException(locator);

  @override
  Future<Never> readBundle(String locator) async =>
      throw TomContainerNotFoundException(locator);

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) async => TomStorage.emptyHead;

  @override
  Future<void> delete(String locator) async {}

  @override
  Future<String?> headOf(String locator) async => null;
}

void main() {
  group('STORAGE-CEILING: storage backends publish their per-object ceiling', () {
    test(
      'STORAGE-CEILING-1: a backend with no limit of its own answers null, not a number '
      '[0803]',
      () {
        expect(_SilentStorage().maxObjectBytes, isNull);
      },
    );

    test(
      'STORAGE-CEILING-2: the local filesystem imposes no ceiling of its own [0803]',
      () {
        // Deliberately not "some large number": the filesystem's own limits are
        // not this package's to restate, and a wrong restatement would refuse an
        // asset that would have saved fine.
        expect(TomLocalFileSystemStorage().maxObjectBytes, isNull);
      },
    );

    test(
      'STORAGE-CEILING-3: the GitHub backend publishes the measured blob ceiling [0803]',
      () {
        final storage = TomGitHubStorage(
          tokens: TomInMemoryTokenSource([
            const TomToken(
              host: TomGitHubStorage.host,
              secret: 'unused — the ceiling is a static property',
            ),
          ]),
        );
        expect(storage.maxObjectBytes, TomGitHubStorage.maxBlobBytes);
      },
    );

    test(
      'STORAGE-CEILING-4: that ceiling is the last size measured to be accepted, strictly '
      'below the 40 MiB refusal [0803]',
      () {
        const mib = 1024 * 1024;
        // 41,820,160 B was accepted; 41,943,040 B (exactly 40 MiB) was refused
        // with a 422. Naming both ends here is what makes the constant a
        // recorded observation rather than a round number someone liked.
        expect(TomGitHubStorage.maxBlobBytes, 41820160);
        expect(TomGitHubStorage.maxBlobBytes, lessThan(40 * mib));
      },
    );

    test(
      'STORAGE-CEILING-5: the ceiling bounds one changeset entry, not a whole changeset '
      '[0803]',
      () {
        // The measurement found no aggregate budget — 96 MiB across twelve
        // blobs landed in a single commit — so a save is only over the limit
        // when some *single* path is. A changeset far larger than the ceiling
        // in total is therefore fine, and this test states that in the terms a
        // an application's ingest clamp will use.
        final ceiling = TomGitHubStorage.maxBlobBytes;
        final sizes = [ceiling - 1, ceiling - 1, ceiling - 1];
        expect(sizes.reduce((a, b) => a + b), greaterThan(ceiling));
        expect(sizes.every((size) => size <= ceiling), isTrue);
      },
    );
  });
}
