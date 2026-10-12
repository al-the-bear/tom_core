import 'package:tom_core_kernel/tom_core_kernel.dart';

/// What a `HEAD` against a file slot says, carried on the application wire.
///
/// The framework's file endpoint addresses every blob by **slot** —
/// `<table>/<id>/<column>` — and answers a `HEAD` with the kernel's
/// [TomFileMetadata] descriptor. A board that wants to render a paperclip, a
/// size and a media type needs exactly those facts and none of the bytes, so
/// this DTO is that descriptor plus the slot it describes: [fromMetadata] and
/// [toMetadata] are lossless in both directions, which is what keeps the wire
/// contract and the endpoint in agreement *by construction* rather than by a
/// comment. Modelling a bespoke `hasFile`/`type`/`size` triple instead would
/// have created a second, drifting definition of the same thing.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer. The three optional members of
/// [TomFileMetadata] travel as the empty string rather than `null` ([fileName],
/// [storedAt], [digest]) because that is the reflection path's natural shape for an
/// absent `String`; [toMetadata] maps empty back to `null`, so a descriptor
/// that went out without a file name comes back without one.
@tomReflector
class FileDescriptorDto {
  /// The slot this descriptor is about, as `<table>/<id>/<column>` — the same
  /// address [TomFileTransferClient] uses, so a client can go straight from a
  /// listed descriptor to a download without composing anything.
  String slot;

  /// The server-generated storage key. Empty when nothing is stored.
  String key;

  /// The media type the file was stored with.
  String mediaType;

  /// The stored size in bytes.
  int byteCount;

  /// The original file name, or empty when the server kept none.
  String fileName;

  /// When the file was stored, as an ISO-8601 string; empty when unreported.
  String storedAt;

  /// The content digest the server reported for the stored bytes, or empty
  /// when it reported none — what a client compares a download against.
  String digest;

  /// Creates a descriptor. The defaults describe an *empty* slot, so an unset
  /// descriptor reads as "no file" rather than as a zero-byte one.
  FileDescriptorDto({
    this.slot = '',
    this.key = '',
    this.mediaType = '',
    this.byteCount = 0,
    this.fileName = '',
    this.storedAt = '',
    this.digest = '',
  });

  /// Wraps the kernel descriptor [metadata] for the slot it came from.
  factory FileDescriptorDto.fromMetadata(
    String slot,
    TomFileMetadata metadata,
  ) => FileDescriptorDto(
    slot: slot,
    key: metadata.key,
    mediaType: metadata.mediaType,
    byteCount: metadata.byteCount,
    fileName: metadata.fileName ?? '',
    storedAt: metadata.storedAt?.toIso8601String() ?? '',
    digest: metadata.digest ?? '',
  );

  /// Composes the slot address for a file column of one row.
  static String slotOf(String table, String id, String column) =>
      '$table/$id/$column';

  /// The row id segment of [slot], or null when [slot] is not a
  /// `<table>/<id>/<column>` address.
  String? get slotId {
    final parts = slot.split('/');
    return parts.length == 3 ? parts[1] : null;
  }

  /// Whether a file is actually stored in the slot.
  bool get hasFile => key.isNotEmpty;

  /// The kernel descriptor this DTO carries — the exact value a `HEAD` against
  /// [slot] produces.
  TomFileMetadata toMetadata() => TomFileMetadata(
    key: key,
    mediaType: mediaType,
    byteCount: byteCount,
    fileName: fileName.isEmpty ? null : fileName,
    storedAt: storedAt.isEmpty ? null : DateTime.tryParse(storedAt),
    digest: digest.isEmpty ? null : digest,
  );

  @override
  String toString() => 'FileDescriptorDto($slot: $mediaType, $byteCount bytes)';
}

/// The file slots the two servers publish, named once.
///
/// A slot address is as much a part of the wire contract as an endpoint path:
/// the app server declares `app_items.attachment` as an exposed
/// `@TomFileReference` and the app client uploads to `app_items/<id>/attachment`
/// — two independent spellings of one address, and a mismatch surfaces only as a
/// 404 at runtime. So both sides read the table and column names from here, and
/// the server's own `@TomDbTable`/`@TomDbColumn` annotations use the same
/// constants. There is nothing left to keep in sync.
abstract final class AppFileSlots {
  /// The app server's item table (`app_db`).
  static const String itemsTable = 'app_items';

  /// The exposed attachment column on [itemsTable].
  static const String itemAttachmentColumn = 'attachment';

  /// The auth server's user table (`auth_db`).
  static const String usersTable = 'auth_users';

  /// The exposed avatar column on [usersTable].
  static const String userAvatarColumn = 'avatar_ref';

  /// The slot holding item [itemId]'s attachment, on the **app** server.
  static String itemAttachment(String itemId) =>
      FileDescriptorDto.slotOf(itemsTable, itemId, itemAttachmentColumn);

  /// The slot holding user [userId]'s avatar, on the **auth** server.
  static String userAvatar(String userId) =>
      FileDescriptorDto.slotOf(usersTable, userId, userAvatarColumn);
}
