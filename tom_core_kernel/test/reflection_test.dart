// ignore_for_file: unused_local_variable
import 'dart:async';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_init;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'reflection_test.reflection.dart';
import 'support/reflection_clash_first.dart' as first_clash;
import 'support/reflection_clash_second.dart' as second_clash;

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

/// A settings holder whose two required fields a caller must supply, and one
/// ordinary field it may leave out.
/// Deliberately **not** annotated: the class a reflective question has no
/// mirrors to answer from.
class _Unreflected {
  String name = '';
}

@tomReflector
class RequiredSettings {
  @TomRequiredField()
  String dbUrl = '';

  @TomRequiredField()
  int port = 0;

  String label = '';

  RequiredSettings();
}

/// The inherited case: a required field declared on a base class has to be
/// found on an instance of the subclass, which is where an application's own
/// configuration lives.
@tomReflector
class DerivedSettings extends RequiredSettings {
  @TomRequiredField()
  String region = '';

  DerivedSettings();
}

/// A settings holder that marks one field required and two recommended, so a
/// test can tell the two questions apart on one class.
@tomReflector
class RecommendedSettings {
  @TomRequiredField()
  String dbUrl = '';

  @TomRecommendedField()
  String region = '';

  @TomRecommendedField()
  int poolSize = 0;

  String label = '';

  RecommendedSettings();
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
class SetHolder {
  Set<String>? stringSet;
  Set<int>? intSet;
  Set<String?>? nullableStringSet;

  SetHolder();
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

/// A `fromJson` hook that exists and always raises.
///
/// Distinct from feeding [PersonWithFromJson] a badly typed payload: this one
/// fails for a reason of its own, so nothing about the payload could explain
/// the failure away.
@tomReflector
class ThrowingFromJsonHolder {
  String name = '';

  ThrowingFromJsonHolder();

  factory ThrowingFromJsonHolder.fromJson(Map<String, dynamic> json) =>
      throw StateError('fromJson is broken');
}

/// Carries both reflective JSON hooks in working order, so that
/// `setValues`/`getValues` hand over to them instead of walking fields.
///
/// Both hooks write something a field walk could not produce, which is what
/// makes "the hook ran" observable.
@tomReflector
class JsonHookHolder {
  String name = '';
  int age = 0;

  JsonHookHolder();

  void jsonDecode(Map<String, dynamic> json) {
    name = 'decoded:${json['name']}';
    age = 99;
  }

  Map<String, Object?> get jsonEncode => {'encoded': name};
}

/// The documented way out of dynamic-collection type erasure.
///
/// A `Map<String, dynamic>` field cannot tell the decoder that one of its
/// values was a [DateTime], so the reflective field walk puts the ISO text
/// back. This class knows what it stores, and a `jsonDecode` hook is where
/// that knowledge can be applied — see "Dynamic Collections Carry Values, Not
/// Types" in `doc/reflection/reflection.md`.
///
/// The hook takes decoding over *entirely*, so it restores [label] too rather
/// than only the field it cares about.
@tomReflector
class DynamicMapWithHookHolder {
  String label = '';
  Map<String, dynamic>? attributes;

  DynamicMapWithHookHolder();

  void jsonDecode(Map<String, dynamic> json) {
    label = json['label'] as String? ?? '';
    final source = json['attributes'] as Map?;
    attributes = source?.map(
      (key, value) => MapEntry(key as String, _restore(value)),
    );
  }

  /// `when` is the one key this model stores a [DateTime] under.
  static Object? _restore(Object? value) =>
      value is String ? (DateTime.tryParse(value) ?? value) : value;
}

/// Both hooks exist and both raise.
@tomReflector
class ThrowingJsonHookHolder {
  String name = '';

  ThrowingJsonHookHolder();

  void jsonDecode(Map<String, dynamic> json) =>
      throw StateError('jsonDecode is broken');

  Map<String, Object?> get jsonEncode =>
      throw StateError('jsonEncode is broken');
}

/// A `jsonEncode` hook that exists, returns normally, and returns something
/// that is not a JSON object.
@tomReflector
class BadJsonEncodeHolder {
  String name = '';

  BadJsonEncodeHolder();

  Object get jsonEncode => 'not a map';
}

/// A plain [TomClass], carrying no hook of its own.
///
/// `getValues`/`setValues` short-circuit on `o is TomClass` before they reflect
/// on anything, so this class is what "the delegation happened" is measured
/// against: its observable members are reachable only through that branch.
@tomReflector
class ObservablePoint extends TomClass {
  TomString label = TomString('');
  TomInt x = TomInt(0);
}

/// A [TomClass] that *also* declares both reflective hooks.
///
/// Nothing in the language stops a class from doing this, and the two
/// mechanisms disagree about what the object's JSON is — so which one wins is
/// a real decision, and this class is what pins it. Both hooks write a value
/// no member walk could produce, so "the hook ran instead" would be obvious.
@tomReflector
class ObservableWithJsonHooks extends TomClass {
  TomString label = TomString('');

  Map<String, Object?> get jsonEncode => {'encoded': 'by the getter'};

  void jsonDecode(Map<String, dynamic> json) {
    label | 'decoded by the hook';
  }
}

/// Declares that it serializes itself, in the way the interface exists to make
/// cheap to detect.
///
/// `toJson` deliberately renames the field, so honouring the interface and
/// walking the fields cannot produce the same map.
@tomReflector
class SelfSerializingDto implements TomJsonSerializable {
  String status = '';

  SelfSerializingDto();

  @override
  Map<String, Object?> toJson() => {'ok': status};
}

/// Carries a plain `toJson()` and nothing else — no interface, no annotation
/// beyond `@tomReflector`, no getter.
///
/// The structural half of the same question [SelfSerializingDto] asks
/// nominally.
@tomReflector
class PlainToJsonHolder {
  String status = '';

  PlainToJsonHolder();

  Map<String, Object?> toJson() => {'ok': status};
}

/// Declares the interface and carries **no `@tomReflector`**.
///
/// The interface is meant to be settled by an `is` test before any mirror is
/// taken, and this type is the only way to show that it is: every other
/// fixture here would serialize anyway by walking its fields, so an
/// implementation that consulted the interface after reflecting would still
/// pass. This one cannot be reflected at all — if the `is` test moved below
/// `_annotatedType` it would throw instead of rendering.
class UnreflectedSelfSerializingDto implements TomJsonSerializable {
  String status = '';

  UnreflectedSelfSerializingDto();

  @override
  Map<String, Object?> toJson() => {'ok': status};
}

/// Declares the interface *and* carries a disagreeing `jsonEncode` getter.
///
/// Pins that the nominal `toJson` outranks `jsonEncode`, which is the half of
/// the ordering that keeps the interface from changing a type's wire format:
/// [EncodeAndToJsonHolder] is this class without the `implements`, and the two
/// must answer the same way.
@tomReflector
class InterfaceAndEncodeHolder implements TomJsonSerializable {
  String status = '';

  InterfaceAndEncodeHolder();

  Map<String, Object?> get jsonEncode => {'from': 'jsonEncode'};

  @override
  Map<String, Object?> toJson() => {'from': 'toJson'};
}

/// A `toJson` that returns something other than a JSON object.
///
/// The structural counterpart of the same fault on the `jsonEncode` getter:
/// the hook was written to replace the field walk, so quietly performing the
/// walk anyway would hide the defect behind a plausible-looking payload.
@tomReflector
class BadToJsonHolder {
  String status = '';

  BadToJsonHolder();

  Object toJson() => 'not a map';
}

/// A `toJson` that always throws, to separate "no hook" from "broken hook".
@tomReflector
class ThrowingToJsonHolder {
  String status = '';

  ThrowingToJsonHolder();

  Map<String, Object?> toJson() => throw StateError('toJson is broken');
}

/// Carries two *outbound* hooks that disagree.
@tomReflector
class EncodeAndToJsonHolder {
  String status = '';

  EncodeAndToJsonHolder();

  Map<String, Object?> get jsonEncode => {'from': 'jsonEncode'};

  Map<String, Object?> toJson() => {'from': 'toJson'};
}

/// Carries two *inbound* hooks that disagree: a `fromJson` constructor and a
/// `jsonDecode` method, each writing a distinguishable marker.
@tomReflector
class FromJsonAndDecodeHolder {
  String source = '';

  FromJsonAndDecodeHolder();

  factory FromJsonAndDecodeHolder.fromJson(Map<String, dynamic> json) =>
      FromJsonAndDecodeHolder()..source = 'fromJson';

  void jsonDecode(Map<String, dynamic> json) {
    source = 'jsonDecode';
  }
}

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

/// Deliberately not annotated, but named as a field type by
/// [OpaqueFieldHolder] and so pulled into the generated data anyway.
///
/// That last part is the whole point, and the reason this is not
/// [NotReflectedHolder]: capabilities quantify over field types, so mentioning
/// a class from an annotated one generates data for it. It therefore reflects,
/// and is refused by this module's `@tomReflector` metadata check rather than
/// by `tom_reflection` — a different guard, needing its own subject.
class QuantifiedUnannotated {
  String name = '';

  QuantifiedUnannotated();
}

/// Test class whose fields declare types the map-setting path cannot build.
///
/// Every strategy that fills a field from a `Map` ends by trying to instantiate
/// the field's declared type and fill it. These four declarations each defeat
/// that in a different way — `dynamic` and `Object?` name no class to build,
/// [QuantifiedUnannotated] names one that carries no `@tomReflector`, and
/// `GenericHolder<int>` names a generic instantiation that the registry, which
/// is keyed by declaration, does not hold. They exist to pin what happens
/// after the last strategy declines, which is not the same answer in all four
/// cases.
@tomReflector
class OpaqueFieldHolder {
  dynamic anything;
  Object? thing;
  QuantifiedUnannotated? plain;
  GenericHolder<int>? generic;

  OpaqueFieldHolder();
}

/// Test class whose object field is `late`, so reading it before it is
/// assigned throws instead of answering null.
///
/// The map-setting path asks a field what it already holds, because a field
/// holding an object is filled in place rather than replaced. `late` is the
/// one declaration for which that question has no answer: reading an
/// unassigned `late` field raises `LateInitializationError`, and the generated
/// accessor is a direct field read (`(instance) => instance.address`), so the
/// error arrives at the reflector rather than being contained by it. Treating
/// that as anything but "there is nothing here to fill" would make a `late`
/// object field impossible to deserialize into.
@tomReflector
class LateFieldHolder {
  late Address address;

  /// A map field the annotated-object strategy does not claim.
  ///
  /// That strategy takes any field whose declared type begins `Map<String,`,
  /// so a raw `Map` is one of the few shapes that reaches the fill-in-place
  /// strategy with a map already in it. Filling it can then fail on the
  /// element type of whatever map the field actually holds, which is the only
  /// reachable way to make that strategy fail *after* it has decided it
  /// applies.
  Map? raw;

  LateFieldHolder();
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

/// Test class with collection fields whose element type is itself a collection.
///
/// One level of nesting is the supported depth; this fixture exists to pin down
/// what the *unsupported* second level actually does, so the documentation can
/// say it rather than infer it.
@tomReflector
class NestedCollectionHolder {
  String name = '';
  List<List<String>>? nestedLists;
  Map<String, List<Address>>? nestedMaps;

  NestedCollectionHolder();
}

/// An annotated class whose every wire member is `final`.
///
/// The shape the field walk cannot serve: `final` members are skipped outbound
/// because they cannot be restored inbound, so a class made only of them
/// contributed nothing and rendered as `{}`.
@tomReflector
class AllFinalHolder {
  final String name;
  final int age;

  AllFinalHolder(this.name, this.age);
}

/// Holds collections of both annotated classes named `ClashingItem`, which
/// differ only by the library that declares them.
///
/// The field walk resolves an element type through the field's own mirror —
/// its declared type arguments — so the shared simple name never enters into
/// it, and both collections have to round-trip as their own class.
@tomReflector
class ClashingItemsHolder {
  List<first_clash.ClashingItem> firsts = [];
  List<second_clash.ClashingItem> seconds = [];
  Map<String, first_clash.ClashingItem> firstsByName = {};
  Map<String, second_clash.ClashingItem> secondsByName = {};

  ClashingItemsHolder();
}

/// A holder whose collections name an element class that cannot be built from
/// a map: [AllFinalHolder] has no no-argument constructor, so every element
/// handed to either field is refused — and the refusal has to say which field
/// and which position it came from, not only which class would not build.
@tomReflector
class UnbuildableElementsHolder {
  List<AllFinalHolder>? items;
  Map<String, AllFinalHolder>? byName;

  UnbuildableElementsHolder();
}

/// The same shape, declaring the structural `toJson` hook.
///
/// The control for [AllFinalHolder]: an immutable DTO is not refused for being
/// immutable, it is refused for having said nothing about how to render. This
/// one has said, so the walk is never reached.
@tomReflector
class AllFinalWithToJsonHolder {
  final String name;

  AllFinalWithToJsonHolder(this.name);

  Map<String, Object?> toJson() => {'name': name};
}

/// An annotated class mixing one `final` member with a settable one.
///
/// The guard asks whether the walk produced *nothing*, not whether a `final`
/// member exists — a class that still contributes a field is serializable and
/// is left alone, silently dropping only the member that could never return.
@tomReflector
class PartlyFinalHolder {
  final String id;
  String label = '';

  PartlyFinalHolder(this.id);
}

/// An annotated class with no wire members at all.
///
/// The other control: `{}` is the honest rendering of a class that declares
/// nothing, so nothing is diagnosed. Only a class that *has* members and
/// dropped every one of them is a silent loss.
@tomReflector
class NoMemberHolder {
  NoMemberHolder();
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

/// A three-argument generic, which is an arity neither element resolver takes.
///
/// Unannotated on purpose, and named by no annotated class: the resolvers
/// refuse it on its shape before any lookup happens, so reflection data for it
/// would prove nothing and would only add a second class to the quantified set.
class Triple<A, B, C> {
  Triple();
}

/// Deliberately **not** annotated, so no mirror data exists for it.
///
/// The one input for which `tom_reflection`, rather than this module's code,
/// decides what the failure looks like — which is what makes it the test
/// subject for the error boundary.
///
/// **No annotated class in this file may name this type.** Capabilities
/// quantify over field types, so one `NotReflectedHolder` field anywhere would
/// generate data for it; it would start reflecting, and the tests that depend
/// on it *not* reflecting would quietly begin exercising the metadata guard
/// instead. Use [QuantifiedUnannotated] when an unannotated *field type* is
/// what is wanted.
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

  // `getValues` and `setValues` must not reflect the instance and then throw
  // that mirror away to look the class up again by `o.runtimeType`. That
  // second lookup is declaration-keyed, so a generic value reflects
  // successfully and is then reported as un-reflectable one line later — it
  // could be neither serialized nor populated, despite being annotated.
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

    // `createInstance<T>([Type? type])` takes the type twice over, and the two
    // are not the same question: the positional says *what to build*, the type
    // argument says *what to call the result*. They default to each other, and
    // documenting them as interchangeable is what produced a Quick Start that
    // named a class it never declared.
    //
    // The positional exists for the case where the type is only known at
    // runtime — `server_connection` picks a response type out of a map — and
    // there the type argument cannot be written, so it infers to the bound.

    test('the positional selects the class when there is no type argument', () {
      // Statically this is an `Object`: `T` is not inferred from the
      // positional, so it falls to the bound. The built object is still a
      // SimplePerson, which is the whole point of passing the Type.
      final Object person = tomReflectionInfo.createInstance(SimplePerson);
      expect(person, isA<SimplePerson>());
      expect((person as SimplePerson).age, 0);
    });

    test(
      'the type argument is the cast applied to what the positional built',
      () {
        // A supertype is therefore accepted — the cast succeeds — which is the
        // only reason to pass both.
        final Object person = tomReflectionInfo.createInstance<Object>(
          SimplePerson,
        );
        expect(person, isA<SimplePerson>());
      },
    );

    test('a positional that is not a T fails as an instance-creation error', () {
      // The mismatch is not caught statically — the two parameters are
      // unrelated until the cast — so it surfaces at runtime, wrapped like any
      // other construction failure rather than as a bare CastError.
      expect(
        () => tomReflectionInfo.createInstance<SimplePerson>(Address),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.instance_creation.failed',
          ),
        ),
      );
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
    //
    // The key is asserted, not just the exception type, because the key is what
    // the documentation quotes. Checking only `isA<TomReflectorException>` left
    // the documented `reflection.set.unexpected_type` unpinned — and the prose
    // example that quoted it had drifted onto a field the class did not
    // declare, so it demonstrated the silent-ignore path instead and nothing
    // caught that.
    test('should reject a double value for an int field', () {
      final person = SimplePerson();
      expect(
        () => tomReflectionInfo.setValues(person, {'age': 2.5}),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unexpected_type',
          ),
        ),
      );
      expect(person.age, 0, reason: 'the field is left as it was');
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

  // Why unknown keys have two behaviours rather than one: on the wire,
  // tolerance is a feature — a newer client talking to an older server sends
  // keys the target no longer declares, and failing the whole payload for them
  // would make the format non-forward-compatible. Where the caller owns the
  // payload, that same tolerance hides the commonest deserialization bug there
  // is: a renamed field, or a typo, silently dropped. So the default stays
  // lenient and the strictness is opt in, chosen per converter.
  group('tomReflectionInfo.setValues - Unknown keys', () {
    test('should ignore an unknown key by default', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {'name': 'John', 'headcount': 2.5});
      expect(person.name, 'John', reason: 'the known key is still applied');
      expect(person.age, 0);
      expect(person.salary, 0.0);
    });

