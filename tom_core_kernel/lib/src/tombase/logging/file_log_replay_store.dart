/// File-backed [TomLogReplayStore] for durable replay buffering.
///
/// This library provides a persistent replay store so records that failed
/// every send attempt survive a process restart while the remote endpoint is
/// down — the one edge the in-memory store cannot cover. The queue is mirrored
/// to a JSON file on every mutation and reloaded from that file when the store
/// is constructed, so a fresh process pointed at the same path resumes with the
/// records that were buffered before it exited.
///
/// It is entirely opt-in: assign an instance to
/// [TomRemoteLogOutput.globalSettingReplayStore] to enable durability. The
/// default stays the zero-config in-memory store.
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'remote_logoutput.dart';

// =============================================================================
// File-backed Replay Store
// =============================================================================

/// A [TomLogReplayStore] that persists buffered records to a JSON file.
///
/// Records are held in memory for fast access and mirrored to [file] on every
/// mutation (`flush: true`, so the bytes reach disk before the call returns).
/// Constructing the store reloads any records previously written to [file], so
/// buffered records survive a process restart during an endpoint outage.
///
/// The on-disk format is a JSON array of objects, one per [TomRemoteLogMessage]
/// — a self-contained encoding kept here (rather than on the message type) so
/// the reflected/bridged surface of [TomRemoteLogMessage] is not affected.
class TomFileLogReplayStore implements TomLogReplayStore {
  /// The file the queue is mirrored to and reloaded from.
  final File file;

  final List<TomRemoteLogMessage> _records = [];

  /// Creates a store backed by [path], loading any previously persisted
  /// records so the queue resumes where a prior process left off.
  TomFileLogReplayStore(String path) : file = File(path) {
    _load();
  }

  @override
  int get length => _records.length;

  @override
  void append(TomRemoteLogMessage message) {
    _records.add(message);
    _persist();
  }

  @override
  List<TomRemoteLogMessage> snapshot() => List.of(_records);

  @override
  TomRemoteLogMessage? get oldest => _records.isEmpty ? null : _records.first;

  @override
  void removeOldest() {
    if (_records.isEmpty) return;
    _records.removeAt(0);
    _persist();
  }

  @override
  void trim(int maxSize) {
    if (maxSize <= 0) {
      clear();
      return;
    }
    if (_records.length <= maxSize) return;
    while (_records.length > maxSize) {
      _records.removeAt(0);
    }
    _persist();
  }

  @override
  void clear() {
    _records.clear();
    _persist();
  }

  /// Reads and decodes records from [file] if it exists; leaves the queue
  /// empty on a missing or unreadable file.
  void _load() {
    if (!file.existsSync()) return;
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    for (final entry in decoded) {
      if (entry is Map<String, Object?>) {
        _records.add(_decodeReplayRecord(entry));
      }
    }
  }

  /// Writes the current queue to [file], creating parent directories as needed
  /// and flushing so the bytes reach disk before returning.
  void _persist() {
    file.parent.createSync(recursive: true);
    final encoded = jsonEncode(_records.map(_encodeReplayRecord).toList());
    file.writeAsStringSync(encoded, flush: true);
  }
}

// =============================================================================
// Record serialization
// =============================================================================

/// Encodes a [TomRemoteLogMessage] into a JSON-native map.
///
/// Kept here rather than on [TomRemoteLogMessage] so the message type's
/// reflected/bridged surface stays unchanged.
Map<String, Object?> _encodeReplayRecord(TomRemoteLogMessage message) => {
  'sender': message.sender,
  'timeStamp': message.timeStamp,
  'loggerLevel': message.loggerLevel,
  'logLevel': message.logLevel,
  'level': message.level,
  'message': message.message,
  'isolateName': message.isolateName,
  'origin': message.origin,
};

/// Decodes a map produced by [_encodeReplayRecord] back into a message,
/// defaulting any missing or mistyped fields to their empty values.
TomRemoteLogMessage _decodeReplayRecord(Map<String, Object?> map) {
  return TomRemoteLogMessage()
    ..sender = _asString(map['sender'])
    ..timeStamp = _asString(map['timeStamp'])
    ..loggerLevel = _asInt(map['loggerLevel'])
    ..logLevel = _asInt(map['logLevel'])
    ..level = _asString(map['level'])
    ..message = _asString(map['message'])
    ..isolateName = _asString(map['isolateName'])
    ..origin = map['origin'] is String ? map['origin'] as String : null;
}

String _asString(Object? value) => value is String ? value : '';

int _asInt(Object? value) => value is int ? value : 0;
