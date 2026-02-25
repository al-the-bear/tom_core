import 'package:timezone/standalone.dart' as tz;

Future<int> tomSetupTimezones() async {
  await tz.initializeTimeZone();
  return 0;
}