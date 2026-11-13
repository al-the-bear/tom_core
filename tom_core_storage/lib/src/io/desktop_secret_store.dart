/// The platform secret store for desktop programs without Flutter.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../settings/secret_store.dart';

/// [TomSecretStore] over the OS keychain for plain Dart programs (a CLI, a
/// background service compiled ahead of time), where `flutter_secure_storage`
/// is not available:
///
/// - **macOS**: the login keychain through `/usr/bin/security`. The one call
///   that carries the secret (`add-generic-password`) is sent on the
///   tool's **standard input** (`security -i`), never as an argument: an
///   argument is visible to every user in `ps`.
/// - **Linux**: libsecret through `secret-tool`, the secret on standard
///   input. Without a D-Bus session (an SSH login) or without `secret-tool`
///   the store is not available.
/// - **Windows**: the Credential Manager through `CredWriteW`, `CredReadW`
///   and `CredDeleteW` (`CRED_TYPE_GENERIC`, target `<service>/<handle>`).
///
/// Secrets are stored as base64 of their UTF-8 bytes, so every backend reads
/// them back unambiguously (`security` prints a non-ASCII password as hex).
/// Every call has a [timeout]: a keychain that would wait for a prompt answers
/// as not available instead of hanging. A failing call throws
/// [TomSecretStoreException]; [isAvailable] says beforehand whether the store
/// can be used at all.
final class TomDesktopSecretStore
    implements TomSecretStore, TomSecretStoreAvailability {
  /// The store of [service] (the keychain's service name, e.g.
  /// `tom-secrets-manager`). [operatingSystem] and [environment] default to
  /// this process's.
  TomDesktopSecretStore({
    required this.service,
    this.timeout = const Duration(seconds: 10),
    String? operatingSystem,
    Map<String, String>? environment,
    String securityExecutable = '/usr/bin/security',
    String secretToolExecutable = 'secret-tool',
  }) : _os = operatingSystem ?? Platform.operatingSystem,
       _env = environment ?? Platform.environment,
       _security = securityExecutable,
       _secretTool = secretToolExecutable {
    _checkName(service, 'service');
  }

  /// The keychain's service name.
  final String service;

  /// How long one call may take.
  final Duration timeout;

  final String _os;
  final Map<String, String> _env;
  final String _security;
  final String _secretTool;

  static final RegExp _name = RegExp(r'^[A-Za-z0-9._:@-]{1,200}$');

  static void _checkName(String value, String what) {
    if (!_name.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        what,
        'letters, digits and . _ : @ - only, 1 to 200 characters',
      );
    }
  }

  static String _encode(String secret) => base64.encode(utf8.encode(secret));

  static String _decode(String stored) =>
      utf8.decode(base64.decode(stored.trim()));

  /// Whether the keychain can be used now: a probe item is written and
  /// deleted. A locked keychain, a missing D-Bus session or tool, or a
  /// Windows logon without credentials answer false; never a prompt.
  @override
  Future<bool> isAvailable() async {
    if (_os == 'linux' && (_env['DBUS_SESSION_BUS_ADDRESS'] ?? '').isEmpty) {
      return false;
    }
    const probe = 'tom.availability-probe';
    try {
      await write(probe, 'probe');
      final back = await read(probe);
      await delete(probe);
      return back == 'probe';
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> read(String handle) async {
    _checkName(handle, 'handle');
    try {
      final stored = switch (_os) {
        'macos' => await _macRead(handle),
        'windows' => _windowsRead(handle),
        _ => await _linuxRead(handle),
      };
      return stored == null ? null : _decode(stored);
    } on TomSecretStoreException {
      rethrow;
    } on Object catch (e) {
      throw TomSecretStoreException(TomSecretStoreStep.read, e);
    }
  }

  @override
  Future<void> write(String handle, String secret) async {
    _checkName(handle, 'handle');
    try {
      final stored = _encode(secret);
      switch (_os) {
        case 'macos':
          await _macWrite(handle, stored);
        case 'windows':
          _windowsWrite(handle, stored);
        default:
          await _linuxWrite(handle, stored);
      }
    } on TomSecretStoreException {
      rethrow;
    } on Object catch (e) {
      throw TomSecretStoreException(TomSecretStoreStep.write, e);
    }
  }

  @override
  Future<void> delete(String handle) async {
    _checkName(handle, 'handle');
    try {
      switch (_os) {
        case 'macos':
          await _run(
            _security,
            ['delete-generic-password', '-a', handle, '-s', service],
            TomSecretStoreStep.write,
            okCodes: const {0, 44},
          );
        case 'windows':
          _windowsDelete(handle);
        default:
          await _run(_secretTool, [
            'clear',
            'service',
            service,
            'handle',
            handle,
          ], TomSecretStoreStep.write);
      }
    } on TomSecretStoreException {
      rethrow;
    } on Object catch (e) {
      throw TomSecretStoreException(TomSecretStoreStep.write, e);
    }
  }

  // ── Running a tool with a timeout ────────────────────────────────────────

  Future<ProcessResult> _run(
    String executable,
    List<String> args,
    TomSecretStoreStep step, {
    String? input,
    Set<int> okCodes = const {0},
  }) async {
    final process = await Process.start(
      executable,
      args,
      environment: _env,
      includeParentEnvironment: false,
    );
    final out = process.stdout.transform(utf8.decoder).join();
    final err = process.stderr.transform(utf8.decoder).join();
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
    final int code;
    try {
      code = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw TomSecretStoreException(
        step,
        TimeoutException('$executable did not answer', timeout),
      );
    }
    final result = ProcessResult(process.pid, code, await out, await err);
    if (!okCodes.contains(code)) {
      throw TomSecretStoreException(
        step,
        ProcessException(executable, [args.first], 'exit code $code', code),
      );
    }
    return result;
  }

  // ── macOS ────────────────────────────────────────────────────────────────

  Future<String?> _macRead(String handle) async {
    final result = await _run(
      _security,
      ['find-generic-password', '-a', handle, '-s', service, '-w'],
      TomSecretStoreStep.read,
      okCodes: const {0, 44},
    );
    // 44: errSecItemNotFound.
    return result.exitCode == 44 ? null : result.stdout as String;
  }

  Future<void> _macWrite(String handle, String stored) async {
    final hex = utf8
        .encode(stored)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    // The command goes in on standard input: an argument would show the
    // secret in `ps`. -U replaces an existing item.
    await _run(
      _security,
      ['-i'],
      TomSecretStoreStep.write,
      input: 'add-generic-password -U -a $handle -s $service -X $hex\n',
    );
  }

  // ── Linux ────────────────────────────────────────────────────────────────

  void _checkDbus(TomSecretStoreStep step) {
    if ((_env['DBUS_SESSION_BUS_ADDRESS'] ?? '').isEmpty) {
      throw TomSecretStoreException(
        step,
        const OSError('no D-Bus session: the keychain is not available'),
      );
    }
  }

  Future<String?> _linuxRead(String handle) async {
    _checkDbus(TomSecretStoreStep.read);
    final result = await _run(
      _secretTool,
      ['lookup', 'service', service, 'handle', handle],
      TomSecretStoreStep.read,
      okCodes: const {0, 1},
    );
    final stdoutText = (result.stdout as String).trim();
    if (result.exitCode == 1) {
      // secret-tool answers a miss with exit code 1 and no output; a failure
      // also exits 1, but says why on standard error.
      if ((result.stderr as String).trim().isNotEmpty) {
        throw TomSecretStoreException(
          TomSecretStoreStep.read,
          ProcessException(_secretTool, const [
            'lookup',
          ], result.stderr as String),
        );
      }
      return null;
    }
    return stdoutText.isEmpty ? null : stdoutText;
  }

  Future<void> _linuxWrite(String handle, String stored) async {
    _checkDbus(TomSecretStoreStep.write);
    await _run(
      _secretTool,
      [
        'store',
        '--label=$service $handle',
        'service',
        service,
        'handle',
        handle,
      ],
      TomSecretStoreStep.write,
      input: stored,
    );
  }

  // ── Windows ──────────────────────────────────────────────────────────────

  static const int _credTypeGeneric = 1;
  static const int _credPersistLocalMachine = 2;

  String _target(String handle) => '$service/$handle';

  static DynamicLibrary get _advapi => DynamicLibrary.open('advapi32.dll');

  String? _windowsRead(String handle) {
    final credRead = _advapi
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16>,
            Uint32,
            Uint32,
            Pointer<Pointer<_Credential>>,
          ),
          int Function(Pointer<Utf16>, int, int, Pointer<Pointer<_Credential>>)
        >('CredReadW');
    final credFree = _advapi
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('CredFree');
    final target = _target(handle).toNativeUtf16();
    final out = calloc<Pointer<_Credential>>();
    try {
      // A failed read is a miss: the runtime does not keep GetLastError for
      // Dart, so a missing item and an unreadable store look the same here;
      // isAvailable tells the second apart beforehand.
      if (credRead(target, _credTypeGeneric, 0, out) == 0) return null;
      final cred = out.value.ref;
      final bytes = Uint8List.fromList(
        cred.credentialBlob.asTypedList(cred.credentialBlobSize),
      );
      credFree(out.value.cast());
      return utf8.decode(bytes);
    } finally {
      calloc.free(target);
      calloc.free(out);
    }
  }

  void _windowsWrite(String handle, String stored) {
    final credWrite = _advapi
        .lookupFunction<
          Int32 Function(Pointer<_Credential>, Uint32),
          int Function(Pointer<_Credential>, int)
        >('CredWriteW');
    final target = _target(handle).toNativeUtf16();
    final user = handle.toNativeUtf16();
    final blobBytes = utf8.encode(stored);
    final blob = calloc<Uint8>(blobBytes.length);
    final cred = calloc<_Credential>();
    try {
      blob.asTypedList(blobBytes.length).setAll(0, blobBytes);
      cred.ref
        ..type = _credTypeGeneric
        ..targetName = target
        ..credentialBlobSize = blobBytes.length
        ..credentialBlob = blob
        ..persist = _credPersistLocalMachine
        ..userName = user;
      if (credWrite(cred, 0) == 0) {
        throw TomSecretStoreException(
          TomSecretStoreStep.write,
          const OSError('CredWriteW failed'),
        );
      }
    } finally {
      blob.asTypedList(blobBytes.length).fillRange(0, blobBytes.length, 0);
      calloc
        ..free(blob)
        ..free(cred)
        ..free(target)
        ..free(user);
    }
  }

  void _windowsDelete(String handle) {
    final credDelete = _advapi
        .lookupFunction<
          Int32 Function(Pointer<Utf16>, Uint32, Uint32),
          int Function(Pointer<Utf16>, int, int)
        >('CredDeleteW');
    final target = _target(handle).toNativeUtf16();
    try {
      // A delete of a missing item fails too; forgetting nothing is fine.
      credDelete(target, _credTypeGeneric, 0);
    } finally {
      calloc.free(target);
    }
  }
}

/// `FILETIME`.
final class _FileTime extends Struct {
  @Uint32()
  external int low;

  @Uint32()
  external int high;
}

/// `CREDENTIALW`.
final class _Credential extends Struct {
  @Uint32()
  external int flags;

  @Uint32()
  external int type;

  external Pointer<Utf16> targetName;

  external Pointer<Utf16> comment;

  external _FileTime lastWritten;

  @Uint32()
  external int credentialBlobSize;

  external Pointer<Uint8> credentialBlob;

  @Uint32()
  external int persist;

  @Uint32()
  external int attributeCount;

  external Pointer<Void> attributes;

  external Pointer<Utf16> targetAlias;

  external Pointer<Utf16> userName;
}
