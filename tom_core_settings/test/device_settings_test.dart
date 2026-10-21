/// The device settings file: an open registry written back whole, behind one
/// serialized write queue.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_basics/diagnostics.dart';
import 'package:tom_core_settings/tom_core_settings.dart';
import 'package:tom_core_storage/testing.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

const _locator = 'mem:/device/device.yaml';

/// Refuses the first [refusals] commits, then behaves.
class _RefusingStorage extends TomMemoryStorage {
  _RefusingStorage() : super(TomMemoryRemote());

  int refusals = 1;
  int attempts = 0;

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) {
    attempts++;
    if (refusals > 0) {
      refusals--;
      throw const TomUnreachableException(_locator, 'refused');
    }
    return super.commit(
      locator,
      changeset,
      expectedHead: expectedHead,
      message: message,
      onProgress: onProgress,
    );
  }
}

Future<Map<String, Object?>> _onDisk(TomMemoryStorage storage) async {
  final reread = TomDeviceSettings(locator: _locator, storage: storage);
  await reread.load();
  return {for (final key in reread.keys) key: reread[key]};
}

void main() {
  test('SETTINGS-DEVICE-1: saves started together all land — none is '
      'refused for the head an earlier one moved', () async {
    final storage = TomMemoryStorage(TomMemoryRemote());
    final device = TomDeviceSettings(locator: _locator, storage: storage);
    await device.load();

    device['panelWidth'] = 300;
    final first = device.save(message: 'layout');
    device.cacheQuotaBytes = 1 << 20;
    final second = device.save(message: 'cache');
    device.diagnosticsLogLevel = TomDiagnosticLevel.debug;
    final third = device.save(message: 'log');

    final heads = await Future.wait([first, second, third]);
    expect(heads.toSet(), hasLength(3), reason: 'three commits, in order');
    expect(await _onDisk(storage), {
      'panelWidth': 300,
      TomDeviceSettings.cacheQuotaBytesKey: 1 << 20,
      TomDeviceSettings.diagnosticsLogLevelKey: 'debug',
    });
  });

  test('SETTINGS-DEVICE-2: a refused write reaches its own caller and does '
      'not stall the writes queued behind it', () async {
    final storage = _RefusingStorage();
    final device = TomDeviceSettings(locator: _locator, storage: storage);
    await device.load();

    device['panelWidth'] = 280;
    final refused = device.save();
    device.cacheQuotaBytes = 2 << 20;
    final landed = device.save();

    await expectLater(refused, throwsA(isA<TomStorageException>()));
    expect(await landed, isNotNull);
    expect(storage.attempts, 2);
    // The write that landed carries what the refused one would have.
    expect(await _onDisk(storage), {
      'panelWidth': 280,
      TomDeviceSettings.cacheQuotaBytesKey: 2 << 20,
    });
  });

  test('SETTINGS-DEVICE-3: the log level round-trips and states nothing by '
      'default; a value naming no level states nothing', () async {
    final storage = TomMemoryStorage(TomMemoryRemote());
    final device = TomDeviceSettings(locator: _locator, storage: storage);
    await device.load();
    expect(device.diagnosticsLogLevel, isNull);

    device.diagnosticsLogLevel = TomDiagnosticLevel.debug;
    await device.save();
    final reread = TomDeviceSettings(locator: _locator, storage: storage);
    await reread.load();
    expect(reread.diagnosticsLogLevel, TomDiagnosticLevel.debug);

    reread.diagnosticsLogLevel = null;
    expect(reread.keys, isNot(contains('diagnosticsLogLevel')));
    reread[TomDeviceSettings.diagnosticsLogLevelKey] = 'verbose';
    expect(reread.diagnosticsLogLevel, isNull);
    reread[TomDeviceSettings.diagnosticsLogLevelKey] = 3;
    expect(reread.diagnosticsLogLevel, isNull);
  });

  test('SETTINGS-DEVICE-4: typed accessors refuse values of the wrong shape '
      'rather than failing the file', () async {
    final device = TomDeviceSettings(
      locator: _locator,
      storage: TomMemoryStorage(TomMemoryRemote()),
    );
    await device.load();
    device[TomDeviceSettings.cacheQuotaBytesKey] = -5;
    expect(device.cacheQuotaBytes, isNull);
    device[TomDeviceSettings.cacheEncryptionKey] = 'yes';
    expect(device.cacheEncryption, isNull);
    device[TomDeviceSettings.settingsKeyHandleKey] = '';
    expect(device.settingsKeyHandle, isNull);
    device.diagnosticsLogPath = '/var/log/app.log';
    expect(device.diagnosticsLogPath, '/var/log/app.log');
  });

  test('SETTINGS-DEVICE-5: keys this build does not know survive a load and '
      'a save', () async {
    final storage = TomMemoryStorage(TomMemoryRemote());
    await storage.commit(
      _locator,
      TomChangeset.singleFile(
        Uint8List.fromList(utf8.encode('futureKey:\n  nested: [1, 2]\n')),
      ),
    );
    final device = TomDeviceSettings(locator: _locator, storage: storage);
    await device.load();
    device.cacheEncryption = true;
    await device.save();
    expect(await _onDisk(storage), {
      'futureKey': {
        'nested': [1, 2],
      },
      TomDeviceSettings.cacheEncryptionKey: true,
    });
  });

  test('SETTINGS-DEVICE-6: a malformed file reads as empty, and the next save '
      'replaces it', () async {
    final storage = TomMemoryStorage(TomMemoryRemote());
    await storage.commit(
      _locator,
      TomChangeset.singleFile(Uint8List.fromList(utf8.encode('a: [1, 2\n'))),
    );
    final device = TomDeviceSettings(locator: _locator, storage: storage);
    await device.load();
    expect(device.isLoaded, isTrue);
    expect(device.keys, isEmpty);

    device.settingsKeyHandle = 'h';
    await device.save();
    expect(await _onDisk(storage), {
      TomDeviceSettings.settingsKeyHandleKey: 'h',
    });
  });

  test('SETTINGS-DEVICE-7: a save without a message uses the default commit '
      'message the file was built with', () async {
    final messages = <String?>[];
    final storage = _RecordingStorage(messages);
    final device = TomDeviceSettings(
      locator: _locator,
      storage: storage,
      defaultCommitMessage: 'Update my app',
    );
    await device.load();
    await device.save();
    await device.save(message: 'explicit');
    expect(messages, ['Update my app', 'explicit']);
  });
}

class _RecordingStorage extends TomMemoryStorage {
  _RecordingStorage(this.messages) : super(TomMemoryRemote());
  final List<String?> messages;

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) {
    messages.add(message);
    return super.commit(locator, changeset, expectedHead: expectedHead);
  }
}
