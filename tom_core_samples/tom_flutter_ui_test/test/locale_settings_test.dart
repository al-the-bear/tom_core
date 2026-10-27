/// Unit coverage for the locale layer (`lib/locale_settings.dart`).
///
/// The non-trivial edges — the ones that regress silently — are pinned here:
///
///  - `AppLocales.find()` — the three-tier fallback
///    (exact language+country → language-only → first supported), with a case
///    chosen at each tier so a collapsed tier would change the result.
///  - `LocaleSettingsService.initialize()` — the idempotency early-return and
///    the corrupt-prefs guard that only restores a saved value when
///    `saved.split('_')` yields **exactly** two parts.
///  - `LocaleSettingsService.setLocale()` — the unchanged-locale early-return,
///    round-trip persistence, and the deliberate notify-**before**-async-write
///    ordering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_flutter_ui_test/locale_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enUs = Locale('en', 'US');
  const deDe = Locale('de', 'DE');
  const deAt = Locale('de', 'AT');

  group('AppLocales.find — three-tier fallback', () {
    test('tier 1: exact language+country match wins over language-only', () {
      // de_AT is the SECOND `de` entry, so returning it (not the first `de`,
      // de_DE) proves the exact tier beats the language-only tier.
      final option = AppLocales.find(deAt);
      expect(option.locale, deAt);
      expect(option.displayName, 'Deutsch (Österreich)');
    });

    test('tier 2: language-only match when the country is unsupported', () {
      // CH is not in the supported list → falls to the first `de` entry.
      final option = AppLocales.find(const Locale('de', 'CH'));
      expect(option.locale, deDe);
    });

    test('tier 3: first supported when the language is unsupported', () {
      final option = AppLocales.find(const Locale('xx', 'YY'));
      expect(option.locale, enUs);
    });

    test('tier 3: first supported for a null locale', () {
      expect(AppLocales.find(null).locale, enUs);
    });
  });

  group('LocaleSettingsService.initialize', () {
    test('restores a well-formed lang_country value from prefs', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'de_DE'});
      final service = LocaleSettingsService();

      await service.initialize();

      expect(service.initialized, isTrue);
      expect(service.locale, deDe);
    });

    test(
      'falls back to the default when the saved value is one-part',
      () async {
        // 'de'.split('_') -> ['de'] (length 1) -> corrupt-guard rejects it.
        SharedPreferences.setMockInitialValues({'app_locale': 'de'});
        final service = LocaleSettingsService();

        await service.initialize();

        expect(service.locale, enUs, reason: 'one-part value must not restore');
      },
    );

    test(
      'falls back to the default when the saved value is three-part',
      () async {
        // 'de_DE_x'.split('_') -> length 3 -> corrupt-guard rejects it.
        SharedPreferences.setMockInitialValues({'app_locale': 'de_DE_x'});
        final service = LocaleSettingsService();

        await service.initialize();

        expect(
          service.locale,
          enUs,
          reason: 'three-part value must not restore',
        );
      },
    );

    test('falls back to the default when nothing is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LocaleSettingsService();

      await service.initialize();

      expect(service.locale, enUs);
    });

    test(
      'is idempotent: a second initialize neither re-loads nor re-notifies',
      () async {
        // First init seeds de_DE from prefs and notifies once.
        SharedPreferences.setMockInitialValues({'app_locale': 'de_DE'});
        final service = LocaleSettingsService();
        var notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.initialize();
        expect(notifyCount, 1);
        expect(service.locale, deDe);

        // Change the underlying store, then re-initialize: the early-return must
        // keep the already-loaded locale and emit no further notification.
        SharedPreferences.setMockInitialValues({'app_locale': 'ja_JP'});
        await service.initialize();

        expect(notifyCount, 1, reason: 'second initialize must not re-notify');
        expect(
          service.locale,
          deDe,
          reason: 'second initialize must not re-load',
        );
      },
    );
  });

  group('LocaleSettingsService.setLocale', () {
    test('persists the new locale in lang_country form (round-trip)', () async {
      SharedPreferences.setMockInitialValues({});
      final writer = LocaleSettingsService();
      await writer.initialize();

      await writer.setLocale(deAt);

      // A fresh service reading the same store must restore the written value.
      final reader = LocaleSettingsService();
      await reader.initialize();
      expect(reader.locale, deAt);

      // And the raw persisted string is the exact format initialize() parses.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'de_AT');
    });

    test('notifies synchronously before the async write completes', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LocaleSettingsService();
      await service.initialize();

      var notified = false;
      service.addListener(() => notified = true);

      // Do NOT await yet: setLocale sets _locale + notifyListeners() before its
      // first `await`, so control returns here with the switch already visible.
      final pending = service.setLocale(const Locale('tr', 'TR'));
      expect(
        notified,
        isTrue,
        reason: 'UI must see the new locale before disk I/O',
      );
      expect(service.locale, const Locale('tr', 'TR'));

      await pending;
    });

    test(
      'early-returns without notifying when the locale is unchanged',
      () async {
        SharedPreferences.setMockInitialValues({'app_locale': 'de_DE'});
        final service = LocaleSettingsService();
        await service.initialize();

        var notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.setLocale(deDe);

        expect(notifyCount, 0, reason: 'setting the current locale is a no-op');
        expect(service.locale, deDe);
      },
    );
  });
}
