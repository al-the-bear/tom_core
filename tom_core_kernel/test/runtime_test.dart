import 'package:test/test.dart';
import 'package:http/http.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Test Implementations
// =============================================================================

/// A mock implementation of [TomPlatformUtils] for testing.
///
/// This implementation allows configuring all platform detection methods
/// and provides working implementations for all abstract methods.
class MockPlatformUtils extends TomPlatformUtils {
  final bool _isDesktop;
  final bool _isMobile;
  final bool _isWeb;
  final bool _isWindows;
  final bool _isLinux;
  final bool _isMacOs;
  final bool _isFuchsia;
  final bool _isAndroid;
  final bool _isIos;
  final String _browserLocation;
  final String _isolateName;
  final List<String> outputMessages = [];
  final List<String> errorMessages = [];

  MockPlatformUtils({
    bool isDesktop = false,
    bool isMobile = false,
    bool isWeb = false,
    bool isWindows = false,
    bool isLinux = false,
    bool isMacOs = false,
    bool isFuchsia = false,
    bool isAndroid = false,
    bool isIos = false,
    String browserLocation = '',
    String isolateName = 'test-isolate',
  }) : _isDesktop = isDesktop,
       _isMobile = isMobile,
       _isWeb = isWeb,
       _isWindows = isWindows,
       _isLinux = isLinux,
       _isMacOs = isMacOs,
       _isFuchsia = isFuchsia,
       _isAndroid = isAndroid,
       _isIos = isIos,
       _browserLocation = browserLocation,
       _isolateName = isolateName;

  @override
  bool isDesktop() => _isDesktop;

  @override
  bool isMobile() => _isMobile;

  @override
  bool isWeb() => _isWeb;

  @override
  bool isWindows() => _isWindows;

  @override
  bool isLinux() => _isLinux;

  @override
  bool isMacOs() => _isMacOs;

  @override
  bool isFuchsia() => _isFuchsia;

  @override
  bool isAndroid() => _isAndroid;

  @override
  bool isIos() => _isIos;

  @override
  String? getBrowserLocation() => _browserLocation;

  @override
  String getIsolateName() => _isolateName;

  @override
  void out(String s) {
    outputMessages.add(s);
  }

  @override
  void outError(String s) {
    errorMessages.add(s);
  }

  @override
  Client httpClient() {
    return Client();
  }
}

/// A mock platform simulating a desktop macOS environment.
class MacOsDesktopPlatformUtils extends MockPlatformUtils {
  MacOsDesktopPlatformUtils()
    : super(
        isDesktop: true,
        isMobile: false,
        isWeb: false,
        isMacOs: true,
        isWindows: false,
        isLinux: false,
      );
}

/// A mock platform simulating a mobile Android environment.
class AndroidMobilePlatformUtils extends MockPlatformUtils {
  AndroidMobilePlatformUtils()
    : super(
        isDesktop: false,
        isMobile: true,
        isWeb: false,
        isAndroid: true,
        isIos: false,
      );
}

/// A mock platform simulating a web browser environment.
class WebBrowserPlatformUtils extends MockPlatformUtils {
  WebBrowserPlatformUtils({super.browserLocation = 'https://example.com'})
    : super(isDesktop: false, isMobile: false, isWeb: true);
}

