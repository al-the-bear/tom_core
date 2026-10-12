/// Drives a real browser through a passkey enrolment and a passkey sign-in
/// against the live advanced sample — a manual check, run by a person, never
/// scheduled.
///
/// What it proves is the one thing no suite can: the web build of this app,
/// the browser's own WebAuthn, and the live auth server agreeing end to end.
/// The browser is headless Chrome; the authenticator is a CDP virtual one
/// (`WebAuthn.addVirtualAuthenticator`), which is a real platform
/// authenticator as far as the page and the server are concerned — it holds a
/// private key and signs the challenge the server issued.
///
/// The steps, each asserted:
///
///  1. sign in as `erin` (password only — she holds no second factor);
///  2. choose **Passkey** on the offer and **Create passkey**: the browser makes
///     a credential for relying party `localhost`, and the board loads;
///  3. sign out, sign in again: the server now challenges with the passkey;
///  4. **Use passkey**: the browser signs, the board loads, and the
///     authenticator's signature counter has moved.
///
/// Preconditions, all on this machine (see `README_advanced_sample.md`, "A real
/// passkey from a browser"):
///
///  * the auth and app servers running on 8081 / 8080 over a **fresh**
///    `auth_db` — `erin` must not already hold a passkey;
///  * `flutter build web` run in this package, so `build/web` exists;
///  * Google Chrome installed (`CHROME` names its binary when it is not at the
///    platform's default path).
///
/// It serves `build/web` on port 8090 itself — the origin the auth server's
/// relying party allows by default — and starts and stops its own Chrome.
///
/// ```sh
/// dart run tool/drive_passkey_web.dart
/// ```
///
/// The page is drawn on a canvas, so the driver works through Flutter's
/// semantics tree: it turns semantics on, then finds fields and buttons by the
/// labels a screen reader would read, and clicks and types through CDP's input
/// events, as a person's mouse and keyboard would.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _webPort = 8090;
const _debugPort = 9222;
const _username = 'erin';
const _password = 'erin-pass';

Future<void> main() async {
  final webRoot = Directory('build/web');
  if (!File('${webRoot.path}/index.html').existsSync()) {
    _fail(
      'build/web is missing — run `flutter build web` in this package first.',
    );
  }
  await _requireServer('http://localhost:8081/auth', 'auth server');
  await _requireServer('http://localhost:8080/health', 'app server');

  final web = await _serve(webRoot);
  final profile = Directory.systemTemp.createTempSync('passkey_chrome_');
  final chrome = await Process.start(_chromeBinary(), [
    '--headless=new',
    '--remote-debugging-port=$_debugPort',
    '--user-data-dir=${profile.path}',
    '--window-size=1280,900',
    '--no-first-run',
    'about:blank',
  ]);
  var exitCode = 0;
  try {
    final page = await _Cdp.connect();
    await _run(page);
    stdout.writeln(
      '\nPASS — a passkey was enrolled and used from a browser '
      'against the live auth server.',
    );
  } on _Failure catch (failure) {
    stderr.writeln('\nFAIL — ${failure.message}');
    exitCode = 1;
  } finally {
    chrome.kill();
    await web.close(force: true);
    try {
      profile.deleteSync(recursive: true);
    } on FileSystemException {
      // Chrome may still hold the profile for a moment; it is a temp dir.
    }
  }
  exit(exitCode);
}

Future<void> _run(_Cdp page) async {
  await page.send('Runtime.enable');
  await page.send('Page.enable');
  await page.send('WebAuthn.enable');
  final authenticator = await page.send('WebAuthn.addVirtualAuthenticator', {
    'options': {
      'protocol': 'ctap2',
      'transport': 'internal',
      'hasResidentKey': true,
      'hasUserVerification': true,
      'isUserVerified': true,
      'automaticPresenceSimulation': true,
    },
  });
  final authenticatorId = authenticator['authenticatorId'] as String;

  _step('Open the app at http://localhost:$_webPort/');
  await page.send('Page.navigate', {'url': 'http://localhost:$_webPort/'});
  await page.waitFor(_input('Username'), timeout: const Duration(seconds: 60));

  _step('Sign in as $_username (password only)');
  await _signIn(page);
  await page.waitFor(_button('Passkey'));

  _step('Choose Passkey, then Create passkey');
  await page.click(_button('Passkey'));
  await page.waitFor(_button('Create passkey'));
  await page.click(_button('Create passkey'));
  await page.waitFor(_button('Sign out'), timeout: const Duration(seconds: 30));
  final enrolled = await _credentials(page, authenticatorId);
  if (enrolled.length != 1 || enrolled.single['rpId'] != 'localhost') {
    throw _Failure('expected one credential for rpId localhost, got $enrolled');
  }
  final countAfterEnrolment = enrolled.single['signCount'] as int;
  stdout.writeln('   credential created for rpId localhost; board loaded');

  _step('Sign out, then sign in again');
  await page.click(_button('Sign out'));
  await page.waitFor(_input('Username'));
  await _signIn(page);
  await page.waitFor(_button('Use passkey'));
  stdout.writeln('   the server challenged with the passkey');

  _step('Use passkey');
  await page.click(_button('Use passkey'));
  await page.waitFor(_button('Sign out'), timeout: const Duration(seconds: 30));
  final used = await _credentials(page, authenticatorId);
  final countAfterSignIn = used.single['signCount'] as int;
  if (countAfterSignIn <= countAfterEnrolment) {
    throw _Failure(
      'the authenticator did not sign: signCount $countAfterEnrolment -> '
      '$countAfterSignIn',
    );
  }
  stdout.writeln(
    '   signed in with the passkey (signCount $countAfterEnrolment -> '
    '$countAfterSignIn); board loaded',
  );
}

