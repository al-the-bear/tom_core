/// Executable example for the file-storage module of `tom_core_server`.
///
/// Demonstrates the whole capability without a database, a bucket or a
/// credential: the one streaming contract every backend implements, the key
/// grammar that makes a key safe to hand to any of them, the two backends that
/// need no infrastructure, the registry that selects one from configuration,
/// the key scheme a `@TomFileReference` column generates, and the export
/// module riding on the same API.
///
/// The thing to watch for is what is *absent*: at no point is a whole file
/// held. Step 3 proves it — a payload larger than any buffer here arrives as a
/// sequence of chunks, and the count of them is the assertion.
///
/// The two backends this example does *not* run are the ones that need
/// something to run against: [TomDatabaseBlobStore] needs a data source (see
/// `test/file_storage_db_test.dart`) and [TomS3BlobStore] needs a bucket. Both
/// are the same four methods; that is the point of the abstraction.
///
/// Run with `dart run example/file_storage/file_storage_example.dart`.
/// The same behaviour is covered by `test/file_storage_test.dart`,
/// `test/file_reference_test.dart` and `test/file_storage_db_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:yaml/yaml.dart';

// ignore_for_file: avoid_print

/// A payload of [count] bytes, delivered in 64 KiB events — a stand-in for a
/// socket or a file read, neither of which hands over the whole thing at once.
Stream<List<int>> payload(int count) async* {
  const eventSize = 64 * 1024;
  var sent = 0;
  while (sent < count) {
    final take = (count - sent).clamp(0, eventSize);
    yield List<int>.filled(take, 0x41);
    sent += take;
  }
}

Future<void> run(Directory workDir) async {
  // 1. One contract, four methods. Everything below is an implementation of
  //    it, and nothing that consumes storage knows which one it has.
  final memory = TomMemoryBlobStore();
  final stored = await memory.put(
    key: 'notes/2026/07/welcome.txt',
    bytes: Stream.value(utf8.encode('hello storage')),
    mediaType: 'text/plain',
    fileName: 'welcome.txt',
  );
  print('1.  stored                  : ${stored.key} '
      '(${stored.byteCount} bytes, ${stored.mediaType})');

  // 2. A key is a name in someone else's namespace — an S3 object name, a path
  //    under a directory, a row in a table. The grammar is therefore narrow
  //    enough to be safe in all of them, and checked before the key is used
  //    rather than after.
  print('2.  "a/b/c-1_2.txt" valid   : '
      '${TomBlobStore.isValidKey('a/b/c-1_2.txt')}');
  print('    "../../etc/passwd" valid: '
      '${TomBlobStore.isValidKey('../../etc/passwd')}');
  try {
    await memory.put(key: '../escape', bytes: Stream.value(const [1]));
  } on TomStorageException catch (e) {
    print('    rejected as             : ${e.key}');
  }

  // 3. Streaming is the reason this module exists. A 512 KiB blob comes back
  //    as several events, so a consumer — an HTTP response, a renderer — can
  //    forward each one and never hold the file.
  final directory = TomDirectoryBlobStore(Directory('${workDir.path}/blobs'));
  await directory.put(key: 'big/sample.bin', bytes: payload(512 * 1024));
  var events = 0;
  var bytes = 0;
  await for (final chunk in directory.get('big/sample.bin')) {
    events++;
    bytes += chunk.length;
  }
  print('3.  512 KiB read back in    : $events chunks ($bytes bytes)');

  // 4. The directory backend writes to a temporary name and renames, so a
  //    reader never sees a half-written file, and keeps a sidecar for the
  //    metadata a filesystem cannot hold (media type, original name).
  final described = await directory.describe('big/sample.bin');
  print('4.  described               : ${described!.mediaType}, '
      '${described.byteCount} bytes, at ${described.location}');

  // 5. Backends are selected from configuration, not from code — the same
  //    mechanism the data sources use, so a deployment changes where its files
  //    live by editing YAML.
  final config = loadYaml('''
files:
  type: directory
  default: true
  root: ${workDir.path}/configured
archive:
  type: memory
''') as YamlMap;
  await TomBlobStoreInfo.initializeBlobStores(Map<String, dynamic>.from(config));
  print('5.  configured stores       : ${TomBlobStoreInfo.stores.keys.toList()}'
      ' (default "${TomBlobStoreInfo.defaultStoreName}")');

  // 6. An application with a backend of its own registers a factory under a
  //    name; from then on it is spelled in configuration like any built-in.
  TomBlobStoreInfo.registerBackend('memory-plus', (name, settings) => memory);
  print('6.  known backends          : ${TomBlobStoreInfo.backendTypes.toList()}');

  // 7. A misconfigured store name is a named error at the point of use, not a
  //    write to the wrong place.
  try {
    TomBlobStoreInfo.storeNamed('nosuchstore');
  } on TomStorageException catch (e) {
    print('7.  unknown store           : ${e.key}');
  }

  // 8. A `@TomFileReference` column holds a *key*, and the key is generated —
  //    never taken from the client. The prefix comes from the annotation, the
  //    year/month makes a retention rule expressible, and the UUID makes the
  //    key unguessable and collision-free.
  const reference = TomFileReference(keyPrefix: 'invoices/pdf');
  final key = TomFileReferenceKeys.generate(
    reference,
    fileName: 'Invoice 2026-07.pdf',
  );
  print('8.  generated key           : $key');

  // 9. Which matters because the "file name" is caller-supplied text. Only a
  //    short alphanumeric suffix survives into the key; everything else is
  //    dropped rather than escaped.
  print('9.  extension of a hostile  : '
      '"${TomFileReferenceKeys.extensionOf('../etc/passwd')}" '
      '(plain: "${TomFileReferenceKeys.extensionOf('report.PDF')}")');

  // 10. The export module stores through the same API, so an export can be
  //     written to a database, a bucket or an application's own store without
  //     the export module knowing any of them exist.
  final exports = TomBlobExportStore(memory, keyPrefix: 'exports');
  final export = await exports.store(
    key: 'sales.csv',
    bytes: Stream.value(utf8.encode('product,amount\nWidget,19.5\n')),
    mediaType: 'text/csv',
  );
  //     The recorded key is the caller's; the prefix is the store's business,
  //     and an export whose key could not be passed back to `open` would be a
  //     trap. What the blob store actually holds shows the difference.
  print('10. export stored as        : ${export.key} '
      '(${export.byteCount} bytes)');
  print('    blob store holds        : ${memory.keys.toList()}');

  // 11. Deleting reports whether there was anything to delete, so a cascade
  //     can tell "removed" from "already gone" without a second round trip.
  print('11. delete existing         : ${await exports.delete(export.key)}');
  print('    delete again            : ${await exports.delete(export.key)}');

  await TomBlobStoreInfo.closeAll();
}

Future<void> main() async {
  // A directory the run cleans up: an example must not leave files behind.
  final workDir = await Directory.systemTemp.createTemp('tom_file_storage_');
  try {
    await run(workDir);
  } finally {
    await workDir.delete(recursive: true);
  }
}