void main() {
  // ===========================================================================
  // TomPlatformUtils Tests
  // ===========================================================================
  group('TomPlatformUtils', () {
    // Reset to fallback implementation before each test
    setUp(() {
      TomPlatformUtils.setCurrentPlatform(TomFallbackPlatformUtils());
      TomPlatformUtils.envVars = {};
    });

    // -------------------------------------------------------------------------
    // Static Fields
    // -------------------------------------------------------------------------
    group('envVars', () {
      test('should be empty by default', () {
        expect(TomPlatformUtils.envVars, isEmpty);
      });

      test('should allow setting key-value pairs', () {
        TomPlatformUtils.envVars['API_URL'] = 'https://api.example.com';
        TomPlatformUtils.envVars['DEBUG'] = 'true';

        expect(
          TomPlatformUtils.envVars['API_URL'],
          equals('https://api.example.com'),
        );
        expect(TomPlatformUtils.envVars['DEBUG'], equals('true'));
      });

      test('should allow overwriting existing values', () {
        TomPlatformUtils.envVars['KEY'] = 'original';
        TomPlatformUtils.envVars['KEY'] = 'updated';

        expect(TomPlatformUtils.envVars['KEY'], equals('updated'));
      });

      test('should allow clearing all values', () {
        TomPlatformUtils.envVars['KEY1'] = 'value1';
        TomPlatformUtils.envVars['KEY2'] = 'value2';
        TomPlatformUtils.envVars.clear();

        expect(TomPlatformUtils.envVars, isEmpty);
      });

      test('should allow replacing entire map', () {
        TomPlatformUtils.envVars['OLD_KEY'] = 'old_value';
        TomPlatformUtils.envVars = {'NEW_KEY': 'new_value'};

        expect(TomPlatformUtils.envVars.containsKey('OLD_KEY'), isFalse);
        expect(TomPlatformUtils.envVars['NEW_KEY'], equals('new_value'));
      });
    });

    // -------------------------------------------------------------------------
    // Static Methods
    // -------------------------------------------------------------------------
    group('setCurrentPlatform', () {
      test('should set the current platform implementation', () {
        final mockPlatform = MockPlatformUtils(isDesktop: true);
        TomPlatformUtils.setCurrentPlatform(mockPlatform);

        expect(TomPlatformUtils.current, same(mockPlatform));
      });

      test('should allow changing platform implementation multiple times', () {
        final platform1 = MockPlatformUtils(isDesktop: true);
        final platform2 = MockPlatformUtils(isMobile: true);

        TomPlatformUtils.setCurrentPlatform(platform1);
        expect(TomPlatformUtils.current, same(platform1));

        TomPlatformUtils.setCurrentPlatform(platform2);
        expect(TomPlatformUtils.current, same(platform2));
      });

      test('should allow setting back to fallback implementation', () {
        final mockPlatform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(mockPlatform);
        TomPlatformUtils.setCurrentPlatform(TomFallbackPlatformUtils());

        expect(TomPlatformUtils.current, isA<TomFallbackPlatformUtils>());
      });
    });

    group('current', () {
      test('should return TomFallbackPlatformUtils by default', () {
        expect(TomPlatformUtils.current, isA<TomFallbackPlatformUtils>());
      });

      test('should return the implementation set via setCurrentPlatform', () {
        final mockPlatform = MacOsDesktopPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(mockPlatform);

        expect(TomPlatformUtils.current, same(mockPlatform));
        expect(TomPlatformUtils.current.isDesktop(), isTrue);
        expect(TomPlatformUtils.current.isMacOs(), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Instance Methods - Environment Detection
    // -------------------------------------------------------------------------
    group('environment type detection', () {
      test('should detect desktop environment correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isDesktop: true, isMobile: false, isWeb: false),
        );

        expect(TomPlatformUtils.current.isDesktop(), isTrue);
        expect(TomPlatformUtils.current.isMobile(), isFalse);
        expect(TomPlatformUtils.current.isWeb(), isFalse);
      });

      test('should detect mobile environment correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isDesktop: false, isMobile: true, isWeb: false),
        );

        expect(TomPlatformUtils.current.isDesktop(), isFalse);
        expect(TomPlatformUtils.current.isMobile(), isTrue);
        expect(TomPlatformUtils.current.isWeb(), isFalse);
      });

      test('should detect web environment correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isDesktop: false, isMobile: false, isWeb: true),
        );

        expect(TomPlatformUtils.current.isDesktop(), isFalse);
        expect(TomPlatformUtils.current.isMobile(), isFalse);
        expect(TomPlatformUtils.current.isWeb(), isTrue);
      });
    });

    group('desktop OS detection', () {
      test('should detect Windows correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isDesktop: true, isWindows: true),
        );

        expect(TomPlatformUtils.current.isWindows(), isTrue);
        expect(TomPlatformUtils.current.isLinux(), isFalse);
        expect(TomPlatformUtils.current.isMacOs(), isFalse);
        expect(TomPlatformUtils.current.isFuchsia(), isFalse);
      });

      test('should detect Linux correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isDesktop: true, isLinux: true),
        );

        expect(TomPlatformUtils.current.isWindows(), isFalse);
        expect(TomPlatformUtils.current.isLinux(), isTrue);
        expect(TomPlatformUtils.current.isMacOs(), isFalse);
        expect(TomPlatformUtils.current.isFuchsia(), isFalse);
      });

      test('should detect macOS correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isDesktop: true, isMacOs: true),
        );

        expect(TomPlatformUtils.current.isWindows(), isFalse);
        expect(TomPlatformUtils.current.isLinux(), isFalse);
        expect(TomPlatformUtils.current.isMacOs(), isTrue);
        expect(TomPlatformUtils.current.isFuchsia(), isFalse);
      });

      test('should detect Fuchsia correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isDesktop: true, isFuchsia: true),
        );

        expect(TomPlatformUtils.current.isWindows(), isFalse);
        expect(TomPlatformUtils.current.isLinux(), isFalse);
        expect(TomPlatformUtils.current.isMacOs(), isFalse);
        expect(TomPlatformUtils.current.isFuchsia(), isTrue);
      });
    });

    group('mobile OS detection', () {
      test('should detect Android correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isMobile: true, isAndroid: true),
        );

        expect(TomPlatformUtils.current.isAndroid(), isTrue);
        expect(TomPlatformUtils.current.isIos(), isFalse);
      });

      test('should detect iOS correctly', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isMobile: true, isIos: true),
        );

        expect(TomPlatformUtils.current.isAndroid(), isFalse);
        expect(TomPlatformUtils.current.isIos(), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Instance Methods - Environment Variables
    // -------------------------------------------------------------------------
    group('getTomEnvVars', () {
      test('should return empty map when no envVars set', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        expect(platform.getTomEnvVars(), isEmpty);
      });

      test('should return configured environment variables', () {
        TomPlatformUtils.envVars = {
          'API_KEY': 'secret123',
          'ENV': 'development',
        };
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        final envVars = platform.getTomEnvVars();
        expect(envVars['API_KEY'], equals('secret123'));
        expect(envVars['ENV'], equals('development'));
      });

      test('should return same reference as static envVars', () {
        TomPlatformUtils.envVars['KEY'] = 'value';
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        expect(platform.getTomEnvVars(), same(TomPlatformUtils.envVars));
      });

      test('should reflect changes to static envVars', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        TomPlatformUtils.envVars['DYNAMIC'] = 'value1';
        expect(platform.getTomEnvVars()['DYNAMIC'], equals('value1'));

        TomPlatformUtils.envVars['DYNAMIC'] = 'value2';
        expect(platform.getTomEnvVars()['DYNAMIC'], equals('value2'));
      });
    });

    // -------------------------------------------------------------------------
    // Instance Methods - Browser & Isolate
    // -------------------------------------------------------------------------
    group('getBrowserLocation', () {
      test('should return configured browser location', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(browserLocation: 'https://myapp.example.com/page'),
        );

        expect(
          TomPlatformUtils.current.getBrowserLocation(),
          equals('https://myapp.example.com/page'),
        );
      });

      test('should return empty string when no location set', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(browserLocation: ''),
        );

        expect(TomPlatformUtils.current.getBrowserLocation(), equals(''));
      });

      test('should return full URL with query parameters', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(
            browserLocation: 'https://app.com?token=abc&page=1',
          ),
        );

        expect(
          TomPlatformUtils.current.getBrowserLocation(),
          equals('https://app.com?token=abc&page=1'),
        );
      });
    });

    group('getIsolateName', () {
      test('should return configured isolate name', () {
        TomPlatformUtils.setCurrentPlatform(
          MockPlatformUtils(isolateName: 'worker-1'),
        );

        expect(TomPlatformUtils.current.getIsolateName(), equals('worker-1'));
      });

      test('should return empty string when no isolate name set', () {
        TomPlatformUtils.setCurrentPlatform(MockPlatformUtils(isolateName: ''));

        expect(TomPlatformUtils.current.getIsolateName(), equals(''));
      });

      test('should return default test-isolate name', () {
        TomPlatformUtils.setCurrentPlatform(MockPlatformUtils());

        expect(
          TomPlatformUtils.current.getIsolateName(),
          equals('test-isolate'),
        );
      });
    });

    // -------------------------------------------------------------------------
    // Instance Methods - Console Output
    // -------------------------------------------------------------------------
    group('out', () {
      test('should capture output messages', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        platform.out('Hello, World!');

        expect(platform.outputMessages, contains('Hello, World!'));
      });

      test('should capture multiple output messages in order', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);
        platform.outputMessages
            .clear(); // Clear logging output from setCurrentPlatform

        platform.out('First');
        platform.out('Second');
        platform.out('Third');

        expect(platform.outputMessages, equals(['First', 'Second', 'Third']));
      });

      test('should handle empty string output', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        platform.out('');

        expect(platform.outputMessages, contains(''));
      });
    });

    group('outError', () {
      test('should capture error messages', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        platform.outError('Error occurred!');

        expect(platform.errorMessages, contains('Error occurred!'));
      });

      test('should capture multiple error messages in order', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        platform.outError('Error 1');
        platform.outError('Error 2');

        expect(platform.errorMessages, equals(['Error 1', 'Error 2']));
      });

      test('should keep output and error messages separate', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);
        platform.outputMessages
            .clear(); // Clear logging output from setCurrentPlatform

        platform.out('Regular message');
        platform.outError('Error message');

        expect(platform.outputMessages, equals(['Regular message']));
        expect(platform.errorMessages, equals(['Error message']));
      });
    });

    // -------------------------------------------------------------------------
    // Instance Methods - HTTP Client
    // -------------------------------------------------------------------------
    group('httpClient', () {
      test('should return a Client instance', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        final client = platform.httpClient();

        expect(client, isA<Client>());
      });

      test('should return new client instance on each call', () {
        final platform = MockPlatformUtils();
        TomPlatformUtils.setCurrentPlatform(platform);

        final client1 = platform.httpClient();
        final client2 = platform.httpClient();

        expect(client1, isNot(same(client2)));
      });
    });

    // -------------------------------------------------------------------------
    // Preset Platform Implementations
    // -------------------------------------------------------------------------
    group('MacOsDesktopPlatformUtils', () {
      test('should report as desktop platform', () {
        final platform = MacOsDesktopPlatformUtils();

        expect(platform.isDesktop(), isTrue);
        expect(platform.isMobile(), isFalse);
        expect(platform.isWeb(), isFalse);
      });

      test('should report as macOS operating system', () {
        final platform = MacOsDesktopPlatformUtils();

        expect(platform.isMacOs(), isTrue);
        expect(platform.isWindows(), isFalse);
        expect(platform.isLinux(), isFalse);
      });
    });

    group('AndroidMobilePlatformUtils', () {
      test('should report as mobile platform', () {
        final platform = AndroidMobilePlatformUtils();

        expect(platform.isDesktop(), isFalse);
        expect(platform.isMobile(), isTrue);
        expect(platform.isWeb(), isFalse);
      });

      test('should report as Android operating system', () {
        final platform = AndroidMobilePlatformUtils();

        expect(platform.isAndroid(), isTrue);
        expect(platform.isIos(), isFalse);
      });
    });

    group('WebBrowserPlatformUtils', () {
      test('should report as web platform', () {
        final platform = WebBrowserPlatformUtils();

        expect(platform.isDesktop(), isFalse);
        expect(platform.isMobile(), isFalse);
        expect(platform.isWeb(), isTrue);
      });

      test('should return configured browser location', () {
        final platform = WebBrowserPlatformUtils(
          browserLocation: 'https://custom.example.com/path',
        );

        expect(
          platform.getBrowserLocation(),
          equals('https://custom.example.com/path'),
        );
      });

      test('should use default browser location', () {
        final platform = WebBrowserPlatformUtils();

        expect(platform.getBrowserLocation(), equals('https://example.com'));
      });
    });
  });

  // ===========================================================================
  // TomFallbackPlatformUtils Tests
  // ===========================================================================
  group('TomFallbackPlatformUtils', () {
    late TomFallbackPlatformUtils fallback;

    setUp(() {
      fallback = TomFallbackPlatformUtils();
    });

    // -------------------------------------------------------------------------
    // Working Methods
    // -------------------------------------------------------------------------
    group('getBrowserLocation', () {
      test('should return empty string', () {
        expect(fallback.getBrowserLocation(), equals(''));
      });
    });

    group('getIsolateName', () {
      test('should return empty string', () {
        expect(fallback.getIsolateName(), equals(''));
      });
    });

    group('out', () {
      test('should not throw when called', () {
        expect(() => fallback.out('test message'), returnsNormally);
      });

      test('should accept empty string', () {
        expect(() => fallback.out(''), returnsNormally);
      });
    });

    group('outError', () {
      test('should not throw when called', () {
        expect(() => fallback.outError('error message'), returnsNormally);
      });

      test('should accept empty string', () {
        expect(() => fallback.outError(''), returnsNormally);
      });
    });

    group('getTomEnvVars', () {
      test('should return static envVars map', () {
        TomPlatformUtils.envVars = {'FALLBACK_KEY': 'fallback_value'};

        expect(
          fallback.getTomEnvVars()['FALLBACK_KEY'],
          equals('fallback_value'),
        );
      });
    });

    // -------------------------------------------------------------------------
    // Unimplemented Methods - Environment Type Detection
    // -------------------------------------------------------------------------
    group('isDesktop', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isDesktop(), throwsA(isA<UnimplementedError>()));
      });
    });

    group('isMobile', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isMobile(), throwsA(isA<UnimplementedError>()));
      });
    });

    group('isWeb', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isWeb(), throwsA(isA<UnimplementedError>()));
      });
    });

    // -------------------------------------------------------------------------
    // Unimplemented Methods - Desktop OS Detection
    // -------------------------------------------------------------------------
    group('isWindows', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isWindows(), throwsA(isA<UnimplementedError>()));
      });
    });

    group('isLinux', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isLinux(), throwsA(isA<UnimplementedError>()));
      });
    });

    group('isMacOs', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isMacOs(), throwsA(isA<UnimplementedError>()));
      });
    });

    group('isFuchsia', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isFuchsia(), throwsA(isA<UnimplementedError>()));
      });
    });

    // -------------------------------------------------------------------------
    // Unimplemented Methods - Mobile OS Detection
    // -------------------------------------------------------------------------
    group('isAndroid', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isAndroid(), throwsA(isA<UnimplementedError>()));
      });
    });

    group('isIos', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.isIos(), throwsA(isA<UnimplementedError>()));
      });
    });

    // -------------------------------------------------------------------------
    // Unimplemented Methods - HTTP Client
    // -------------------------------------------------------------------------
    group('httpClient', () {
      test('should throw UnimplementedError', () {
        expect(() => fallback.httpClient(), throwsA(isA<UnimplementedError>()));
      });
    });
  });

  // ===========================================================================
  // Integration Tests
  // ===========================================================================
  group('Platform Switching Integration', () {
    setUp(() {
      TomPlatformUtils.setCurrentPlatform(TomFallbackPlatformUtils());
      TomPlatformUtils.envVars = {};
    });

    test('should switch between different platform implementations', () {
      // Start with desktop
      TomPlatformUtils.setCurrentPlatform(MacOsDesktopPlatformUtils());
      expect(TomPlatformUtils.current.isDesktop(), isTrue);
      expect(TomPlatformUtils.current.isMacOs(), isTrue);

      // Switch to mobile
      TomPlatformUtils.setCurrentPlatform(AndroidMobilePlatformUtils());
      expect(TomPlatformUtils.current.isMobile(), isTrue);
      expect(TomPlatformUtils.current.isAndroid(), isTrue);

      // Switch to web
      TomPlatformUtils.setCurrentPlatform(WebBrowserPlatformUtils());
      expect(TomPlatformUtils.current.isWeb(), isTrue);
    });

    test('should preserve envVars across platform switches', () {
      TomPlatformUtils.envVars['PERSISTENT_KEY'] = 'persistent_value';

      TomPlatformUtils.setCurrentPlatform(MacOsDesktopPlatformUtils());
      expect(
        TomPlatformUtils.current.getTomEnvVars()['PERSISTENT_KEY'],
        equals('persistent_value'),
      );

      TomPlatformUtils.setCurrentPlatform(AndroidMobilePlatformUtils());
      expect(
        TomPlatformUtils.current.getTomEnvVars()['PERSISTENT_KEY'],
        equals('persistent_value'),
      );
    });

    test('should allow runtime configuration of platform detection', () {
      // Simulate detecting platform at runtime
      const simulatedPlatform = 'macos';

      late TomPlatformUtils platform;
      switch (simulatedPlatform) {
        case 'macos':
          platform = MacOsDesktopPlatformUtils();
        case 'android':
          platform = AndroidMobilePlatformUtils();
        case 'web':
          platform = WebBrowserPlatformUtils();
        default:
          platform = TomFallbackPlatformUtils();
      }

      TomPlatformUtils.setCurrentPlatform(platform);
      expect(TomPlatformUtils.current.isDesktop(), isTrue);
      expect(TomPlatformUtils.current.isMacOs(), isTrue);
    });
  });

  // ==========================================================================
  // TomEnvironment Tests
  // ==========================================================================
  group('TomEnvironment', () {
    test('should create environment with name', () {
      const env = TomEnvironment('test');

      expect(env.env, equals('test'));
      expect(env.parent, isNull);
      expect(env.isTest, isFalse);
      expect(env.isDevelopment, isFalse);
    });

    test('should create environment with parent', () {
      const parent = TomEnvironment('parent');
      const child = TomEnvironment('child', parent: parent);

      expect(child.parent, equals(parent));
      expect(child.parent?.env, equals('parent'));
    });

    test('should create test environment', () {
      const env = TomEnvironment('test-env', isTest: true);

      expect(env.isTest, isTrue);
    });

    test('should create development environment', () {
      const env = TomEnvironment('dev-env', isDevelopment: true);

      expect(env.isDevelopment, isTrue);
    });

    test('should call initializer when initialize() is called', () {
      var called = false;
      final env = TomEnvironment(
        'init-env',
        initializer: (e) {
          called = true;
        },
      );

      expect(called, isFalse);
      env.initialize();
      expect(called, isTrue);
    });

    test('should have correct toString representation', () {
      const env = TomEnvironment('test');
      final str = env.toString();

      expect(str, contains('TomEnvironment'));
      expect(str, contains('test'));
    });
  });

  // ==========================================================================
  // TomPlatform Tests
  // ==========================================================================
  group('TomPlatform', () {
    test('should create platform with name', () {
      const platform = TomPlatform('custom');

      expect(platform.name, equals('custom'));
    });

    test('should have correct built-in platform names', () {
      expect(platformWeb.name, equals('web'));
      expect(platformMacos.name, equals('macos'));
      expect(platformWindows.name, equals('windows'));
      expect(platformLinux.name, equals('linux'));
      expect(platformAndroid.name, equals('android'));
      expect(platformIos.name, equals('ios'));
      expect(platformFuchsia.name, equals('fuchsia'));
    });

    test('should have correct toString representation', () {
      final str = platformWeb.toString();

      expect(str, contains('TomPlatform'));
      expect(str, contains('web'));
    });
  });

  // ==========================================================================
  // TomRuntime Tests
  // ==========================================================================
  group('TomRuntime', () {
    group('Environment Management', () {
      test('should add and get environments', () {
        const env = TomEnvironment('runtime-test');
        TomRuntime.addEnvironment(env);

        final envs = TomRuntime.getEnvironments();
        expect(envs.any((e) => e.env == 'runtime-test'), isTrue);
      });

      test('should set current environment by name', () {
        const env = TomEnvironment('current-env-test');
        TomRuntime.addEnvironment(env);
        TomRuntime.setCurrentEnvironment('current-env-test');

        final current = TomRuntime.getCurrentEnvironment();
        expect(current.env, equals('current-env-test'));
      });

      test('should get environment hierarchy', () {
        const base = TomEnvironment('base-hier');
        const child = TomEnvironment('child-hier', parent: base);

        TomRuntime.addEnvironment(base);
        TomRuntime.addEnvironment(child);
        TomRuntime.setCurrentEnvironment('child-hier');

        final hierarchy = TomRuntime.getEnvironmentHierarchy();
        expect(hierarchy.length, greaterThanOrEqualTo(1));
        expect(hierarchy.last.env, equals('child-hier'));
      });

      test('should set root environment', () {
        const root = TomEnvironment('root-env');
        TomRuntime.setRootEnvironment(root);

        expect(TomRuntime.getRoot().env, equals('root-env'));
      });

      test('should apply the named fallback even when a current environment '
          'is already set', () {
        // setCurrentEnvironment is an unconditional setter: when the requested
        // name is not registered it resolves the fallback and *replaces* the
        // current environment, regardless of whether one was already active.
        // (Guarding the fallback on `_currentEnvironment == null` would keep
        // an already-set environment silently — a setter that refuses to set.)
        TomRuntime.reset();
        const activeEnv = TomEnvironment('env-active');
        const fallbackEnv = TomEnvironment('env-fallback-test');
        TomRuntime.addEnvironment(activeEnv);
        TomRuntime.addEnvironment(fallbackEnv);

        // Establish a current environment.
        TomRuntime.setCurrentEnvironment('env-active');
        expect(TomRuntime.getCurrentEnvironment().env, equals('env-active'));

        // Requesting a non-existent name must switch to the named fallback.
        TomRuntime.setCurrentEnvironment(
          'nonexistent-xyz',
          'env-fallback-test',
        );
        expect(
          TomRuntime.getCurrentEnvironment().env,
          equals('env-fallback-test'),
        );
      });
    });

    group('Platform Management', () {
      test('should add and get platforms', () {
        const platform = TomPlatform('test-platform');
        TomRuntime.addPlatform(platform);

        final platforms = TomRuntime.getPlatforms();
        expect(platforms.any((p) => p.name == 'test-platform'), isTrue);
      });

      test('should set and get current platform', () {
        TomRuntime.setCurrentPlatform(platformLinux);

        final current = TomRuntime.getCurrentPlatform();
        expect(current?.name, equals('linux'));
      });

      test('should detect platform from TomPlatformUtils', () {
        // Set up a macOS platform
        TomPlatformUtils.setCurrentPlatform(MacOsDesktopPlatformUtils());

        TomRuntime.initializePlatform();

        expect(TomRuntime.getCurrentPlatform()?.name, equals('macos'));
      });
    });

    group('Initialization Sequence', () {
      test('should use envVars to select environment', () {
        // Set up environment variable
        TomPlatformUtils.envVars['env'] = 'dev-test';

        const prod = TomEnvironment('prod-test');
        const dev = TomEnvironment(
          'dev-test',
          parent: prod,
          isDevelopment: true,
        );

        TomRuntime.addEnvironment(prod);
        TomRuntime.addEnvironment(dev);
        TomRuntime.setRootEnvironment(prod);

        // Use envVars to select environment
        TomRuntime.setCurrentEnvironment(
          TomPlatformUtils.current.getTomEnvVars()['env'],
          'prod-test',
        );

        expect(TomRuntime.getCurrentEnvironment().env, equals('dev-test'));
        expect(TomRuntime.getCurrentEnvironment().isDevelopment, isTrue);
      });

      test('should run environment initializer', () {
        var initializerCalled = false;

        final env = TomEnvironment(
          'init-test',
          initializer: (e) {
            initializerCalled = true;
          },
        );

        TomRuntime.addEnvironment(env);
        TomRuntime.setCurrentEnvironment('init-test');

        expect(initializerCalled, isFalse);

        TomRuntime.getCurrentEnvironment().initialize();

        expect(initializerCalled, isTrue);
      });

      test('should run platform initializer', () {
        var initializerCalled = false;

        const platform = TomPlatform('custom-init-platform');
        platform.setInitializer((p, env) {
          initializerCalled = true;
        });

        TomRuntime.addPlatform(platform);
        TomRuntime.setCurrentPlatform(platform);

        expect(initializerCalled, isFalse);

        TomRuntime.getCurrentPlatform()?.initializePlatform(null);

        expect(initializerCalled, isTrue);
      });
    });

    test('printReport should return non-empty string', () {
      final report = TomRuntime.printReport();

      expect(report, isNotEmpty);
      expect(report, contains('TomRuntime'));
    });
  });

  // ==========================================================================
  // Default Constants Tests
  // ==========================================================================
  group('Default Constants', () {
    test('defaultTomEnvironment should be "default"', () {
      expect(defaultTomEnvironment.env, equals('default'));
    });

    test('noTomEnvironment should be "none"', () {
      expect(noTomEnvironment.env, equals('none'));
    });

    test('noTomPlatform should be "none"', () {
      expect(noTomPlatform.name, equals('none'));
    });
  });
}
