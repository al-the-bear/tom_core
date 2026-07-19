import 'package:tom_core_codespecs/tom_core_codespecs.dart';
import 'package:test/test.dart';

void main() {
  group('csm2r7: CE-CL TomClientApplication', () {
    test('constructs with defaults and no shared mutable list', () {
      final a = TomClientApplication();
      final b = TomClientApplication();
      a.platforms.add('web');
      expect(a.platforms, ['web']);
      expect(b.platforms, isEmpty, reason: 'each instance owns its own list');
    });

    test('carries the spec-authorable client descriptor fields', () {
      final app = TomClientApplication(
        clientId: 'admin_console',
        displayName: 'Admin Console',
        platforms: ['web', 'macos'],
        entryRoute: 'dashboard',
        serverBaseUrl: 'https://api.example.com',
      );
      expect(app.clientId, 'admin_console');
      expect(app.platforms, ['web', 'macos']);
      expect(app.entryRoute, 'dashboard');
      expect(app.serverBaseUrl, 'https://api.example.com');
    });
  });

  group('csm2r7: CE-CC TomClientConfiguration', () {
    test('per-machine config holder defaults own their maps', () {
      final a = TomClientConfiguration();
      final b = TomClientConfiguration();
      a.featureToggles['beta'] = true;
      a.deviceOptions['dpi'] = 144;
      expect(b.featureToggles, isEmpty);
      expect(b.deviceOptions, isEmpty);
    });

    test('holds the deployment/per-installation fields', () {
      final cfg = TomClientConfiguration(
        apiBaseUrl: 'https://api.example.com',
        environment: 'prod',
        updateChannel: 'stable',
      );
      expect(cfg.apiBaseUrl, 'https://api.example.com');
      expect(cfg.environment, 'prod');
      expect(cfg.updateChannel, 'stable');
    });
  });

  group('csm2r7: CE-UP TomUserSettings + persistence split', () {
    test('defaults to roaming (follows the user)', () {
      final s = TomUserSettings(settingId: 'preferred_language');
      expect(s.persistence, TomUserSettingsPersistence.roaming);
      expect(s.isRoaming, isTrue);
    });

    test('a local setting is machine-bound', () {
      final s = TomUserSettings(
        settingId: 'window_layout',
        persistence: TomUserSettingsPersistence.local,
      );
      expect(s.persistence, TomUserSettingsPersistence.local);
      expect(s.isRoaming, isFalse);
    });

    test('the persistence enum has exactly the local/roaming split', () {
      expect(TomUserSettingsPersistence.values,
          [TomUserSettingsPersistence.local, TomUserSettingsPersistence.roaming]);
    });

    test('carries value and default independently', () {
      final s = TomUserSettings(
        settingId: 'theme',
        value: 'dark',
        defaultValue: 'light',
      );
      expect(s.value, 'dark');
      expect(s.defaultValue, 'light');
    });
  });
}
