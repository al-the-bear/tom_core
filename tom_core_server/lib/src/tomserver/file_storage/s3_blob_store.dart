/// The external object-store backend: S3 and everything that speaks its API.
///
/// One implementation covers Amazon S3, MinIO, Ceph RadosGW, Backblaze B2's S3
/// endpoint, DigitalOcean Spaces, Hetzner, Wasabi and Google Cloud Storage's
/// interoperability endpoint, because they all speak the same four requests
/// with the same signature. Azure Blob is the one that does not; it is reached
/// by writing a [TomBlobStore] over its REST API, which is the same amount of
/// work as this file and shares its shape.
///
/// ## How the upload streams
///
/// S3 will not accept a `PUT` without a `Content-Length`, so a body of unknown
/// length cannot be sent as one request. The protocol's own answer is
/// **multipart upload**, and it is what makes streaming possible here: the
/// incoming stream is buffered up to [TomS3BlobStore.partSize], and
///
/// - if the stream ends inside that first buffer — the common case, an
///   attachment or a report — it goes out as a single `PUT`, one round trip;
/// - otherwise the upload is opened, each full buffer becomes one part, and the
///   upload is completed at the end.
///
/// Memory is therefore bounded by the part size, not by the object size: a 4 GB
/// upload costs 8 MB of buffer. A failure at any point issues an
/// `AbortMultipartUpload`, so a half-sent object never becomes readable and the
/// bucket is not left paying for orphaned parts.
///
/// ## Why the responses are read with regular expressions
///
/// S3 answers in XML, and this file needs exactly two values out of it: the
/// upload id, and an error code when a request fails. Adding an XML parser to
/// the dependency set to extract two leaf elements from documents whose shape
/// is fixed by the protocol would be the more expensive choice, not the safer
/// one. Anything that needs the *whole* document is not a request this store
/// makes.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'aws_v4_signer.dart';
import 'blob_store.dart';

