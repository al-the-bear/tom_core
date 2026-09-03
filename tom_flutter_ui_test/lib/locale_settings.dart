/// Locale settings service for the demo app.
///
/// Manages locale selection and persistence via SharedPreferences.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported locales for the demo application.
class AppLocales {
  AppLocales._();

  /// All supported locales with display names.
  static const List<LocaleOption> supported = [
    LocaleOption(Locale('en', 'US'), 'English (US)', '🇺🇸'),
    LocaleOption(Locale('en', 'GB'), 'English (UK)', '🇬🇧'),
    LocaleOption(Locale('de', 'DE'), 'Deutsch (Deutschland)', '🇩🇪'),
    LocaleOption(Locale('de', 'AT'), 'Deutsch (Österreich)', '🇦🇹'),
    LocaleOption(Locale('ar', 'AE'), 'العربية (الإمارات)', '🇦🇪'),
    LocaleOption(Locale('tr', 'TR'), 'Türkçe', '🇹🇷'),
    LocaleOption(Locale('el', 'GR'), 'Ελληνικά', '🇬🇷'),
    LocaleOption(Locale('ru', 'RU'), 'Русский', '🇷🇺'),
    LocaleOption(Locale('th', 'TH'), 'ไทย', '🇹🇭'),
    LocaleOption(Locale('vi', 'VN'), 'Tiếng Việt', '🇻🇳'),
    LocaleOption(Locale('zh', 'CN'), '中文 (简体)', '🇨🇳'),
    LocaleOption(Locale('zh', 'TW'), '中文 (繁體)', '🇹🇼'),
    LocaleOption(Locale('ja', 'JP'), '日本語', '🇯🇵'),
  ];

  /// Get list of Locale objects for MaterialApp.supportedLocales.
  static List<Locale> get locales => supported.map((o) => o.locale).toList();

  /// Find LocaleOption by locale, returns first supported if not found.
  static LocaleOption find(Locale? locale) {
    if (locale == null) return supported.first;
    return supported.firstWhere(
      (o) =>
          o.locale.languageCode == locale.languageCode &&
          o.locale.countryCode == locale.countryCode,
      orElse: () => supported.firstWhere(
        (o) => o.locale.languageCode == locale.languageCode,
        orElse: () => supported.first,
      ),
    );
  }
}

/// A locale option with display information.
class LocaleOption {
  final Locale locale;
  final String displayName;
  final String flag;

  const LocaleOption(this.locale, this.displayName, this.flag);

  String get code => '${locale.languageCode}_${locale.countryCode}';
}

/// Service for managing locale settings with persistence.
class LocaleSettingsService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  Locale _locale = AppLocales.supported.first.locale;
  bool _initialized = false;

  /// Current locale.
  Locale get locale => _locale;

  /// Whether the service has been initialized.
  ///
  /// Public-for-testing only: no `lib/` consumer reads this — the idempotency
  /// guard in [initialize] consults the private `_initialized` field directly.
  /// It exists so `locale_settings_test.dart` can pin the lifecycle flag after
  /// `initialize()`; the annotation lints any non-test use (mv §12).
  @visibleForTesting
  bool get initialized => _initialized;

  /// Current locale option.
  LocaleOption get currentOption => AppLocales.find(_locale);

  /// Initialize the service and load saved locale.
  Future<void> initialize() async {
    // Why: guard against a second await on the platform channel — main()
    // calls this once at bootstrap, but the public method is idempotent so
    // a hot-reload or test re-entry can't double-load or re-notify.
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);

    // Why: the locale is persisted as the `lang_country` string produced by
    // setLocale() below; only restore when both parts are present, otherwise
    // fall through to the default seeded in the field initializer rather than
    // construct a malformed Locale from corrupt prefs.
    if (saved != null) {
      final parts = saved.split('_');
      if (parts.length == 2) {
        _locale = Locale(parts[0], parts[1]);
      }
    }

    _initialized = true;
    notifyListeners();
  }

  /// Set the locale and persist the setting.
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    // Why: notify before the async write so the UI re-renders in the new
    // language immediately; persistence is fire-and-forget for the next
    // launch and must not block the visible locale switch on disk I/O. The
    // `lang_country` format here is the exact string initialize() parses.
    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localeKey,
      '${locale.languageCode}_${locale.countryCode}',
    );
  }
}

/// Widget that shows a language selector dialog.
class LanguageSelectorButton extends StatelessWidget {
  final LocaleSettingsService localeService;

  const LanguageSelectorButton({super.key, required this.localeService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeService,
      builder: (context, _) {
        final current = localeService.currentOption;
        return IconButton(
          icon: Text(current.flag, style: const TextStyle(fontSize: 24)),
          tooltip: 'Language: ${current.displayName}',
          onPressed: () => _showLanguageDialog(context),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppLocales.supported.length,
            itemBuilder: (context, index) {
              final option = AppLocales.supported[index];
              final isSelected = option.locale == localeService.locale;
              return ListTile(
                leading: Text(
                  option.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(option.displayName),
                subtitle: Text(option.code),
                selected: isSelected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                onTap: () {
                  localeService.setLocale(option.locale);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
