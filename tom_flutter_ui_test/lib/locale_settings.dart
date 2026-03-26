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
  bool get initialized => _initialized;

  /// Current locale option.
  LocaleOption get currentOption => AppLocales.find(_locale);

  /// Initialize the service and load saved locale.
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);

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

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _localeKey, '${locale.languageCode}_${locale.countryCode}');
  }
}

/// Widget that shows a language selector dialog.
class LanguageSelectorButton extends StatelessWidget {
  final LocaleSettingsService localeService;

  const LanguageSelectorButton({
    super.key,
    required this.localeService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeService,
      builder: (context, _) {
        final current = localeService.currentOption;
        return IconButton(
          icon: Text(
            current.flag,
            style: const TextStyle(fontSize: 24),
          ),
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
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
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
