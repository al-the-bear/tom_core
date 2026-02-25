import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

void main() {
  group('Tom Core Server tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('Server module exports correctly', () {
      // Basic test that package imports work
      // ignore: unnecessary_type_check
      expect(TomServer is Type, isTrue);
    });
  });
}
