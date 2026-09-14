/// `multipart/form-data` decoding for the endpoints pipeline: the shape a
/// browser form takes when it carries a file *and* the metadata that describes
/// it.
///
/// ## Why this exists next to the file endpoint rather than inside it
///
/// The [file endpoint](file_endpoint.dart) already moves single files, and it
/// does so over a **raw body**: the whole request is the file, the slot is the
/// URL, and nothing is buffered. That is the right shape for "replace the
/// attachment of row 42", and the wrong shape for "create a document *with* its
/// attachment" — there is no row yet, and the title, the tags and the bytes
/// arrive together. A raw body can express exactly one of those values.
///
/// So the two are not alternatives. This library decodes the *envelope* — text
/// parts into the request DTO, file parts into typed values a handler can take
/// as parameters — and the bytes still reach the blob store through the very
/// same [TomFileSlot] the raw-body endpoint uses (see `TomFormFileStorage` in
/// `file_endpoint.dart`). There is one route from bytes to storage, and
/// multipart takes it.
///
/// ## Parts are materialised, and that is a bound, not an oversight
///
/// A multipart body is a *single sequential stream*: part N+1 cannot be read
/// until part N has been drained. A lazy handle to a part is therefore not
/// expressible without buffering it anyway, so each file part is read into
/// memory as it goes past. That makes multipart the shape for forms, not for
/// bulk transfer — and [TomMultipartForm.globalSettingMaxFilePartBytes] states
/// the ceiling out loud rather than letting a large upload discover it as an
/// out-of-memory crash. An upload that does not fit belongs on the raw-body
/// file endpoint, which streams.
///
/// ### The one-file form does not get a streaming path either
///
/// The bound above is about the general case, and it leaves one case open: a
/// form with a *single* file part could in principle be handed to the handler
/// as a live stream, because there is nothing after it to reach. That is not
/// offered, and the reason is that the condition cannot be stated in the
/// endpoint's contract.
///
/// "The file is the last part" is a property of the **page**, not of the
/// protocol. HTML submits a form's entries in the document's own tree order, so
/// whether the file arrives last depends on where the `<input type="file">`
/// happens to sit among the other inputs — a decision taken in markup the
/// endpoint does not own and cannot see. An endpoint accepting a streamed part
/// would therefore work for one page and silently buffer, or fail, for another
/// that submits the same fields in a different order. A contract that holds or
/// not depending on how a caller's form was authored is worse than the ceiling,
/// which at least refuses in one place and says why.
///
/// So the split stands: forms carry what a form carries, and a transfer that
/// outgrows the ceiling changes route rather than shape. The guidance is
/// repeated on [TomEndpoint.consumes], because that is where an endpoint
/// declares itself a form and where the choice is actually made.
library;

import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// Thrown while decoding or binding a `multipart/form-data` request body.
///
/// Always caused by what the *caller* sent — a malformed envelope, a part over
/// the size ceiling, a declared file part that never arrived — so these surface
/// as client errors rather than as an opaque 500.
class TomFormBindingException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomFormBindingException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// One uploaded file part of a `multipart/form-data` request.
///
/// Carries the bytes together with what the envelope said about them — the form
/// [field] it arrived under, the client's [fileName], and the part's own
/// [mediaType]. All three are the caller's word and none is trusted: the file
/// name is a display hint (never a path), and the media type is a claim the
/// store records rather than a fact it verifies.
class TomFormFile {
  /// The form field name the part arrived under (its `name=` in the
  /// `content-disposition` header).
  final String field;

  /// The file name the client supplied, if any.
  ///
  /// A hint for display and for the stored descriptor — never a path. It is not
  /// resolved, joined, or used to choose a storage key; the store mints its own.
  final String? fileName;

  /// The media type the part declared, if any.
  final String? mediaType;

  /// The part's bytes.
  final Uint8List bytes;

  /// Creates an uploaded file part from its envelope data and [bytes].
  TomFormFile({
    required this.field,
    required this.bytes,
    this.fileName,
    this.mediaType,
  });

  /// The size of the part, in bytes.
  int get byteCount => bytes.length;

  /// The part's bytes as a stream, for handing to a store.
  ///
  /// Single-subscription semantics are irrelevant here — the bytes are already
  /// in memory, so the stream may be opened as often as the caller likes.
  Stream<List<int>> openRead() => Stream<List<int>>.value(bytes);

  @override
  String toString() =>
      'TomFormFile($field, fileName: $fileName, mediaType: $mediaType, '
      '$byteCount bytes)';
}

/// The decoded body of a `multipart/form-data` request: its text [fields] and
/// its uploaded [files].
///
/// Produced once per request by [readForm] and handed to the pipeline, which
/// folds [fields] into the request DTO and binds [files] to the handler's
/// parameters.
class TomMultipartForm {
  /// The largest a single file part may be before it is refused.
  ///
  /// Defaults to 8 MiB. A multipart part must be materialised to be read (see
  /// the library doc), so an unbounded one is an unbounded allocation driven by
  /// the caller. Raise it deliberately for a deployment that needs to, or move
  /// the transfer to the raw-body file endpoint, which streams and needs no
  /// ceiling at all.
  static int globalSettingMaxFilePartBytes = 8 * 1024 * 1024;

  /// The text parts, keyed by field name.
  ///
  /// A repeated field name keeps the **last** value, matching how a query
  /// string folds into a DTO — one field, one value. A form is not the shape
  /// for a repeated *text* field; an endpoint that needs one declares a JSON
  /// body, where a list is expressible.
  final Map<String, String> fields;

  /// The uploaded file parts, in the order they arrived.
  final List<TomFormFile> files;

  /// Creates a decoded form from its text [fields] and uploaded [files].
  TomMultipartForm({required this.fields, required this.files});

