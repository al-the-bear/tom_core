// ignore_for_file: unused_local_variable
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_init;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'reflection_test.reflection.dart';

// ============================================================================
// Test Classes
// ============================================================================

@tomReflector
class SimplePerson {
  String name = '';
  int age = 0;
  bool active = false;
  double salary = 0.0;

  SimplePerson();
}

@tomReflector
class NullablePerson {
  String? name;
  int? age;
  bool? active;
  double? salary;

  NullablePerson();
}

@tomReflector
class DateTimeHolder {
  DateTime? dateTime;
  DateTime? dateOnly;
  DateTime? timeOnly;

  DateTimeHolder();
}

@tomReflector
@tomReflector
class ZonedDateTimeHolder {
  TomZonedDate? zonedDate;
  TomZonedTime? zonedTime;
  TomZonedDateTime? zonedDateTime;

  ZonedDateTimeHolder();
}

@tomReflector
class MapHolder {
  Map<String, String>? stringMap;
  Map<String, int>? intMap;
  Map<String, double>? doubleMap;
  Map<String, bool>? boolMap;
  Map<String, dynamic>? dynamicMap;

  MapHolder();
}

@tomReflector
class ListHolder {
  List<String>? stringList;
  List<int>? intList;
  List<double>? doubleList;
  List<bool>? boolList;
  List<dynamic>? dynamicList;

  ListHolder();
}

@tomReflector
class DateTimeMapHolder {
  Map<String, DateTime>? dateTimeMap;
  Map<String, TomZonedDate>? zonedDateMap;
  Map<String, TomZonedTime>? zonedTimeMap;
  Map<String, TomZonedDateTime>? zonedDateTimeMap;

  DateTimeMapHolder();
}

@tomReflector
class DateTimeListHolder {
  List<DateTime>? dateTimeList;
  List<TomZonedDate>? zonedDateList;
  List<TomZonedTime>? zonedTimeList;
  List<TomZonedDateTime>? zonedDateTimeList;

  DateTimeListHolder();
}

@tomReflector
class Address {
  String street = '';
  String city = '';
  String zipCode = '';

  Address();
}

@tomReflector
class PersonWithAddress {
  String name = '';
  Address? address;

  PersonWithAddress();
}

@tomReflector
class Employee {
  String name = '';
  String department = '';
  Employee? manager;

  Employee();
}

@tomReflector
@tomReflector
class TeamMember {
  String name = '';
  String role = '';

  TeamMember();
}

@tomReflector
class Team {
  String teamName = '';
  List<TeamMember> members = [];

  Team();
}

@tomReflector
class PersonWithFromJson {
  String name = '';
  int age = 0;

  PersonWithFromJson();

  factory PersonWithFromJson.fromJson(Map<String, dynamic> json) {
    final person = PersonWithFromJson();
    person.name = (json['name'] as String?) ?? '';
    person.age = (json['age'] as int?) ?? 0;
    return person;
  }
}

@tomReflector
@tomReflector
class NestedInfo {
  String info = '';
  int level = 0;

  NestedInfo();
}

@tomReflector
class ComplexEntity {
  String name = '';
  List<String>? tags;
  Map<String, int>? scores;
  NestedInfo? nestedInfo;
  List<NestedInfo> nestedList = [];

  ComplexEntity();
}

// ============================================================================
// Test Classes for Uninitialized Collections
// ============================================================================

/// Test class with nullable List of annotated objects WITHOUT default value.
@tomReflector
class UninitializedListHolder {
  String name = '';
  List<TeamMember>? members; // No default value - starts as null

  UninitializedListHolder();
}

/// Test class with nullable Map of annotated objects WITHOUT default value.
@tomReflector
class UninitializedMapHolder {
  String name = '';
  Map<String, NestedInfo>? infoMap; // No default value - starts as null

  UninitializedMapHolder();
}

/// Test class with both uninitialized List and Map.
@tomReflector
class UninitializedCollectionsHolder {
  String name = '';
  List<Address>? addresses; // No default value
  Map<String, TeamMember>? teamMembers; // No default value

  UninitializedCollectionsHolder();
}

/// Test class with nullable List elements (`List<X?>?`).
@tomReflector
class NullableElementListHolder {
  String name = '';
  List<TeamMember?>? members; // Nullable elements allowed

  NullableElementListHolder();
}

/// Test class with nullable Map values (`Map<String, X?>?`).
@tomReflector
class NullableValueMapHolder {
  String name = '';
  Map<String, NestedInfo?>? infoMap; // Nullable values allowed

  NullableValueMapHolder();
}

/// A *generic* reflected class.
///
/// The registry is keyed by declaration, so `reflectType(GenericHolder<int>)`
/// finds nothing while `reflect(instance)` does. Any code that reflects a value
/// by way of `o.runtimeType` therefore fails on this class and on no other.
@tomReflector
class GenericHolder<T> {
  String name = '';
  int count = 0;

  GenericHolder();
}

/// Deliberately **not** annotated, so no mirror data exists for it.
///
/// The one input for which the reflectable package, rather than Tom's code,
/// decides what the failure looks like — which is what makes it the test
/// subject for the error boundary.
class NotReflectedHolder {
  String name = '';
  int count = 0;

  NotReflectedHolder();
}