    test('should ignore an unknown key holding a complex value by default', () {
      final person = SimplePerson();
      tomReflectionInfo.setValues(person, {
        'nope': {'a': 1},
      });
      expect(person.name, '');
    });

    test('should reject an unknown key when the converter is strict', () {
      final strict = TomReflectionInfo(strictUnknownFields: true);
      expect(
        () => strict.setValues(SimplePerson(), {'headcount': 2.5}),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unknown_field',
          ),
        ),
      );
    });

    // A primitive value reaches the same place by a different route:
    // `_trySetPrimitiveValue` calls the setter first and swallows the failure,
    // so the check has to hold for both kinds of value.
    test('should reject an unknown key holding a primitive when strict', () {
      final strict = TomReflectionInfo(strictUnknownFields: true);
      expect(
        () => strict.setValues(SimplePerson(), {'nickname': 'Jo'}),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unknown_field',
          ),
        ),
      );
    });

    // The key alone does not locate the mistake: the same payload is applied to
    // several classes, and "unknown field 'id'" leaves the reader to guess
    // which one rejected it.
    test('should name both the key and the class it was applied to', () {
      final strict = TomReflectionInfo(strictUnknownFields: true);
      expect(
        () => strict.setValues(SimplePerson(), {'nickname': 'Jo'}),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.defaultUserMessage,
            'defaultUserMessage',
            allOf(contains('nickname'), contains('SimplePerson')),
          ),
        ),
      );
    });

    // Strictness is a property of the converter, not of the call, so a nested
    // object built during the walk inherits it — the recursion re-enters
    // through this same instance.
    test('should apply strictness to a nested object', () {
      final strict = TomReflectionInfo(strictUnknownFields: true);
      expect(
        () => strict.setValues(PersonWithAddress(), {
          'name': 'John',
          'address': {'street': 'Main', 'bogus': 1},
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unknown_field',
          ),
        ),
      );
    });

    test('should accept the same nested payload by default', () {
      final person = PersonWithAddress();
      tomReflectionInfo.setValues(person, {
        'name': 'John',
        'address': {'street': 'Main', 'bogus': 1},
      });
      expect(person.address?.street, 'Main');
    });

    // The sibling branch, which is not about unknown keys at all and is
    // unaffected by the flag: the key names a member that exists but cannot be
    // written. `hashCode` is a getter on every object and has no setter.
    test('should reject a key naming an unwritable member in both modes', () {
      for (final converter in [
        tomReflectionInfo,
        TomReflectionInfo(strictUnknownFields: true),
      ]) {
        expect(
          () => converter.setValues(SimplePerson(), {'hashCode': 7}),
          throwsA(
            isA<TomReflectorException>().having(
              (e) => e.key,
              'key',
              'reflection.set.unexpected_condition_final_static_private',
            ),
          ),
        );
      }
    });
  });

  // The same question strictness answers as it goes, asked in advance. A caller
  // binding a document it owns wants to report every offending key at once, in
  // its own vocabulary and naming the document — none of which this converter
  // can do, because it knows the class and not where the map came from.
  group('tomReflectionInfo.unknownFields', () {
    test('names every key the target declares no member for', () {
      expect(
        tomReflectionInfo.unknownFields(SimplePerson(), {
          'name': 'John',
          'nickname': 'Jo',
          'headcount': 2,
        }),
        ['nickname', 'headcount'],
      );
    });

    test('answers empty for a map that binds completely', () {
      expect(
        tomReflectionInfo.unknownFields(SimplePerson(), {
          'name': 'John',
          'age': 30,
        }),
        isEmpty,
      );
    });

    test('preserves the order the keys were written in', () {
      // The report is read next to the file it came from, so the keys should
      // arrive in the order that file lists them.
      expect(
        tomReflectionInfo.unknownFields(SimplePerson(), {
          'zeta': 1,
          'alpha': 2,
        }),
        ['zeta', 'alpha'],
      );
    });

    // The sibling fault, and deliberately not this method's: `hashCode` exists
    // on every object and cannot be written. Reporting it as *unknown* would
    // send a reader looking for a declaration that is right there, and
    // setValues raises on it in both modes anyway.
    test('does not report a member that exists but cannot be written', () {
      expect(
        tomReflectionInfo.unknownFields(SimplePerson(), {'hashCode': 7}),
        isEmpty,
      );
    });

    // A hook takes the map over entirely, so what counts as a known key is the
    // hook's to define. Answering anything else would be a verdict on a
    // question this converter was never asked.
    test('answers empty for a class whose jsonDecode hook owns the map', () {
      expect(
        tomReflectionInfo.unknownFields(JsonHookHolder(), {'anything': 1}),
        isEmpty,
      );
    });

    test('answers empty for a class with a fromJson constructor', () {
      expect(
        tomReflectionInfo.unknownFields(PersonWithFromJson(), {'anything': 1}),
        isEmpty,
      );
    });

    // The agreement that keeps the pre-flight and the walk from drifting: every
    // key this method names is one a strict setValues rejects, and every key it
    // passes over is one a strict setValues accepts.
    test('agrees with what a strict setValues does with the same map', () {
      final strict = TomReflectionInfo(strictUnknownFields: true);
      const values = {'name': 'John', 'nickname': 'Jo'};
      expect(tomReflectionInfo.unknownFields(SimplePerson(), values), [
        'nickname',
      ]);
      expect(
        () => strict.setValues(SimplePerson(), values),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.parameters?['key'],
            'key',
            'nickname',
          ),
        ),
      );
      final accepted = {'name': 'John'};
      expect(
        tomReflectionInfo.unknownFields(SimplePerson(), accepted),
        isEmpty,
      );
      expect(strict.setValues(SimplePerson(), accepted).name, 'John');
    });
  });

  // The softer twin of missingRequiredFields: the same question, asked of
  // the fields a class marks recommended, which a caller warns about rather
  // than refusing.
  group('tomReflectionInfo.missingRecommendedFields', () {
    test('names every recommended field the map supplies no key for', () {
      expect(
        tomReflectionInfo.missingRecommendedFields(RecommendedSettings(), {
          'dbUrl': 'mysql://h/db',
        }),
        ['region', 'poolSize'],
      );
    });

    test('answers empty when every recommended field is supplied', () {
      expect(
        tomReflectionInfo.missingRecommendedFields(RecommendedSettings(), {
          'region': 'eu',
          'poolSize': 4,
        }),
        isEmpty,
      );
    });

    // The two annotations are separate questions: a missing required field
    // is not a missing recommended one, and the reverse.
    test('keeps required and recommended fields apart', () {
      final settings = RecommendedSettings();
      expect(tomReflectionInfo.missingRequiredFields(settings, {}), ['dbUrl']);
      expect(tomReflectionInfo.missingRecommendedFields(settings, {}), [
        'region',
        'poolSize',
      ]);
    });

    test('a key whose value is null is not supplied', () {
      expect(
        tomReflectionInfo.missingRecommendedFields(RecommendedSettings(), {
          'region': null,
          'poolSize': 2,
        }),
        ['region'],
      );
    });
  });

  // The mirror image of unknownFields: that one names keys with no field,
  // this one names fields with no key. Binding reports neither by itself --
  // an unsupplied setting leaves the field at its initialiser, which is
  // indistinguishable from a setting that was never required.
  group('tomReflectionInfo.missingRequiredFields', () {
    test('names every required field the map supplies no key for', () {
      expect(
        tomReflectionInfo.missingRequiredFields(RequiredSettings(), {
          'label': 'billing',
        }),
        ['dbUrl', 'port'],
      );
    });

    test('answers empty when every required field is supplied', () {
      expect(
        tomReflectionInfo.missingRequiredFields(RequiredSettings(), {
          'dbUrl': 'mysql://h/db',
          'port': 3306,
        }),
        isEmpty,
      );
    });

    // An unannotated field is not a required one, however empty it is left:
    // `label` is absent from the map here and is not reported, while `port`
    // is. The rule is what the class declares, not what the map holds.
    test('says nothing about an unannotated field the map omits', () {
      expect(
        tomReflectionInfo.missingRequiredFields(RequiredSettings(), {
          'dbUrl': 'mysql://h/db',
        }),
        ['port'],
      );
    });

    // The question is whether a *source* supplied the setting, not whether the
    // value looks empty. `dbUrl=` on a command line is an explicit empty
    // value, and refusing it would conflate "set to nothing" with "not set" --
    // the very distinction the conversion table draws deliberately.
    test('an explicitly empty value is supplied', () {
      expect(
        tomReflectionInfo.missingRequiredFields(RequiredSettings(), {
          'dbUrl': '',
          'port': 0,
        }),
        isEmpty,
      );
    });

    // Null is the other side of that line. `DB_URL=` in a `.env` file parses
    // to null, which names the setting without giving it a value -- and
    // `resolveEnvironment` already drops such a key rather than carrying it.
    test('a key whose value is null is not supplied', () {
      expect(
        tomReflectionInfo.missingRequiredFields(RequiredSettings(), {
          'dbUrl': null,
          'port': 3306,
        }),
        ['dbUrl'],
      );
    });

    // A configuration class is the deep end of an application's hierarchy, so
    // a required field two levels up has to be seen from the instance.
    test('reaches a required field declared on a superclass', () {
      expect(
        tomReflectionInfo.missingRequiredFields(DerivedSettings(), {
          'port': 3306,
        }),
        ['region', 'dbUrl'],
      );
    });

    test('a subclass instance reports nothing when all are supplied', () {
      expect(
        tomReflectionInfo.missingRequiredFields(DerivedSettings(), {
          'dbUrl': 'mysql://h/db',
          'port': 3306,
          'region': 'eu',
        }),
        isEmpty,
      );
    });

    // The same guard `unknownFields` carries, for the same reason: a class
    // that decodes the map itself defines what a key means, so a field the
    // hook filled from a differently-named key is not missing.
    test('answers empty for a class whose jsonDecode hook owns the map', () {
      expect(
        tomReflectionInfo.missingRequiredFields(JsonHookHolder(), const {}),
        isEmpty,
      );
    });

    test('answers empty for a class with no required field at all', () {
      expect(
        tomReflectionInfo.missingRequiredFields(SimplePerson(), const {}),
        isEmpty,
      );
    });
  });

  // The predicate the required-field check is gated on, and the only method
  // here that answers rather than throwing when reflection is unavailable.
  group('tomReflectionInfo.canReflect', () {
    test('is true for an annotated class whose reflection is installed', () {
      expect(tomReflectionInfo.canReflect(SimplePerson()), isTrue);
    });

    // The case the configuration check exists to tolerate: a class that binds
    // its own values instead of being bound by the generator has no mirrors,
    // so there is no annotation on it to read.
    test('is false for a class carrying no @tomReflector', () {
      expect(tomReflectionInfo.canReflect(_Unreflected()), isFalse);
    });

    // The distinction that makes it a predicate rather than a convenience:
    // every other method treats the same object as a fault, because it was
    // asked to convert one and cannot.
    test('the converting methods still refuse the same object', () {
      expect(
        () => tomReflectionInfo.missingRequiredFields(_Unreflected(), const {}),
        throwsA(isA<TomReflectorException>()),
      );
    });
  });

  group('tomReflectionInfo.setValues - DateTime', () {
    test('should set DateTime from ISO string', () {
      final holder = DateTimeHolder();
      tomReflectionInfo.setValues(holder, {
        'dateTime': '2024-06-15T14:30:00.000',
      });
      expect(holder.dateTime, isNotNull);
      expect(holder.dateTime!.year, 2024);
      expect(holder.dateTime!.month, 6);
      expect(holder.dateTime!.day, 15);
      expect(holder.dateTime!.hour, 14);
      expect(holder.dateTime!.minute, 30);
    });

    test('should set DateTime from ISO string with Z suffix', () {
      final holder = DateTimeHolder();
      tomReflectionInfo.setValues(holder, {
        'dateTime': '2024-06-15T14:30:00.000Z',
      });
      expect(holder.dateTime, isNotNull);
      expect(holder.dateTime!.year, 2024);
      expect(holder.dateTime!.month, 6);
      expect(holder.dateTime!.day, 15);
    });
  });

  group('tomReflectionInfo.setValues - TomZoned types', () {
    test('should set TomZonedDate from string', () {
      final holder = ZonedDateTimeHolder();
      // Midnight on 15 June in Berlin is 22:00 on the 14th in UTC, which is
      // what the type serializes — the same encoding the round-trip test
      // below expects back out. The date it names is therefore the 15th in
      // the local frame and the 14th in the stored one.
      tomReflectionInfo.setValues(holder, {
        'zonedDate': '@D@2024-06-14T22:00:00.000Z_+02:00_Europe/Berlin',
      });
      expect(holder.zonedDate, isNotNull);
      expect(holder.zonedDate!.localYear, 2024);
      expect(holder.zonedDate!.localMonth, 6);
      expect(holder.zonedDate!.localDay, 15);
      expect(holder.zonedDate!.day, 14);
      expect(holder.zonedDate!.timezone.timezone, 'Europe/Berlin');
    });

    test('should set TomZonedTime from string', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedTime': '@T@1970-01-01T14:30:00.000Z_+09:00_Asia/Tokyo',
      });
      expect(holder.zonedTime, isNotNull);
      expect(holder.zonedTime!.hour, 14);
      expect(holder.zonedTime!.minute, 30);
      expect(holder.zonedTime!.second, 0);
      expect(holder.zonedTime!.timezone.timezone, 'Asia/Tokyo');
    });

    test('should set TomZonedDateTime from string', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedDateTime': '@X@2024-06-15T14:30:00.000Z_-04:00_America/New_York',
      });
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
      tomReflectionInfo.setValues(holder, {
        'zonedDate': '@D@2024-03-20T00:00:00.000Z_Z_Europe/London',
      });
      expect(holder.zonedDate, isNotNull);
      expect(holder.zonedDate!.year, 2024);
      expect(holder.zonedDate!.month, 3);
      expect(holder.zonedDate!.day, 20);
      expect(holder.zonedDate!.timezone.timezone, 'Europe/London');
    });

    test('should set TomZonedTime from string with different timezone', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedTime': '@T@1970-01-01T10:45:30.500Z_+10:00_Australia/Sydney',
      });
      expect(holder.zonedTime, isNotNull);
      expect(holder.zonedTime!.hour, 10);
      expect(holder.zonedTime!.minute, 45);
      expect(holder.zonedTime!.second, 30);
      expect(holder.zonedTime!.millisecond, 500);
      expect(holder.zonedTime!.timezone.timezone, 'Australia/Sydney');
    });

    test('should set TomZonedDateTime from string with different timezone', () {
      final holder = ZonedDateTimeHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedDateTime': '@X@2024-12-25T08:00:00.000Z_+13:00_Pacific/Auckland',
      });
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
        'stringMap': {'key1': 'value1', 'key2': 'value2'},
      });
      expect(holder.stringMap, {'key1': 'value1', 'key2': 'value2'});
    });

    test('should set Map<String, int>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'intMap': {'a': 1, 'b': 2, 'c': 3},
      });
      expect(holder.intMap, {'a': 1, 'b': 2, 'c': 3});
    });

    test('should set Map<String, double>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'doubleMap': {'x': 1.5, 'y': 2.5},
      });
      expect(holder.doubleMap, {'x': 1.5, 'y': 2.5});
    });

    test('should set Map<String, bool>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'boolMap': {'enabled': true, 'visible': false},
      });
      expect(holder.boolMap, {'enabled': true, 'visible': false});
    });

    test('should set Map<String, dynamic>', () {
      final holder = MapHolder();
      tomReflectionInfo.setValues(holder, {
        'dynamicMap': {'str': 'hello', 'num': 42, 'flag': true},
      });
      expect(holder.dynamicMap, {'str': 'hello', 'num': 42, 'flag': true});
    });
  });

  group('tomReflectionInfo.setValues - Lists', () {
    test('should set List<String>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'stringList': ['a', 'b', 'c'],
      });
      expect(holder.stringList, ['a', 'b', 'c']);
    });

    test('should set List<int>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'intList': [1, 2, 3, 4, 5],
      });
      expect(holder.intList, [1, 2, 3, 4, 5]);
    });

    test('should set List<double>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'doubleList': [1.1, 2.2, 3.3],
      });
      expect(holder.doubleList, [1.1, 2.2, 3.3]);
    });

    test('should set List<bool>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'boolList': [true, false, true],
      });
      expect(holder.boolList, [true, false, true]);
    });

    test('should set List<dynamic>', () {
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'dynamicList': ['text', 123, true, 4.5],
      });
      expect(holder.dynamicList, ['text', 123, true, 4.5]);
    });
  });

  // A JSON array read into a Set field: the collection a membership-only field
  // really is. The wire stays an array; the set is built from it, so a
  // duplicate collapses rather than being carried, and every element is
  // checked exactly as for a list.
  group('tomReflectionInfo.setValues - Sets', () {
    test('should set Set<String> from a JSON array', () {
      final holder = SetHolder();
      tomReflectionInfo.setValues(holder, {
        'stringSet': ['a', 'b', 'c'],
      });
      expect(holder.stringSet, {'a', 'b', 'c'});
      expect(holder.stringSet, isA<Set<String>>());
    });

    test('a duplicate on the wire collapses', () {
      final holder = SetHolder();
      tomReflectionInfo.setValues(holder, {
        'stringSet': ['admin', 'user', 'admin'],
        'intSet': [1, 2, 2, 3],
      });
      expect(holder.stringSet, {'admin', 'user'});
      expect(holder.intSet, {1, 2, 3});
    });

    test('should set a set of nullable elements', () {
      final holder = SetHolder();
      tomReflectionInfo.setValues(holder, {
        'nullableStringSet': ['a', null],
      });
      expect(holder.nullableStringSet, {'a', null});
    });

    test('a wrong-typed element is refused, naming its position', () {
      final holder = SetHolder();
      expect(
        () => tomReflectionInfo.setValues(holder, {
          'intSet': [1, 'x'],
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.collection_element_type_mismatch',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(contains('intSet'), contains('[1]'), contains("'x'")),
              ),
        ),
      );
    });

    test('a set serializes as a JSON array and round-trips', () {
      final holder = SetHolder()..stringSet = {'x', 'y'};
      final values = tomReflectionInfo.getValues(holder);
      expect(values['stringSet'], ['x', 'y']);

      final restored = SetHolder();
      tomReflectionInfo.setValues(holder, values);
      tomReflectionInfo.setValues(restored, values);
      expect(restored.stringSet, {'x', 'y'});
    });
  });

  group('tomReflectionInfo.setValues - DateTime Maps', () {
    test('should set Map<String, DateTime> from ISO strings', () {
      final holder = DateTimeMapHolder();
      tomReflectionInfo.setValues(holder, {
        'dateTimeMap': {
          'start': '2024-01-01T00:00:00.000',
          'end': '2024-12-31T23:59:59.999',
        },
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
          'tokyo': '@D@2024-07-20T00:00:00.000Z_+09:00_Asia/Tokyo',
        },
      });
      expect(holder.zonedDateMap, isNotNull);
      expect(
        holder.zonedDateMap!['berlin']!.timezone.timezone,
        'Europe/Berlin',
      );
      expect(holder.zonedDateMap!['tokyo']!.timezone.timezone, 'Asia/Tokyo');
    });

    test('should set Map<String, TomZonedTime> from strings', () {
      final holder = DateTimeMapHolder();
      tomReflectionInfo.setValues(holder, {
        'zonedTimeMap': {
          'morning': '@T@1970-01-01T08:00:00.000Z_Z_Europe/London',
          'evening': '@T@1970-01-01T20:00:00.000Z_-06:00_America/Chicago',
        },
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
          'deadline': '@X@2024-06-30T23:59:59.000Z_Z_UTC',
        },
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
          '2024-12-31T23:59:59.999',
        ],
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
          '@D@2024-12-25T00:00:00.000Z_-05:00_America/New_York',
        ],
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
          '@T@1970-01-01T18:45:00.000Z_-08:00_America/Los_Angeles',
        ],
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
          '@X@2024-12-25T08:00:00.000Z_+11:00_Australia/Sydney',
        ],
      });
      expect(holder.zonedDateTimeList, isNotNull);
      expect(holder.zonedDateTimeList!.length, 3);
      expect(holder.zonedDateTimeList![0].timezone.timezone, 'UTC');
      expect(holder.zonedDateTimeList![1].timezone.timezone, 'Europe/Paris');
      expect(
        holder.zonedDateTimeList![2].timezone.timezone,
        'Australia/Sydney',
      );
    });
  });

  group('tomReflectionInfo.setValues - Nested Objects', () {
    test('should set nested object from map', () {
      final person = PersonWithAddress();
      tomReflectionInfo.setValues(person, {
        'name': 'John Doe',
        'address': {
          'street': '123 Main St',
          'city': 'Springfield',
          'zipCode': '12345',
        },
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
        'manager': {'name': 'Bob', 'department': 'Management', 'manager': null},
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
          {'name': 'Charlie', 'role': 'Manager'},
        ],
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

    test('should get DateTime as the UTC instant it denotes', () {
      // Renegotiated deliberately. This asserted the zoneless
      // `2024-06-15T14:30:00.000` — the wall-clock reading with no zone — which
      // is the form `DateTime.parse` resolves against whichever machine reads
      // it. The written text now names the instant instead, so it means the
      // same thing on every host.
      //
      // Stated against the value rather than a frozen literal, because the
      // literal would only be right in the timezone this file was written in.
      final holder = DateTimeHolder();
      final local = DateTime(2024, 6, 15, 14, 30, 0, 0);
      holder.dateTime = local;

      final values = tomReflectionInfo.getValues(holder);
      expect(values['dateTime'], local.toUtc().toIso8601String());
      expect(
        values['dateTime'],
        endsWith('Z'),
        reason: 'the text must name its zone, or the reader invents one',
      );
    });

    test('should get TomZonedDate as serialized string', () {
      final holder = ZonedDateTimeHolder();
      final tz = TomTimezone.fromName('Europe/Berlin');
      // June 15 at 00:00 Berlin (UTC+2 in summer) = June 14 at 22:00 UTC
      holder.zonedDate = TomZonedDate(
        year: 2024,
        month: 6,
        day: 15,
        timezone: tz,
      );

      final values = tomReflectionInfo.getValues(holder);
      expect(values['zonedDate'], startsWith('@D@2024-06-14T22:00:00.000Z_'));
      expect(values['zonedDate'], endsWith('Europe/Berlin'));
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
      expect(values['zonedTime'], endsWith('Asia/Tokyo'));
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
      expect(
        values['zonedDateTime'],
        startsWith('@X@2024-06-15T18:30:00.000Z_'),
      );
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

  // ==========================================================================
  // convertToJsonString over the JSON containers — the shapes a handler
  // returns that are not themselves DTOs. `getValues` refuses these (a Map is
  // not a reflected type and a List cannot even resolve), so before this the
  // only way to put one on the wire was to encode it yourself — which is how
  // the endpoint pipeline came to carry a five-way chain of its own.
  // ==========================================================================
  group('convertToJsonString renders the JSON containers', () {
    test('a Map is encoded as itself', () {
      expect(
        tomReflectionInfo.convertToJsonString({'a': 1, 'b': 'two'}),
        '{"a":1,"b":"two"}',
      );
    });

    test('a List is encoded as itself', () {
      expect(
        tomReflectionInfo.convertToJsonString([1, 'two', true]),
        '[1,"two",true]',
      );
    });

    test('a Map value that is a DTO is rendered, not refused', () {
      // `jsonEncode(map)` alone throws JsonUnsupportedObjectError here: the
      // value is not a JSON-native type and there is no `toEncodable`. This is
      // the case the pipeline's `Map` branch silently could not serve.
      expect(
        tomReflectionInfo.convertToJsonString({
          'person': SimplePerson()
            ..name = 'Ada'
            ..age = 36,
        }),
        contains('"name":"Ada"'),
      );
    });

    test('every element of a List goes through the outbound precedence', () {
      // One element per hook shape: the interface, the structural method, the
      // getter, and a plain reflected DTO. If the container path did anything
      // other than call `getValues`, at least one of these would come out as
      // its field walk instead of its hook.
      final json = tomReflectionInfo.convertToJsonString([
        SelfSerializingDto()..status = 'iface',
        PlainToJsonHolder()..status = 'method',
        JsonHookHolder()..name = 'getter',
        SimplePerson()..name = 'plain',
      ]);

      expect(
        json,
        '[{"ok":"iface"},{"ok":"method"},{"encoded":"getter"},'
        '{"name":"plain","age":0,"active":false,"salary":0.0}]',
      );
    });

    test('containers nest to any depth', () {
      expect(
        tomReflectionInfo.convertToJsonString({
          'rows': [
            {'dto': SelfSerializingDto()..status = 'deep'},
          ],
        }),
        '{"rows":[{"dto":{"ok":"deep"}}]}',
      );
    });

    test('a value inside a container that is not ours is still refused', () {
      // The container path must not become a way around the annotation guard:
      // an element reaches exactly the same `getValues` a top-level object
      // would, and is refused on the same terms.
      expect(
        () => tomReflectionInfo.convertToJsonString([NotReflectedHolder()]),
        throwsA(isA<TomReflectorException>()),
      );
    });

    // A bare scalar stays refused — it is not a container, so it takes the
    // object path and meets the annotation guard. Pinned where that guard is
    // asserted: 'convertToJsonString no longer produces the string "{}"'.
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
        },
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
        ],
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

      // Renegotiated with its list sibling and the scalar assertion, and for
      // the same reason: `.year` / `.month` read a wall clock, which is exactly
      // what a wire carrying instants does not promise. `DateTime(2024, 1, 1)`
      // east of UTC is still 2023 in UTC — this passed in one timezone and
      // failed in the next, which is the shape of every bug this change is
      // about.
      for (final key in ['start', 'end']) {
        expect(
          newHolder.dateTimeMap![key]!.isAtSameMomentAs(
            holder.dateTimeMap![key]!,
          ),
          isTrue,
          reason: "'$key' came back as a different moment",
        );
      }
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

      expect(
        newHolder.zonedDateMap!['date1']!.timezone.timezone,
        'Europe/Berlin',
      );
      expect(newHolder.zonedDateMap!['date2']!.timezone.timezone, 'Asia/Tokyo');
    });
  });

  group('a bare DateTime crosses the wire as an instant', () {
    // The convention, and the reason it needs stating. `toIso8601String` emits
    // the `Z` for a UTC instant and *no zone marker at all* for a local one,
    // and the read side parses with `DateTime.parse`, which resolves a zoneless
    // string against the *reading* device. A local `DateTime` therefore did not
    // arrive unconverted — it arrived as a different instant, shifted by the
    // offset between the two machines, with nothing in the payload to convert
    // from. None of that is visible on one host, which is why it survived this
    // suite: every assertion below that could have caught it was written in
    // wall-clock terms, and a wall clock is what agrees with itself.
    //
    // The `TomZoned*` types are matched before `DateTime` when a value is
    // written, so a value reaching the bare branch is a `DateTime` and means an
    // instant. UTC is that instant's unambiguous name.

    test('a local DateTime is written as the instant it denotes', () {
      final holder = DateTimeHolder();
      final local = DateTime(2024, 6, 15, 14, 30);
      holder.dateTime = local;

      final written = tomReflectionInfo.getValues(holder)['dateTime'] as String;

      expect(written, local.toUtc().toIso8601String());
      expect(DateTime.parse(written).isAtSameMomentAs(local), isTrue);
    });

    test('the written text always names its zone', () {
      // The machine-independent half, and the one that makes the round trip
      // below mean anything on a host other than this one: a reader cannot
      // shift an instant it was never asked to resolve. Asserted for a local
      // and a UTC value alike, because the old form was only ambiguous for one
      // of them and a rule that holds for half the inputs is not a rule.
      final holder = DateTimeHolder();
      for (final value in [
        DateTime(2024, 6, 15, 14, 30),
        DateTime.utc(2024, 6, 15, 14, 30),
        DateTime(2024, 1, 1),
        DateTime(2024, 12, 31, 23, 59, 59),
      ]) {
        holder.dateTime = value;
        final written =
            tomReflectionInfo.getValues(holder)['dateTime'] as String;
        expect(written, endsWith('Z'), reason: 'wrote $value as $written');
        expect(
          DateTime.parse(written).isUtc,
          isTrue,
          reason: '$written would be resolved against the reading device',
        );
      }
    });

    test('a local DateTime round-trips to the same instant, not the same '
        'wall clock', () {
      // The defect stated as the property it broke. On a host east of UTC the
      // old wire wrote `2024-06-15T14:30:00.000`, which a host west of UTC read
      // back as *its* 14:30 — the same reading, a different moment. What
      // survives now is the moment.
      final source = DateTimeHolder();
      source.dateTime = DateTime(2024, 6, 15, 14, 30);

      final restored = DateTimeHolder();
      tomReflectionInfo.setValues(
        restored,
        tomReflectionInfo.getValues(source),
      );

      expect(restored.dateTime!.isAtSameMomentAs(source.dateTime!), isTrue);
      expect(
        restored.dateTime!.isUtc,
        isTrue,
        reason:
            'the instant arrives named, and a reader calls toLocal() '
            'if it wants a wall clock',
      );
    });

    test('a UTC DateTime is unchanged by the normalisation', () {
      // The conversion settles how an instant is named and never which instant
      // it is, so a value that was already named passes through untouched.
      final holder = DateTimeHolder();
      final utc = DateTime.utc(2024, 6, 15, 12, 30);
      holder.dateTime = utc;

      expect(
        tomReflectionInfo.getValues(holder)['dateTime'],
        utc.toIso8601String(),
      );
    });

    test('a nested DateTime obeys the same rule', () {
      // The conversion is one function, and lists and maps route back through
      // it — so this is not a second implementation but a check that they do.
      final holder = DateTimeListHolder();
      final local = DateTime(2024, 6, 15, 14, 30);
      holder.dateTimeList = [local];

      final written =
          (tomReflectionInfo.getValues(holder)['dateTimeList'] as List).single;

      expect(written, local.toUtc().toIso8601String());
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

      // Renegotiated with the scalar assertion above: this compared the
      // *month* of each round-tripped value, which is a wall-clock reading and
      // is not what crosses the wire. `DateTime(2024, 1, 1)` west of UTC is
      // still 2023 in UTC, so the old form asserted that the conversion had not
      // happened. The instant is the thing that survives, so the instant is
      // what this asks about.
      expect(newHolder.dateTimeList!.length, 3);
      for (var index = 0; index < 3; index++) {
        expect(
          newHolder.dateTimeList![index].isAtSameMomentAs(
            holder.dateTimeList![index],
          ),
          isTrue,
          reason: 'element $index came back as a different moment',
        );
      }
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
      final exception = TomReflectorException(
        'test.error.key',
        'Test error message',
      );
      expect(exception.toString(), contains('Test error message'));
    });
  });

  // ===========================================================================
  // Tests for Uninitialized Collections (nullable without default value)
  // ===========================================================================
  group('tomReflectionInfo.setValues - Uninitialized Lists', () {
    test(
      'should set List<TeamMember>? when field is null (no default value)',
      () {
        final holder = UninitializedListHolder();

        // Verify field starts as null
        expect(holder.members, isNull);

        // Set values using reflection
        tomReflectionInfo.setValues(holder, {
          'name': 'Test Holder',
          'members': [
            {'name': 'Alice', 'role': 'Developer'},
            {'name': 'Bob', 'role': 'Designer'},
          ],
        });

        // Verify the list was created and populated
        expect(holder.name, 'Test Holder');
        expect(holder.members, isNotNull);
        expect(holder.members!.length, 2);
        expect(holder.members![0].name, 'Alice');
        expect(holder.members![0].role, 'Developer');
        expect(holder.members![1].name, 'Bob');
        expect(holder.members![1].role, 'Designer');
      },
    );

    test('should handle empty list for uninitialized List<TeamMember>?', () {
      final holder = UninitializedListHolder();

      expect(holder.members, isNull);

      tomReflectionInfo.setValues(holder, {
        'name': 'Empty List Holder',
        'members': [],
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
        ],
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
    test(
      'should set Map<String, NestedInfo>? when field is null (no default value)',
      () {
        final holder = UninitializedMapHolder();

        // Verify field starts as null
        expect(holder.infoMap, isNull);

        // Set values using reflection
        tomReflectionInfo.setValues(holder, {
          'name': 'Test Map Holder',
          'infoMap': {
            'first': {'info': 'First Info', 'level': 1},
            'second': {'info': 'Second Info', 'level': 2},
          },
        });

        // Verify the map was created and populated
        expect(holder.name, 'Test Map Holder');
        expect(holder.infoMap, isNotNull);
        expect(holder.infoMap!.length, 2);
        expect(holder.infoMap!['first']!.info, 'First Info');
        expect(holder.infoMap!['first']!.level, 1);
        expect(holder.infoMap!['second']!.info, 'Second Info');
        expect(holder.infoMap!['second']!.level, 2);
      },
    );

    test(
      'should handle empty map for uninitialized Map<String, NestedInfo>?',
      () {
        final holder = UninitializedMapHolder();

        expect(holder.infoMap, isNull);

        tomReflectionInfo.setValues(holder, {
          'name': 'Empty Map Holder',
          'infoMap': {},
        });

        expect(holder.infoMap, isNotNull);
        expect(holder.infoMap!.length, 0);
      },
    );

    test('should set Map<String, TeamMember>? when field is null', () {
      final holder = UninitializedCollectionsHolder();

      expect(holder.teamMembers, isNull);

      tomReflectionInfo.setValues(holder, {
        'name': 'Team Map Holder',
        'teamMembers': {
          'lead': {'name': 'Charlie', 'role': 'Team Lead'},
          'dev': {'name': 'Diana', 'role': 'Developer'},
        },
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
        },
      });

      expect(holder.name, 'Full Holder');
      expect(holder.addresses, isNotNull);
      expect(holder.addresses!.length, 1);
      expect(holder.addresses![0].street, '789 Pine Rd');
      expect(holder.teamMembers, isNotNull);
      expect(holder.teamMembers!.length, 1);
      expect(holder.teamMembers!['manager']!.name, 'Eve');
    });

    // NOTE: The following tests verify ATOMIC deserialization: a null
    // value destined for a non-nullable collection element MUST surface a
    // TomReflectorException and leave the target field untouched, rather than
    // silently truncating it to whatever was materialized before the failure.
    // The collection types here are:
    // - List<TeamMember>? (elements are non-nullable TeamMember)
    // - Map<String, NestedInfo>? (values are non-nullable NestedInfo)
    // To support null elements/values, you would need List<TeamMember?>? or
    // Map<String, NestedInfo?>? which is exercised in the next group.

    test(
      'should propagate failure and leave list untouched when null element hits non-nullable List<TeamMember>?',
      () {
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
            ],
          }),
          throwsA(isA<TomReflectorException>()),
        );

        // Atomic: the field was never null-initialized nor partially filled.
        expect(holder.members, isNull);
      },
    );

    test(
      'should propagate failure and leave map untouched when null value hits non-nullable Map<String, NestedInfo>?',
      () {
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
            },
          }),
          throwsA(isA<TomReflectorException>()),
        );

        // Atomic: the field was never null-initialized nor partially filled.
        expect(holder.infoMap, isNull);
      },
    );

    test(
      'should preserve pre-populated list content when an update fails atomically',
      () {
        // A pre-populated List<TeamMember> must keep its existing content if the
        // incoming update cannot be materialized in full.
        final team = Team()
          ..teamName = 'Original'
          ..members.add(
            TeamMember()
              ..name = 'Old'
              ..role = 'Veteran',
          );

        expect(
          () => tomReflectionInfo.setValues(team, {
            'teamName': 'Updated',
            'members': [
              {'name': 'New', 'role': 'Rookie'},
              null, // Forces the whole members update to fail
              {'name': 'Third', 'role': 'Junior'},
            ],
          }),
          throwsA(isA<TomReflectorException>()),
        );

        // The original member list is intact — not cleared, not truncated.
        expect(team.members.length, 1);
        expect(team.members[0].name, 'Old');
      },
    );
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
        ],
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
        },
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
        ],
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
        },
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
        'members': [null, null, null],
      });

      expect(holder.members, isNotNull);
      expect(holder.members!.length, 3);
      expect(holder.members!.every((e) => e == null), isTrue);
    });

    test('should handle map with all null values', () {
      final holder = NullableValueMapHolder();

      tomReflectionInfo.setValues(holder, {
        'name': 'All Null Values Holder',
        'infoMap': {'a': null, 'b': null, 'c': null},
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
        ],
      });

      tomReflectionInfo.setValues(mapHolder, {
        'name': 'No Nulls Map',
        'infoMap': {
          'first': {'info': 'First', 'level': 1},
          'second': {'info': 'Second', 'level': 2},
        },
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
  // Type Resolution — generic-argument validation
  // ==========================================================================
  group('tomReflectionInfo type resolution validation', () {
    // Each case asserts the *key*, not merely the exception type. The two
    // failures below arise one line apart in the same method and are told apart
    // only by their key, so a test that accepts any TomReflectorException would
    // still pass if the two were merged or swapped.
    test(
      'mapValueElementType throws TomReflectorException on a non-generic value',
      () {
        // 42.runtimeType.toString() == 'int' has no '<...>' — must not force-unwrap.
        expect(
          () => tomReflectionInfo.mapValueElementType(42),
          throwsA(
            isA<TomReflectorException>().having(
              (e) => e.key,
              'key',
              'reflector.type_resolution.not_a_generic_type',
            ),
          ),
        );
      },
    );

    test(
      'mapValueElementType throws TomReflectorException on a single-arg generic',
      () {
        // List<int> only has one type argument — not a Map<K, V>; must not RangeError.
        expect(
          () => tomReflectionInfo.mapValueElementType(<int>[1, 2, 3]),
          throwsA(
            isA<TomReflectorException>()
                .having(
                  (e) => e.key,
                  'key',
                  'reflector.type_resolution.not_a_map_type',
                )
                .having(
                  (e) => e.defaultUserMessage,
                  'defaultUserMessage',
                  contains('use singleElementType'),
                ),
          ),
        );
      },
    );

    test('singleElementType refuses a two-argument generic', () {
      // The mirror image of the test above, and the one that matters more: a
      // Map's first type argument is its *key*, so without this check the
      // method answers with the wrong mirror and calls it success. Asking for
      // the element type of a Map is asking the wrong method, and the message
      // has to say which one is right — a plain "not found" would send the
      // reader looking for a missing annotation that is not the problem.
      expect(
        () => tomReflectionInfo.singleElementType(<String, Address>{}),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.type_resolution.not_a_single_element_type',
              )
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                allOf(
                  contains('Map<String, Address>'),
                  contains('use mapValueElementType'),
                ),
              ),
        ),
      );
    });

    test('singleElementType refuses a Map whose key type is annotated', () {
      // The case that made the missing check a wrong answer rather than a
      // confusing message: `Address` *is* annotated, so the old code resolved
      // the key type and returned a perfectly valid mirror for the wrong half
      // of the Map.
      expect(
        () => tomReflectionInfo.singleElementType(<Address, TeamMember>{}),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.type_resolution.not_a_single_element_type',
          ),
        ),
      );
    });

    test('neither resolver suggests the other for an arity it cannot use', () {
      // Three arguments fit neither method, so naming a sibling that would
      // also refuse the call would send the reader in a circle. The shape
      // error still fires; only the hint is withheld.
      for (final call in <MapEntry<String, void Function()>>[
        MapEntry(
          'reflector.type_resolution.not_a_single_element_type',
          () => tomReflectionInfo.singleElementType(Triple<int, int, int>()),
        ),
        MapEntry(
          'reflector.type_resolution.not_a_map_type',
          () => tomReflectionInfo.mapValueElementType(Triple<int, int, int>()),
        ),
      ]) {
        expect(
          call.value,
          throwsA(
            isA<TomReflectorException>()
                .having((e) => e.key, 'key', call.key)
                .having(
                  (e) => e.defaultUserMessage,
                  'defaultUserMessage',
                  allOf(contains('found 3'), isNot(contains('use '))),
                ),
          ),
        );
      }
    });

    test(
      'singleElementType throws TomReflectorException on a non-generic value',
      () {
        expect(
          () => tomReflectionInfo.singleElementType(42),
          throwsA(
            isA<TomReflectorException>().having(
              (e) => e.key,
              'key',
              'reflector.type_resolution.not_a_generic_type',
            ),
          ),
        );
      },
    );

    test('singleElementType reports an element type that is not annotated', () {
      // NotReflectedHolder carries no @tomReflector, so its simple name
      // matches nothing in the domain. The key names the *iterable* lookup,
      // which is what tells this apart from the map-value lookup below.
      expect(
        () => tomReflectionInfo.singleElementType(<NotReflectedHolder>[]),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.classmirror.not_found_for_iterable_value',
          ),
        ),
      );
    });

    test('mapValueElementType reports a value type that is not annotated', () {
      expect(
        () => tomReflectionInfo.mapValueElementType(
          <String, NotReflectedHolder>{},
        ),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.classmirror.not_found_for_map_value',
          ),
        ),
      );
    });

    test('a simple name shared by two annotated classes is refused', () {
      // ClashingItem is declared in both support/reflection_clash_first.dart
      // and support/reflection_clash_second.dart. These lookups resolve a type
      // *by simple name*, so there is no principled way to choose — and
      // choosing the first registered would return a mirror for a class the
      // caller never named, materializing the wrong type without a word.
      //
      // Both directions are asserted: the refusal is a property of the name,
      // not of which of the two libraries the caller happened to reach from.
      final ambiguous = isA<TomReflectorException>()
          .having(
            (e) => e.key,
            'key',
            'reflector.classmirror.ambiguous_simple_name',
          )
          // Naming the collision is the whole value of the message, and the
          // name alone does not name it: both candidates are called
          // ClashingItem. Only the owning libraries tell them apart, so both
          // must appear — a message built from qualifiedName would read
          // ".ClashingItem, .ClashingItem" and leave the reader exactly where
          // they started.
          .having(
            (e) => e.defaultUserMessage,
            'defaultUserMessage',
            allOf(
              contains("'ClashingItem' is ambiguous"),
              contains('support/reflection_clash_first.dart'),
              contains('support/reflection_clash_second.dart'),
              // And the way out: the refusal is a limit of resolving from a
              // bare collection, so it points at resolving from a
              // declaration, which has no such limit.
              contains('tomReflector.reflectType(ClashingItem)'),
            ),
          )
          .having((e) => e.parameters?['typeName'], 'typeName', 'ClashingItem');

      expect(
        () => tomReflectionInfo.singleElementType(<first_clash.ClashingItem>[]),
        throwsA(ambiguous),
      );
      expect(
        () => tomReflectionInfo.mapValueElementType(
          <String, second_clash.ClashingItem>{},
        ),
        throwsA(ambiguous),
      );
    });

    test('a shared simple name does not reach the field walk', () {
      // The refusal above belongs to the two helpers that are handed a bare
      // collection, where the element type exists only as text. Deserializing
      // a *field* never asks that question: the element type is the field's
      // declared type argument, read from its own mirror. So two classes
      // sharing a simple name — the collision that appears the first time an
      // unrelated package with its own `Item` is added — both deserialize,
      // each as itself, in lists and in maps.
      final holder = tomReflectionInfo.setValues(ClashingItemsHolder(), {
        'firsts': [
          {'label': 'a'},
        ],
        'seconds': [
          {'label': 'b'},
        ],
        'firstsByName': {
          'x': {'label': 'c'},
        },
        'secondsByName': {
          'y': {'label': 'd'},
        },
      });

      expect(holder.firsts.single, isA<first_clash.ClashingItem>());
      expect(holder.firsts.single.label, 'a');
      expect(holder.seconds.single, isA<second_clash.ClashingItem>());
      expect(holder.seconds.single.label, 'b');
      expect(holder.firstsByName['x'], isA<first_clash.ClashingItem>());
      expect(holder.firstsByName['x']!.label, 'c');
      expect(holder.secondsByName['y'], isA<second_clash.ClashingItem>());
      expect(holder.secondsByName['y']!.label, 'd');
    });

    test('collections of both same-named classes round-trip', () {
      final original = ClashingItemsHolder()
        ..firsts.add(first_clash.ClashingItem()..label = 'one')
        ..seconds.add(second_clash.ClashingItem()..label = 'two')
        ..firstsByName['k'] = (first_clash.ClashingItem()..label = 'three')
        ..secondsByName['k'] = (second_clash.ClashingItem()..label = 'four');

      final restored = tomReflectionInfo
          .createInstanceFromJsonString<ClashingItemsHolder>(
            tomReflector.reflectType(ClashingItemsHolder) as ClassMirror,
            tomReflectionInfo.convertToJsonString(original),
          );

      expect(restored.firsts.single, isA<first_clash.ClashingItem>());
      expect(restored.firsts.single.label, 'one');
      expect(restored.seconds.single, isA<second_clash.ClashingItem>());
      expect(restored.seconds.single.label, 'two');
      expect(restored.firstsByName['k'], isA<first_clash.ClashingItem>());
      expect(restored.firstsByName['k']!.label, 'three');
      expect(restored.secondsByName['k'], isA<second_clash.ClashingItem>());
      expect(restored.secondsByName['k']!.label, 'four');
    });
  });

  // ==========================================================================
  // Type Resolution — nested generic type arguments
  // ==========================================================================
  group('tomReflectionInfo type resolution rejects nested generics', () {
    // These assert on the *message text*, not just on the exception type. The
    // failure mode being guarded is a message that names a type which does not
    // exist: truncating `List<List<String>>` at the first `>` yields the
    // element name `List<String`, and "ClassMirror for type List<String could
    // not be found" reads like a typo in the framework rather than a limit of
    // it. A test that only checks `throwsA(isA<TomReflectorException>())`
    // passes either way.

    test('singleElementType names the real type of a nested list', () {
      expect(
        () => tomReflectionInfo.singleElementType(<List<String>>[]),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.type_resolution.nested_generic_unsupported',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('List<List<String>>'),
                  contains('List<String>'),
                  contains('nested'),
                ),
              ),
        ),
      );
    });

    test('mapValueElementType names the real type of a nested value', () {
      expect(
        () => tomReflectionInfo.mapValueElementType(<String, List<Address>>{}),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.type_resolution.nested_generic_unsupported',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('Map<String, List<Address>>'),
                  contains('List<Address>'),
                  contains('nested'),
                ),
              ),
        ),
      );
    });

    test('mapValueElementType splits arguments at the top level only', () {
      // A comma inside the value's own type arguments is not an argument
      // separator: splitting `String, Map<String, int` on ',' yields three
      // parts and picks `Map<String` as the value type. The message must name
      // `Map<String, int>` whole.
      expect(
        () =>
            tomReflectionInfo.mapValueElementType(<String, Map<String, int>>{}),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.type_resolution.nested_generic_unsupported',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('Map<String, int>'),
                  isNot(contains("'Map<String'")),
                ),
              ),
        ),
      );
    });

    test('arity is judged on top-level arguments', () {
      // `List<List<int>>` carries one type argument, not two — the inner comma
      // must not make it look like a Map<K, V>.
      expect(
        () => tomReflectionInfo.mapValueElementType(<List<int>>[]),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.type_resolution.not_a_map_type',
          ),
        ),
      );
    });

    test('setValues diagnoses a nested list field by its declared type', () {
      // The wrapped cast error this replaces read "type 'List<String>' is not
      // a subtype of type 'Map<String, dynamic>?'" and named the field type
      // `List<List>` — the mirror's simple name has already dropped the inner
      // argument. Neither half told the reader that nesting is the problem.
      final holder = NestedCollectionHolder()
        ..nestedLists = [
          ['kept'],
        ];
      expect(
        () => tomReflectionInfo.setValues(holder, {
          'nestedLists': [
            ['a'],
          ],
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.type_resolution.nested_generic_unsupported',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('nestedLists'),
                  contains('List<List<String>>'),
                  contains('nested'),
                ),
              ),
        ),
      );
      expect(holder.nestedLists, [
        ['kept'],
      ]);
    });

    test('setValues diagnoses a nested map field by its declared type', () {
      final holder = NestedCollectionHolder();
      expect(
        () => tomReflectionInfo.setValues(holder, {
          'nestedMaps': {
            'x': [
              {'street': 's', 'city': 'c', 'zipCode': 'z'},
            ],
          },
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflector.type_resolution.nested_generic_unsupported',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('nestedMaps'),
                  contains('Map<String, List<Address>>'),
                  contains('nested'),
                ),
              ),
        ),
      );
      expect(holder.nestedMaps, isNull);
    });

    test('a single-level annotated element type still resolves', () {
      expect(
        tomReflectionInfo.singleElementType(<Address>[]).simpleName,
        'Address',
      );
      expect(
        tomReflectionInfo.mapValueElementType(<String, Address>{}).simpleName,
        'Address',
      );
    });
  });

  // ==========================================================================
  // Round-trip serialization
  // ==========================================================================
  group('tomReflectionInfo round-trip serialization', () {
    test(
      'createInstanceFromJsonString reconstructs a Team with nested members',
      () {
        final team = Team()
          ..teamName = 'Alpha'
          ..members.add(
            TeamMember()
              ..name = 'Alice'
              ..role = 'Lead',
          )
          ..members.add(
            TeamMember()
              ..name = 'Bob'
              ..role = 'Dev',
          );

        final json = tomReflectionInfo.convertToJsonString(team);
        final mirror = tomReflector.reflectType(Team) as ClassMirror;
        final restored = tomReflectionInfo.createInstanceFromJsonString<Team>(
          mirror,
          json,
        );

        expect(restored.teamName, 'Alpha');
        expect(restored.members.length, 2);
        expect(restored.members[0].name, 'Alice');
        expect(restored.members[0].role, 'Lead');
        expect(restored.members[1].name, 'Bob');
        expect(restored.members[1].role, 'Dev');
      },
    );

    test('createInstanceFromJson round-trips a PersonWithAddress', () {
      final person = PersonWithAddress()
        ..name = 'Carol'
        ..address = (Address()
          ..street = '1 Main St'
          ..city = 'Springfield'
          ..zipCode = '12345');

      final json = tomReflectionInfo.getValues(person);
      final mirror = tomReflector.reflectType(PersonWithAddress) as ClassMirror;
      final restored = tomReflectionInfo
          .createInstanceFromJson<PersonWithAddress>(mirror, json);

      expect(restored.name, 'Carol');
      expect(restored.address, isNotNull);
      expect(restored.address!.street, '1 Main St');
      expect(restored.address!.city, 'Springfield');
      expect(restored.address!.zipCode, '12345');
    });
  });

  // ==========================================================================
  // Dynamic collections erase the type of anything that is not JSON-native
  // ==========================================================================
  group('a dynamic collection round-trips values, not their types', () {
    // The encode side knows what it holds; the decode side does not. A
    // `Map<String, dynamic>` field has no element type to dispatch on, so
    // whatever the encoder turned a value into is what the decoder puts back.
    //
    // These tests pin that outcome rather than correct it: the asymmetry is
    // inherent to `dynamic`, and the alternatives — refusing to serialize such
    // values, or tagging them with a type marker — either break working models
    // or invent a wire format inside a field other systems already read. What
    // matters is that the boundary is *known*, so it is asserted here and
    // stated in the "Supported Types" documentation.
    //
    // Nothing is lost that the caller cannot recover: the text is the same
    // encoding the typed fields use, so a caller who knows the intended type
    // can parse it back. The type is erased; the data is not.

    test('a DateTime in a dynamic map comes back as its ISO text', () {
      final holder = MapHolder();
      holder.dynamicMap = {'when': DateTime.utc(2026, 1, 2), 'count': 5};

      final json = tomReflectionInfo.convertToJsonString(holder);
      final restored = MapHolder();
      tomReflectionInfo.convertFromJsonString(restored, json);

      expect(restored.dynamicMap!['when'], isA<String>());
      expect(restored.dynamicMap!['when'], '2026-01-02T00:00:00.000Z');
      // The JSON-native neighbour in the same map is unaffected.
      expect(restored.dynamicMap!['count'], 5);

      // Recoverable by the caller, because it is the standard encoding.
      expect(
        DateTime.parse(restored.dynamicMap!['when'] as String),
        DateTime.utc(2026, 1, 2),
      );
    });

    test(
      'the same DateTime in a typed map field is restored as a DateTime',
      () {
        // The contrast that makes the erasure a property of `dynamic` rather
        // than of DateTime handling: identical value, declared element type.
        final holder = DateTimeMapHolder();
        holder.dateTimeMap = {'when': DateTime.utc(2026, 1, 2)};

        final json = tomReflectionInfo.convertToJsonString(holder);
        final restored = DateTimeMapHolder();
        tomReflectionInfo.convertFromJsonString(restored, json);

        expect(restored.dateTimeMap!['when'], isA<DateTime>());
        expect(restored.dateTimeMap!['when'], DateTime.utc(2026, 1, 2));
      },
    );

    test('a DateTime in a dynamic list comes back as its ISO text', () {
      final holder = ListHolder();
      holder.dynamicList = [DateTime.utc(2026, 1, 2), 7];

      final json = tomReflectionInfo.convertToJsonString(holder);
      final restored = ListHolder();
      tomReflectionInfo.convertFromJsonString(restored, json);

      expect(restored.dynamicList![0], isA<String>());
      expect(restored.dynamicList![0], '2026-01-02T00:00:00.000Z');
      expect(restored.dynamicList![1], 7);
    });

    test(
      'a TomZonedDateTime in a dynamic map comes back as its marker text',
      () {
        // Worth pinning separately from DateTime: the zoned types serialize to
        // an `@X@`-prefixed marker, not to ISO-8601. That is this module's wire
        // format for them everywhere — a typed `List<TomZonedDateTime>` uses the
        // same text and restores from it — but in a dynamic map it is what the
        // caller is left holding, and it does not read like a date.
        final holder = MapHolder();
        holder.dynamicMap = {
          'z': TomZonedDateTime(
            year: 2024,
            month: 6,
            day: 15,
            hour: 14,
            minute: 30,
            second: 0,
            millisecond: 0,
            timezone: TomTimezone.fromName('America/New_York'),
          ),
        };

        final json = tomReflectionInfo.convertToJsonString(holder);
        final restored = MapHolder();
        tomReflectionInfo.convertFromJsonString(restored, json);

        final text = restored.dynamicMap!['z'];
        expect(text, isA<String>());
        expect(text, startsWith('@X@'));
        expect(text, contains('America/New_York'));

        // Also recoverable, by the parser the typed path would have used.
        final parsed = TomZonedDateTime.parseFromString(text as String);
        expect(parsed.timezone.timezone, 'America/New_York');
      },
    );

    test('an annotated object in a dynamic map comes back as a plain Map', () {
      // Not only the date/time types: `getValues` recurses into an annotated
      // value and emits its field map, and a field map is what returns. The
      // class is gone, so `as Address` at the call site throws.
      final holder = MapHolder();
      holder.dynamicMap = {
        'addr': Address()
          ..street = 'Main'
          ..city = 'Berlin',
      };

      final json = tomReflectionInfo.convertToJsonString(holder);
      final restored = MapHolder();
      tomReflectionInfo.convertFromJsonString(restored, json);

      expect(restored.dynamicMap!['addr'], isNot(isA<Address>()));
      expect(restored.dynamicMap!['addr'], isA<Map<String, dynamic>>());
      expect(restored.dynamicMap!['addr'], containsPair('city', 'Berlin'));
    });

    test('the erasure reaches values nested inside a dynamic map', () {
      // The dynamic-ness is inherited: a map inside a dynamic map has no
      // declared element type either, so depth does not restore the type.
      final holder = MapHolder();
      holder.dynamicMap = {
        'inner': {'when': DateTime.utc(2026, 3, 4)},
      };

      final json = tomReflectionInfo.convertToJsonString(holder);
      final restored = MapHolder();
      tomReflectionInfo.convertFromJsonString(restored, json);

      expect(
        (restored.dynamicMap!['inner'] as Map)['when'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('a jsonDecode hook is where a model can restore what it knows', () {
      // The documented way out, executed rather than merely described: the
      // field type cannot carry the knowledge, but the class can.
      final holder = DynamicMapWithHookHolder()
        ..label = 'session'
        ..attributes = {'when': DateTime.utc(2026, 1, 2), 'count': 5};

      final json = tomReflectionInfo.convertToJsonString(holder);
      final restored = DynamicMapWithHookHolder();
      tomReflectionInfo.convertFromJsonString(restored, json);

      expect(restored.attributes!['when'], isA<DateTime>());
      expect(restored.attributes!['when'], DateTime.utc(2026, 1, 2));
      expect(restored.attributes!['count'], 5);
      // The hook owns the whole decode, so the untouched field is its job too.
      expect(restored.label, 'session');
    });
  });

  // ==========================================================================
  // convertFromJsonString — the in-place inverse of convertToJsonString
  // ==========================================================================
  group('convertFromJsonString fills the object it is given', () {
    // The three other string/JSON entry points *construct*; this one is the
    // only one that writes into an object the caller already holds, and its
    // whole observable contract is that it returns that same object rather
    // than a copy. It was reachable only through its two failure tests, so
    // nothing pinned what it does when it succeeds.

    test('it parses the string and writes the fields in place', () {
      final person = SimplePerson();

      final returned = tomReflectionInfo.convertFromJsonString(
        person,
        '{"name": "Grace", "age": 45, "active": true, "salary": 120.5}',
      );

      expect(person.name, 'Grace');
      expect(person.age, 45);
      expect(person.active, true);
      expect(person.salary, 120.5);
      // In place, not a copy: a caller that ignores the return value must
      // still see the new values on the object it passed in.
      expect(identical(returned, person), isTrue);
    });

    test('it is the inverse of convertToJsonString', () {
      final person = SimplePerson()
        ..name = 'Grace'
        ..age = 45
        ..active = true
        ..salary = 120.5;

      final restored = tomReflectionInfo.convertFromJsonString(
        SimplePerson(),
        tomReflectionInfo.convertToJsonString(person),
      );

      expect(
        tomReflectionInfo.getValues(restored),
        tomReflectionInfo.getValues(person),
      );
    });

    test('it fills a nested annotated object from the same string', () {
      // The parse is one level; the walk below it is `setValues`, so the
      // nesting is what shows the string form is not a shallow shortcut.
      final person = PersonWithAddress();

      tomReflectionInfo.convertFromJsonString(
        person,
        '{"name": "Carol", "address": {"street": "1 Main St", '
        '"city": "Springfield", "zipCode": "12345"}}',
      );

      expect(person.name, 'Carol');
      expect(person.address, isNotNull);
      expect(person.address!.city, 'Springfield');
    });

    test('malformed JSON fails as a FormatException, before any reflection', () {
      // `jsonDecode` runs first, so a bad payload never reaches the reflective
      // path and is not dressed up as a TomReflectorException. Asserting the
      // object is untouched is the part that matters: a partial write would be
      // far worse than the throw.
      final person = SimplePerson()..name = 'unchanged';

      expect(
        () => tomReflectionInfo.convertFromJsonString(person, '{not json'),
        throwsA(isA<FormatException>()),
      );
      expect(person.name, 'unchanged');
    });
  });

  group('the JSON factories return an instance or throw, never null', () {
    // Both factories were typed `T?` and documented as "returns the new
    // instance, or null if creation fails". Neither had a `return null`
    // anywhere, and neither could acquire one: every exit either returns an
    // object or throws. The nullable type was therefore a promise of a case
    // that does not exist, and it propagated — every call site had to write
    // `!`, `?? throw`, or an `if (x == null)` branch that could never be
    // entered and so hid nothing.
    //
    // The static half of this contract is enforced by these tests *compiling*:
    // each one binds the result to a non-nullable local without `!`. Under the
    // old `T?` signature that is an error, not a failure — which is the right
    // kind of red for a change that is about the type.

    setUp(initializeReflection);

    test('createInstanceFromJson is statically non-nullable', () {
      final Address restored = tomReflectionInfo
          .createInstanceFromJson<Address>(
            tomReflector.reflectType(Address) as ClassMirror,
            {'street': '1 Main St', 'city': 'Springfield', 'zipCode': '12345'},
          );

      expect(restored.street, '1 Main St');
    });

    test('createInstanceFromJsonString is statically non-nullable', () {
      final Address restored = tomReflectionInfo
          .createInstanceFromJsonString<Address>(
            tomReflector.reflectType(Address) as ClassMirror,
            '{"street": "1 Main St", "city": "Springfield", "zipCode": "1"}',
          );

      expect(restored.city, 'Springfield');
    });

    test('a payload the target rejects throws rather than returning null', () {
      expect(
        () => tomReflectionInfo.createInstanceFromJson<Address>(
          tomReflector.reflectType(Address) as ClassMirror,
          {'street': 42},
        ),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unexpected_type',
          ),
        ),
      );
    });

    test('the string overload reports the same rejection', () {
      expect(
        () => tomReflectionInfo.createInstanceFromJsonString<Address>(
          tomReflector.reflectType(Address) as ClassMirror,
          '{"street": 42}',
        ),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unexpected_type',
          ),
        ),
      );
    });

    test('a target that cannot be constructed throws, wrapped', () {
      // The `T?` return was the only thing that made "creation failed" look
      // like a value a caller could test for; it is an exception, and it was
      // always an exception. It has to be *our* exception, though: the
      // default-constructor fallback was unguarded, so a mirror the reflector
      // cannot instantiate — a quantified built-in such as `String`, which has
      // mirror data but no invocable constructor — escaped as
      // `tom_reflection`'s own NoSuchCapabilityError, which is not the type
      // this module documents or that `on TomReflectorException` catches.
      expect(
        () => tomReflectionInfo.createInstanceFromJson<SimplePerson>(
          tomReflector.reflectType(String) as ClassMirror,
          {'anything': 1},
        ),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.instance_creation.failed',
          ),
        ),
      );
    });

    test('malformed JSON escapes the string overload as a FormatException', () {
      // `jsonDecode` runs before any reflection does, so this is not a
      // reflection failure and is deliberately not wrapped as one. It is
      // recorded here because it is the one failure of these two methods that
      // is *not* a TomReflectorException.
      expect(
        () => tomReflectionInfo.createInstanceFromJsonString<Address>(
          tomReflector.reflectType(Address) as ClassMirror,
          'not json',
        ),
        throwsFormatException,
      );
    });
  });

  group('a hook that throws is not a hook that is absent', () {
    // Three optional hooks let a class take over its own conversion:
    // `fromJson` (a constructor, used by createInstanceFromJson), `jsonDecode`
    // (a method, used by setValues) and `jsonEncode` (a getter, used by
    // getValues). Each was looked up by *trying* it inside an unqualified
    // catch, so "there is no such member" and "the member ran and raised"
    // were the same answer: fall back. A bug inside a caller's own hook was
    // swallowed, the object was rebuilt by the fallback path, and the error
    // the caller eventually saw — if any — never mentioned their code.
    //
    // Absent still falls back silently. Throwing now propagates, wrapped,
    // naming the hook and the class.

    Matcher hookFailed(String hook, String owner, String because) => throwsA(
      isA<TomReflectorException>()
          .having((e) => e.key, 'key', 'reflection.hook.failed')
          .having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(contains(hook), contains(owner), contains(because)),
          ),
    );

    ClassMirror mirrorOf(Type t) => tomReflector.reflectType(t) as ClassMirror;

    group('fromJson', () {
      test('absent: falls back to the default constructor', () {
        final restored = tomReflectionInfo.createInstanceFromJson<SimplePerson>(
          mirrorOf(SimplePerson),
          {'name': 'Ann', 'age': 30},
        );

        expect(restored.name, 'Ann');
        expect(restored.age, 30);
      });

      test('present and working: the hook builds the instance', () {
        final restored = tomReflectionInfo
            .createInstanceFromJson<PersonWithFromJson>(
              mirrorOf(PersonWithFromJson),
              {'name': 'Ann', 'age': 30},
            );

        expect(restored.name, 'Ann');
        expect(restored.age, 30);
      });

      test('present and throwing: propagates, naming hook and class', () {
        expect(
          () =>
              tomReflectionInfo.createInstanceFromJson<ThrowingFromJsonHolder>(
                mirrorOf(ThrowingFromJsonHolder),
                {'name': 'Ann'},
              ),
          hookFailed('fromJson', 'ThrowingFromJsonHolder', 'is broken'),
        );
      });

      test('a bug inside the caller\'s own fromJson is not swallowed', () {
        // The todo's scenario verbatim: the hook is fine, the payload is not,
        // and the cast inside `PersonWithFromJson.fromJson` raises. This used
        // to fall through to the default constructor plus `setValues`, which
        // rebuilt the object from the same bad payload and reported a type
        // mismatch on the *field* — pointing at the reflection layer rather
        // than at the constructor that actually failed.
        expect(
          () => tomReflectionInfo.createInstanceFromJson<PersonWithFromJson>(
            mirrorOf(PersonWithFromJson),
            {'name': 7, 'age': 30},
          ),
          hookFailed('fromJson', 'PersonWithFromJson', 'String'),
        );
      });

      test('the original error is kept as rootException', () {
        try {
          tomReflectionInfo.createInstanceFromJson<ThrowingFromJsonHolder>(
            mirrorOf(ThrowingFromJsonHolder),
            {'name': 'Ann'},
          );
          fail('expected a TomReflectorException');
        } on TomReflectorException catch (e) {
          expect(e.rootException, isA<StateError>());
        }
      });
    });

    group('jsonDecode', () {
      test('absent: setValues walks the fields', () {
        final person = tomReflectionInfo.setValues(SimplePerson(), {
          'name': 'Ann',
          'age': 30,
        });

        expect(person.name, 'Ann');
        expect(person.age, 30);
      });

      test('present and working: the hook takes over deserialization', () {
        final holder = tomReflectionInfo.setValues(JsonHookHolder(), {
          'name': 'Ann',
          'age': 30,
        });

        // Values a field walk could not have produced.
        expect(holder.name, 'decoded:Ann');
        expect(holder.age, 99);
      });

      test('present and throwing: propagates, naming hook and class', () {
        expect(
          () => tomReflectionInfo.setValues(ThrowingJsonHookHolder(), {
            'name': 'Ann',
          }),
          hookFailed('jsonDecode', 'ThrowingJsonHookHolder', 'is broken'),
        );
      });

      test('a throwing hook does not silently degrade to a field walk', () {
        // The quiet consequence a silent fallback would have: `setValues`
        // returns the object having written the fields itself, so the caller
        // gets a plausible-looking result that ignored the custom
        // representation entirely. Raising is what makes that visible.
        final holder = ThrowingJsonHookHolder();

        expect(
          () => tomReflectionInfo.setValues(holder, {'name': 'Ann'}),
          throwsA(isA<TomReflectorException>()),
        );
        expect(holder.name, '', reason: 'the fallback walk must not have run');
      });
    });

    group('jsonEncode', () {
      test('absent: getValues walks the fields', () {
        final person = SimplePerson()
          ..name = 'Ann'
          ..age = 30;

        expect(
          tomReflectionInfo.getValues(person),
          allOf(
            containsPair('name', 'Ann'),
            containsPair('age', 30),
            isNot(contains('encoded')),
          ),
        );
      });

      test('present and working: the hook supplies the representation', () {
        final holder = JsonHookHolder()..name = 'Ann';

        expect(tomReflectionInfo.getValues(holder), {'encoded': 'Ann'});
      });

      test('present and throwing: propagates, naming hook and class', () {
        expect(
          () => tomReflectionInfo.getValues(ThrowingJsonHookHolder()),
          hookFailed('jsonEncode', 'ThrowingJsonHookHolder', 'is broken'),
        );
      });

      test('present and returning a non-object: reported, not ignored', () {
        // Narrowing the catch turns this from "silently walk the fields
        // instead" into a `TypeError` unless it is handled on purpose. The
        // hook exists and answered; the answer is unusable, and saying so is
        // the only honest outcome.
        expect(
          () => tomReflectionInfo.getValues(BadJsonEncodeHolder()),
          throwsA(
            isA<TomReflectorException>()
                .having((e) => e.key, 'key', 'reflection.hook.invalid_return')
                .having(
                  (e) => e.defaultUserMessage,
                  'message',
                  allOf(
                    contains('jsonEncode'),
                    contains('BadJsonEncodeHolder'),
                    contains('String'),
                  ),
                ),
          ),
        );
      });

      test('convertToJsonString carries the hook failure through', () {
        expect(
          () => tomReflectionInfo.convertToJsonString(ThrowingJsonHookHolder()),
          hookFailed('jsonEncode', 'ThrowingJsonHookHolder', 'is broken'),
        );
      });
    });
  });

  group('a TomClass converts itself, and the reflective path steps aside', () {
    // `getValues` and `setValues` both open with `o is TomClass` and hand the
    // whole conversion to the object — outbound to `TomClass.toJson()`, inbound
    // to `TomClass.setValues()`. Neither branch had a test. They are the widest
    // of the hooks: every observable model in the framework takes them, and a
    // regression would not be a wrong value but an object converted by the
    // wrong mechanism entirely, which for a TomClass means its members are
    // ignored and its `TomObject` wrappers are walked as if they were data.

    test('outbound: getValues delegates to the observable members', () {
      final point = ObservablePoint();
      point.label | 'origin';
      point.x | 7;

      // The member map, not a field walk: a walk would find the `TomString`
      // and `TomInt` *wrappers* rather than the values inside them.
      expect(tomReflectionInfo.getValues(point), {'label': 'origin', 'x': 7});
    });

    test('outbound: it agrees with the object converting itself', () {
      final point = ObservablePoint();
      point.label | 'origin';

      expect(tomReflectionInfo.getValues(point), point.toJson());
    });

    test('inbound: setValues writes through the observable members', () {
      final point = ObservablePoint();

      final returned = tomReflectionInfo.setValues(point, {
        'label': 'origin',
        'x': 7,
      });

      expect(identical(returned, point), isTrue);
      expect(point.label.get(), 'origin');
      expect(point.x.get(), 7);
    });

    test('inbound: the write is observable, as the delegation exists to make '
        'it', () {
      // The reason the branch exists at all. A field walk would assign over
      // the `TomObject` members and no observer would ever hear about it.
      final point = ObservablePoint();
      final seen = <String>[];
      // Retained deliberately: observers are held weakly, so an unassigned
      // handle can be collected and the callback stop firing.
      final handle = point.label >> (observable) => seen.add(observable.get());

      tomReflectionInfo.setValues(point, {'label': 'origin'});

      expect(seen, ['origin']);
      point.label.removeObserver(handle);
    });

    test('absent: a class that is not a TomClass is walked as usual', () {
      // The other half of the pair — the delegation is a branch, and a branch
      // that always fires is indistinguishable from no branch.
      final person = SimplePerson()..name = 'Ann';

      expect(tomReflectionInfo.getValues(person), containsPair('name', 'Ann'));
    });

    test('createInstanceFromJson reaches the delegation through setValues', () {
      // A TomClass declares `fromJson(String)` as an ordinary method, not as a
      // named constructor, so the constructor lookup misses it and the default
      // path runs — which then hits the TomClass branch of `setValues`. The
      // two hooks compose rather than competing.
      final mirror = tomReflector.reflectType(ObservablePoint) as ClassMirror;

      final built = tomReflectionInfo.createInstanceFromJson<ObservablePoint>(
        mirror,
        {'label': 'origin', 'x': 7},
      );

      expect(built.label.get(), 'origin');
      expect(built.x.get(), 7);
    });
  });

  group('when two hooks disagree, the precedence is pinned', () {
    // Each class here carries two hooks that would produce different results,
    // so the assertion is not "a hook ran" but "*this* hook ran". Without
    // these the order is an accident of how the `if`s happen to be stacked,
    // and a reordering would be invisible to the suite.
    //
    // The order under test is the one documented on `getValues` and
    // `setValues`: outbound, TomClass then TomJsonSerializable then a `toJson`
    // method then a `jsonEncode` getter then the fields; inbound, TomClass
    // then a `fromJson` constructor then a `jsonDecode` method then the
    // fields.

    ClassMirror mirrorOf(Type t) => tomReflector.reflectType(t) as ClassMirror;

    test('outbound: TomClass beats the jsonEncode getter', () {
      final holder = ObservableWithJsonHooks();
      holder.label | 'origin';

      expect(
        tomReflectionInfo.getValues(holder),
        {'label': 'origin'},
        reason: 'the `o is TomClass` test is ahead of the hook lookup',
      );
    });

    test('inbound: TomClass beats the jsonDecode method', () {
      final holder = ObservableWithJsonHooks();

      tomReflectionInfo.setValues(holder, {'label': 'origin'});

      expect(holder.label.get(), 'origin');
      expect(
        holder.label.get(),
        isNot('decoded by the hook'),
        reason: 'the jsonDecode hook must not have run',
      );
    });

    test('outbound: a plain toJson method beats the jsonEncode getter', () {
      expect(tomReflectionInfo.getValues(EncodeAndToJsonHolder()), {
        'from': 'toJson',
      });
    });

    test('outbound: the declared interface beats the jsonEncode getter', () {
      expect(tomReflectionInfo.getValues(InterfaceAndEncodeHolder()), {
        'from': 'toJson',
      });
    });

    test('outbound: declaring the interface does not change the answer', () {
      // The point of ranking all three `toJson` forms above `jsonEncode`.
      // These two fixtures differ only by `implements TomJsonSerializable`; if
      // the interface sat above `jsonEncode` and the bare method below it,
      // adding that clause to a class carrying both hooks would silently
      // change what it puts on the wire.
      expect(
        tomReflectionInfo.getValues(InterfaceAndEncodeHolder()),
        tomReflectionInfo.getValues(EncodeAndToJsonHolder()),
      );
    });

    test('inbound: the fromJson constructor beats the jsonDecode method', () {
      final built = tomReflectionInfo
          .createInstanceFromJson<FromJsonAndDecodeHolder>(
            mirrorOf(FromJsonAndDecodeHolder),
            {'source': 'payload'},
          );

      expect(built.source, 'fromJson');
    });

    test('inbound: reaching setValues directly runs fromJson too', () {
      // Same class, same payload, different entry point — and now the same
      // hook. The answer no longer depends on which method the caller happened
      // to reach for, which is the whole reason the two entry points share
      // one order.
      final holder = tomReflectionInfo.setValues(FromJsonAndDecodeHolder(), {
        'source': 'payload',
      });

      expect(holder.source, 'fromJson');
    });

    test('inbound: setValues and createInstanceFromJson agree', () {
      // Stated directly rather than left to be inferred from the two tests
      // above: whichever door the caller uses, the same hook runs and the same
      // value comes out.
      final viaSetValues = tomReflectionInfo.setValues(
        FromJsonAndDecodeHolder(),
        {'source': 'payload'},
      );
      final viaCreate = tomReflectionInfo
          .createInstanceFromJson<FromJsonAndDecodeHolder>(
            mirrorOf(FromJsonAndDecodeHolder),
            {'source': 'payload'},
          );

      expect(viaSetValues.source, viaCreate.source);
    });

    test(
      'inbound: setValues returns the fromJson instance, not its argument',
      () {
        // The one price of the unification, pinned so it cannot be paid by
        // accident. A constructor builds an object rather than filling one, so
        // for a `fromJson` class the argument is left untouched and the result
        // is a different instance. Callers must assign the return value.
        final original = FromJsonAndDecodeHolder()..source = 'untouched';

        final returned = tomReflectionInfo.setValues(original, {
          'source': 'payload',
        });

        expect(returned.source, 'fromJson');
        expect(
          original.source,
          'untouched',
          reason: 'the argument is not the object that was built',
        );
        expect(identical(returned, original), isFalse);
      },
    );

    test('inbound: a failing fromJson is reported, not walked around', () {
      // The fixture is the hook that always throws, because it is the only way
      // to tell the two paths apart — a working `fromJson` would produce the
      // same values a field walk does, and the test would pass either way.
      // Falling back to the walk here would turn a broken hook into a silent
      // one; see `_hookFailed`.
      expect(
        () => tomReflectionInfo.setValues(ThrowingFromJsonHolder(), {
          'name': 'Ann',
        }),
        throwsA(
          isA<TomReflectorException>()
              .having((e) => e.key, 'key', 'reflection.hook.failed')
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('ThrowingFromJsonHolder.fromJson'),
              ),
        ),
      );
    });
  });

  group('toJson is an outbound hook of the reflective path', () {
    // A type that renders itself through `toJson` is asked, rather than being
    // field-walked with its own rendering discarded — whether it says so
    // nominally by implementing `TomJsonSerializable` or structurally by
    // having the method. Before this held, the server endpoint pipeline
    // compensated with a hook chain of its own, which is exactly what kept the
    // gap from being noticed.

    test('a TomJsonSerializable is asked, not walked', () {
      final dto = SelfSerializingDto()..status = 'up';

      expect(
        tomReflectionInfo.getValues(dto),
        {'ok': 'up'},
        reason: 'the interface renames the field, so a walk cannot match',
      );
      expect(tomReflectionInfo.getValues(dto), dto.toJson());
    });

    test('the interface is honoured without @tomReflector', () {
      // The `is` test is settled before any mirror is taken, so the type never
      // has to be reflectable. This fixture is not, and would throw
      // `reflector.reflect.not_reflectable` if the check had been placed after
      // the reflection step.
      final dto = UnreflectedSelfSerializingDto()..status = 'up';

      expect(tomReflectionInfo.getValues(dto), {'ok': 'up'});
    });

    test('a plain toJson method is asked too', () {
      final holder = PlainToJsonHolder()..status = 'up';

      expect(tomReflectionInfo.getValues(holder), {'ok': 'up'});
    });

    test('convertToJsonString inherits the same answer', () {
      // The string entry point adds no chain of its own; it is `jsonEncode` of
      // whatever `getValues` produced.
      final dto = SelfSerializingDto()..status = 'up';

      expect(tomReflectionInfo.convertToJsonString(dto), '{"ok":"up"}');
    });

    test('a toJson returning the wrong shape is reported, not ignored', () {
      // The hook exists to replace the field walk, so producing the walk's
      // output instead would be a silent substitution of the very thing the
      // hook overrides. Same rule as the `jsonEncode` getter.
      expect(
        () => tomReflectionInfo.getValues(BadToJsonHolder()),
        throwsA(
          isA<TomReflectorException>()
              .having((e) => e.key, 'key', 'reflection.hook.invalid_return')
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('BadToJsonHolder.toJson'),
              ),
        ),
      );
    });

    test('a failing toJson is reported as a failing hook', () {
      expect(
        () => tomReflectionInfo.getValues(ThrowingToJsonHolder()),
        throwsA(
          isA<TomReflectorException>()
              .having((e) => e.key, 'key', 'reflection.hook.failed')
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('ThrowingToJsonHolder.toJson'),
              ),
        ),
      );
    });
  });

  group('there is one reflector, and unreflected input is reported', () {
    // The constructor takes no reflector, and must not: `createInstance`,
    // `setValues` and `getValues` read the global `tomReflector`, and a
    // per-instance choice could never be honoured anyway — the generator emits
    // no data for an indirect subclass of `Reflection`, and
    // `const TomReflector()` is canonicalised to the global. A public
    // `final reflector` field documented as "used for all reflection
    // operations" would therefore promise a choice that does not exist. What
    // is testable is the consequence such a promise hides: what a caller sees
    // when the reflector does not know the type.

    test('a converter of your own reflects against the same registry', () {
      // Standing in for "the constructor offers no choice of reflector", which
      // is a compile-time fact. What is observable is that a locally built
      // converter answers identically: same registry, same answers. It can
      // differ in `strictUnknownFields` — and in nothing else.
      final own = TomReflectionInfo();
      final person = SimplePerson()
        ..name = 'Ada'
        ..age = 36;

      expect(own.getValues(person), tomReflectionInfo.getValues(person));
      expect(own.createInstance<SimplePerson>(), isA<SimplePerson>());
    });

    test('getValues reports an unreflected class instead of leaking', () {
      // Was a bare `NoSuchCapabilityError` from inside `tom_reflection`:
      // it named the type and nothing else — not the operation, not
      // the missing annotation — and slipped past every `on
      // TomReflectorException` the framework has.
      expect(
        () => tomReflectionInfo.getValues(NotReflectedHolder()),
        throwsA(
          isA<TomReflectorException>()
              .having((e) => e.key, 'key', 'reflector.reflect.not_reflectable')
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
              .having((e) => e.key, 'key', 'reflector.reflect.not_reflectable')
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
      //
      // The key is pinned as well as the message: `createInstance` wraps
      // everything, so an unreflectable class and a class with no usable
      // default constructor arrive under the same key, and the prose doc's
      // Error Handling example names it. Asserting only the exception type
      // would let that name drift.
      expect(
        () => tomReflectionInfo.createInstance<NotReflectedHolder>(),
        throwsA(
          isA<TomReflectorException>()
              .having((e) => e.key, 'key', 'reflector.instance_creation.failed')
              .having(
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

  // ==========================================================================
  // The debug reporters
  // ==========================================================================
  group('the debug reporters describe the class they are given', () {
    // Debug helpers, but public API, and their entire result is what they
    // print — so they were reachable only through their refusal tests and
    // nothing pinned the report itself. They are the module's answer to "why
    // did reflection not see my field", which makes an empty or truncated
    // report a real failure rather than a cosmetic one.
    //
    // The assertions are on structure and content, not on the exact line
    // format: the layout is a debugging convenience and pinning it verbatim
    // would make every formatting tweak a test failure.

    /// Runs [body] while collecting every `print` line into [sink].
    void capturePrints(List<String> sink, void Function() body) {
      runZoned(
        body,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => sink.add(line),
        ),
      );
    }

    test('reportReflect names the class, its fields and its members', () {
      final lines = <String>[];
      capturePrints(
        lines,
        () => tomReflectionInfo.reportReflect(
          tomReflector.reflectType(SimplePerson) as ClassMirror,
        ),
      );

      final report = lines.join('\n');
      expect(report, contains('Reflecting on SimplePerson'));
      expect(report, contains('Declarations:'));
      expect(report, contains('Instance Members:'));
      // Every declared field appears, which is the question the helper exists
      // to answer.
      for (final field in ['name', 'age', 'active', 'salary']) {
        expect(
          report,
          contains(field),
          reason: 'the report should mention the field $field',
        );
      }
      // Members are reported with their accessor kind, not just their name.
      expect(report, contains('getter'));
      expect(report, contains('setter'));
    });

    test('reportReflect walks up into the superclass', () {
      // `_printSuperclass` recurses, so the report does not stop at the
      // annotated class. SimplePerson extends Object directly, so Object is
      // the whole of the inherited half — enough to show the recursion runs.
      final lines = <String>[];
      capturePrints(
        lines,
        () => tomReflectionInfo.reportReflect(
          tomReflector.reflectType(SimplePerson) as ClassMirror,
        ),
      );

      expect(lines.join('\n'), contains('Reflecting on Object'));
    });

    test('reportReflectObject reports the annotated type of its instance', () {
      // The instance form resolves the object to a mirror and then defers, so
      // the two must agree line for line. Asserting the agreement rather than
      // the text pins the delegation itself: a reportReflectObject that
      // resolved the wrong mirror would still print a plausible report.
      final fromObject = <String>[];
      final fromMirror = <String>[];

      capturePrints(
        fromObject,
        () => tomReflectionInfo.reportReflectObject(SimplePerson()),
      );
      capturePrints(
        fromMirror,
        () => tomReflectionInfo.reportReflect(
          tomReflector.reflectType(SimplePerson) as ClassMirror,
        ),
      );

      expect(fromObject, isNotEmpty);
      expect(fromObject, fromMirror);
    });

    test('a mirror with no reflected type says so and stops', () {
      // The early return. Reachable through any generic annotated class: the
      // registry holds `GenericHolder`'s declaration, but a declaration is not
      // a type and there is nothing to enumerate. One line, and none of the
      // three sections — a report that carried on would print a page of
      // nothing.
      final generic = tomReflector.annotatedClasses.firstWhere(
        (cm) => cm.simpleName == 'GenericHolder',
      );

      final lines = <String>[];
      capturePrints(lines, () => tomReflectionInfo.reportReflect(generic));

      expect(lines, ['GenericHolder has no reflected type']);
    });
  });

  group('a reflectable type that is not annotated is refused', () {
    // The complement of the group above. `NotReflectedHolder` has no generated
    // data at all, so `reflect` itself fails and the boundary catches it.
    // `String`, `int`, `DateTime`, `List` and `Map` are different: they appear
    // as *field types* of annotated classes, so the deep type-annotation
    // quantify capability generates data for them too. They reflect
    // successfully, and then contribute no non-static, non-final, non-private
    // declarations — so the field walk completed and returned `{}`, reporting
    // success while dropping everything. `convertToJsonString` turned that
    // into the string `"{}"`: a valid-looking payload with every field gone.
    //
    // Membership of `tomReflector.annotatedClasses` cannot tell the two apart
    // — that list holds the quantified types as well, and, worse, does *not*
    // hold the mirror of a generic instantiation. The discriminator asserted
    // here is the `@tomReflector` metadata on the resolved class mirror, which
    // is present exactly on the classes a developer annotated.

    Matcher refusesToReflect(String operation, String type) => throwsA(
      isA<TomReflectorException>().having(
        (e) => e.defaultUserMessage,
        'message',
        allOf(contains(operation), contains(type), contains('@tomReflector')),
      ),
    );

    test('getValues refuses a String instead of returning an empty map', () {
      expect(
        () => tomReflectionInfo.getValues('hello'),
        refusesToReflect('getValues', 'String'),
      );
    });

    test('getValues names the not-annotated key for a quantified type', () {
      // The key is the part a caller writes code against, so it is pinned
      // separately from the message. It is deliberately *not*
      // `reflector.reflect.not_reflectable`: the class has reflection data,
      // it simply is not one of ours, and the remedy differs.
      expect(
        () => tomReflectionInfo.getValues(42),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.type.not_annotated',
          ),
        ),
      );
    });

    test('getValues refuses a DateTime', () {
      expect(
        () => tomReflectionInfo.getValues(DateTime.utc(2026, 1, 2)),
        refusesToReflect('getValues', 'DateTime'),
      );
    });

    test('getValues refuses a List, which could not even resolve', () {
      // This one never reached the empty map: resolving the class mirror of a
      // generic instantiation the reflector does not own threw a bare
      // `_TypeError` ("Null check operator used on a null value") from inside
      // `tom_reflection` — no type name, no operation, and not a
      // `TomReflectorException`. The boundary has to survive the lookup
      // failing, not just answer once it succeeds.
      expect(
        () => tomReflectionInfo.getValues(<int>[1, 2]),
        refusesToReflect('getValues', 'List<int>'),
      );
    });

    test('getValues refuses a plain Map', () {
      // A `_Map` has no generated data at all, so this arrives by the
      // not_reflectable door rather than the not_annotated one. Both are
      // `TomReflectorException`, which is what lets a caller write one catch.
      expect(
        () => tomReflectionInfo.getValues(<String, Object?>{'a': 1}),
        refusesToReflect('getValues', 'Map'),
      );
    });

    test('convertToJsonString no longer produces the string "{}"', () {
      expect(
        () => tomReflectionInfo.convertToJsonString('hello'),
        refusesToReflect('getValues', 'String'),
      );
    });

    test('setValues refuses a String instead of doing nothing', () {
      // Returned the string unchanged, reporting success for a write that
      // could never have happened.
      expect(
        () => tomReflectionInfo.setValues('hello', {'a': 1}),
        refusesToReflect('setValues', 'String'),
      );
    });

    test('setValues refuses an int, a DateTime and a List', () {
      expect(
        () => tomReflectionInfo.setValues(42, {'a': 1}),
        refusesToReflect('setValues', 'int'),
      );
      expect(
        () => tomReflectionInfo.setValues(DateTime.utc(2026), {'a': 1}),
        refusesToReflect('setValues', 'DateTime'),
      );
      expect(
        () => tomReflectionInfo.setValues(<int>[1, 2], {'a': 1}),
        refusesToReflect('setValues', 'List<int>'),
      );
    });

    test('setValues refuses a plain Map', () {
      expect(
        () => tomReflectionInfo.setValues(<String, Object?>{}, {'a': 1}),
        refusesToReflect('setValues', 'Map'),
      );
    });

    test('convertFromJsonString inherits the refusal', () {
      expect(
        () => tomReflectionInfo.convertFromJsonString('hello', '{"a":1}'),
        refusesToReflect('setValues', 'String'),
      );
    });

    test('reportReflectObject inherits the refusal', () {
      expect(
        () => tomReflectionInfo.reportReflectObject(42),
        refusesToReflect('reportReflectObject', 'int'),
      );
    });

    test('an annotated class is untouched by the check', () {
      final person = SimplePerson()
        ..name = 'Ada'
        ..age = 36;

      expect(tomReflectionInfo.getValues(person), containsPair('name', 'Ada'));
      expect(
        tomReflectionInfo.setValues(SimplePerson(), {'name': 'Ada'}).name,
        'Ada',
      );
    });

    test('an annotated *generic* class is untouched by the check', () {
      // The trap this check has to avoid. `im.type` for `GenericHolder<int>`
      // is an instantiated mirror that is absent from
      // `tomReflector.annotatedClasses`, so the membership test the obvious
      // implementation reaches for would reject a class that is annotated.
      // Metadata survives the instantiation; membership does not.
      final holder = GenericHolder<int>()..name = 'boxed';

      expect(
        tomReflectionInfo.getValues(holder),
        containsPair('name', 'boxed'),
      );
      expect(
        tomReflectionInfo.setValues(GenericHolder<int>(), {'name': 'x'}).name,
        'x',
      );
    });
  });

  group('an all-final class is refused rather than rendered as nothing', () {
    // `final` members are skipped outbound because they cannot be restored
    // inbound: no reflective deserializer can assign one after construction,
    // and emitting a member that will never come back produces an asymmetric
    // round trip — serializes, never restores — which is a worse answer than
    // an empty map, not a better one.
    //
    // So the skip stays. What does not stay is the silence around it. A class
    // whose members are *all* final walked every declaration, skipped every
    // one, and returned `{}` as a success — the same valid-looking payload
    // with everything dropped that `reflector.type.not_annotated` exists to
    // stop, arrived at by a different route. That silence is what pushes
    // hand-written serializers back into framework code: the developer sees
    // an empty body and nothing that says why.
    //
    // The refusal is narrow on purpose. It asks whether the walk produced
    // nothing *while* the class declares at least one member it dropped — so
    // a class with no members at all still renders `{}`, and a class that
    // contributes even one field is left alone.

    test('getValues refuses a class whose every member is final', () {
      expect(
        () => tomReflectionInfo.getValues(AllFinalHolder('Ada', 36)),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.type.all_final',
          ),
        ),
      );
    });

    test('the message names the type and every member it dropped', () {
      // The diagnostic is the whole point of the change, so its content is
      // pinned rather than left to prose: without the member names the
      // developer still has to go looking for which fields vanished.
      expect(
        () => tomReflectionInfo.getValues(AllFinalHolder('Ada', 36)),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(
              contains('AllFinalHolder'),
              contains('name'),
              contains('age'),
            ),
          ),
        ),
      );
    });

    test('the message points at the remedies rather than only the fault', () {
      expect(
        () => tomReflectionInfo.getValues(AllFinalHolder('Ada', 36)),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(contains('final'), contains('toJson')),
          ),
        ),
      );
    });

    test('convertToJsonString inherits the refusal', () {
      // The string-level entry point is where `"{}"` actually reached a wire,
      // so it is asserted separately from the map-level one.
      expect(
        () => tomReflectionInfo.convertToJsonString(AllFinalHolder('Ada', 36)),
        throwsA(isA<TomReflectorException>()),
      );
    });

    test('a final member inside a container is refused too', () {
      // `convertToJsonString` renders a `List` by handing each element to
      // `getValues`, so the guard has to reach elements as well — otherwise
      // the one shape that most often carries DTOs would keep the silence.
      expect(
        () => tomReflectionInfo.convertToJsonString([AllFinalHolder('Ada', 1)]),
        throwsA(isA<TomReflectorException>()),
      );
    });

    test('declaring toJson is enough to keep an immutable DTO working', () {
      // Immutability is not what is refused. All four rendering hooks are
      // consulted before the field walk, so a class that says how to render
      // itself never reaches the guard — which is what makes the refusal a
      // demand for a decision rather than a ban on a shape.
      expect(tomReflectionInfo.getValues(AllFinalWithToJsonHolder('Ada')), {
        'name': 'Ada',
      });
    });

    test('a class that still contributes a field is not refused', () {
      // The `final` member is still dropped. Only the total loss is
      // diagnosed, because only the total loss is indistinguishable from a
      // class that genuinely has nothing to say.
      final values = tomReflectionInfo.getValues(
        PartlyFinalHolder('abc')..label = 'visible',
      );

      expect(values, {'label': 'visible'});
      expect(values.containsKey('id'), isFalse);
    });

    test('a class with no members at all still renders an empty map', () {
      // The control that keeps the guard honest: `{}` is only wrong when
      // something was lost producing it.
      expect(tomReflectionInfo.getValues(NoMemberHolder()), isEmpty);
    });

    test('inbound was never the silent direction, and is left alone', () {
      // Decision 1: a `final` field cannot be assigned after construction, so
      // inbound there is nothing to choose. But it was already *loud* — a
      // payload naming a final member raises rather than being dropped — so
      // only the outbound half of this asymmetry was ever silent, and only the
      // outbound half changes. Asserted here so that stays true: if the
      // inbound refusal were ever relaxed into a skip, the pair would go quiet
      // again from the other end.
      expect(
        () => tomReflectionInfo.setValues(PartlyFinalHolder('abc'), {
          'id': 'xyz',
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unexpected_condition_final_static_private',
          ),
        ),
      );
    });

    test('a settable member is still written when no final one is named', () {
      final holder = PartlyFinalHolder('abc');

      expect(
        tomReflectionInfo.setValues(holder, {'label': 'set'}).label,
        'set',
      );
      expect(holder.id, 'abc');
    });
  });

  group('an unparseable date string names where it came from', () {
    // Letting the parse failure escape as a bare FormatException would carry
    // only the offending text — no field, no class, no position, no
    // exception id — and would defeat both `on TomReflectorException` and the
    // module's auto-logging. Each test below asserts on the *context*, not
    // merely on the fact that something threw.

    Matcher refusesToParse(String field, String owner, String text) => throwsA(
      isA<TomReflectorException>()
          .having((e) => e.key, 'key', 'reflection.set.date_parse_failed')
          .having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(contains(field), contains(owner), contains(text)),
          ),
    );

    test('a malformed string for a DateTime field is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(DateTimeHolder(), {
          'dateTime': 'not-a-date',
        }),
        refusesToParse('dateTime', 'DateTimeHolder', 'not-a-date'),
      );
    });

    test('an empty string for a DateTime field is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(DateTimeHolder(), {'dateTime': ''}),
        refusesToParse('dateTime', 'DateTimeHolder', '""'),
      );
    });

    test('the underlying FormatException is kept as the cause', () {
      try {
        tomReflectionInfo.setValues(DateTimeHolder(), {
          'dateTime': 'not-a-date',
        });
        fail('expected a TomReflectorException');
      } on TomReflectorException catch (e) {
        expect(e.rootException, isA<FormatException>());
      }
    });

    test('a malformed string for a TomZonedDate field is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(ZonedDateTimeHolder(), {
          'zonedDate': 'not-a-date',
        }),
        refusesToParse('zonedDate', 'ZonedDateTimeHolder', 'not-a-date'),
      );
    });

    test('an empty string for a TomZonedDate field is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(ZonedDateTimeHolder(), {
          'zonedDate': '',
        }),
        refusesToParse('zonedDate', 'ZonedDateTimeHolder', '""'),
      );
    });

    test('a malformed string for a TomZonedTime field is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(ZonedDateTimeHolder(), {
          'zonedTime': 'not-a-time',
        }),
        refusesToParse('zonedTime', 'ZonedDateTimeHolder', 'not-a-time'),
      );
    });

    test('a malformed string for a TomZonedDateTime field is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(ZonedDateTimeHolder(), {
          'zonedDateTime': 'nope',
        }),
        refusesToParse('zonedDateTime', 'ZonedDateTimeHolder', 'nope'),
      );
    });

    test('a bad element in a DateTime map names the map key', () {
      expect(
        () => tomReflectionInfo.setValues(DateTimeMapHolder(), {
          'dateTimeMap': {'due': 'not-a-date'},
        }),
        allOf(
          refusesToParse('dateTimeMap', 'DateTimeMapHolder', 'not-a-date'),
          throwsA(
            isA<TomReflectorException>().having(
              (e) => e.defaultUserMessage,
              'message names the key',
              contains("'due'"),
            ),
          ),
        ),
      );
    });

    test('a bad element in a TomZonedDate map is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(DateTimeMapHolder(), {
          'zonedDateMap': {'due': 'not-a-date'},
        }),
        refusesToParse('zonedDateMap', 'DateTimeMapHolder', 'not-a-date'),
      );
    });

    test('a bad element in a DateTime list names the index', () {
      expect(
        () => tomReflectionInfo.setValues(DateTimeListHolder(), {
          'dateTimeList': ['2024-01-01T00:00:00.000Z', 'not-a-date'],
        }),
        allOf(
          refusesToParse('dateTimeList', 'DateTimeListHolder', 'not-a-date'),
          throwsA(
            isA<TomReflectorException>().having(
              (e) => e.defaultUserMessage,
              'message names the index',
              contains('index 1'),
            ),
          ),
        ),
      );
    });

    test('a bad element in a TomZonedDate list is wrapped', () {
      expect(
        () => tomReflectionInfo.setValues(DateTimeListHolder(), {
          'zonedDateList': ['not-a-date'],
        }),
        refusesToParse('zonedDateList', 'DateTimeListHolder', 'not-a-date'),
      );
    });

    test('convertFromJsonString inherits the wrap', () {
      expect(
        () => tomReflectionInfo.convertFromJsonString(
          DateTimeHolder(),
          '{"dateTime":"not-a-date"}',
        ),
        refusesToParse('dateTime', 'DateTimeHolder', 'not-a-date'),
      );
    });

    test('a failed parse leaves the previous field value intact', () {
      final holder = DateTimeHolder()..dateTime = DateTime.utc(2020, 1, 1);

      expect(
        () => tomReflectionInfo.setValues(holder, {'dateTime': 'not-a-date'}),
        throwsA(isA<TomReflectorException>()),
      );
      expect(holder.dateTime, DateTime.utc(2020, 1, 1));
    });

    test('a failed element leaves the previous collection intact', () {
      final holder = DateTimeListHolder()
        ..dateTimeList = [DateTime.utc(2020, 1, 1)];

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'dateTimeList': ['not-a-date'],
        }),
        throwsA(isA<TomReflectorException>()),
      );
      expect(holder.dateTimeList, [DateTime.utc(2020, 1, 1)]);
    });

    test('well-formed strings are still parsed', () {
      final holder = DateTimeHolder();
      tomReflectionInfo.setValues(holder, {
        'dateTime': '2026-01-02T03:04:05.000Z',
      });

      expect(holder.dateTime, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });
  });

  group('a typed primitive collection is checked before it is assigned', () {
    // These assert on the *offending element*, not on length. A lazy
    // `.cast<T>()` passes a length assertion and every well-typed element,
    // and only fails when the bad one is read — so a test that stops at
    // `length` cannot tell the two implementations apart.

    test('a wrong-typed list element is refused at setValues', () {
      final holder = ListHolder();

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'intList': [1, 'x', 3],
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.collection_element_type_mismatch',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(
                  contains('intList'),
                  contains('[1]'),
                  contains("'x'"),
                  contains('String'),
                  contains('int'),
                ),
              ),
        ),
      );
    });

    test('a refused list element leaves the field as it was', () {
      final holder = ListHolder()..intList = [7, 8];

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'intList': [1, 'x'],
        }),
        throwsA(isA<TomReflectorException>()),
      );
      expect(holder.intList, [7, 8]);
    });

    test('null in a non-nullable list is refused', () {
      // The commonest wire accident: a nullable column serialized straight
      // into a non-nullable field. `cast<int>()` hides it until a read.
      final holder = ListHolder();

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'stringList': ['a', null],
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(contains('stringList'), contains('[1]'), contains('null')),
          ),
        ),
      );
      expect(holder.stringList, isNull);
    });

    test('a wrong-typed map value is refused at setValues', () {
      final holder = MapHolder();

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'intMap': {'a': 1, 'b': 'x'},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.collection_element_type_mismatch',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(
                  contains('intMap'),
                  contains("['b']"),
                  contains("'x'"),
                  contains('String'),
                ),
              ),
        ),
      );
    });

    test('a refused map value leaves the field as it was', () {
      final holder = MapHolder()..intMap = {'kept': 9};

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'intMap': {'a': 'x'},
        }),
        throwsA(isA<TomReflectorException>()),
      );
      expect(holder.intMap, {'kept': 9});
    });

    test('a non-String map key is refused at setValues', () {
      final holder = MapHolder();

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'intMap': {1: 2},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.map_key_type_mismatch',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(contains('intMap'), contains('int')),
              ),
        ),
      );
    });

    test('whole-number JSON numbers widen onto a double collection', () {
      // Same reason the scalar path widens: `{"rates": [1, 2]}` has no way to
      // say "double". Refusing it would make a whole-number double
      // unrepresentable on the wire — see _trySetWidenedNumericValue.
      final listHolder = ListHolder();
      tomReflectionInfo.setValues(listHolder, {
        'doubleList': [1, 2.5],
      });
      expect(listHolder.doubleList, [1.0, 2.5]);

      final mapHolder = MapHolder();
      tomReflectionInfo.setValues(mapHolder, {
        'doubleMap': {'a': 1, 'b': 2.5},
      });
      expect(mapHolder.doubleMap, {'a': 1.0, 'b': 2.5});
    });

    test('a well-typed collection still arrives element for element', () {
      // The control: the check must not reject anything that used to work.
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'stringList': ['a', 'b'],
        'intList': [1, 2],
        'boolList': [true, false],
        'dynamicList': [1, 'two', null],
      });

      expect(holder.stringList, ['a', 'b']);
      expect(holder.intList, [1, 2]);
      expect(holder.boolList, [true, false]);
      expect(holder.dynamicList, [1, 'two', null]);
    });
  });

  // ==========================================================================
  // setValues — the remaining refusals, asserted by key
  // ==========================================================================
  group('every way setValues can refuse a value has its own key', () {
    // The keys are the API: callers branch on them and translations are looked
    // up by them, so a refusal that silently changes key is a breaking change
    // that no type-only assertion would catch. Each test below names the key
    // it pins, and the group covers the `reflection.set.*` refusals that the
    // groups above leave untested.

    test('a String offered for a field that is not date-like is refused', () {
      // Reaching a String-valued entry means the field is not a String either
      // — that case is handled long before here. What remains is the date
      // family, which parses from text, and everything else, which does not.
      expect(
        () => tomReflectionInfo.setValues(SimplePerson(), {'age': 'abc'}),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.unexpected_string_type',
              )
              // The message has to identify the field and what arrived, or the
              // caller is left grepping a payload for the offending entry.
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                allOf(contains('age'), contains('abc'), contains('int')),
              ),
        ),
      );
    });

    test('a String offered for a nested annotated field is refused too', () {
      // An annotated object is built from a Map, never from text. This is the
      // same refusal as above and must not degrade into a cast error just
      // because the target happens to be reflectable.
      expect(
        () => tomReflectionInfo.setValues(PersonWithAddress(), {
          'address': 'Main Street 1',
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.unexpected_string_type',
          ),
        ),
      );
    });

    test('a non-String element of a DateTime map is refused', () {
      expect(
        () => tomReflectionInfo.setValues(DateTimeMapHolder(), {
          'dateTimeMap': {'start': 42},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.datetime_must_be_filled_from_string_in_map',
              )
              // The map key locates the bad entry; without it a large map
              // reports only that *something* in it was wrong.
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                contains('start'),
              ),
        ),
      );
    });

    test('a null value in a non-nullable DateTime map is refused', () {
      // null takes the same exit as 42: it is only accepted when the declared
      // value type admits it. `Map<String, DateTime>` does not, and letting
      // null through would produce a map that violates its own type.
      expect(
        () => tomReflectionInfo.setValues(DateTimeMapHolder(), {
          'dateTimeMap': {'start': null},
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.datetime_must_be_filled_from_string_in_map',
          ),
        ),
      );
    });

    test('a non-String element of a DateTime list is refused', () {
      // The list counterpart carries its own key: the two collection shapes
      // fail for the same reason but a caller fixing a payload needs to know
      // which one it was looking at.
      expect(
        () => tomReflectionInfo.setValues(DateTimeListHolder(), {
          'dateTimeList': [42],
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflection.set.datetime_must_be_filled_from_string_for_list',
          ),
        ),
      );
    });

    test('a list element that is not a Map cannot be materialized', () {
      // `List<Address>` is filled by building an Address per element, so each
      // element must be a Map. A String is not, and the cast that discovers
      // this fires while the lazily cast list is *iterated* — inside the try —
      // which is what lets this be reported as a materialization failure
      // naming the field rather than as a bare TypeError.
      final holder = UninitializedCollectionsHolder();
      expect(
        () => tomReflectionInfo.setValues(holder, {
          'addresses': ['Main Street 1'],
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.list_element_materialization_failed',
              )
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                allOf(contains('addresses'), contains('List<Address>')),
              )
              .having(
                (e) => e.parameters?['key'],
                'parameters[key]',
                'addresses',
              ),
        ),
      );
      // The list is built to the side and assigned only once it is complete,
      // so a refusal must leave the field exactly as it found it.
      expect(holder.addresses, isNull);
    });

    test('a map value that is not a Map cannot be materialized', () {
      final holder = UninitializedCollectionsHolder();
      expect(
        () => tomReflectionInfo.setValues(holder, {
          'teamMembers': {'lead': 'Alice'},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.map_value_materialization_failed',
              )
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                allOf(
                  contains('teamMembers'),
                  contains('Map<String, TeamMember>'),
                ),
              )
              .having(
                (e) => e.parameters?['key'],
                'parameters[key]',
                'teamMembers',
              ),
        ),
      );
      expect(holder.teamMembers, isNull);
    });
  });

  group('a value whose shape does not fit the field', () {
    // `setValues` dispatches on the *incoming value's* type, not the field's: a
    // Map goes to the map path and a List to the list path whatever the field
    // was declared as. Neither path may then leave the entry unapplied without
    // saying so. That is the whole contract this group pins, and it is worth
    // stating why it is not obvious: the strategies each path tries are
    // *allowed* to decline, so the natural implementation runs out of
    // strategies and falls off the end, and a field left holding its previous
    // value is indistinguishable at the call site from one that was set. The
    // two paths reach that end differently, so each is pinned separately: the
    // map path runs out of strategies, and the list path fails in its last
    // one. Either could regress on its own into dropping the value and
    // reporting success, which is the asymmetry these tests exist to catch.

    test('a List handed to a field that is not a list is refused', () {
      // Four different non-list shapes, one call each, so a future change that
      // stops refusing one of them is attributed to that one. The message has
      // to carry the field and its declared type: the payload behind a refusal
      // is a whole JSON document, and "a list is wrong somewhere in it" leaves
      // the caller to find which one.
      void refuses(
        Object holder,
        Map<String, dynamic> values, {
        required String field,
        required String declared,
        required Object value,
      }) {
        expect(
          () => tomReflectionInfo.setValues(holder, values),
          throwsA(
            isA<TomReflectorException>()
                .having(
                  (e) => e.key,
                  'key',
                  'reflection.set.list_field_not_settable',
                )
                .having(
                  (e) => e.defaultUserMessage,
                  'defaultUserMessage',
                  allOf(
                    contains("'$field'"),
                    contains(declared),
                    contains('$value'),
                  ),
                ),
          ),
          reason: 'field $field',
        );
      }

      refuses(
        MapHolder(),
        {
          'intMap': [1, 2, 3],
        },
        field: 'intMap',
        declared: 'Map<String, int>',
        value: [1, 2, 3],
      );
      refuses(
        UninitializedCollectionsHolder(),
        {
          'teamMembers': [
            {'name': 'Alice'},
          ],
        },
        field: 'teamMembers',
        declared: 'Map<String, TeamMember>',
        value: [
          {'name': 'Alice'},
        ],
      );
      refuses(
        NullablePerson(),
        {
          'age': [1],
        },
        field: 'age',
        declared: 'int',
        value: [1],
      );
      refuses(
        NullablePerson(),
        {
          'name': ['Alice'],
        },
        field: 'name',
        declared: 'String',
        value: ['Alice'],
      );
      refuses(
        PersonWithAddress(),
        {
          'address': [
            {'city': 'Berlin'},
          ],
        },
        field: 'address',
        declared: 'Address',
        value: [
          {'city': 'Berlin'},
        ],
      );
    });

    test('every refusal names the class, the field, its declared type and '
        'the value\'s type', () {
      // The keys say how far the reflector got before it gave up; these four
      // parameters say *where*, and they are what a caller needs when the
      // payload behind the refusal is a whole JSON document. A refusal that
      // names only the type it could not build — "Failed to create instance
      // of type List" — leaves the caller to search the document for every
      // field that might be a list. The value's runtime type is named rather
      // than left inside a root error, because the root error is the Dart
      // runtime's wording and is not there at all for a refusal decided by
      // inspection.
      void attributes(
        Object holder,
        String field,
        Object value, {
        required String key,
        required String declared,
      }) {
        final valueType = '${value.runtimeType}';
        expect(
          () => tomReflectionInfo.setValues(holder, {field: value}),
          throwsA(
            isA<TomReflectorException>()
                .having((e) => e.key, 'key', key)
                .having(
                  (e) => e.parameters?['class'],
                  'class',
                  '${holder.runtimeType}',
                )
                .having((e) => e.parameters?['field'], 'field', field)
                .having(
                  (e) => e.parameters?['declaredType'],
                  'declaredType',
                  contains(declared),
                )
                .having(
                  (e) => e.parameters?['valueType'],
                  'valueType',
                  valueType,
                )
                .having(
                  (e) => e.defaultUserMessage,
                  'defaultUserMessage',
                  allOf(
                    contains("'$field'"),
                    contains('${holder.runtimeType}'),
                    contains(declared),
                    contains(valueType),
                  ),
                ),
          ),
          reason: '$field of ${holder.runtimeType} given a $valueType',
        );
      }

      // A value no strategy handles at all.
      attributes(
        SimplePerson(),
        'age',
        2.5,
        key: 'reflection.set.unexpected_type',
        declared: 'int',
      );
      attributes(
        ListHolder(),
        'intList',
        {1, 2},
        key: 'reflection.set.unexpected_type',
        declared: 'List<int>',
      );
      // A List for a field that cannot hold one.
      attributes(
        MapHolder(),
        'intMap',
        [1, 2, 3],
        key: 'reflection.set.list_field_not_settable',
        declared: 'Map<String, int>',
      );
      // A Map for a field that cannot hold one, down each of the paths that
      // can refuse it: a type with nothing to build, a type the registry
      // cannot construct, a type with no reflected fields, and a field
      // already holding a list the map is poured into.
      attributes(
        OpaqueFieldHolder(),
        'anything',
        {'name': 'Alice'},
        key: 'reflection.set.map_field_not_settable',
        declared: 'dynamic',
      );
      attributes(
        ListHolder(),
        'intList',
        {'a': 1},
        key: 'reflector.instance_creation.failed',
        declared: 'List<int>',
      );
      attributes(
        NullablePerson(),
        'age',
        {'a': 1},
        key: 'reflector.instance_creation.failed',
        declared: 'int',
      );
      attributes(
        OpaqueFieldHolder(),
        'thing',
        {'name': 'Alice'},
        key: 'reflector.type.not_annotated',
        declared: 'Object',
      );
      attributes(
        Team(),
        'members',
        {'a': 1},
        key: 'reflector.type.not_annotated',
        declared: 'List<TeamMember>',
      );
    });

    test('an element that cannot be built names its field and position', () {
      // The class that would not build is only half the answer: the same
      // class may be the element type of several fields, and a long list has
      // many elements. The refusal keeps its key — the element's class could
      // not be constructed — and gains the field, the declared collection type
      // and the index or map key it was building.
      final element = {'name': 'a', 'age': 1};
      for (final (field, value, position) in [
        ('items', <Object>[element], 'index 0'),
        ('byName', <String, Object>{'first': element}, "key 'first'"),
      ]) {
        expect(
          () => tomReflectionInfo.setValues(UnbuildableElementsHolder(), {
            field: value,
          }),
          throwsA(
            isA<TomReflectorException>()
                .having(
                  (e) => e.key,
                  'key',
                  'reflector.instance_creation.failed',
                )
                .having((e) => e.parameters?['field'], 'field', field)
                .having(
                  (e) => e.parameters?['class'],
                  'class',
                  'UnbuildableElementsHolder',
                )
                .having(
                  (e) => e.parameters?['declaredType'],
                  'declaredType',
                  contains('AllFinalHolder'),
                )
                .having(
                  (e) => e.defaultUserMessage,
                  'defaultUserMessage',
                  allOf(
                    contains("'$field'"),
                    contains(position),
                    contains('AllFinalHolder'),
                  ),
                ),
          ),
          reason: field,
        );
      }
    });

    test('a refusal already attributed deeper is not re-attributed', () {
      // Attribution is innermost: a field of a nested object that refuses its
      // value names *that* field, and the enclosing field it was being built
      // for must not overwrite it with its own name.
      expect(
        () => tomReflectionInfo.setValues(PersonWithAddress(), {
          'address': {
            'city': {'a': 1},
          },
        }),
        throwsA(
          isA<TomReflectorException>()
              .having((e) => e.parameters?['field'], 'field', 'city')
              .having((e) => e.parameters?['class'], 'class', 'Address'),
        ),
      );
    });

    test('a refusal under any other key travels unchanged', () {
      // Only the two build refusals are re-raised with a field. Every other
      // key is a verdict that already carries its own context — here, a
      // nested key the strict converter does not know, which names the class
      // and the key it could not place. Wrapping it in "could not build a
      // value for field 'address'" would bury the precise statement under a
      // vaguer one, and put the enclosing class into its parameters.
      final strict = TomReflectionInfo(strictUnknownFields: true);

      expect(
        () => strict.setValues(PersonWithAddress(), {
          'address': {'nope': 1},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having((e) => e.key, 'key', 'reflection.set.unknown_field')
              .having((e) => e.parameters?['field'], 'field', isNull)
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                startsWith("TomReflectionInfo.setValues: 'Address'"),
              ),
        ),
      );
    });

    test('a List handed to a list field still binds', () {
      // The control for the test above: the drop is about the *field*, not
      // about lists being unsupported.
      final holder = ListHolder();
      tomReflectionInfo.setValues(holder, {
        'intList': [1, 2, 3],
      });
      expect(holder.intList, [1, 2, 3]);
    });

    test('a Map handed to a scalar or typed-collection field is refused', () {
      // The mirror image of the first test, and the reason the pair is worth
      // pinning: the same category of mistake is loud here and silent there.
      for (final entry in {
        'age': NullablePerson.new,
        'name': NullablePerson.new,
      }.entries) {
        expect(
          () => tomReflectionInfo.setValues(entry.value(), {
            entry.key: {'a': 1},
          }),
          throwsA(
            isA<TomReflectorException>().having(
              (e) => e.key,
              'key',
              'reflector.instance_creation.failed',
            ),
          ),
          reason: 'field ${entry.key}',
        );
      }

      expect(
        () => tomReflectionInfo.setValues(ListHolder(), {
          'intList': {'a': 1},
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.instance_creation.failed',
          ),
        ),
      );

      expect(
        () => tomReflectionInfo.setValues(UninitializedCollectionsHolder(), {
          'addresses': {'a': 1},
        }),
        throwsA(
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.instance_creation.failed',
          ),
        ),
      );
    });

    test('a Map handed to a field of an unreflected type is refused', () {
      // `Object?` and an unannotated class both name a type the registry has
      // no data for, and that refusal is attributed to the type, not to the
      // instantiation attempt.
      for (final field in ['thing', 'plain']) {
        expect(
          () => tomReflectionInfo.setValues(OpaqueFieldHolder(), {
            field: {'name': 'Alice'},
          }),
          throwsA(
            isA<TomReflectorException>().having(
              (e) => e.key,
              'key',
              'reflector.type.not_annotated',
            ),
          ),
          reason: 'field $field',
        );
      }
    });

    test('a Map handed to a field with no type to build is refused', () {
      // One of the two tails of the map path, and the only way to reach it:
      // every strategy declined by *inspection* rather than by failing, so
      // there is no underlying error to report and the refusal has to be
      // assembled from what was asked for. `dynamic` names no class at all. A
      // field declared `dynamic` to carry an arbitrary payload is the
      // realistic case, and losing that payload without a word is the whole
      // failure being refused here.
      expect(
        () => tomReflectionInfo.setValues(OpaqueFieldHolder(), {
          'anything': {'name': 'Alice'},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.map_field_not_settable',
              )
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                allOf(
                  contains("'anything'"),
                  contains('OpaqueFieldHolder'),
                  contains('dynamic'),
                  contains('{name: Alice}'),
                ),
              ),
        ),
      );
    });

    test('a Map lands on a `late` object field that cannot be read yet', () {
      // The one failure the map chain still absorbs, and the reason it has to.
      // Filling in place asks the field what it already holds; a `late` field
      // answers that question by raising, and the generated accessor is a
      // direct field read, so the error reaches the reflector. Reading it as
      // anything but "there is nothing here to fill" would make a `late`
      // object field impossible to deserialize into — the strategy would
      // report a failure instead of declining, and the strategy that *can*
      // build an Address would never be reached.
      final holder = LateFieldHolder();
      tomReflectionInfo.setValues(holder, {
        'address': {'city': 'Berlin', 'street': 'Main Street 1'},
      });
      expect(holder.address.city, 'Berlin');
      expect(holder.address.street, 'Main Street 1');
    });

    test(
      'an assigned `late` object field is filled in place, not replaced',
      () {
        // The control: once the field holds something the probe succeeds, the
        // fill-in-place strategy claims the payload, and a partial one updates
        // only what it names. Without this the test above would still pass if
        // the probe were removed and every `late` field simply rebuilt.
        final holder = LateFieldHolder();
        holder.address = Address()
          ..street = 'Old Street'
          ..city = 'Berlin';
        final before = holder.address;

        tomReflectionInfo.setValues(holder, {
          'address': {'city': 'Hamburg'},
        });

        expect(holder.address.city, 'Hamburg');
        expect(holder.address.street, 'Old Street');
        expect(identical(holder.address, before), isTrue);
      },
    );

    test('a fill that fails past the point of no return is not a decline', () {
      // The other half of the same rule. Once the probe has succeeded the
      // strategy has decided it applies, and a failure after that is a verdict
      // on the payload rather than a reason to try the next strategy. A raw
      // `Map` field is one of the few that reaches this strategy holding a
      // map, because the annotated-object strategy claims everything declared
      // `Map<String, ...>`; the map it actually holds is typed, so a value of
      // the wrong type is rejected by the map itself. Declining here would put
      // that back where this whole group started: the entry dropped, the call
      // reporting success.
      final holder = LateFieldHolder();
      holder.address = Address();
      holder.raw = <String, int>{'count': 1};

      expect(
        () => tomReflectionInfo.setValues(holder, {
          'raw': {'count': 'not a number'},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.map_field_fill_failed',
              )
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                allOf(
                  contains("'raw'"),
                  contains('LateFieldHolder'),
                  contains('not a number'),
                ),
              )
              .having((e) => e.rootException, 'rootException', isNotNull),
        ),
      );
      expect(holder.raw, {'count': 1}, reason: 'the field is not half-written');
    });

    test('a Map built for a field the field then rejects keeps the error', () {
      // The other tail, and the reason the two are not one key: here a
      // strategy did apply. `GenericHolder<int>` names a class the registry
      // holds — keyed by declaration, so what comes back is a
      // `GenericHolder<dynamic>` — and the setter rejects it with a bare
      // `_TypeError` that names two type arguments and no field. Letting that
      // through unwrapped would trade a silent drop for an error nobody can
      // attribute, so the refusal carries both the field and the cause.
      expect(
        () => tomReflectionInfo.setValues(OpaqueFieldHolder(), {
          'generic': {'name': 'Alice', 'count': 3},
        }),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'reflection.set.map_field_assignment_failed',
              )
              .having(
                (e) => e.defaultUserMessage,
                'defaultUserMessage',
                allOf(
                  contains("'generic'"),
                  contains('OpaqueFieldHolder'),
                  contains('GenericHolder<int>'),
                  contains('{name: Alice, count: 3}'),
                ),
              )
              .having((e) => e.rootException, 'rootException', isNotNull),
        ),
      );
    });

    test('a Map that does fit replaces a map field but fills an object field', () {
      // Not mismatches, but they bound the cases above from the other side and
      // they are not the same answer: which strategy claims the payload decides
      // whether prior content survives. A `Map<String, String>` is a primitive
      // map type, handled first and assigned wholesale, so a partial payload
      // loses the keys it omits. A field holding an annotated object falls
      // through to the fill-in-place strategy, so a partial payload there
      // updates only what it names.
      final mapHolder = MapHolder();
      mapHolder.stringMap = {'keep': 'me'};
      tomReflectionInfo.setValues(mapHolder, {
        'stringMap': {'add': 'new'},
      });
      expect(mapHolder.stringMap, {'add': 'new'});

      final nested = PersonWithAddress();
      nested.address = Address()
        ..street = 'Old Street'
        ..city = 'Berlin';
      tomReflectionInfo.setValues(nested, {
        'address': {'city': 'Hamburg'},
      });
      expect(nested.address?.city, 'Hamburg');
      expect(nested.address?.street, 'Old Street');
    });
  });
}