/// A blob store over an S3-compatible object store.
class TomS3BlobStore extends TomBlobStore {
  /// Creates a store for [bucket] at [endpoint].
  ///
  /// [endpoint] is the service root without the bucket — `https://s3.eu-central-1
  /// .amazonaws.com`, or `http://127.0.0.1:9000` for a local MinIO.
  ///
  /// [pathStyle] addresses objects as `<endpoint>/<bucket>/<key>`. It defaults
  /// to `true` because it is what every self-hosted implementation accepts,
  /// whereas virtual-host style (`https://<bucket>.<endpoint>/<key>`) needs
  /// wildcard DNS and a certificate to match. Set it `false` for Amazon, which
  /// prefers virtual-host addressing.
  ///
  /// [partSize] is the multipart part size and the upload buffer bound,
  /// defaulting to [defaultPartSize]. S3 requires every part except the last to
  /// be at least [minimumPartSize], so values below that are rejected.
  TomS3BlobStore({
    required this.endpoint,
    required this.bucket,
    required this.region,
    required TomAwsCredentials credentials,
    this.pathStyle = true,
    this.partSize = defaultPartSize,
    this.keyPrefix,
    http.Client? client,
  }) : signer = TomAwsV4Signer(credentials: credentials, region: region),
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (partSize < minimumPartSize) {
      throw TomStorageException(
        'storage.s3.part_size_too_small',
        'The configured multipart part size is below the protocol minimum.',
        parameters: {'partSize': partSize, 'minimum': minimumPartSize},
      );
    }
    // Checked here because it is checked nowhere else: [put] and its siblings
    // validate the caller's key, but the prefix is joined *after* that and the
    // result goes straight into a signed request URI. An unchecked `..` was a
    // traversal segment in the path this store asks the object store to act on.
    TomBlobStore.validateKeyPrefix(keyPrefix);
  }

  /// The service root, without the bucket.
  final Uri endpoint;

  /// The bucket every key resolves inside.
  final String bucket;

  /// The region the credential scope names.
  final String region;

  /// Whether objects are addressed as `<endpoint>/<bucket>/<key>`.
  final bool pathStyle;

  /// Bytes per multipart part, and the upload buffer bound.
  final int partSize;

  /// A prefix prepended to every key, so one bucket can host several stores.
  ///
  /// Checked twice, because one check cannot cover it. At construction it is
  /// held to [TomBlobStore.isValidKeyPrefix], the grammar of the keys it will
  /// be joined to; at each request the join itself is held to
  /// [TomBlobStore.maxKeyLength], which depends on the key and so cannot be
  /// settled before one arrives. Either refusal is
  /// `storage.blob.invalid_key_prefix`: the prefix is the half a deployment
  /// chose, and the half that is wrong for every key rather than for one.
  final String? keyPrefix;

  /// The request signer.
  final TomAwsV4Signer signer;

  final http.Client _client;
  final bool _ownsClient;

  /// S3's minimum size for any part but the last.
  static const int minimumPartSize = 5 * 1024 * 1024;

  /// The default bytes per multipart part, 8 MiB.
  ///
  /// Above [minimumPartSize] with room to spare, so the common case is not
  /// sitting on the protocol's floor, and small enough that the upload buffer
  /// it bounds stays a reasonable per-upload allocation.
  ///
  /// Declared here rather than repeated at each defaulting site, for the same
  /// reason the table names are declared in `database_blob_sql.dart`: a default
  /// restated is a default that can diverge.
  static const int defaultPartSize = 8 * 1024 * 1024;

  /// The header the original file name is carried in.
  static const String fileNameHeader = 'x-amz-meta-filename';

  /// The header the content digest is carried in.
  ///
  /// User metadata rather than a protocol header, because S3 has none that
  /// means this. `x-amz-content-sha256` is the *signature's* payload hash, sent
  /// per request — on a multipart upload it is a part's hash, never the
  /// object's — and `ETag` is an MD5 only for single-part objects and an opaque
  /// string otherwise. Neither survives as a whole-object SHA-256, so the store
  /// records its own.
  static const String digestHeader = 'x-amz-meta-digest';

  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    final buffer = <int>[];
    var byteCount = 0;
    // Hashed as the bytes arrive, which is the only place the *whole* object
    // passes through on a multipart upload: each part is signed with its own
    // payload hash, and nothing downstream ever sees them joined.
    final digest = TomBlobDigest();
    String? uploadId;
    final etags = <String>[];

    // Deferred until the digest is known, so a single PUT carries it in the
    // same request as the bytes. A multipart upload cannot: its metadata is
    // fixed when the upload is created, before the last part has been seen —
    // so that path sets the digest afterwards, with a copy onto itself.
    Map<String, String> metadataWith(String contentDigest) => {
      'content-type': mediaType,
      if (fileName != null) fileNameHeader: fileName,
      if (contentDigest.isNotEmpty) digestHeader: contentDigest,
    };

    Future<void> uploadPart() async {
      uploadId ??= await _createMultipartUpload(
        key,
        metadataWith(TomStoredBlob.unknownDigest),
      );
      final partNumber = etags.length + 1;
      final response = await _send(
        method: 'PUT',
        operation: 'uploadPart',
        key: key,
        uri: _objectUri(key, {
          'partNumber': '$partNumber',
          'uploadId': uploadId!,
        }),
        body: List<int>.of(buffer),
      );
      final etag = response.headers['etag'];
      if (etag == null) {
        throw TomStorageException(
          'storage.s3.part_without_etag',
          'The object store did not acknowledge an uploaded part.',
          parameters: {'key': key, 'partNumber': partNumber},
          autoLog: true,
        );
      }
      etags.add(etag);
      buffer.clear();
    }

    try {
      await for (final incoming in bytes) {
        byteCount += incoming.length;
        digest.add(incoming);
        var offset = 0;
        while (offset < incoming.length) {
          final take = (partSize - buffer.length).clamp(
            0,
            incoming.length - offset,
          );
          buffer.addAll(incoming.getRange(offset, offset + take));
          offset += take;
          if (buffer.length >= partSize) await uploadPart();
        }
      }

      if (uploadId == null) {
        // The whole object fitted in one buffer: a single PUT, and no multipart
        // bookkeeping to clean up if it fails.
        await _send(
          method: 'PUT',
          operation: 'put',
          key: key,
          uri: _objectUri(key, const {}),
          headers: metadataWith(digest.close()),
          body: List<int>.of(buffer),
        );
      } else {
        if (buffer.isNotEmpty) await uploadPart();
        await _completeMultipartUpload(key, uploadId!, etags);
        // The digest is only known now, and multipart metadata was fixed when
        // the upload was created. A copy onto the same key with
        // `REPLACE` is S3's own way of rewriting metadata in place: the object
        // store moves the bytes internally, so this is one request rather than
        // a re-upload. Without it a multipart object would come back from
        // `describe` with no digest — the one size where a caller most wants
        // one.
        await _send(
          method: 'PUT',
          operation: 'setMetadata',
          key: key,
          uri: _objectUri(key, const {}),
          headers: {
            ...metadataWith(digest.close()),
            'x-amz-copy-source': _copySource(key),
            'x-amz-metadata-directive': 'REPLACE',
          },
        );
      }
    } on Object catch (error, stack) {
      if (uploadId != null) {
        // Without this the bucket keeps (and bills for) the parts of an upload
        // that will never be completed.
        await _abortMultipartUpload(key, uploadId!).catchError((Object _) {});
      }
      // Rethrown rather than wrapped: [TomBlobStore.put] reports it as
      // `storage.blob.write_failed`. This block exists for the abort, and
      // having done it must not swallow what caused it.
      Error.throwWithStackTrace(error, stack);
    }

    return TomStoredBlob(
      key: key,
      mediaType: mediaType,
      byteCount: byteCount,
      storedAt: DateTime.now(),
      digest: digest.close(),
      fileName: fileName,
      location: _objectUri(key, const {}),
    );
  }

  @override
  Stream<List<int>> doGet(String key) => _openObject(key);

  @override
  Stream<List<int>> doGetRange(String key, TomBlobRange range) =>
      _openObject(key, range: range);

  /// The object at [key], optionally only [range] of it.
  ///
  /// One body for both reads because everything below the header is the same
  /// request, and the reasoning about the 404, the failure and the `yield*` is
  /// what would have to be duplicated — and then kept in step — to have two.
  ///
  /// S3 answers a ranged `GET` natively, which is the whole reason
  /// [TomBlobStore.doGetRange] is overridable: the bytes before the range never
  /// cross the wire. The header is inclusive at both ends, so the exclusive end
  /// this module carries is written as `end - 1`; an open-ended range is
  /// `bytes=start-`, which S3 reads as "to the end" without being told where
  /// that is. The response comes back `206`, which the `>= 300` check below
  /// already treats as success.
  Stream<List<int>> _openObject(String key, {TomBlobRange? range}) async* {
    final uri = _objectUri(key, const {});
    final headers = <String, String>{
      if (range != null)
        'range':
            'bytes=${range.start}-'
            '${range.endExclusive == null ? '' : range.endExclusive! - 1}',
    };
    final request = http.Request('GET', uri)
      ..headers.addAll(
        _requestHeaders(
          method: 'GET',
          uri: uri,
          headers: headers,
          payloadHash: TomAwsV4Signer.emptyPayloadHash,
        ),
      );
    final response = await _client.send(request);
    if (response.statusCode == 404) {
      // Drained so the connection returns to the pool rather than being held
      // open by an unread body.
      await response.stream.drain<void>();
      throw TomBlobStore.notFound(key);
    }
    if (response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw _failure('get', key, uri, response.statusCode, body);
    }
    // `yield*` is correct here, and only because of where this runs.
    // [TomBlobStore.get] consumes this stream with `await for` inside its
    // translating `try`, so a socket that dies after the first bytes still
    // reaches the caller as `storage.blob.read_failed` carrying the key. Read
    // in isolation this line looks like the module leaking a `ClientException`
    // — it is not, and the difference is one caller away. Do not "fix" it by
    // catching here: the base class owns the translation so that every backend
    // gets it, and a second layer would only restate what it already says.
    yield* response.stream;
  }

  @override
  Future<TomStoredBlob?> doDescribe(String key) async {
    final response = await _send(
      method: 'HEAD',
      operation: 'describe',
      key: key,
      uri: _objectUri(key, const {}),
      allowNotFound: true,
    );
    if (response.statusCode == 404) return null;
    return TomStoredBlob(
      key: key,
      mediaType:
          response.headers['content-type'] ?? TomStoredBlob.defaultMediaType,
      byteCount: int.tryParse(response.headers['content-length'] ?? '') ?? 0,
      storedAt: _lastModified(response.headers['last-modified']),
      // An object this store did not write carries no such header, and reports
      // `unknownDigest` rather than a hash nobody computed.
      digest: response.headers[digestHeader] ?? TomStoredBlob.unknownDigest,
      fileName: response.headers[fileNameHeader],
      location: _objectUri(key, const {}),
    );
  }

  @override
  Future<TomStoredBlob> doCopy(String fromKey, String toKey) async {
    // `CopyObject`: a PUT at the destination naming the source in a header. The
    // object never leaves the object store — which is the whole reason this
    // override exists, since the inherited default would pull every byte down
    // to this process and push it back up.
    final described = await doDescribe(fromKey);
    if (described == null) throw TomBlobStore.notFound(fromKey);
    await _send(
      method: 'PUT',
      operation: 'copy',
      key: fromKey,
      uri: _objectUri(toKey, const {}),
      headers: {'x-amz-copy-source': _copySource(fromKey)},
    );
    return TomStoredBlob(
      key: toKey,
      mediaType: described.mediaType,
      byteCount: described.byteCount,
      storedAt: DateTime.now().toUtc(),
      // `CopyObject` without a metadata directive copies the source's user
      // metadata, so the digest header travels with the bytes — and it is the
      // same bytes, so it is still true.
      digest: described.digest,
      fileName: described.fileName,
      location: _objectUri(toKey, const {}),
    );
  }

  /// The `x-amz-copy-source` value naming [key] in this store's bucket.
  ///
  /// `/<bucket>/<prefixed key>`, and **URI-encoded per segment**: the header
  /// carries a path, so a key containing a character that is legal in a key and
  /// reserved in a path would otherwise name a different object — or none. The
  /// bucket is always in the value, whatever `pathStyle` puts in the URL,
  /// because the header is addressed against the service and not against the
  /// request's host.
  String _copySource(String key) {
    final segments = _prefixed(key).split('/').map(Uri.encodeComponent);
    return '/$bucket/${segments.join('/')}';
  }

  @override
  bool get supportsPrefixDelete => true;

  @override
  Future<int> doDeletePrefix(String prefix) async {
    // The one operation on this backend whose cost is not one request. S3 has
    // no prefix delete: it has a paginated listing and a batched delete, and
    // this is those two. The cost is stated rather than hidden, which is the
    // difference between a method a caller can reason about and the `list` this
    // module refused to put on the contract — there a caller would have been
    // handed a paginated scan wearing the shape of a map lookup.
    //
    // **Eventually consistent.** A `LIST` may not yet show an object written a
    // moment ago, so a prefix delete run against a live key space can leave
    // one behind. Retention runs against partitions nothing is still writing
    // to, which is what the date partitioning in a key is for.
    var removed = 0;
    String? token;
    do {
      final listed = await _listUnder(prefix, token);
      if (listed.keys.isNotEmpty) {
        await _deleteObjects(prefix, listed.keys);
        removed += listed.keys.length;
      }
      token = listed.next;
    } while (token != null);
    return removed;
  }

  /// One page of the object keys under [prefix], with the token for the next.
  ///
  /// The keys come back **prefixed** — S3 knows nothing about [keyPrefix] — and
  /// are handed to the delete as they arrived, since that is the form the
  /// request needs.
  Future<({List<String> keys, String? next})> _listUnder(
    String prefix,
    String? token,
  ) async {
    // The segment rule, expressed to S3: a trailing separator is what stops
    // `2026/07` from listing `2026/070`. The prefix itself, which may be a
    // whole key, is covered by [doDeletePrefix]'s caller having validated it —
    // and by the `<Key>` scan below, which returns whatever S3 matched.
    final uri = _bucketUri({
      'list-type': '2',
      'prefix': _prefixed(prefix),
      if (token != null) 'continuation-token': token,
    });
    final response = await _send(
      method: 'GET',
      operation: 'listPrefix',
      key: prefix,
      uri: uri,
    );
    final body = response.body;
    final wanted = _prefixed(prefix);
    final keys = [
      for (final match in RegExp(r'<Key>(.*?)</Key>').allMatches(body))
        _unescapeXml(match.group(1)!),
    ].where((key) => key == wanted || key.startsWith('$wanted/')).toList();
    final next = RegExp(
      r'<NextContinuationToken>(.*?)</NextContinuationToken>',
    ).firstMatch(body);
    final truncated = body.contains('<IsTruncated>true</IsTruncated>');
    return (
      keys: keys,
      next: truncated && next != null ? _unescapeXml(next.group(1)!) : null,
    );
  }

  /// Deletes [keys] — already prefixed — in batches of the protocol's maximum.
  Future<void> _deleteObjects(String prefix, List<String> keys) async {
    // 1000 is S3's own cap on one `DeleteObjects` request, not a number chosen
    // here: a larger body is refused outright.
    const batch = 1000;
    for (var at = 0; at < keys.length; at += batch) {
      final page = keys.sublist(at, (at + batch).clamp(0, keys.length));
      final xml = StringBuffer('<Delete><Quiet>true</Quiet>');
      for (final key in page) {
        xml.write('<Object><Key>${_escapeXml(key)}</Key></Object>');
      }
      xml.write('</Delete>');
      final body = utf8.encode(xml.toString());
      final response = await _send(
        method: 'POST',
        operation: 'deletePrefix',
        key: prefix,
        uri: _bucketUri(const {'delete': ''}),
        headers: {
          'content-type': 'application/xml',
          // Required by the protocol, and an MD5 rather than a choice: S3
          // refuses a `DeleteObjects` without it.
          'content-md5': base64.encode(md5.convert(body).bytes),
        },
        body: body,
      );
      // `Quiet` suppresses the per-key success entries, so anything left in the
      // body is a failure — and S3 reports those with a `200`.
      if (response.body.contains('<Error>')) {
        throw _failure(
          'deletePrefix',
          prefix,
          _bucketUri(const {'delete': ''}),
          response.statusCode,
          response.body,
        );
      }
    }
  }

  /// The bucket's own URI, for the two requests addressed at it rather than at
  /// an object.
  Uri _bucketUri(Map<String, String> query) => endpoint.replace(
    host: pathStyle ? endpoint.host : '$bucket.${endpoint.host}',
    pathSegments: [
      ...endpoint.pathSegments.where((s) => s.isNotEmpty),
      if (pathStyle) bucket,
    ],
    queryParameters: query.isEmpty ? null : query,
  );

  /// The five XML entities, for a key going into a request body.
  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// The same five, coming back out of a response.
  static String _unescapeXml(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  @override
  Future<bool> doDelete(String key) async {
    // S3 answers `204` to a delete whether or not the object was there, so the
    // "did it exist" the contract promises has to be asked separately.
    //
    // Which makes the answer a *recent observation* rather than a fact, and
    // deliberately so — see [TomBlobStore.delete]. Another caller can create or
    // remove the key between this probe and the request below, so two
    // concurrent deletes can both answer `true` and a delete racing a `put` can
    // answer `false` having removed nothing. There is no conditional delete in
    // the API to close it with: `x-amz-if-match` does not exist on `DeleteObject`,
    // and a versioned bucket's delete marker answers a different question
    // (which version) from the one the contract asks (was there anything).
    if (!await doExists(key)) return false;
    await _send(
      method: 'DELETE',
      operation: 'delete',
      key: key,
      uri: _objectUri(key, const {}),
    );
    return true;
  }

  @override
  Future<void> close() async {
    if (_ownsClient) _client.close();
  }

  Future<String> _createMultipartUpload(
    String key,
    Map<String, String> metadata,
  ) async {
    final response = await _send(
      method: 'POST',
      operation: 'createMultipartUpload',
      key: key,
      uri: _objectUri(key, const {'uploads': ''}),
      headers: metadata,
      body: const [],
    );
    final uploadId = _element(response.body, 'UploadId');
    if (uploadId == null) {
      throw TomStorageException(
        'storage.s3.no_upload_id',
        'The object store did not return an upload id.',
        parameters: {'key': key},
        autoLog: true,
      );
    }
    return uploadId;
  }

  Future<void> _completeMultipartUpload(
    String key,
    String uploadId,
    List<String> etags,
  ) async {
    final xml = StringBuffer('<CompleteMultipartUpload>');
    for (var i = 0; i < etags.length; i++) {
      xml.write(
        '<Part><PartNumber>${i + 1}</PartNumber>'
        '<ETag>${etags[i]}</ETag></Part>',
      );
    }
    xml.write('</CompleteMultipartUpload>');
    // Hoisted out of the call below because the failure built here has to
    // report the same URI the request went to, and rebuilding it would let the
    // two drift.
    final uri = _objectUri(key, {'uploadId': uploadId});
    final response = await _send(
      method: 'POST',
      operation: 'completeMultipartUpload',
      key: key,
      uri: uri,
      headers: const {'content-type': 'application/xml'},
      body: utf8.encode(xml.toString()),
    );
    // S3 can answer `200` and *then* report a failure in the body — the one
    // place where the status code is not the answer.
    if (response.body.contains('<Error>')) {
      throw _failure(
        'completeMultipartUpload',
        key,
        uri,
        response.statusCode,
        response.body,
      );
    }
  }

  Future<void> _abortMultipartUpload(String key, String uploadId) => _send(
    method: 'DELETE',
    operation: 'abortMultipartUpload',
    key: key,
    uri: _objectUri(key, {'uploadId': uploadId}),
  );

  /// Signs and sends one request, turning a rejection into a named failure.
  ///
  /// [operation] and [key] are what the *caller* is doing and to which object —
  /// not what this method is sending. They are separate parameters from
  /// [method] and [uri] because they answer a different question: an operator
  /// reading a failed request needs to know that a part upload stopped, and a
  /// caller needs its own key back. `PUT /examplebucket/tenant-7/big.bin` is
  /// neither, and is reported alongside rather than instead.
  Future<http.Response> _send({
    required String method,
    required String operation,
    required String key,
    required Uri uri,
    Map<String, String> headers = const {},
    List<int>? body,
    bool allowNotFound = false,
  }) async {
    final payload = body ?? const <int>[];
    final request = http.Request(method, uri)
      ..headers.addAll(
        _requestHeaders(
          method: method,
          uri: uri,
          headers: headers,
          payloadHash: TomAwsV4Signer.hashPayload(payload),
        ),
      );
    if (body != null) request.bodyBytes = payload;
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode == 404 && allowNotFound) return response;
    if (response.statusCode >= 300) {
      throw _failure(operation, key, uri, response.statusCode, response.body);
    }
    return response;
  }

  /// The signed headers to put on a request, minus `host`.
  ///
  /// `host` is signed (the canonical request requires it) but not set here: the
  /// HTTP client derives the identical value from the URI, and dart:io rejects
  /// some attempts to override it.
  Map<String, String> _requestHeaders({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String payloadHash,
  }) {
    final signed = signer.signedHeaders(
      method: method,
      uri: uri,
      headers: headers,
      payloadHash: payloadHash,
    );
    return {
      for (final entry in signed.entries)
        if (entry.key != 'host') entry.key: entry.value,
    };
  }

  /// [key] under [keyPrefix], refused if the two are unusable together.
  ///
  /// Both halves are already known to be valid on their own — the prefix at
  /// construction, the key by [TomBlobStore.put] and its siblings — so the only
  /// clause left is the one neither can settle alone: two keys inside
  /// [TomBlobStore.maxKeyLength] can join past it. S3 would not object, its own
  /// limit being twice ours, so the refusal has to come from here or from
  /// nowhere; without it this backend alone would store keys every other
  /// backend refuses.
  ///
  /// Named against the prefix rather than the key because the key is the
  /// caller's and is fine: it is the deployment's prefix that leaves no room,
  /// for this key and every other one this store will be asked for.
  String _prefixed(String key) {
    if (keyPrefix == null) return key;
    final joined = '$keyPrefix/$key';
    if (joined.length > TomBlobStore.maxKeyLength) {
      throw TomStorageException(
        'storage.blob.invalid_key_prefix',
        'The configured key prefix is not a valid storage key prefix.',
        parameters: {'keyPrefix': keyPrefix, 'key': key},
      );
    }
    return joined;
  }

  /// The URL of [key], honouring [pathStyle] and [keyPrefix].
  Uri _objectUri(String key, Map<String, String> query) {
    final segments = _prefixed(key).split('/');
    return endpoint.replace(
      host: pathStyle ? endpoint.host : '$bucket.${endpoint.host}',
      pathSegments: [
        ...endpoint.pathSegments.where((s) => s.isNotEmpty),
        if (pathStyle) bucket,
        ...segments,
      ],
      queryParameters: query.isEmpty ? null : query,
    );
  }

  /// Builds the module's one "the store said no" error.
  ///
  /// [key] is the caller's key, never the request path. Every error in this
  /// module and in [TomBlobStore] puts the caller's key under `key`, and a
  /// handler that logs or renders `parameters['key']` cannot know that one
  /// backend meant something else by it. Under a [keyPrefix] the path is worse
  /// than merely unrecognisable — the prefix is typically the tenant, and the
  /// bucket is infrastructure detail.
  ///
  /// The path is still reported, under [Uri.path] as `objectPath`. It is what
  /// an operator reading a rejected request actually needs, and `autoLog: true`
  /// means one will read it. The separate name is the point: rendering
  /// parameters wholesale then visibly opts into infrastructure detail instead
  /// of being handed it by a field called `key`.
  TomStorageException _failure(
    String operation,
    String key,
    Uri uri,
    int status,
    String body,
  ) => TomStorageException(
    'storage.s3.request_failed',
    'The object store rejected the request.',
    parameters: {
      'operation': operation,
      'key': key,
      'objectPath': uri.path,
      'status': status,
      'code': _element(body, 'Code') ?? '',
      'message': _element(body, 'Message') ?? '',
    },
    autoLog: true,
  );

  /// The text of the first `<name>…</name>` element in [xml], or `null`.
  static String? _element(String xml, String name) =>
      RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(xml)?.group(1);

  /// Parses an HTTP-date `Last-Modified`, falling back to now when the header
  /// is absent or unparsable — a missing timestamp is not worth failing a read.
  static DateTime _lastModified(String? header) {
    if (header == null) return DateTime.now();
    try {
      return parseHttpDate(header);
    } on FormatException {
      return DateTime.now();
    }
  }

  /// Parses an RFC 7231 IMF-fixdate (`Wed, 21 Oct 2015 07:28:00 GMT`).
  ///
  /// Exposed for the test that pins the one header this store reads a value
  /// out of; throws a [FormatException] on anything else.
  static DateTime parseHttpDate(String value) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    // "Wed, 21 Oct 2015 07:28:00 GMT"
    final match = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value.trim());
    // throws-outside-family: parse contract — a public parse function; its one
    // caller, _lastModified, catches it.
    if (match == null) throw FormatException('Not an HTTP date', value);
    return DateTime.utc(
      int.parse(match.group(3)!),
      months[match.group(2)!] ?? 1,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  @override
  String toString() => 'TomS3BlobStore($bucket at $endpoint)';
}
