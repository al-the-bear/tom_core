/// The device settings file: plain YAML that describes this machine.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:tom_basics/diagnostics.dart';
import 'package:tom_basics/utilities.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:yaml/yaml.dart' as yaml;

/// The device-scoped settings file at one locator.
///
/// The other half of an encrypted, roaming settings container: where that
/// holds what should follow the person, this holds what describes the
/// machine, and three properties follow from that one fact:
///
/// - **Plain YAML**, written deterministically. It has to be readable when
///   nothing else works, including when the settings container will not open,
///   so it cannot be encrypted by the key it helps find.
/// - **Never synced.** A window position is wrong on another machine by
///   definition.
/// - **Never a secret.** The one device-local secret is the settings key, kept
///   in the platform secret store with only its *handle* here.
///
/// The key set is an **open registry**: this class offers map access plus
/// typed accessors for the keys every application has, an application adds
/// its own (an extension is the natural shape), and [save] writes back
/// everything it read. A build that predates a key must not delete it — two
/// versions of an application on one machine is the ordinary case.
///
/// It reads and writes through [TomStorage] rather than `dart:io`, so it links
/// on every platform: in a browser the "device" scope is a browser-local
/// store, and a class that named a file path could not express that.
class TomDeviceSettings {
  /// The handle under which the platform secret store holds this device's
  /// settings-container key.
  @visibleForTesting
  static const settingsKeyHandleKey = 'settingsKeyHandle';

  /// Where this device's rolling diagnostics log is written.
  ///
  /// A device key because a path right on one machine is meaningless on
  /// another, and because it has to be readable when the settings container
  /// will not open — one of the situations somebody reads a log for.
  @visibleForTesting
  static const diagnosticsLogPathKey = 'diagnosticsLogPath';

  /// The least severe level this device's log keeps — verbose logging is
  /// turned on where a problem is being chased, not everywhere a user signs in.
  @visibleForTesting
  static const diagnosticsLogLevelKey = 'diagnosticsLogLevel';

  /// How many bytes of file content this device's storage cache may hold.
  @visibleForTesting
  static const cacheQuotaBytesKey = 'cacheQuotaBytes';

  /// Whether plaintext storage-cache files are sealed on this device.
  @visibleForTesting
  static const cacheEncryptionKey = 'cacheEncryption';

  final String locator;
  final TomStorage storage;

  /// The commit message a [save] without one uses.
  final String defaultCommitMessage;

  final Map<String, Object?> _values = {};
  String? _head;
  bool _loaded = false;

  TomDeviceSettings({
    required this.locator,
    required this.storage,
    this.defaultCommitMessage = 'Update device settings',
  });

  /// Whether [load] has run. Before it has, every read answers with nothing —
  /// the same answer a first run gives, so no caller needs a third state.
  bool get isLoaded => _loaded;

  /// The keys present, including ones this build does not understand.
  Iterable<String> get keys => _values.keys;

  Object? operator [](String key) => _values[key];

  /// Sets [key], or removes it when [value] is null — so "states nothing" has
  /// one on-disk representation rather than two.
  void operator []=(String key, Object? value) {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  /// The secret-store handle for the settings container's key.
  String? get settingsKeyHandle {
    final value = _values[settingsKeyHandleKey];
    return value is String && value.isNotEmpty ? value : null;
  }

  set settingsKeyHandle(String? handle) => this[settingsKeyHandleKey] = handle;

  /// The rolling log's path, or null when this device states none.
  ///
  /// Null is the ordinary first-run answer: a composition root resolves a
  /// default, writes it here so the location is discoverable, and honours a
  /// value already present.
  String? get diagnosticsLogPath {
    final value = _values[diagnosticsLogPathKey];
    return value is String && value.isNotEmpty ? value : null;
  }

  set diagnosticsLogPath(String? path) => this[diagnosticsLogPathKey] = path;

  /// The log's level, or null when this device states none. A value that
  /// names no level states nothing, rather than failing the whole file over
  /// one hand-edited key.
  TomDiagnosticLevel? get diagnosticsLogLevel {
    final value = _values[diagnosticsLogLevelKey];
    for (final level in TomDiagnosticLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }

  set diagnosticsLogLevel(TomDiagnosticLevel? level) =>
      this[diagnosticsLogLevelKey] = level?.name;

  /// The cache quota, or null when this device states none and the platform
  /// default applies. A value that is not a positive whole number states
  /// nothing.
  int? get cacheQuotaBytes {
    final value = _values[cacheQuotaBytesKey];
    return value is int && value > 0 ? value : null;
  }

  set cacheQuotaBytes(int? bytes) => this[cacheQuotaBytesKey] = bytes;

  /// Whether the cache is sealed, or null when this device states nothing
  /// and the platform default applies — off where the platform has disk
  /// encryption to rely on, on where it has none.
  bool? get cacheEncryption {
    final value = _values[cacheEncryptionKey];
    return value is bool ? value : null;
  }

  set cacheEncryption(bool? sealed) => this[cacheEncryptionKey] = sealed;

  /// Reads the file, treating "no file" as "an empty file".
  ///
  /// A malformed file is treated the same way rather than raised. This is the
  /// file an application reads *before* it can show the user anything, so a
  /// parse error here would be a launch failure with no surface to report it
  /// on — and the content is by definition device-local and reconstructible.
  Future<void> load() async {
    _values.clear();
    _loaded = true;
    Uint8List bytes;
    try {
      bytes = await storage.readBytes(locator);
      _head = await storage.headOf(locator);
    } on TomStorageException {
      _head = null;
      return;
    }
    Object? decoded;
    try {
      decoded = tomYamlToPlain(yaml.loadYaml(utf8.decode(bytes)));
    } on FormatException {
      return;
    }
    if (decoded is Map) {
      _values.addAll(decoded.cast<String, Object?>());
    }
  }

  /// Commits the current values, refusing the write if the file moved.
  ///
  /// **Writes are serialized** — one queue in front of the file. The file has
  /// several writers in one process, and each save is a compare-and-swap on
  /// the head the previous one left: two in flight at once would both carry
  /// the same expected head, and the second would be refused although nothing
  /// outside this process touched the file. Queued, each write commits the
  /// values as they are when its turn comes, over the head the write before it
  /// produced — so a later write also carries every key an earlier one set.
  ///
  /// A refused write does not stall the queue: its exception reaches its own
  /// caller and the next write still runs.
  ///
  /// With nothing in flight the write starts at once rather than behind an
  /// already-completed future: a future carries the zone it was made in, and
  /// a write queued behind one made elsewhere waits for that zone to run it.
  Future<String?> save({String? message}) {
    final previous = _writes;
    final result = previous == null
        ? _saveNow(message)
        : previous.then((_) => _saveNow(message));
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_writes, tail)) _writes = null;
    });
    _writes = tail;
    return result;
  }

  /// The tail of the write queue [save] appends to; null when nothing is in
  /// flight.
  Future<void>? _writes;

  Future<String?> _saveNow(String? message) async {
    final text = _values.isEmpty ? '{}\n' : tomEmitCanonicalFragment(_values);
    final head = await storage.commit(
      locator,
      TomChangeset.singleFile(Uint8List.fromList(utf8.encode(text))),
      expectedHead: _head,
      message: message ?? defaultCommitMessage,
    );
    _head = head;
    return head;
  }
}
