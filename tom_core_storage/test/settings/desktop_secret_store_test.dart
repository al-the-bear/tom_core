/// `TomDesktopSecretStore`: the OS keychain for programs without Flutter.
///
/// On a machine whose keychain answers (a macOS login session, a Linux
/// desktop with libsecret, a Windows logon with the Credential Manager) the
/// store round-trips a demo secret. Everywhere: the secret never appears on a
/// tool's command line (a fake `security` records what it was given), a Linux
/// session without D-Bus answers "not available" at once, and a tool that
/// does not answer runs into the timeout instead of hanging.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/settings.dart';

const service = 'tom-core-storage-test';

void main() {
  group('the real keychain of this machine', () {
    final store = TomDesktopSecretStore(service: service);
    late bool available;
    final handle = 'test.${pid}.${DateTime.now().microsecondsSinceEpoch}';

    setUpAll(() async {
      available = await store.isAvailable();
    });

    tearDownAll(() async {
      if (available) await store.delete(handle);
    });

    test('a demo secret written, read, replaced, deleted', () async {
      if (!available) {
        markTestSkipped('no keychain answers in this session');
        return;
      }
      expect(await store.read(handle), isNull);
      await store.write(handle, 'demo-secret-1');
      expect(await store.read(handle), 'demo-secret-1');
      const tricky = 'ü "quoted" \\back slash\n-X 00 \u{1F511}';
      await store.write(handle, tricky);
      expect(await store.read(handle), tricky, reason: 'replaced, any text');
      await store.delete(handle);
      expect(await store.read(handle), isNull);
      await store.delete(handle); // forgetting nothing is fine
    });

    test('the availability probe leaves nothing behind', () async {
      if (!available) {
        markTestSkipped('no keychain answers in this session');
        return;
      }
      expect(await store.read('tom.availability-probe'), isNull);
    });
  });

  test('handles and service names are checked', () {
    expect(
      () => TomDesktopSecretStore(service: 'has space'),
      throwsArgumentError,
    );
    final store = TomDesktopSecretStore(service: service);
    expect(() => store.read('a"b'), throwsArgumentError);
    expect(() => store.write('a b', 's'), throwsArgumentError);
    expect(() => store.delete(''), throwsArgumentError);
  });

  group('without a real keychain', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tomkc');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    String fake(String name, String body) {
      final file = File('${dir.path}/$name')
        ..writeAsStringSync('#!/bin/bash\n$body\n');
      Process.runSync('chmod', ['+x', file.path]);
      return file.path;
    }

    test('macOS: the secret goes on standard input, never on the command '
        'line', () async {
      final security = fake(
        'security',
        'printf "%s\\n" "\$@" > "${dir.path}/args"; '
            'cat > "${dir.path}/stdin"; exit 0',
      );
      final store = TomDesktopSecretStore(
        service: service,
        operatingSystem: 'macos',
        securityExecutable: security,
      );
      await store.write('demo.handle', 'super-secret-value');
      final args = File('${dir.path}/args').readAsStringSync();
      final stdin = File('${dir.path}/stdin').readAsStringSync();
      expect(args.trim(), '-i');
      expect(args, isNot(contains('super-secret')));
      final hex = utf8
          .encode(base64.encode(utf8.encode('super-secret-value')))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(
        stdin,
        'add-generic-password -U -a demo.handle -s $service -X $hex\n',
      );
    }, testOn: '!windows');

    test('macOS: a miss (exit 44) is null, another failure throws', () async {
      final miss = TomDesktopSecretStore(
        service: service,
        operatingSystem: 'macos',
        securityExecutable: fake('security', 'exit 44'),
      );
      expect(await miss.read('demo.handle'), isNull);
      final locked = TomDesktopSecretStore(
        service: service,
        operatingSystem: 'macos',
        securityExecutable: fake('security2', 'exit 36'),
      );
      await expectLater(
        locked.read('demo.handle'),
        throwsA(isA<TomSecretStoreException>()),
      );
      expect(await locked.isAvailable(), isFalse);
    }, testOn: '!windows');

    test('Linux without a D-Bus session: not available at once', () async {
      final store = TomDesktopSecretStore(
        service: service,
        operatingSystem: 'linux',
        environment: const {'PATH': '/usr/bin:/bin'},
        secretToolExecutable: fake('secret-tool', 'sleep 60'),
      );
      final watch = Stopwatch()..start();
      expect(await store.isAvailable(), isFalse);
      await expectLater(
        store.read('demo.handle'),
        throwsA(isA<TomSecretStoreException>()),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    }, testOn: '!windows');

    test('Linux: a tool that does not answer runs into the timeout', () async {
      final store = TomDesktopSecretStore(
        service: service,
        operatingSystem: 'linux',
        environment: const {
          'PATH': '/usr/bin:/bin',
          'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent',
        },
        timeout: const Duration(milliseconds: 300),
        secretToolExecutable: fake('secret-tool', 'sleep 60'),
      );
      final watch = Stopwatch()..start();
      await expectLater(
        store.read('demo.handle'),
        throwsA(isA<TomSecretStoreException>()),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(await store.isAvailable(), isFalse);
    }, testOn: '!windows');

    test('Linux: secret-tool\'s miss (exit 1, nothing said) is null; the '
        'secret goes on standard input', () async {
      final store = TomDesktopSecretStore(
        service: service,
        operatingSystem: 'linux',
        environment: const {
          'PATH': '/usr/bin:/bin',
          'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/x',
        },
        secretToolExecutable: fake(
          'secret-tool',
          'printf "%s\\n" "\$@" > "${dir.path}/args"; '
              'cat > "${dir.path}/stdin"; [ "\$1" = lookup ] && exit 1; exit 0',
        ),
      );
      expect(await store.read('demo.handle'), isNull);
      await store.write('demo.handle', 'linux-secret');
      expect(
        File('${dir.path}/args').readAsStringSync(),
        isNot(contains('linux-secret')),
      );
      expect(
        File('${dir.path}/stdin').readAsStringSync(),
        base64.encode(utf8.encode('linux-secret')),
      );
    }, testOn: '!windows');
  });
}
