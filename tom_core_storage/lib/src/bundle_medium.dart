import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:archive/archive.dart';

/// A keyed file medium: the files of one container — a document's parts, its
/// manifest, its history — read and written by path, whether they live in a
/// directory, in memory (and as a ZIP archive), in a browser store or in a
/// remote container.
///
/// **Bytes are the primitive, text is the convenience.** [readBytes] and
/// [writeBytes] are what an implementation supplies, and [readString] /
/// [writeString] are utf8 over them, defined once here so no implementation
/// can encode a text file differently from another.
///
/// The directory-backed implementation is deliberately **not** here — it lives
/// behind `io.dart`, because a single `dart:io` import in this file would make
/// every store written against a medium unlinkable on web.
///
/// **A write is atomic**, and that is part of the contract rather than a
/// property of one implementation. A reader must see either the file's previous
/// contents or its new ones, never a prefix of the new ones.
///
/// It is stated here, and not offered as an opt-in `writeBytesAtomic`, because
/// no caller of this class wants a torn file and an opt-in safety primitive is
/// one the next caller forgets. The consequence is not theoretical: a
/// commit journal rewrites its whole file on every mutation, and its entire
/// reason to exist is surviving a process death — so the moment it is most
/// likely to be interrupted is the moment its own write is in flight. A
/// truncated YAML file does not degrade to "one entry short": it does not
/// parse, and an unparseable journal is indistinguishable from an empty one.
/// The same argument covers a torn manifest, which maps a document's parts to
/// files and is therefore the whole document.
///
/// The in-memory and browser implementations satisfy this for free — a map
/// assignment and an IndexedDB `put` are each a single step — so only the
/// directory-backed one has work to do.
///
/// **Every member is asynchronous, and that is what makes a container cheap to
/// save.** A medium reads a member **on demand**, so `TomStorage.readBundle`
/// need not fetch the whole container before handing it over, and a save costs
/// what it actually compares — proportional to the document, not to its
/// history. The interface is the load-bearing part: the selectivity could have
/// been pushed into `readBundle` instead (fetch the manifest, then only the
/// files it names), but that would teach the storage layer one format's file
/// layout.
abstract class TomBundleMedium {
  Future<bool> exists(String path);

  Future<Uint8List> readBytes(String path);

  /// Replaces the file at [path], atomically (see the class doc).
  Future<void> writeBytes(String path, Uint8List bytes);

  Future<void> delete(String path);

  /// All file paths (relative, `/`-separated), including `.history/` files.
  ///
  /// Cheap by contract: an implementation backed by a remote answers from a
  /// listing it already holds rather than by reading the files. The retention
  /// sweep calls it on every save and reads none of what it names.
  Future<List<String>> listFiles();

  /// The file at [path] decoded as utf8 — the form every text file of a
  /// container is addressed through.
  Future<String> readString(String path) async =>
      utf8.decode(await readBytes(path));

  /// Writes [content] as utf8.
  Future<void> writeString(String path, String content) =>
      writeBytes(path, Uint8List.fromList(utf8.encode(content)));

  /// Moves a file, byte-for-byte — so the snapshot that retires an
  /// asset into `.history/.assets/` is the asset, not a mangled decode of it.
  ///
  /// **Not atomic as a whole**, unlike [writeBytes]: this default is a copy and
  /// a delete, so an interruption between them leaves the file at both paths.
  /// That is deliberate rather than overlooked — every caller is a `.history/`
  /// snapshot, where the duplicate is harmless and the next save redoes the
  /// move — and an implementation that can do better should say so by
  /// overriding, as the directory-backed one does.
  Future<void> move(String from, String to) async {
    await writeBytes(to, await readBytes(from));
    await delete(from);
  }
}

/// Bundle backed by an in-memory path→bytes map; converts to/from ZIP.
class TomMemoryBundleMedium extends TomBundleMedium {
  final Map<String, Uint8List> files;

  TomMemoryBundleMedium([Map<String, Uint8List>? files]) : files = files ?? {};

  /// A bundle whose files are given as text — the shape a test or a fixture
  /// naturally writes, encoded utf8 on the way in so the map this holds is
  /// the same map either constructor produces.
  @visibleForTesting
  factory TomMemoryBundleMedium.fromText(Map<String, String> files) =>
      TomMemoryBundleMedium({
        for (final entry in files.entries)
          entry.key: Uint8List.fromList(utf8.encode(entry.value)),
      });

  /// Decodes a ZIP archive into a memory medium, one file per entry.
  factory TomMemoryBundleMedium.fromZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, Uint8List>{};
    for (final entry in archive) {
      if (entry.isFile) {
        files[entry.name] = Uint8List.fromList(entry.content as List<int>);
      }
    }
    return TomMemoryBundleMedium(files);
  }

  /// Encodes this bundle (including `.history/`) as a ZIP archive.
  Uint8List toZip() {
    final archive = Archive();
    final paths = files.keys.toList()..sort();
    for (final path in paths) {
      final bytes = files[path]!;
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async =>
      files[path] ?? (throw StateError('No such bundle file: $path'));

  /// Atomic for free: a map assignment is a single step, so no reader can
  /// observe a partial value.
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      files[path] = bytes;

  @override
  Future<void> delete(String path) async => files.remove(path);

  @override
  Future<List<String>> listFiles() async => files.keys.toList()..sort();
}

/// A read-through view of a container: reads pass through, writes are refused.
///
/// What `TomStorage.readBundle` hands back. It used to hand back a
/// pre-fetched *copy*, which was detached by being a copy — and which made
/// every save cost the whole container, `.history/` included. A lazy medium
/// cannot be a copy, so detachment moved to `TomRecordingBundleMedium` (which
/// buffers writes) and the read side became explicitly read-only here.
///
/// Refusing rather than accepting-and-discarding is the point: a medium that
/// silently swallowed a write would produce a save that looked like it worked
/// and sent nothing. One decorator rather than a refusal per backend, so the
/// two tiers cannot disagree about what a `readBundle` result does.
class TomReadOnlyBundleMedium extends TomBundleMedium {
  final TomBundleMedium base;

  TomReadOnlyBundleMedium(this.base);

  @override
  Future<bool> exists(String path) => base.exists(path);

  @override
  Future<Uint8List> readBytes(String path) => base.readBytes(path);

  @override
  Future<List<String>> listFiles() => base.listFiles();

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      throw UnsupportedError(_message);

  @override
  Future<void> delete(String path) async => throw UnsupportedError(_message);

  static const _message =
      'A `readBundle` medium is a view of the container. Writes go through '
      'TomRecordingBundleMedium and reach storage as one commit.';
}
