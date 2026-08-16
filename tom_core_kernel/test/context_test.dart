import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Tests for the Tom Execution Context System
// ============================================================================

void main() {
  // ==========================================================================
  // TomExecutionContext Tests
  // ==========================================================================
  group('TomExecutionContext', () {
    group('constructor', () {
      test('should create context with empty map', () {
        final context = TomExecutionContext({});

        expect(context.contextMap, isEmpty);
      });

      test('should create context with entries', () {
        final context = TomExecutionContext({
          'key1': TomContextEntry<String>(() => 'value1'),
          'key2': TomContextEntry<int>(() => 42),
        });

        expect(context.contextMap.length, equals(2));
        expect(context.contextMap.containsKey('key1'), isTrue);
        expect(context.contextMap.containsKey('key2'), isTrue);
      });
    });

    group('add', () {
      test('should add new entry', () {
        final context = TomExecutionContext({});

        context.add('newKey', TomContextEntry<String>(() => 'newValue'));

        expect(context.contextMap.containsKey('newKey'), isTrue);
        expect(
          context.contextMap['newKey']?.contextFunction(),
          equals('newValue'),
        );
      });

      test('should replace existing entry', () {
        final context = TomExecutionContext({
          'key': TomContextEntry<String>(() => 'original'),
        });

        context.add('key', TomContextEntry<String>(() => 'replaced'));

        expect(
          context.contextMap['key']?.contextFunction(),
          equals('replaced'),
        );
      });
    });

    group('clear', () {
      test('should remove all entries', () {
        final context = TomExecutionContext({
          'key1': TomContextEntry<String>(() => 'value1'),
          'key2': TomContextEntry<String>(() => 'value2'),
        });

        expect(context.contextMap.length, equals(2));

        context.clear();

        expect(context.contextMap, isEmpty);
      });
    });

    group('combineWith', () {
      test('should merge entries from another context', () {
        final context1 = TomExecutionContext({
          'key1': TomContextEntry<String>(() => 'value1'),
        });

        final context2 = TomExecutionContext({
          'key2': TomContextEntry<String>(() => 'value2'),
        });

        context1.combineWith(context2);

        expect(context1.contextMap.length, equals(2));
        expect(context1.contextMap.containsKey('key1'), isTrue);
        expect(context1.contextMap.containsKey('key2'), isTrue);
      });

      test('should overwrite duplicate keys', () {
        final context1 = TomExecutionContext({
          'key': TomContextEntry<String>(() => 'original'),
        });

        final context2 = TomExecutionContext({
          'key': TomContextEntry<String>(() => 'overwritten'),
        });

        context1.combineWith(context2);

        expect(
          context1.contextMap['key']?.contextFunction(),
          equals('overwritten'),
        );
      });
    });

    group('runInContext', () {
      test('should make context available in zone', () {
        final context = TomExecutionContext({
          'testKey': TomContextEntry<String>(() => 'testValue'),
        });

        String? retrievedValue;

        context.runInContext(() {
          final ctx = getFromCurrentZone<TomExecutionContext>();
          retrievedValue =
              ctx?.contextMap['testKey']?.contextFunction() as String?;
        });

        expect(retrievedValue, equals('testValue'));
      });

      test('should return value from body', () {
        final context = TomExecutionContext({});

        final result = context.runInContext(() => 42);

        expect(result, equals(42));
      });

      test('should merge with existing context in zone', () {
        final outerContext = TomExecutionContext({
          'outer': TomContextEntry<String>(() => 'outerValue'),
        });

        final innerContext = TomExecutionContext({
          'inner': TomContextEntry<String>(() => 'innerValue'),
        });

        String? outerVal;
        String? innerVal;

        outerContext.runInContext(() {
          innerContext.runInContext(() {
            final ctx = getFromCurrentZone<TomExecutionContext>();
            outerVal = ctx?.contextMap['outer']?.contextFunction() as String?;
            innerVal = ctx?.contextMap['inner']?.contextFunction() as String?;
          });
        });

        expect(outerVal, equals('outerValue'));
        expect(innerVal, equals('innerValue'));
      });

      test('inner context wins on colliding key (precedence)', () {
        // Bug §3b regression: when a key exists in both the parent (outer) and
        // the child (inner) context, the inner — the one being run — must win.
        final outerContext = TomExecutionContext({
          'shared': TomContextEntry<String>(() => 'outerValue'),
        });
        final innerContext = TomExecutionContext({
          'shared': TomContextEntry<String>(() => 'innerValue'),
        });

        String? sharedVal;

        outerContext.runInContext(() {
          innerContext.runInContext(() {
            final ctx = getFromCurrentZone<TomExecutionContext>();
            sharedVal = ctx?.contextMap['shared']?.contextFunction() as String?;
          });
        });

        expect(sharedVal, equals('innerValue'));
      });

      test('does not mutate source context map (no aliasing)', () {
        // Bug §3a regression: running the inner context inside a parent zone
        // must not pollute the inner context's own contextMap with the
        // parent's entries — the source object must be left unchanged.
        final outerContext = TomExecutionContext({
          'outer': TomContextEntry<String>(() => 'outerValue'),
        });
        final innerContext = TomExecutionContext({
          'inner': TomContextEntry<String>(() => 'innerValue'),
        });

        outerContext.runInContext(() {
          innerContext.runInContext(() {});
        });

        expect(innerContext.contextMap.keys, equals(['inner']));
        expect(innerContext.contextMap.containsKey('outer'), isFalse);
      });
    });

    group('runInContextAsync', () {
      test('should make context available in async zone', () async {
        final context = TomExecutionContext({
          'asyncKey': TomContextEntry<String>(() => 'asyncValue'),
        });

        String? retrievedValue;

        await context.runInContextAsync(() async {
          await Future.delayed(Duration.zero);
          final ctx = getFromCurrentZone<TomExecutionContext>();
          retrievedValue =
              ctx?.contextMap['asyncKey']?.contextFunction() as String?;
        });

        expect(retrievedValue, equals('asyncValue'));
      });

      test('should return future value from body', () async {
        final context = TomExecutionContext({});

        final result = await context.runInContextAsync(() async {
          await Future.delayed(Duration.zero);
          return 'async result';
        });

        expect(result, equals('async result'));
      });

      test('should merge with existing context in zone', () async {
        final outerContext = TomExecutionContext({
          'outer': TomContextEntry<String>(() => 'outerValue'),
        });
        final innerContext = TomExecutionContext({
          'inner': TomContextEntry<String>(() => 'innerValue'),
        });

        String? outerVal;
        String? innerVal;

        await outerContext.runInContextAsync(() async {
          await innerContext.runInContextAsync(() async {
            await Future.delayed(Duration.zero);
            final ctx = getFromCurrentZone<TomExecutionContext>();
            outerVal = ctx?.contextMap['outer']?.contextFunction() as String?;
            innerVal = ctx?.contextMap['inner']?.contextFunction() as String?;
          });
        });

        expect(outerVal, equals('outerValue'));
        expect(innerVal, equals('innerValue'));
      });

      test('inner context wins on colliding key (precedence)', () async {
        // Bug §3b regression for the async path.
        final outerContext = TomExecutionContext({
          'shared': TomContextEntry<String>(() => 'outerValue'),
        });
        final innerContext = TomExecutionContext({
          'shared': TomContextEntry<String>(() => 'innerValue'),
        });

        String? sharedVal;

        await outerContext.runInContextAsync(() async {
          await innerContext.runInContextAsync(() async {
            await Future.delayed(Duration.zero);
            final ctx = getFromCurrentZone<TomExecutionContext>();
            sharedVal = ctx?.contextMap['shared']?.contextFunction() as String?;
          });
        });

        expect(sharedVal, equals('innerValue'));
      });

      test('does not mutate source context map (no aliasing)', () async {
        // Bug §3a regression for the async path.
        final outerContext = TomExecutionContext({
          'outer': TomContextEntry<String>(() => 'outerValue'),
        });
        final innerContext = TomExecutionContext({
          'inner': TomContextEntry<String>(() => 'innerValue'),
        });

        await outerContext.runInContextAsync(() async {
          await innerContext.runInContextAsync(() async {});
        });

        expect(innerContext.contextMap.keys, equals(['inner']));
        expect(innerContext.contextMap.containsKey('outer'), isFalse);
      });
    });

    group('getEntry', () {
      test('should return entry by name with correct type', () {
        final context = TomExecutionContext({
          'stringKey': TomContextEntry<String>(() => 'hello'),
          'intKey': TomContextEntry<int>(() => 42),
        });

        final stringEntry = context.getEntry<String>('stringKey');
        final intEntry = context.getEntry<int>('intKey');

        expect(stringEntry, isNotNull);
        expect(stringEntry?.value, equals('hello'));
        expect(intEntry, isNotNull);
        expect(intEntry?.value, equals(42));
      });

      test('should return null for wrong type', () {
        final context = TomExecutionContext({
          'stringKey': TomContextEntry<String>(() => 'hello'),
        });

        // Request as int when it's actually String
        final wrongTypeEntry = context.getEntry<int>('stringKey');

        expect(wrongTypeEntry, isNull);
      });

      test('should return null for missing key', () {
        final context = TomExecutionContext({});

        final missingEntry = context.getEntry<String>('nonexistent');

        expect(missingEntry, isNull);
      });
    });

    group('getValueFromCurrentZone (static)', () {
      test('should return value from current zone context', () {
        final context = TomExecutionContext({
          'userId': TomContextEntry<String>(() => 'user-123'),
        });

        String? result;
        context.runInContext(() {
          result = TomExecutionContext.getValueFromCurrentZone<String>('userId');
        });

        expect(result, equals('user-123'));
      });

      test('should return null when key not found', () {
        final context = TomExecutionContext({});

        String? result;
        context.runInContext(() {
          result = TomExecutionContext.getValueFromCurrentZone<String>('missing');
        });

        expect(result, isNull);
      });

      test('should return null when no context in zone', () {
        final result = TomExecutionContext.getValueFromCurrentZone<String>('anyKey');

        expect(result, isNull);
      });
    });

    // ------------------------------------------------------------------------
    // Which read reaches which store
    //
    // runInContext installs exactly two zone keys, both Types:
    // TomExecutionContext and TomZoneValues. Named entries live *inside* the
    // context; ad-hoc zone values live *inside* the container. Neither is
    // reachable by the other's read, and both mistakes fail silently as null,
    // so they are pinned here.
    // ------------------------------------------------------------------------
    group('type-keyed vs name-keyed reads', () {
      test('a named entry is not reachable by its value type', () {
        final context = TomExecutionContext({
          'userId': TomContextEntry<String>(() => '12345'),
        });

        String? byType;
        String? byName;
        context.runInContext(() {
          byType = getFromCurrentZone<String>();
          byName = TomExecutionContext.getValueFromCurrentZone<String>('userId');
        });

        expect(byType, isNull,
            reason: 'the zone holds no String key, only Type keys');
        expect(byName, equals('12345'));
      });

      test('runInContext installs the context and the zone values by Type', () {
        final context = TomExecutionContext({
          'userId': TomContextEntry<String>(() => '12345'),
        });

        TomExecutionContext? ctx;
        TomZoneValues? values;
        context.runInContext(() {
          ctx = getFromCurrentZone<TomExecutionContext>();
          values = getFromCurrentZone<TomZoneValues>();
        }, zoneValues: {'requestId': 'req-7'});

        expect(ctx, isNotNull);
        expect(values, isNotNull);
      });

      test('a zone value is read through the container, not by entry name', () {
        final context = TomExecutionContext({});

        Object? viaContainer;
        String? viaEntryName;
        context.runInContext(() {
          viaContainer = getFromCurrentZone<TomZoneValues>()?['requestId'];
          viaEntryName =
              TomExecutionContext.getValueFromCurrentZone<String>('requestId');
        }, zoneValues: {'requestId': 'req-7'});

        expect(viaContainer, equals('req-7'));
        expect(viaEntryName, isNull,
            reason: 'zoneValues are not entries of the context map');
      });
    });

    // ------------------------------------------------------------------------
    // The inference trap
    //
    // The constructor parameter is Map<String, TomContextEntry>, so a raw
    // TomContextEntry(() => x) written directly in that map literal gets
    // TomContextEntry<dynamic> as its downward inference context — the value
    // expression never gets a say. Since getEntry requires entry.type == T
    // exactly, every typed read of such an entry then returns null. The same
    // expression assigned to a local infers from the value instead, so the
    // trap is *positional*: it is pinned here from both sides.
    // ------------------------------------------------------------------------
    group('raw vs parameterised entry (type inference)', () {
      test('a raw entry in the constructor map infers dynamic, not the value '
          'type', () {
        final context = TomExecutionContext({
          'tenant': TomContextEntry(() => 'acme'),
        });

        expect(context.contextMap['tenant']?.type, equals(dynamic));
        expect(context.getEntry<String>('tenant'), isNull,
            reason: 'getEntry requires entry.type == T exactly');
        expect(context.getEntry<dynamic>('tenant')?.value, equals('acme'),
            reason: 'the value is there — only the typed read misses it');
      });

      test('the same raw expression infers the value type outside the map', () {
        final entry = TomContextEntry(() => 'acme');

        expect(entry.type, equals(String),
            reason: 'no downward context, so inference comes from the value');
      });

      test('a parameterised entry is read back by its value type', () {
        final context = TomExecutionContext({
          'tenant': TomContextEntry<String>(() => 'acme'),
        });

        String? tenant;
        context.runInContext(() {
          tenant = TomExecutionContext.getValueFromCurrentZone<String>('tenant');
        });

        expect(context.contextMap['tenant']?.type, equals(String));
        expect(tenant, equals('acme'));
      });
    });
  });

  // ==========================================================================
  // TomContextEntry Tests
  // ==========================================================================
  group('TomContextEntry', () {
    test('should return value from context function', () {
      final entry = TomContextEntry<String>(() => 'hello');

      expect(entry.contextFunction(), equals('hello'));
    });

    test('should return correct type', () {
      final stringEntry = TomContextEntry<String>(() => 'text');
      final intEntry = TomContextEntry<int>(() => 42);
      final listEntry = TomContextEntry<List<String>>(() => ['a', 'b']);

      expect(stringEntry.type, equals(String));
      expect(intEntry.type, equals(int));
      expect(listEntry.type, equals(List<String>));
    });

    test('should return null when function returns null', () {
      final entry = TomContextEntry<String?>(() => null);

      expect(entry.contextFunction(), isNull);
    });

    test('should compute value lazily', () {
      var computeCount = 0;

      final entry = TomContextEntry<int>(() {
        computeCount++;
        return computeCount;
      });

      expect(computeCount, equals(0));
      entry.contextFunction();
      expect(computeCount, equals(1));
      entry.contextFunction();
      expect(computeCount, equals(2));
    });

    group('value getter', () {
      test('should return value same as contextFunction', () {
        final entry = TomContextEntry<String>(() => 'test-value');

        expect(entry.value, equals('test-value'));
        expect(entry.value, equals(entry.contextFunction()));
      });

      test('should return null when function returns null', () {
        final entry = TomContextEntry<String?>(() => null);

        expect(entry.value, isNull);
      });
    });

    group('call operator', () {
      test('should return value when called', () {
        final entry = TomContextEntry<String>(() => 'callable-value');

        expect(entry(), equals('callable-value'));
      });

      test('should be equivalent to value getter', () {
        final entry = TomContextEntry<int>(() => 99);

        expect(entry(), equals(entry.value));
      });
    });

    group('tilde operator', () {
      test('should return value when used', () {
        final entry = TomContextEntry<String>(() => 'tilde-value');

        expect(~entry, equals('tilde-value'));
      });

      test('should be equivalent to value getter', () {
        final entry = TomContextEntry<int>(() => 77);

        expect(~entry, equals(entry.value));
      });
    });
  });

  // ==========================================================================
  // TomZoneValues Tests
  // ==========================================================================
  group('TomZoneValues', () {
    test('should get value by key', () {
      final zoneValues = TomZoneValues({'key': 'value'});

      expect(zoneValues['key'], equals('value'));
    });

    test('should set value by key', () {
      final zoneValues = TomZoneValues({});

      zoneValues['newKey'] = 'newValue';

      expect(zoneValues['newKey'], equals('newValue'));
    });

    test('should return null for missing key', () {
      final zoneValues = TomZoneValues({});

      expect(zoneValues['missing'], isNull);
    });

    test('should overwrite existing value', () {
      final zoneValues = TomZoneValues({'key': 'original'});

      zoneValues['key'] = 'updated';

      expect(zoneValues['key'], equals('updated'));
    });

    group('addAll', () {
      test('should add all entries from map', () {
        final zoneValues = TomZoneValues({'existing': 'value1'});

        zoneValues.addAll({'new1': 'value2', 'new2': 'value3'});

        expect(zoneValues['existing'], equals('value1'));
        expect(zoneValues['new1'], equals('value2'));
        expect(zoneValues['new2'], equals('value3'));
      });

      test('should return self for chaining', () {
        final zoneValues = TomZoneValues({});

        final result = zoneValues.addAll({'key': 'value'});

        expect(identical(result, zoneValues), isTrue);
      });
    });

    group('clear', () {
      test('should remove all entries', () {
        final zoneValues = TomZoneValues({'key1': 'value1', 'key2': 'value2'});

        zoneValues.clear();

        expect(zoneValues['key1'], isNull);
        expect(zoneValues['key2'], isNull);
      });
    });

    group('containsKey', () {
      test('should return true for existing key', () {
        final zoneValues = TomZoneValues({'existingKey': 'value'});

        expect(zoneValues.containsKey('existingKey'), isTrue);
      });

      test('should return false for missing key', () {
        final zoneValues = TomZoneValues({});

        expect(zoneValues.containsKey('missingKey'), isFalse);
      });
    });

    group('remove', () {
      test('should remove and return value', () {
        final zoneValues = TomZoneValues({'toRemove': 'theValue'});

        final removed = zoneValues.remove('toRemove');

        expect(removed, equals('theValue'));
        expect(zoneValues['toRemove'], isNull);
      });

      test('should return null for missing key', () {
        final zoneValues = TomZoneValues({});

        final removed = zoneValues.remove('notThere');

        expect(removed, isNull);
      });
    });

    group('constructor with existingValues', () {
      test('should merge existing values', () {
        final existing = TomZoneValues({'parent1': 'parentVal1'});
        final child = TomZoneValues({'child1': 'childVal1'}, existingValues: existing);

        expect(child['parent1'], equals('parentVal1'));
        expect(child['child1'], equals('childVal1'));
      });

      test('should allow child to override parent values', () {
        final existing = TomZoneValues({'shared': 'parentValue'});
        final child = TomZoneValues({'shared': 'childValue'}, existingValues: existing);

        expect(child['shared'], equals('childValue'));
      });
    });
  });

  // ==========================================================================
  // TomContextProviders Tests
  // ==========================================================================
  group('TomContextProviders', () {
    group('default values (no principal)', () {
      test('should return "default" for organization', () {
        expect(TomContextProviders.getOrganization(), equals('default'));
      });

      test('should return "default" for application', () {
        expect(TomContextProviders.getApplication(), equals('default'));
      });

      test('should return "default" for process', () {
        expect(TomContextProviders.getProcess(), equals('default'));
      });

      test('should return "en" for language', () {
        expect(TomContextProviders.getLanguage(), equals('en'));
      });

      test('should return "XX" for country', () {
        expect(TomContextProviders.getCountry(), equals('XX'));
      });

      test('should return "utc" for timezone', () {
        expect(TomContextProviders.getTimezone(), equals('utc'));
      });

      test('should return "en" for client language', () {
        expect(TomContextProviders.getClientLanguage(), equals('en'));
      });

      test('should return "XX" for client country', () {
        expect(TomContextProviders.getClientCountry(), equals('XX'));
      });

      test('should return "utc" for client timezone', () {
        expect(TomContextProviders.getClientTimezone(), equals('utc'));
      });
    });

    group('with principal in zone', () {
      late TomPrincipal principal;

      setUp(() {
        principal = TomPrincipal(
          organization: 'test-org',
          application: 'test-app',
          process: 'test-process',
          language: 'de',
          country: 'DE',
          timezone: 'Europe/Berlin',
          clientLanguage: 'fr',
          clientCountry: 'FR',
          clientTimezone: 'Europe/Paris',
        );
      });

      test('should return organization from principal', () {
        final result = runZoned(
          () => TomContextProviders.getOrganization(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('test-org'));
      });

      test('should return application from principal', () {
        final result = runZoned(
          () => TomContextProviders.getApplication(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('test-app'));
      });

      test('should return process from principal', () {
        final result = runZoned(
          () => TomContextProviders.getProcess(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('test-process'));
      });

      test('should return country from principal', () {
        final result = runZoned(
          () => TomContextProviders.getCountry(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('DE'));
      });

      test('should return timezone from principal', () {
        final result = runZoned(
          () => TomContextProviders.getTimezone(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('Europe/Berlin'));
      });

      test('should return client language from principal', () {
        final result = runZoned(
          () => TomContextProviders.getClientLanguage(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('fr'));
      });

      test('should return client country from principal', () {
        final result = runZoned(
          () => TomContextProviders.getClientCountry(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('FR'));
      });

      test('should return language from principal', () {
        final result = runZoned(
          () => TomContextProviders.getLanguage(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('de'));
      });

      test('should return client timezone from principal', () {
        final result = runZoned(
          () => TomContextProviders.getClientTimezone(),
          zoneValues: {TomPrincipal: principal},
        );

        expect(result, equals('Europe/Paris'));
      });
    });
  });

  // ==========================================================================
  // tomExecutionContext (default instance) Tests
  // ==========================================================================
  group('tomExecutionContext', () {
    test('should have standard context entries', () {
      final entries = tomExecutionContext.contextMap.keys.toList();

      expect(entries, contains('organization'));
      expect(entries, contains('application'));
      expect(entries, contains('process'));
      expect(entries, contains('language'));
      expect(entries, contains('country'));
      expect(entries, contains('timezone'));
      expect(entries, contains('clientLanguage'));
      expect(entries, contains('clientCountry'));
      expect(entries, contains('clientTimezone'));
    });

    test('should return default values when no principal', () {
      final org =
          tomExecutionContext.contextMap['organization']?.contextFunction();
      final lang =
          tomExecutionContext.contextMap['language']?.contextFunction();

      expect(org, equals('default'));
      expect(lang, equals('en'));
    });
  });
}
