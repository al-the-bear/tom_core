/// An in-memory S3 object server, answering the requests [TomS3BlobStore]
/// makes through an injected [MockClient].
///
/// It keeps objects rather than asserting requests, so a suite can run the S3
/// backend through the same behavioural checks as the directory backend: a
/// single `PUT`, `CopyObject` (with `REPLACE` metadata), `GET` with an
/// optional range, `HEAD` and `DELETE`. Multipart uploads and listings are not
/// served; the suites using it keep to blobs below a part.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// One stored object.
class FakeS3Object {
  FakeS3Object(this.bytes, this.metadata);

  /// The content.
  final Uint8List bytes;

  /// `content-type` and the `x-amz-meta-*` headers it was written with.
  final Map<String, String> metadata;
}

/// The bucket's objects and the client that reaches them.
class FakeS3Server {
  /// The bucket every request addresses.
  static const String bucket = 'examplebucket';

  /// Objects by key.
  final Map<String, FakeS3Object> objects = {};

  /// A store over this server.
  TomS3BlobStore store() => TomS3BlobStore(
    endpoint: Uri.parse('https://s3.example.com'),
    bucket: bucket,
    region: 'us-east-1',
    credentials: const TomAwsCredentials(
      accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
      secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    ),
    pathStyle: true,
    client: MockClient(_handle),
  );

  Future<http.Response> _handle(http.Request request) async {
    final segments = request.url.pathSegments;
    if (segments.isEmpty || segments.first != bucket) {
      return http.Response('no such bucket', 404);
    }
    final key = segments.skip(1).join('/');
    switch (request.method) {
      case 'PUT':
        final source = request.headers['x-amz-copy-source'];
        if (source != null) return _copy(key, source, request.headers);
        objects[key] = FakeS3Object(
          Uint8List.fromList(request.bodyBytes),
          _metadataOf(request.headers),
        );
        return http.Response('', 200, headers: {'etag': '"etag"'});
      case 'GET':
        final object = objects[key];
        if (object == null) return http.Response('NoSuchKey', 404);
        final range = RegExp(
          r'bytes=(\d+)-(\d*)',
        ).firstMatch(request.headers['range'] ?? '');
        if (range == null) {
          return http.Response.bytes(object.bytes, 200);
        }
        final start = int.parse(range.group(1)!);
        final last = range.group(2)!.isEmpty
            ? object.bytes.length - 1
            : int.parse(range.group(2)!);
        return http.Response.bytes(object.bytes.sublist(start, last + 1), 206);
      case 'HEAD':
        final object = objects[key];
        if (object == null) return http.Response('', 404);
        return http.Response(
          '',
          200,
          headers: {
            ...object.metadata,
            'content-length': '${object.bytes.length}',
            'last-modified': HttpDate.format(DateTime.now()),
          },
        );
      case 'DELETE':
        objects.remove(key);
        return http.Response('', 204);
    }
    return http.Response('unsupported', 501);
  }

  http.Response _copy(String key, String source, Map<String, String> headers) {
    final from = Uri.decodeFull(source).split('/').skip(2).join('/');
    final original = objects[from];
    if (original == null) return http.Response('NoSuchKey', 404);
    objects[key] = FakeS3Object(
      original.bytes,
      headers['x-amz-metadata-directive'] == 'REPLACE'
          ? _metadataOf(headers)
          : original.metadata,
    );
    return http.Response('<CopyObjectResult/>', 200);
  }

  static Map<String, String> _metadataOf(Map<String, String> headers) => {
    for (final MapEntry(:key, :value) in headers.entries)
      if (key == 'content-type' || key.startsWith('x-amz-meta-')) key: value,
  };
}