  /// The single file part named [field], or `null` when none arrived.
  ///
  /// When the same field name carries several files, the **first** wins — the
  /// opposite of [fields], deliberately: a repeated text field is a form
  /// re-stating one value, whereas repeated file parts are distinct uploads and
  /// silently keeping the last would discard data. A handler that means to
  /// accept several takes them through [filesNamed].
  TomFormFile? file(String field) {
    for (final file in files) {
      if (file.field == field) return file;
    }
    return null;
  }

  /// Every file part named [field], in arrival order.
  List<TomFormFile> filesNamed(String field) => [
    for (final file in files)
      if (file.field == field) file,
  ];

  /// Whether the request carried no parts at all.
  bool get isEmpty => fields.isEmpty && files.isEmpty;

  @override
  String toString() =>
      'TomMultipartForm(fields: ${fields.keys.toList()}, files: $files)';

  /// Decodes [req] as `multipart/form-data`, or returns `null` when it is not
  /// one (no multipart content type, or no `boundary` parameter).
  ///
  /// Reads the request body — so it may be called **once** per request, which
  /// is why the pipeline does it before binding any parameter rather than
  /// per parameter.
  ///
  /// A part is a *file* part when its `content-disposition` carries a
  /// `filename`, and a *text* part otherwise. That is the envelope's own
  /// distinction, not a guess from the media type: a browser sends
  /// `filename=""` for an empty file input and no `filename` at all for a text
  /// field, so the header says which is which and there is nothing to infer.
  ///
  /// Needs only a shelf [Request] with a body and a content type, so it is
  /// unit-testable without a live server.
  static Future<TomMultipartForm?> readForm(Request req) async {
    final formRequest = FormDataRequest.of(req);
    if (formRequest == null) return null;

    final fields = <String, String>{};
    final files = <TomFormFile>[];
    try {
      await for (final part in formRequest.formData) {
        final fileName = part.filename;
        if (fileName == null) {
          fields[part.name] = await part.part.readString();
          continue;
        }
        final bytes = await _readBounded(part.name, part.part);
        files.add(
          TomFormFile(
            field: part.name,
            fileName: fileName.isEmpty ? null : fileName,
            mediaType: part.part.headers['content-type'],
            bytes: bytes,
          ),
        );
      }
    } on TomFormBindingException {
      rethrow;
    } catch (error, stackTrace) {
      // A malformed envelope is the caller's error, but it reaches us as
      // whatever the MIME parser chose to throw. Named here so the endpoint
      // reports "your form is malformed" rather than an anonymous 500.
      throw TomFormBindingException(
        'form_binding.malformed_multipart_body',
        'The multipart form body could not be decoded.',
        rootException: error,
        stack: stackTrace,
      );
    }
    return TomMultipartForm(fields: fields, files: files);
  }

  /// Decodes [req] as `application/x-www-form-urlencoded`.
  ///
  /// The other shape an HTML form takes, and the one a form *without* a file
  /// input sends by default. It carries no parts and therefore no files, so the
  /// result always has an empty [files] — which is why it is a
  /// [TomMultipartForm] rather than a second type: everything downstream of the
  /// decode (the [formFields] allow-list, the fold into the request DTO) is
  /// identical, and only the decoding differs.
  ///
  /// A repeated field keeps the **last** value, exactly as [fields] does for a
  /// multipart body and as a query string does.
  static Future<TomMultipartForm> readUrlEncodedForm(Request req) async {
    final body = await req.readAsString();
    if (body.isEmpty) {
      return TomMultipartForm(fields: {}, files: const []);
    }
    try {
      return TomMultipartForm(
        fields: Uri.splitQueryString(body),
        files: const [],
      );
    } catch (error, stackTrace) {
      // Percent-decoding is the only thing that can fail here, and a body that
      // does not decode is the caller's error.
      throw TomFormBindingException(
        'form_binding.malformed_url_encoded_body',
        'The form body could not be decoded.',
        rootException: error,
        stack: stackTrace,
      );
    }
  }

  /// Reads [part] into memory, refusing at [globalSettingMaxFilePartBytes].
  ///
  /// Checked *while* reading rather than after: a ceiling enforced on the
  /// finished buffer has already allocated whatever it was meant to prevent.
  static Future<Uint8List> _readBounded(
    String field,
    Stream<List<int>> part,
  ) async {
    final limit = globalSettingMaxFilePartBytes;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in part) {
      builder.add(chunk);
      if (builder.length > limit) {
        throw TomFormBindingException(
          'form_binding.file_part_too_large',
          'That file is larger than this endpoint accepts.',
          parameters: {'field': field, 'limit': limit},
        );
      }
    }
    return builder.takeBytes();
  }
}

/// Whether [consumes] declares an HTML form body — `multipart/form-data` or
/// `application/x-www-form-urlencoded`.
///
/// Both are answered by the same question because both decode into a
/// [TomMultipartForm] and bind identically from there; which of the two a
/// browser sends is decided by whether the form has a file input, not by
/// anything the endpoint chooses.
///
/// Compares the type and subtype only ([TomMimeType.isEqualType]): the declared
/// constant and the value a real request carries differ in their parameters (a
/// boundary, a charset), so comparing whole values would never match.
bool tomConsumesForm(TomMimeType consumes) =>
    consumes.isEqualType(TomMimeType.multipartFormData) ||
    consumes.isEqualType(TomMimeType.urlEncoded);

/// Whether [consumes] declares specifically a `multipart/form-data` body.
///
/// Separated from [tomConsumesForm] because the two shapes differ in exactly
/// one respect — how the body is read — and the pipeline needs to know which
/// reader to call.
bool tomConsumesMultipartForm(TomMimeType consumes) =>
    consumes.isEqualType(TomMimeType.multipartFormData);