void main() {
  setUpAll(() {
    initializeReflection();
    tz_init.initializeTimeZones();
  });

  // tcinc165: `getValues` and `setValues` each reflected the instance and then
  // threw that mirror away to look the class up again by `o.runtimeType`. The
  // second lookup is declaration-keyed, so a generic value was reflected
  // successfully and then reported as un-reflectable one line later — it could
  // be neither serialized nor populated, despite being annotated.
  group('a generic reflected class is read and written like any other', () {
    test('getValues reads the members of a generic instance', () {
      final holder = GenericHolder<int>()
        ..name = 'boxed'
        ..count = 7;

      expect(tomReflectionInfo.getValues(holder), {
        'name': 'boxed',
        'count': 7,
      });
    });

    test('setValues populates a generic instance', () {
      final holder = GenericHolder<String>();

      tomReflectionInfo.setValues(holder, {'name': 'filled', 'count': 3});

      expect(holder.name, 'filled');
      expect(holder.count, 3);
    });

    test('the instantiation does not change what is read', () {
      // The type argument is not a member and has no bearing on the payload,
      // so two instantiations of one declaration produce one JSON shape.
      final ints = GenericHolder<int>()..name = 'a';
      final strings = GenericHolder<String>()..name = 'a';

      expect(
        tomReflectionInfo.getValues(ints),
        tomReflectionInfo.getValues(strings),
      );
    });
  });

  group('tomReflectionInfo.createInstance', () {
    test('should create instance of simple class', () {
      final person = tomReflectionInfo.createInstance<SimplePerson>();
      expect(person, isNotNull);
      expect(person, isA<SimplePerson>());
    });

    test('should create instance with default values', () {
      final person = tomReflectionInfo.createInstance<SimplePerson>();
      expect(person.name, '');
      expect(person.age, 0);
      expect(person.active, false);
      expect(person.salary, 0.0);
    });
  });

  group('tomReflectionInfo.setValues - Primitives', () {
    test('should set String value', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {'name': 'John'});
      expect(person.name, 'John');
    });

    test('should set int value', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {'age': 30});
      expect(person.age, 30);
    });

    test('should set bool value', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {'active': true});
      expect(person.active, true);
    });

    test('should set double value', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {'salary': 50000.50});
      expect(person.salary, 50000.50);
    });

    // Why: neither JSON nor a command line carries Dart's int/double
    // distinction — `{"salary": 50000}` and `salary=50000` both decode to an
    // `int`. Widening it to the field's declared `double` is lossless, so the
    // setter accepts it rather than rejecting a value the source could not
    // have expressed any other way.
    test('should widen an int value into a double field', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {'salary': 50000});
      expect(person.salary, 50000.0);
    });

    test('should widen an int into a nullable double field', () {
      final person = NullablePerson();
      tomReflectionInfo.setValues(person, {'salary': 42});
      expect(person.salary, 42.0);
    });

    // The converse is deliberately not symmetric: narrowing a double to an int
    // would have to pick a rounding policy, and silently truncating 2.5 loses
    // data. It stays an error.
    test('should reject a double value for an int field', () {
      final person = SimplePerson();
      expect(
        () => tomReflectionInfo.setValues(person, {'age': 2.5}),
        throwsA(isA<TomReflectorException>()),
      );
    });

    test('should set multiple values at once', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {
        'name': 'Jane',
        'age': 25,
        'active': true,
        'salary': 75000.0,
      });
      expect(person.name, 'Jane');
      expect(person.age, 25);
      expect(person.active, true);
      expect(person.salary, 75000.0);
    });

    test('should handle nullable properties', () {
      final person = NullablePerson();
      tomReflectionInfo.setValues(person, {'name': 'Test', 'age': 40});
      expect(person.name, 'Test');
      expect(person.age, 40);
    });

    test('should handle null values for nullable properties', () {
      final person = NullablePerson();
      person.name = 'Initial';
      tomReflectionInfo.setValues(person, {'name': null});
      expect(person.name, isNull);
    });
  });

  group('tomReflectionInfo.setValues - DateTime', () {
    test('should set DateTime from ISO string', () {
      final holder = DateTimeHolder();
      tomReflectionInfo.setValues(holder, {'dateTime': '2024-06-15T14:30:00.000'});
      expect(holder.dateTime, isNotNull);
      expect(holder.dateTime!.year, 2024);
      expect(holder.dateTime!.month, 6);
      expect(holder.dateTime!.day, 15);
      expect(holder.dateTime!.hour, 14);
      expect(holder.dateTime!.minute, 30);
    });

    test('should set DateTime from ISO string with Z suffix', () {
      final holder = DateTimeHolder();
      tomReflectionInfo.setValues(holder, {'dateTime': '2024-06-15T14:30:00.000Z'});
      expect(holder.dateTime, isNotNull);
      expect(holder.dateTime!.year, 2024);
      expect(holder.dateTime!.month, 6);
      expect(holder.dateTime!.day, 15);
    });
  });

  group('tomReflectionInfo.setValues - TomZoned types', () {
    test('should set TomZonedDate from string', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {'zonedDate': '@D@2024-06-15T00:00:00.000Z_+02:00_Europe/Berlin'});
      expect(holder.zonedDate, isNotNull);
      expect(holder.zonedDate!.year, 2024);
      expect(holder.zonedDate!.month, 6);
      expect(holder.zonedDate!.day, 15);
      expect(holder.zonedDate!.timezone.timezone, 'Europe/Berlin');
    });

    test('should set TomZonedTime from string', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {'zonedTime': '@T@1970-01-01T14:30:00.000Z_+09:00_Asia/Tokyo'});
      expect(holder.zonedTime, isNotNull);
      expect(holder.zonedTime!.hour, 14);
      expect(holder.zonedTime!.minute, 30);
      expect(holder.zonedTime!.second, 0);
      expect(holder.zonedTime!.timezone.timezone, 'Asia/Tokyo');
    });

    test('should set TomZonedDateTime from string', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(
          holder, {'zonedDateTime': '@X@2024-06-15T14:30:00.000Z_-04:00_America/New_York'});
      expect(holder.zonedDateTime, isNotNull);
      expect(holder.zonedDateTime!.year, 2024);
      expect(holder.zonedDateTime!.month, 6);
      expect(holder.zonedDateTime!.day, 15);
      expect(holder.zonedDateTime!.hour, 14);
      expect(holder.zonedDateTime!.minute, 30);
      expect(holder.zonedDateTime!.timezone.timezone, 'America/New_York');
    });

    test('should set TomZonedDate from string with different timezone', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {'zonedDate': '@D@2024-03-20T00:00:00.000Z_Z_Europe/London'});
      expect(holder.zonedDate, isNotNull);
      expect(holder.zonedDate!.year, 2024);
      expect(holder.zonedDate!.month, 3);
      expect(holder.zonedDate!.day, 20);
      expect(holder.zonedDate!.timezone.timezone, 'Europe/London');
    });

    test('should set TomZonedTime from string with different timezone', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {'zonedTime': '@T@1970-01-01T10:45:30.500Z_+10:00_Australia/Sydney'});
      expect(holder.zonedTime, isNotNull);
      expect(holder.zonedTime!.hour, 10);
      expect(holder.zonedTime!.minute, 45);
      expect(holder.zonedTime!.second, 30);
      expect(holder.zonedTime!.millisecond, 500);
      expect(holder.zonedTime!.timezone.timezone, 'Australia/Sydney');
    });

    test('should set TomZonedDateTime from string with different timezone', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {'zonedDateTime': '@X@2024-12-25T08:00:00.000Z_+13:00_Pacific/Auckland'});
      expect(holder.zonedDateTime, isNotNull);
      expect(holder.zonedDateTime!.year, 2024);
      expect(holder.zonedDateTime!.month, 12);
      expect(holder.zonedDateTime!.day, 25);
      expect(holder.zonedDateTime!.hour, 8);
      expect(holder.zonedDateTime!.minute, 0);
      expect(holder.zonedDateTime!.timezone.timezone, 'Pacific/Auckland');
    });
  });

  group('tomReflectionInfo.setValues - Maps', () {
    test('should set Map<String, String>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'stringMap': {'key1': 'value1', 'key2': 'value2'}
      });
      expect(holder.stringMap, {'key1': 'value1', 'key2': 'value2'});
    });

    test('should set Map<String, int>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'intMap': {'a': 1, 'b': 2, 'c': 3}
      });
      expect(holder.intMap, {'a': 1, 'b': 2, 'c': 3});
    });

    test('should set Map<String, double>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'doubleMap': {'x': 1.5, 'y': 2.5}
      });
      expect(holder.doubleMap, {'x': 1.5, 'y': 2.5});
    });

    test('should set Map<String, bool>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'boolMap': {'enabled': true, 'visible': false}
      });
      expect(holder.boolMap, {'enabled': true, 'visible': false});
    });

    test('should set Map<String, dynamic>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'dynamicMap': {'str': 'hello', 'num': 42, 'flag': true}
      });
      expect(holder.dynamicMap, {'str': 'hello', 'num': 42, 'flag': true});
    });
  });

  group('tomReflectionInfo.setValues - Lists', () {
    test('should set List<String>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'stringList': ['a', 'b', 'c']
      });
      expect(holder.stringList, ['a', 'b', 'c']);
    });

    test('should set List<int>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'intList': [1, 2, 3, 4, 5]
      });
      expect(holder.intList, [1, 2, 3, 4, 5]);
    });

    test('should set List<double>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'doubleList': [1.1, 2.2, 3.3]
      });
      expect(holder.doubleList, [1.1, 2.2, 3.3]);
    });

    test('should set List<bool>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'boolList': [true, false, true]
      });
      expect(holder.boolList, [true, false, true]);
    });

    test('should set List<dynamic>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'dynamicList': ['text', 123, true, 4.5]
      });
      expect(holder.dynamicList, ['text', 123, true, 4.5]);
    });
  });

  group('tomReflectionInfo.setValues - DateTime Maps', () {
    test('should set Map<String, DateTime> from ISO strings', () {
      final holder = DateTimeMapHolder();
      tomReflectionInfo.setValues(holder, {
        'dateTimeMap': {
          'start': '2024-01-01T00:00:00.000',
          'end': '2024-12-31T23:59:59.999'
        }
      });
      expect(holder.dateTimeMap, isNotNull);
      expect(holder.dateTimeMap!['start']!.year, 2024);
      expect(holder.dateTimeMap!['start']!.month, 1);
      expect(holder.dateTimeMap!['end']!.month, 12);
    });

    test('should set Map<String, TomZonedDate> from strings', () {
      final holder = DateTimeMapHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedDateMap': {
          'berlin': '@D@2024-06-15T00:00:00.000Z_+02:00_Europe/Berlin',
          'tokyo': '@D@2024-07-20T00:00:00.000Z_+09:00_Asia/Tokyo'
        }
      });
      expect(holder.zonedDateMap, isNotNull);
      expect(holder.zonedDateMap!['berlin']!.timezone.timezone, 'Europe/Berlin');
      expect(holder.zonedDateMap!['tokyo']!.timezone.timezone, 'Asia/Tokyo');
    });

    test('should set Map<String, TomZonedTime> from strings', () {
      final holder = DateTimeMapHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedTimeMap': {
          'morning': '@T@1970-01-01T08:00:00.000Z_Z_Europe/London',
          'evening': '@T@1970-01-01T20:00:00.000Z_-06:00_America/Chicago'
        }
      });
      expect(holder.zonedTimeMap, isNotNull);
      expect(holder.zonedTimeMap!['morning']!.hour, 8);
      expect(holder.zonedTimeMap!['evening']!.hour, 20);
    });

    test('should set Map<String, TomZonedDateTime> from strings', () {
      final holder = DateTimeMapHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedDateTimeMap': {
          'meeting': '@X@2024-06-15T10:00:00.000Z_+02:00_Europe/Paris',
          'deadline': '@X@2024-06-30T23:59:59.000Z_Z_UTC'
        }
      });
      expect(holder.zonedDateTimeMap, isNotNull);
      expect(holder.zonedDateTimeMap!['meeting']!.hour, 10);
      expect(holder.zonedDateTimeMap!['deadline']!.day, 30);
    });
  });

  group('tomReflectionInfo.setValues - DateTime Lists', () {
    test('should set List<DateTime> from ISO strings', () {
      final holder = DateTimeListHolder();
      tomReflectionInfo.setValues(holder, {
        'dateTimeList': [
          '2024-01-01T00:00:00.000',
          '2024-06-15T12:00:00.000',
          '2024-12-31T23:59:59.999'
        ]
      });
      expect(holder.dateTimeList, isNotNull);
      expect(holder.dateTimeList!.length, 3);
      expect(holder.dateTimeList![0].month, 1);
      expect(holder.dateTimeList![1].month, 6);
      expect(holder.dateTimeList![2].month, 12);
    });

    test('should set List<TomZonedDate> from strings', () {
      final holder = DateTimeListHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedDateList': [
          '@D@2024-01-01T00:00:00.000Z_+01:00_Europe/Berlin',
          '@D@2024-06-15T00:00:00.000Z_+09:00_Asia/Tokyo',
          '@D@2024-12-25T00:00:00.000Z_-05:00_America/New_York'
        ]
      });
      expect(holder.zonedDateList, isNotNull);
      expect(holder.zonedDateList!.length, 3);
      expect(holder.zonedDateList![0].timezone.timezone, 'Europe/Berlin');
      expect(holder.zonedDateList![1].timezone.timezone, 'Asia/Tokyo');
      expect(holder.zonedDateList![2].timezone.timezone, 'America/New_York');
    });

    test('should set List<TomZonedTime> from strings', () {
      final holder = DateTimeListHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedTimeList': [
          '@T@1970-01-01T08:00:00.000Z_Z_Europe/London',
          '@T@1970-01-01T12:30:00.000Z_+08:00_Asia/Singapore',
          '@T@1970-01-01T18:45:00.000Z_-08:00_America/Los_Angeles'
        ]
      });
      expect(holder.zonedTimeList, isNotNull);
      expect(holder.zonedTimeList!.length, 3);
      expect(holder.zonedTimeList![0].hour, 8);
      expect(holder.zonedTimeList![1].hour, 12);
      expect(holder.zonedTimeList![2].hour, 18);
    });

    test('should set List<TomZonedDateTime> from strings', () {
      final holder = DateTimeListHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedDateTimeList': [
          '@X@2024-01-01T00:00:00.000Z_Z_UTC',
          '@X@2024-06-15T14:30:00.000Z_+02:00_Europe/Paris',
          '@X@2024-12-25T08:00:00.000Z_+11:00_Australia/Sydney'
        ]
      });
      expect(holder.zonedDateTimeList, isNotNull);
      expect(holder.zonedDateTimeList!.length, 3);
      expect(holder.zonedDateTimeList![0].timezone.timezone, 'UTC');
      expect(holder.zonedDateTimeList![1].timezone.timezone, 'Europe/Paris');
      expect(holder.zonedDateTimeList![2].timezone.timezone, 'Australia/Sydney');
    });
  });

  group('tomReflectionInfo.setValues - Nested Objects', () {
    test('should set nested object from map', () {
      final person = PersonWithAddress();
      tomReflectionInfo.setValues(person, {
        'name': 'John Doe',
        'address': {'street': '123 Main St', 'city': 'Springfield', 'zipCode': '12345'}
      });
      expect(person.name, 'John Doe');
      expect(person.address, isNotNull);
      expect(person.address!.street, '123 Main St');
      expect(person.address!.city, 'Springfield');
      expect(person.address!.zipCode, '12345');
    });

    test('should set self-referencing nested object', () {
      final employee = Employee();
      tomReflectionInfo.setValues(employee, {
        'name': 'Alice',
        'department': 'Engineering',
        'manager': {'name': 'Bob', 'department': 'Management', 'manager': null}
      });
      expect(employee.name, 'Alice');
      expect(employee.manager, isNotNull);
      expect(employee.manager!.name, 'Bob');
      expect(employee.manager!.department, 'Management');
      expect(employee.manager!.manager, isNull);
    });
  });

  group('tomReflectionInfo.setValues - List of Objects', () {
    test('should set list of nested objects', () {
      final team = Team();
      tomReflectionInfo.setValues(team, {
        'teamName': 'Alpha Team',
        'members': [
          {'name': 'Alice', 'role': 'Developer'},
          {'name': 'Bob', 'role': 'Designer'},
          {'name': 'Charlie', 'role': 'Manager'}
        ]
      });
      expect(team.teamName, 'Alpha Team');
      expect(team.members.length, 3);
      expect(team.members[0].name, 'Alice');
      expect(team.members[0].role, 'Developer');
      expect(team.members[1].name, 'Bob');
      expect(team.members[2].role, 'Manager');
    });
  });

  group('tomReflectionInfo.getValues', () {
    test('should get all values from simple object', () {
      final person = SimplePerson();
      person.name = 'TestName';
      person.age = 42;
      person.active = true;
      person.salary = 100000.0;

      final values = tomReflectionInfo.getValues(person);
      expect(values['name'], 'TestName');
      expect(values['age'], 42);
      expect(values['active'], true);
      expect(values['salary'], 100000.0);
    });

    test('should get nullable values', () {
      final person = NullablePerson();
      person.name = 'NullableTest';
      person.age = null;

      final values = tomReflectionInfo.getValues(person);
      expect(values['name'], 'NullableTest');
      expect(values['age'], isNull);
    });

    test('should get DateTime as ISO string', () {
      final holder = DateTimeHolder();
      holder.dateTime = DateTime(2024, 6, 15, 14, 30, 0, 0);

      final values = tomReflectionInfo.getValues(holder);
      expect(values['dateTime'], '2024-06-15T14:30:00.000');
    });

    test('should get TomZonedDate as serialized string', () {
      final holder = ZonedDateTimeHolder();
      final tz = TomTimezone.fromName('Europe/Berlin');
      // June 15 at 00:00 Berlin (UTC+2 in summer) = June 14 at 22:00 UTC
      holder.zonedDate = TomZonedDate(year: 2024, month: 6, day: 15, timezone: tz);

      final values = tomReflectionInfo.getValues(holder);
      expect(values['zonedDate'], startsWith('@D@2024-06-14T22:00:00.000Z_'));
      expect(values['zonedDate'], endsWith('Europe/Berlin '));
    });

    test('should get TomZonedTime as serialized string', () {
      final holder = ZonedDateTimeHolder();
      final tz = TomTimezone.fromName('Asia/Tokyo');
      // 14:30 Tokyo (UTC+9) = 05:30 UTC
      holder.zonedTime = TomZonedTime(
        hour: 14,
        minute: 30,
        second: 0,
        millisecond: 0,
        timezone: tz,
      );

      final values = tomReflectionInfo.getValues(holder);
      expect(values['zonedTime'], startsWith('@T@1970-01-01T05:30:00.000Z_'));
      expect(values['zonedTime'], endsWith('Asia/Tokyo '));
    });

    test('should get TomZonedDateTime as serialized string', () {
      final holder = ZonedDateTimeHolder();
      final tz = TomTimezone.fromName('America/New_York');
      // June 15 at 14:30 NY (UTC-4 in summer DST) = June 15 at 18:30 UTC
      holder.zonedDateTime = TomZonedDateTime(
        year: 2024,
        month: 6,
        day: 15,
        hour: 14,
        minute: 30,
        second: 0,
        millisecond: 0,
        timezone: tz,
      );

      final values = tomReflectionInfo.getValues(holder);
      expect(values['zonedDateTime'], startsWith('@X@2024-06-15T18:30:00.000Z_'));
      expect(values['zonedDateTime'], contains('America/New_York'));
    });

    test('should get maps correctly', () {
      final holder = MapHolder();
      holder.stringMap = {'key1': 'value1', 'key2': 'value2'};
      holder.intMap = {'a': 1, 'b': 2};

      final values = tomReflectionInfo.getValues(holder);
      expect(values['stringMap'], {'key1': 'value1', 'key2': 'value2'});
      expect(values['intMap'], {'a': 1, 'b': 2});
    });

    test('should get lists correctly', () {
      final holder = ListHolder();
      holder.stringList = ['a', 'b', 'c'];
      holder.intList = [1, 2, 3];

      final values = tomReflectionInfo.getValues(holder);
      expect(values['stringList'], ['a', 'b', 'c']);
      expect(values['intList'], [1, 2, 3]);
    });

    test('should get nested object as map', () {
      final person = PersonWithAddress();
      person.name = 'John';
      person.address = Address();
      person.address!.street = '123 Main';
      person.address!.city = 'NYC';
      person.address!.zipCode = '10001';

      final values = tomReflectionInfo.getValues(person);
      expect(values['name'], 'John');
      expect(values['address'], isA<Map>());
      expect((values['address'] as Map)['street'], '123 Main');
      expect((values['address'] as Map)['city'], 'NYC');
    });

    test('should get list of objects as list of maps', () {
      final team = Team();
      team.teamName = 'Test Team';
      team.members = [
        TeamMember()
          ..name = 'Alice'
          ..role = 'Dev',
        TeamMember()
          ..name = 'Bob'
          ..role = 'QA',
      ];

      final values = tomReflectionInfo.getValues(team);
      expect(values['teamName'], 'Test Team');
      expect(values['members'], isA<List>());
      final members = values['members'] as List;
      expect(members.length, 2);
      expect((members[0] as Map)['name'], 'Alice');
      expect((members[1] as Map)['name'], 'Bob');
    });
  });

  group('tomReflectionInfo.convertToJsonString', () {
    test('should convert simple object to JSON', () {
      final person = SimplePerson();
      person.name = 'Test';
      person.age = 25;
      person.active = true;
      person.salary = 50000.0;

      final json = tomReflectionInfo.convertToJsonString(person);
      expect(json, contains('"name":"Test"'));
      expect(json, contains('"age":25'));
      expect(json, contains('"active":true'));
    });

    test('should convert nested object to JSON', () {
      final person = PersonWithAddress();
      person.name = 'Nested';
      person.address = Address()
        ..street = 'Test St'
        ..city = 'Test City'
        ..zipCode = '00000';

      final json = tomReflectionInfo.convertToJsonString(person);
      expect(json, contains('"address"'));
      expect(json, contains('"street":"Test St"'));
    });
  });

  group('createInstance and setValues from JSON', () {
    test('should create instance from JSON map', () {
      final person = tomReflectionInfo.createInstance<SimplePerson>();
      tomReflectionInfo.setValues(person, {
        'name': 'FromJson',
        'age': 35,
        'active': true,
        'salary': 80000.0,
      });

      expect(person.name, 'FromJson');
      expect(person.age, 35);
      expect(person.active, true);
      expect(person.salary, 80000.0);
    });

    test('should create instance with nested objects from JSON', () {
      final person = tomReflectionInfo.createInstance<PersonWithAddress>();
      tomReflectionInfo.setValues(person, {
        'name': 'WithAddress',
        'address': {
          'street': 'JSON Street',
          'city': 'JSON City',
          'zipCode': '99999',
        }
      });

      expect(person.name, 'WithAddress');
      expect(person.address, isNotNull);
      expect(person.address!.street, 'JSON Street');
    });

    test('should use fromJson factory when available', () {
      final jsonData = {'name': 'FactoryPerson', 'age': 45};
      final person = PersonWithFromJson.fromJson(jsonData);

      expect(person.name, 'FactoryPerson');
      expect(person.age, 45);
    });
  });

  group('TomReflector - Complex Scenarios', () {
    test('should handle complex entity with multiple property types', () {
      final entity = ComplexEntity();
      tomReflectionInfo.setValues(entity, {
        'name': 'Complex',
        'tags': ['tag1', 'tag2', 'tag3'],
        'scores': {'math': 95, 'science': 88, 'english': 92},
        'nestedInfo': {'info': 'Important', 'level': 5},
        'nestedList': [
          {'info': 'First', 'level': 1},
          {'info': 'Second', 'level': 2},
        ]
      });

      expect(entity.name, 'Complex');
      expect(entity.tags, ['tag1', 'tag2', 'tag3']);
      expect(entity.scores, {'math': 95, 'science': 88, 'english': 92});
      expect(entity.nestedInfo, isNotNull);
      expect(entity.nestedInfo!.info, 'Important');
      expect(entity.nestedInfo!.level, 5);
      expect(entity.nestedList.length, 2);
      expect(entity.nestedList[0].info, 'First');
      expect(entity.nestedList[1].info, 'Second');
    });

    test('should roundtrip complex entity through getValues and setValues', () {
      // Create and populate original
      final original = ComplexEntity();
      original.name = 'Original';
      original.tags = ['a', 'b'];
      original.scores = {'x': 1, 'y': 2};
      original.nestedInfo = NestedInfo()
        ..info = 'NestedData'
        ..level = 10;

      // Get values
      final values = tomReflectionInfo.getValues(original);

      // Create new instance and set values
      final copy = ComplexEntity();
      tomReflectionInfo.setValues(copy, values);

      expect(copy.name, original.name);
      expect(copy.tags, original.tags);
      expect(copy.scores, original.scores);
      expect(copy.nestedInfo?.info, original.nestedInfo?.info);
      expect(copy.nestedInfo?.level, original.nestedInfo?.level);
    });
  });

  group('TomReflector - DateTime Map serialization roundtrip', () {
    test('should roundtrip Map<String, DateTime>', () {
      final holder = DateTimeMapHolder();
      holder.dateTimeMap = {
        'start': DateTime(2024, 1, 1, 9, 0),
        'end': DateTime(2024, 12, 31, 17, 0),
      };

      final values = tomReflectionInfo.getValues(holder);
      final newHolder = DateTimeMapHolder();
      tomReflectionInfo.setValues(newHolder, values);

      expect(newHolder.dateTimeMap!['start']!.year, 2024);
      expect(newHolder.dateTimeMap!['start']!.month, 1);
      expect(newHolder.dateTimeMap!['end']!.month, 12);
    });

    test('should roundtrip Map<String, TomZonedDate>', () {
      final holder = DateTimeMapHolder();
      final tz1 = TomTimezone.fromName('Europe/Berlin');
      final tz2 = TomTimezone.fromName('Asia/Tokyo');
      holder.zonedDateMap = {
        'date1': TomZonedDate(year: 2024, month: 6, day: 15, timezone: tz1),
        'date2': TomZonedDate(year: 2024, month: 7, day: 20, timezone: tz2),
      };

      final values = tomReflectionInfo.getValues(holder);
      final newHolder = DateTimeMapHolder();
      tomReflectionInfo.setValues(newHolder, values);

      expect(newHolder.zonedDateMap!['date1']!.timezone.timezone, 'Europe/Berlin');
      expect(newHolder.zonedDateMap!['date2']!.timezone.timezone, 'Asia/Tokyo');
    });
  });

  group('TomReflector - DateTime List serialization roundtrip', () {
    test('should roundtrip List<DateTime>', () {
      final holder = DateTimeListHolder();
      holder.dateTimeList = [
        DateTime(2024, 1, 1),
        DateTime(2024, 6, 15),
        DateTime(2024, 12, 31),
      ];

      final values = tomReflectionInfo.getValues(holder);
      final newHolder = DateTimeListHolder();
      tomReflectionInfo.setValues(newHolder, values);

      expect(newHolder.dateTimeList!.length, 3);
      expect(newHolder.dateTimeList![0].month, 1);
      expect(newHolder.dateTimeList![1].month, 6);
      expect(newHolder.dateTimeList![2].month, 12);
    });

    test('should roundtrip List<TomZonedDateTime>', () {
      final holder = DateTimeListHolder();
      final tz1 = TomTimezone.fromName('UTC');
      final tz2 = TomTimezone.fromName('Europe/Paris');
      holder.zonedDateTimeList = [
        TomZonedDateTime(
          year: 2024,
          month: 1,
          day: 1,
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          timezone: tz1,
        ),
        TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          second: 0,
          millisecond: 0,
          timezone: tz2,
        ),
      ];

      final values = tomReflectionInfo.getValues(holder);
      final newHolder = DateTimeListHolder();
      tomReflectionInfo.setValues(newHolder, values);

      expect(newHolder.zonedDateTimeList!.length, 2);
      expect(newHolder.zonedDateTimeList![0].timezone.timezone, 'UTC');
      expect(newHolder.zonedDateTimeList![1].timezone.timezone, 'Europe/Paris');
    });
  });

  group('TomReflectorException', () {
    test('should have meaningful toString', () {
      final exception = TomReflectorException('test.error.key', 'Test error message');
      expect(exception.toString(), contains('Test error message'));
    });
  });

  // ===========================================================================
  // Tests for Uninitialized Collections (nullable without default value)
  // ===========================================================================
  group('tomReflectionInfo.setValues - Uninitialized Lists', () {
    test('should set List<TeamMember>? when field is null (no default value)', () {
      final holder = UninitializedListHolder();
      
      // Verify field starts as null
      expect(holder.members, isNull);
      
      // Set values using reflection
      tomReflectionInfo.setValues(holder, {
        'name': 'Test Holder',
        'members': [
          {'name': 'Alice', 'role': 'Developer'},
          {'name': 'Bob', 'role': 'Designer'},
        ]
      });
      
      // Verify the list was created and populated
      expect(holder.name, 'Test Holder');
      expect(holder.members, isNotNull);
      expect(holder.members!.length, 2);
      expect(holder.members![0].name, 'Alice');
      expect(holder.members![0].role, 'Developer');
      expect(holder.members![1].name, 'Bob');
      expect(holder.members![1].role, 'Designer');
    });

    test('should handle empty list for uninitialized List<TeamMember>?', () {
      final holder = UninitializedListHolder();
      
      expect(holder.members, isNull);
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Empty List Holder',
        'members': []
      });
      
      expect(holder.members, isNotNull);
      expect(holder.members!.length, 0);
    });

    test('should set List<Address>? when field is null', () {
      final holder = UninitializedCollectionsHolder();
      
      expect(holder.addresses, isNull);
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Multi Collection Holder',
        'addresses': [
          {'street': '123 Main St', 'city': 'Springfield', 'zipCode': '12345'},
          {'street': '456 Oak Ave', 'city': 'Shelbyville', 'zipCode': '67890'},
        ]
      });
      
      expect(holder.addresses, isNotNull);
      expect(holder.addresses!.length, 2);
      expect(holder.addresses![0].street, '123 Main St');
      expect(holder.addresses![0].city, 'Springfield');
      expect(holder.addresses![1].street, '456 Oak Ave');
      expect(holder.addresses![1].city, 'Shelbyville');
    });
  });

  group('tomReflectionInfo.setValues - Uninitialized Maps', () {
    test('should set Map<String, NestedInfo>? when field is null (no default value)', () {
      final holder = UninitializedMapHolder();
      
      // Verify field starts as null
      expect(holder.infoMap, isNull);
      
      // Set values using reflection
      tomReflectionInfo.setValues(holder, {
        'name': 'Test Map Holder',
        'infoMap': {
          'first': {'info': 'First Info', 'level': 1},
          'second': {'info': 'Second Info', 'level': 2},
        }
      });
      
      // Verify the map was created and populated
      expect(holder.name, 'Test Map Holder');
      expect(holder.infoMap, isNotNull);
      expect(holder.infoMap!.length, 2);
      expect(holder.infoMap!['first']!.info, 'First Info');
      expect(holder.infoMap!['first']!.level, 1);
      expect(holder.infoMap!['second']!.info, 'Second Info');
      expect(holder.infoMap!['second']!.level, 2);
    });

    test('should handle empty map for uninitialized Map<String, NestedInfo>?', () {
      final holder = UninitializedMapHolder();
      
      expect(holder.infoMap, isNull);
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Empty Map Holder',
        'infoMap': {}
      });
      
      expect(holder.infoMap, isNotNull);
      expect(holder.infoMap!.length, 0);
    });

    test('should set Map<String, TeamMember>? when field is null', () {
      final holder = UninitializedCollectionsHolder();
      
      expect(holder.teamMembers, isNull);
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Team Map Holder',
        'teamMembers': {
          'lead': {'name': 'Charlie', 'role': 'Team Lead'},
          'dev': {'name': 'Diana', 'role': 'Developer'},
        }
      });
      
      expect(holder.teamMembers, isNotNull);
      expect(holder.teamMembers!.length, 2);
      expect(holder.teamMembers!['lead']!.name, 'Charlie');
      expect(holder.teamMembers!['lead']!.role, 'Team Lead');
      expect(holder.teamMembers!['dev']!.name, 'Diana');
      expect(holder.teamMembers!['dev']!.role, 'Developer');
    });
  });

  group('tomReflectionInfo.setValues - Uninitialized Collections Combined', () {
    test('should set both uninitialized List and Map in same object', () {
      final holder = UninitializedCollectionsHolder();
      
      expect(holder.addresses, isNull);
      expect(holder.teamMembers, isNull);
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Full Holder',
        'addresses': [
          {'street': '789 Pine Rd', 'city': 'Capital City', 'zipCode': '11111'},
        ],
        'teamMembers': {
          'manager': {'name': 'Eve', 'role': 'Manager'},
        }
      });
      
      expect(holder.name, 'Full Holder');
      expect(holder.addresses, isNotNull);
      expect(holder.addresses!.length, 1);
      expect(holder.addresses![0].street, '789 Pine Rd');
      expect(holder.teamMembers, isNotNull);
      expect(holder.teamMembers!.length, 1);
      expect(holder.teamMembers!['manager']!.name, 'Eve');
    });

    // NOTE: The following tests verify ATOMIC deserialization (bug §48): a null
    // value destined for a non-nullable collection element MUST surface a
    // TomReflectorException and leave the target field untouched, rather than
    // silently truncating it to whatever was materialized before the failure.
    // The collection types here are:
    // - List<TeamMember>? (elements are non-nullable TeamMember)
    // - Map<String, NestedInfo>? (values are non-nullable NestedInfo)
    // To support null elements/values, you would need List<TeamMember?>? or
    // Map<String, NestedInfo?>? which is exercised in the next group.

    test('should propagate failure and leave list untouched when null element hits non-nullable List<TeamMember>?', () {
      // A null element cannot be added to List<TeamMember>. The deserialization
      // must build the new list atomically and propagate a TomReflectorException
      // on failure — never assigning a half-built list to the field.
      final holder = UninitializedListHolder();

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'name': 'Mixed Elements Holder',
          'members': [
            {'name': 'Frank', 'role': 'Tester'},
            null, // Cannot be held by List<TeamMember>
            {'name': 'Grace', 'role': 'QA'},
          ]
        }),
        throwsA(isA<TomReflectorException>()),
      );

      // Atomic: the field was never null-initialized nor partially filled.
      expect(holder.members, isNull);
    });

    test('should propagate failure and leave map untouched when null value hits non-nullable Map<String, NestedInfo>?', () {
      // A null value cannot be added to Map<String, NestedInfo>. The
      // deserialization must build the new map atomically and propagate a
      // TomReflectorException — never assigning a half-built map to the field.
      final holder = UninitializedMapHolder();

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'name': 'Mixed Values Holder',
          'infoMap': {
            'valid': {'info': 'Valid Info', 'level': 3},
            'empty': null, // Cannot be held by Map<String, NestedInfo>
            'another': {'info': 'Another Info', 'level': 5},
          }
        }),
        throwsA(isA<TomReflectorException>()),
      );

      // Atomic: the field was never null-initialized nor partially filled.
      expect(holder.infoMap, isNull);
    });

    test('should preserve pre-populated list content when an update fails atomically', () {
      // A pre-populated List<TeamMember> must keep its existing content if the
      // incoming update cannot be materialized in full (bug §48 atomicity).
      final team = Team()
        ..teamName = 'Original'
        ..members.add(TeamMember()
          ..name = 'Old'
          ..role = 'Veteran');

      expect(
        () => tomReflectionInfo.setValues(team, {
          'teamName': 'Updated',
          'members': [
            {'name': 'New', 'role': 'Rookie'},
            null, // Forces the whole members update to fail
            {'name': 'Third', 'role': 'Junior'},
          ]
        }),
        throwsA(isA<TomReflectorException>()),
      );

      // The original member list is intact — not cleared, not truncated.
      expect(team.members.length, 1);
      expect(team.members[0].name, 'Old');
    });
  });

  // ==========================================================================
  // Tests for Nullable Element/Value Types (List<X?>? and Map<String, X?>?)
  // ==========================================================================
  group('tomReflectionInfo.setValues - Nullable Element Collections', () {
    test('should add null elements to List<TeamMember?>?', () {
      final holder = NullableElementListHolder();
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Nullable Elements Holder',
        'members': [
          {'name': 'Frank', 'role': 'Tester'},
          null,
          {'name': 'Grace', 'role': 'QA'},
        ]
      });
      
      expect(holder.members, isNotNull);
      expect(holder.members!.length, 3);
      expect(holder.members![0]!.name, 'Frank');
      expect(holder.members![1], isNull);
      expect(holder.members![2]!.name, 'Grace');
    });

    test('should add null values to Map<String, NestedInfo?>?', () {
      final holder = NullableValueMapHolder();
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Nullable Values Holder',
        'infoMap': {
          'valid': {'info': 'Valid Info', 'level': 3},
          'empty': null,
          'another': {'info': 'Another Info', 'level': 5},
        }
      });
      
      expect(holder.infoMap, isNotNull);
      expect(holder.infoMap!.length, 3);
      expect(holder.infoMap!['valid']!.info, 'Valid Info');
      expect(holder.infoMap!['empty'], isNull);
      expect(holder.infoMap!['another']!.info, 'Another Info');
    });

    test('should handle list with multiple null elements', () {
      final holder = NullableElementListHolder();
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Multiple Nulls Holder',
        'members': [
          null,
          {'name': 'Alice', 'role': 'Dev'},
          null,
          null,
          {'name': 'Bob', 'role': 'QA'},
        ]
      });
      
      expect(holder.members, isNotNull);
      expect(holder.members!.length, 5);
      expect(holder.members![0], isNull);
      expect(holder.members![1]!.name, 'Alice');
      expect(holder.members![2], isNull);
      expect(holder.members![3], isNull);
      expect(holder.members![4]!.name, 'Bob');
    });

    test('should handle map with multiple null values', () {
      final holder = NullableValueMapHolder();
      
      tomReflectionInfo.setValues(holder, {
        'name': 'Multiple Null Values Holder',
        'infoMap': {
          'first': null,
          'second': {'info': 'Some Info', 'level': 1},
          'third': null,
          'fourth': null,
        }
      });
      
      expect(holder.infoMap, isNotNull);
      expect(holder.infoMap!.length, 4);
      expect(holder.infoMap!['first'], isNull);
      expect(holder.infoMap!['second']!.info, 'Some Info');
      expect(holder.infoMap!['third'], isNull);
      expect(holder.infoMap!['fourth'], isNull);
    });

    test('should handle list with all null elements', () {
      final holder = NullableElementListHolder();
      
      tomReflectionInfo.setValues(holder, {
        'name': 'All Nulls Holder',
        'members': [null, null, null]
      });
      
      expect(holder.members, isNotNull);
      expect(holder.members!.length, 3);
      expect(holder.members!.every((e) => e == null), isTrue);
    });

    test('should handle map with all null values', () {
      final holder = NullableValueMapHolder();
      
      tomReflectionInfo.setValues(holder, {
        'name': 'All Null Values Holder',
        'infoMap': {
          'a': null,
          'b': null,
          'c': null,
        }
      });
      
      expect(holder.infoMap, isNotNull);
      expect(holder.infoMap!.length, 3);
      expect(holder.infoMap!.values.every((v) => v == null), isTrue);
    });

    test('List<X?>? and Map<String, X?>? without nulls work correctly', () {
      final listHolder = NullableElementListHolder();
      final mapHolder = NullableValueMapHolder();
      
      tomReflectionInfo.setValues(listHolder, {
        'name': 'No Nulls List',
        'members': [
          {'name': 'Alice', 'role': 'Dev'},
          {'name': 'Bob', 'role': 'QA'},
        ]
      });
      
      tomReflectionInfo.setValues(mapHolder, {
        'name': 'No Nulls Map',
        'infoMap': {
          'first': {'info': 'First', 'level': 1},
          'second': {'info': 'Second', 'level': 2},
        }
      });
      
      expect(listHolder.members!.length, 2);
      expect(listHolder.members![0]!.name, 'Alice');
      expect(listHolder.members![1]!.name, 'Bob');
      
      expect(mapHolder.infoMap!.length, 2);
      expect(mapHolder.infoMap!['first']!.info, 'First');
      expect(mapHolder.infoMap!['second']!.info, 'Second');
    });
  });

  // ==========================================================================
  // Type Resolution — generic-argument validation (bug §49a)
  // ==========================================================================
  group('tomReflectionInfo type resolution validation', () {
    test('mapValueElementType throws TomReflectorException on a non-generic value', () {
      // 42.runtimeType.toString() == 'int' has no '<...>' — must not force-unwrap.
      expect(
        () => tomReflectionInfo.mapValueElementType(42),
        throwsA(isA<TomReflectorException>()),
      );
    });

    test('mapValueElementType throws TomReflectorException on a single-arg generic', () {
      // List<int> only has one type argument — not a Map<K, V>; must not RangeError.
      expect(
        () => tomReflectionInfo.mapValueElementType(<int>[1, 2, 3]),
        throwsA(isA<TomReflectorException>()),
      );
    });

    test('singleElementType throws TomReflectorException on a non-generic value', () {
      expect(
        () => tomReflectionInfo.singleElementType(42),
        throwsA(isA<TomReflectorException>()),
      );
    });
  });

  // ==========================================================================
  // Round-trip serialization (tests §33a)
  // ==========================================================================
  group('tomReflectionInfo round-trip serialization', () {
    test('createInstanceFromJsonString reconstructs a Team with nested members', () {
      final team = Team()
        ..teamName = 'Alpha'
        ..members.add(TeamMember()
          ..name = 'Alice'
          ..role = 'Lead')
        ..members.add(TeamMember()
          ..name = 'Bob'
          ..role = 'Dev');

      final json = tomReflectionInfo.convertToJsonString(team);
      final mirror = tomReflector.reflectType(Team) as ClassMirror;
      final restored =
          tomReflectionInfo.createInstanceFromJsonString<Team>(mirror, json);

      expect(restored, isNotNull);
      expect(restored!.teamName, 'Alpha');
      expect(restored.members.length, 2);
      expect(restored.members[0].name, 'Alice');
      expect(restored.members[0].role, 'Lead');
      expect(restored.members[1].name, 'Bob');
      expect(restored.members[1].role, 'Dev');
    });

    test('createInstanceFromJson round-trips a PersonWithAddress', () {
      final person = PersonWithAddress()
        ..name = 'Carol'
        ..address = (Address()
          ..street = '1 Main St'
          ..city = 'Springfield'
          ..zipCode = '12345');

      final json = tomReflectionInfo.getValues(person);
      final mirror =
          tomReflector.reflectType(PersonWithAddress) as ClassMirror;
      final restored =
          tomReflectionInfo.createInstanceFromJson<PersonWithAddress>(mirror, json);

      expect(restored, isNotNull);
      expect(restored!.name, 'Carol');
      expect(restored.address, isNotNull);
      expect(restored.address!.street, '1 Main St');
      expect(restored.address!.city, 'Springfield');
      expect(restored.address!.zipCode, '12345');
    });
  });

  group('there is one reflector, and unreflected input is reported', () {
    // The constructor used to take a reflector and store it in a public
    // `final reflector` field documented as "used for all reflection
    // operations", while `createInstance`, `setValues` and `getValues` read
    // the global `tomReflector` regardless. The choice could never have been
    // honoured — the generator emits no data for an indirect subclass of
    // `Reflection`, and `const TomReflector()` is canonicalised to the global
    // — so the parameter was removed rather than obeyed. What remains
    // testable is the consequence the split was hiding: what a caller sees
    // when the reflector does not know the type.

    test('a converter of your own is the same converter', () {
      // Standing in for "the constructor no longer offers a choice", which is
      // a compile-time fact. What is observable is that a locally built
      // converter has nothing to differ about: same registry, same answers.
      final own = TomReflectionInfo();
      final person = SimplePerson()
        ..name = 'Ada'
        ..age = 36;

      expect(own.getValues(person), tomReflectionInfo.getValues(person));
      expect(own.createInstance<SimplePerson>(), isA<SimplePerson>());
    });

    test('getValues reports an unreflected class instead of leaking', () {
      // Was a bare `NoSuchCapabilityError` from inside the reflectable
      // package: it named the type and nothing else — not the operation, not
      // the missing annotation — and slipped past every `on
      // TomReflectorException` the framework has.
      expect(
        () => tomReflectionInfo.getValues(NotReflectedHolder()),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.reflect.not_reflectable',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(
                  contains('getValues'),
                  contains('NotReflectedHolder'),
                  contains('@tomReflector'),
                ),
              ),
        ),
      );
    });

    test('setValues reports an unreflected class instead of leaking', () {
      expect(
        () => tomReflectionInfo.setValues(NotReflectedHolder(), {'name': 'x'}),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.reflect.not_reflectable',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('setValues'),
              ),
        ),
      );
    });

    test('reportReflectObject reports rather than leaking', () {
      // A debug helper, but it reflects the same way and so failed the same
      // way; left out, it would be the one door still open.
      expect(
        () => tomReflectionInfo.reportReflectObject(NotReflectedHolder()),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('reportReflectObject'),
          ),
        ),
      );
    });

    test('createInstance keeps reporting its own failure', () {
      // Already wrapped before this change; asserted so that routing it
      // through the shared boundary later cannot quietly drop the type name.
      expect(
        () => tomReflectionInfo.createInstance<NotReflectedHolder>(),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('NotReflectedHolder'),
          ),
        ),
      );
    });

    test('a reflected class is untouched by the boundary', () {
      // The control: the wrapping must not turn a working reflect into a
      // failure, nor swallow an error raised further in.
      final person = SimplePerson()
        ..name = 'Grace'
        ..age = 45;

      expect(tomReflectionInfo.getValues(person), {
        'name': 'Grace',
        'age': 45,
        'active': false,
        'salary': 0.0,
      });
    });
  });
}
