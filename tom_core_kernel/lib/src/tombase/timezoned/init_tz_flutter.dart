import 'package:timezone/data/latest.dart' as tz;

Future<int> tomSetupTimezones() async {
  tz.initializeTimeZones();
  return 0;
}