Future<void> _signIn(_Cdp page) async {
  await page.type(_input('Username'), _username);
  await page.type(_input('Password'), _password);
  await page.click(_button('Sign in'));
}

Future<List<Map<String, Object?>>> _credentials(
  _Cdp page,
  String authenticatorId,
) async {
  final result = await page.send('WebAuthn.getCredentials', {
    'authenticatorId': authenticatorId,
  });
  return (result['credentials'] as List).cast<Map<String, Object?>>();
}

/// A semantics button whose label starts with [label].
String _button(String label) =>
    "e.getAttribute('role') === 'button' && t.startsWith(${jsonEncode(label)})";

/// A text field whose accessible label starts with [label].
String _input(String label) =>
    "(e.tagName === 'INPUT' || e.tagName === 'TEXTAREA') && "
    't.startsWith(${jsonEncode(label)})';

void _step(String text) => stdout.writeln('\n-> $text');

Never _fail(String message) {
  stderr.writeln(message);
  exit(2);
}

Future<void> _requireServer(String url, String name) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    await response.drain<void>();
  } on SocketException {
    _fail('The $name is not answering at $url — start the stack first.');
  } finally {
    client.close(force: true);
  }
}

String _chromeBinary() {
  final configured = Platform.environment['CHROME'];
  if (configured != null && configured.isNotEmpty) return configured;
  if (Platform.isMacOS) {
    return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  }
  if (Platform.isWindows) {
    return r'C:\Program Files\Google\Chrome\Application\chrome.exe';
  }
  return 'google-chrome';
}

/// Serves [root] on [_webPort], with `index.html` for the root path.
Future<HttpServer> _serve(Directory root) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _webPort);
  server.listen((request) async {
    var path = request.uri.path;
    if (path.isEmpty || path == '/') path = '/index.html';
    final file = File('${root.path}$path');
    if (!file.existsSync() || path.contains('..')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response.headers.contentType = _contentType(path);
    await request.response.addStream(file.openRead());
    await request.response.close();
  });
  return server;
}

ContentType _contentType(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js') || path.endsWith('.mjs')) {
    return ContentType('text', 'javascript', charset: 'utf-8');
  }
  if (path.endsWith('.json')) return ContentType.json;
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.css')) return ContentType('text', 'css');
  if (path.endsWith('.png')) return ContentType('image', 'png');
  return ContentType.binary;
}

class _Failure implements Exception {
  _Failure(this.message);
  final String message;
}

/// A minimal Chrome DevTools Protocol session on the browser's first page.
class _Cdp {
  _Cdp._(this._socket) {
    _socket.listen((data) {
      final message = jsonDecode(data as String) as Map<String, Object?>;
      final id = message['id'];
      if (id is int && _pending.containsKey(id)) {
        final completer = _pending.remove(id)!;
        if (message['error'] != null) {
          completer.completeError(_Failure('CDP error: ${message['error']}'));
        } else {
          completer.complete(
            (message['result'] as Map?)?.cast<String, Object?>() ?? {},
          );
        }
      }
    });
  }

  final WebSocket _socket;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  var _nextId = 0;

  static Future<_Cdp> connect() async {
    final client = HttpClient();
    try {
      for (var attempt = 0; attempt < 50; attempt++) {
        try {
          final response = await (await client.getUrl(
            Uri.parse('http://127.0.0.1:$_debugPort/json/list'),
          )).close();
          final targets =
              jsonDecode(await response.transform(utf8.decoder).join()) as List;
          final page = targets.cast<Map<String, Object?>>().firstWhere(
            (t) => t['type'] == 'page',
          );
          return _Cdp._(
            await WebSocket.connect(page['webSocketDebuggerUrl'] as String),
          );
        } on SocketException {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        } on StateError {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    } finally {
      client.close(force: true);
    }
    throw _Failure('Chrome did not open a debugging port on $_debugPort');
  }

  Future<Map<String, Object?>> send(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    final id = ++_nextId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return completer.future;
  }

  Future<Object?> _evaluate(String expression) async {
    final result = await send('Runtime.evaluate', {
      'expression': expression,
      'returnByValue': true,
      'awaitPromise': true,
    });
    return (result['result'] as Map)['value'];
  }

  /// The centre of the first semantics node or field matching [predicate],
  /// a JavaScript expression over its normalised label `t` and element `e`;
  /// `null` when there is none. Turns semantics on first, since a Flutter
  /// page exposes no DOM to find anything in until it is asked to.
  Future<List<num>?> _find(String predicate) async {
    final value = await _evaluate('''(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) placeholder.click();
      for (const e of document.querySelectorAll('flt-semantics, input, textarea')) {
        const r = e.getBoundingClientRect();
        if (r.width === 0) continue;
        const t = (e.getAttribute('aria-label') || e.textContent || '').replace(/\\s+/g, ' ').trim();
        if ($predicate) return [r.x + r.width / 2, r.y + r.height / 2];
      }
      return null;
    })()''');
    return value == null ? null : (value as List).cast<num>();
  }

  Future<void> waitFor(
    String predicate, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _find(predicate) != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw _Failure('timed out waiting for: $predicate');
  }

  Future<void> click(String predicate) async {
    final at = await _find(predicate);
    if (at == null) throw _Failure('nothing to click for: $predicate');
    for (final type in ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', {
        'type': type,
        'x': at[0],
        'y': at[1],
        'button': 'left',
        'clickCount': 1,
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> type(String predicate, String text) async {
    await click(predicate);
    await send('Input.insertText', {'text': text});
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
