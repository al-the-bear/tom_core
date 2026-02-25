import 'package:timezone/browser.dart' as tz;

Future<int> tomSetupTimezones() async {
  await tz.initializeTimeZone();
  return 0;
}