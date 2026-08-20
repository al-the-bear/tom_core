import 'dart:convert';

import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // ===========================================================================
  // pretty_json.dart tests
  // ===========================================================================

  group('prettyJson', () {
    group('basic formatting', () {
      test('should format simple flat object', () {
        final input = '{"name":"App","port":8080}';
        final result = prettyJson(input);

        expect(result, contains('"name": "App"'));
        expect(result, contains('"port": 8080'));
        expect(result.split('\n').length, greaterThan(1));
      });

      test('should format nested objects with proper indentation', () {
        final input = '{"a":1,"b":{"c":2}}';
        final result = prettyJson(input);

        final lines = result.split('\n');
        expect(lines.length, equals(6));
        expect(lines[0], equals('{'));
        expect(lines[1], equals('  "a": 1,'));
        expect(lines[2], equals('  "b": {'));
        expect(lines[3], equals('    "c": 2'));
        expect(lines[4], equals('  }'));
        expect(lines[5], equals('}'));
      });

      test('should format arrays correctly', () {
        final input = '{"items":[1,2,3]}';
        final result = prettyJson(input);

        expect(result, contains('"items": ['));
        expect(result, contains('    1,'));
        expect(result, contains('    2,'));
        expect(result, contains('    3'));
      });

      test('should handle empty object', () {
        final result = prettyJson('{}');
        expect(result, equals('{}'));
      });

      test('should handle empty array', () {
        final result = prettyJson('[]');
        expect(result, equals('[]'));
      });
    });

    group('data types', () {
      test('should format string values', () {
        final input = '{"text":"hello world"}';
        final result = prettyJson(input);
        expect(result, contains('"text": "hello world"'));
      });

      test('should format integer values', () {
        final input = '{"count":42}';
        final result = prettyJson(input);
        expect(result, contains('"count": 42'));
      });

      test('should format float values', () {
        final input = '{"price":19.99}';
        final result = prettyJson(input);
        expect(result, contains('"price": 19.99'));
      });

      test('should format boolean true', () {
        final input = '{"enabled":true}';
        final result = prettyJson(input);
        expect(result, contains('"enabled": true'));
      });

      test('should format boolean false', () {
        final input = '{"disabled":false}';
        final result = prettyJson(input);
        expect(result, contains('"disabled": false'));
      });

      test('should format null values', () {
        final input = '{"value":null}';
        final result = prettyJson(input);
        expect(result, contains('"value": null'));
      });
    });

    group('complex structures', () {
      test('should format deeply nested objects', () {
        final input = '{"level1":{"level2":{"level3":{"value":"deep"}}}}';
        final result = prettyJson(input);

        expect(result, contains('        "value": "deep"'));
      });

      test('should format array of objects', () {
        final input = '{"users":[{"name":"Alice"},{"name":"Bob"}]}';
        final result = prettyJson(input);

        expect(result, contains('"name": "Alice"'));
        expect(result, contains('"name": "Bob"'));
      });

      test('should format mixed nested structures', () {
        final input =
            '{"config":{"servers":["localhost","remote"],"port":8080}}';
        final result = prettyJson(input);

        expect(result, contains('"servers": ['));
        expect(result, contains('"localhost"'));
        expect(result, contains('"remote"'));
        expect(result, contains('"port": 8080'));
      });
    });

    group('error handling', () {
      test('should throw FormatException for invalid JSON', () {
        expect(() => prettyJson('{invalid}'), throwsA(isA<FormatException>()));
      });

      test('should throw FormatException for empty string', () {
        expect(() => prettyJson(''), throwsA(isA<FormatException>()));
      });

      test('should throw FormatException for malformed JSON', () {
        expect(
          () => prettyJson('{"unclosed":'),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });

  group('prettyJsonLine', () {
    test('should format JSON as single line', () {
      final input = '{"a":1,"b":2}';
      final result = prettyJsonLine(input);

      expect(result.contains('\n'), isFalse);
      expect(result, contains('"a": 1'));
      expect(result, contains('"b": 2'));
    });

    test('should collapse nested object to single line', () {
      final input = '{"a":{"b":{"c":3}}}';
      final result = prettyJsonLine(input);

      expect(result.contains('\n'), isFalse);
      expect(result, contains('"c": 3'));
    });

    test('should preserve spaces between elements', () {
      final input = '{"x":1,"y":2}';
      final result = prettyJsonLine(input);

      // Should have spaces (from newline replacement) between elements
      expect(result, isNot(equals('{"x": 1,"y": 2}')));
    });

    test('should handle empty object', () {
      final result = prettyJsonLine('{}');
      expect(result, equals('{}'));
    });

    test('should throw FormatException for invalid JSON', () {
      expect(
        () => prettyJsonLine('{invalid}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('indentEncoder', () {
    test('should use 2-space indentation', () {
      final data = {
        'nested': {'value': 1},
      };
      final result = indentEncoder.convert(data);

      expect(result, contains('  "nested"'));
      expect(result, contains('    "value"'));
    });

    test('should be reusable for multiple conversions', () {
      final data1 = {'a': 1};
      final data2 = {'b': 2};

      final result1 = indentEncoder.convert(data1);
      final result2 = indentEncoder.convert(data2);

      expect(result1, contains('"a": 1'));
      expect(result2, contains('"b": 2'));
    });
  });

  // ===========================================================================
  // map_merge_and_process.dart tests
  // ===========================================================================

  group('mergeMapsOneSided', () {
    group('basic merging', () {
      test('should merge primitive values from override', () {
        final base = <String, dynamic>{'a': 1, 'b': 2};
        final override = <String, dynamic>{'b': 20, 'c': 3};

        mergeMapsOneSided(base, override);

        expect(base['a'], equals(1));
        expect(base['b'], equals(20));
        expect(base['c'], equals(3));
      });

      test('should add new keys from override', () {
        final base = <String, dynamic>{'existing': 'value'};
        final override = <String, dynamic>{'newKey': 'newValue'};

        mergeMapsOneSided(base, override);

        expect(base['existing'], equals('value'));
        expect(base['newKey'], equals('newValue'));
      });

      test('should override string values', () {
        final base = <String, dynamic>{'host': 'localhost'};
        final override = <String, dynamic>{'host': 'production.com'};

        mergeMapsOneSided(base, override);

        expect(base['host'], equals('production.com'));
      });

      test('should override numeric values', () {
        final base = <String, dynamic>{'port': 8080};
        final override = <String, dynamic>{'port': 443};

        mergeMapsOneSided(base, override);

        expect(base['port'], equals(443));
      });

      test('should override boolean values', () {
        final base = <String, dynamic>{'enabled': false};
        final override = <String, dynamic>{'enabled': true};

        mergeMapsOneSided(base, override);

        expect(base['enabled'], isTrue);
      });
    });

    group('nested map merging', () {
      test('should recursively merge nested maps', () {
        final base = <String, dynamic>{
          'database': <String, Object>{'host': 'localhost', 'port': 5432},
        };
        final override = <String, dynamic>{
          'database': <String, Object>{'host': 'production.db.com'},
        };

        mergeMapsOneSided(base, override);

        expect(base['database']['host'], equals('production.db.com'));
        expect(base['database']['port'], equals(5432));
      });

      test('should merge deeply nested structures', () {
        final base = <String, dynamic>{
          'level1': <String, Object>{
            'level2': <String, Object>{
              'level3': <String, Object>{'a': 1, 'b': 2},
            },
          },
        };
        final override = <String, dynamic>{
          'level1': <String, Object>{
            'level2': <String, Object>{
              'level3': <String, Object>{'b': 20, 'c': 3},
            },
          },
        };

        mergeMapsOneSided(base, override);

        expect(base['level1']['level2']['level3']['a'], equals(1));
        expect(base['level1']['level2']['level3']['b'], equals(20));
        expect(base['level1']['level2']['level3']['c'], equals(3));
      });

      test('should add new nested map from override', () {
        final base = <String, dynamic>{'existing': 'value'};
        final override = <String, dynamic>{
          'newNested': <String, Object>{'key': 'value'},
        };

        mergeMapsOneSided(base, override);

        expect(base['newNested'], isA<Map>());
        expect(base['newNested']['key'], equals('value'));
      });
    });

    group('array merging', () {
      test('should append extra elements from longer override array', () {
        final base = <String, dynamic>{
          'features': ['auth', 'logging'],
        };
        final override = <String, dynamic>{
          'features': ['auth', 'logging', 'metrics'],
        };

        mergeMapsOneSided(base, override);

        final features = base['features'] as List;
        expect(features.length, equals(3));
        expect(features[2], equals('metrics'));
      });

      test('should not truncate base array when override has same length', () {
        // When merging arrays of the same length with maps, all are merged
        final base = <String, dynamic>{
          'items': [
            <String, Object>{'a': 1},
            <String, Object>{'b': 2},
          ],
        };
        final override = <String, dynamic>{
          'items': [
            <String, Object>{'a': 10},
            <String, Object>{'b': 20},
          ],
        };

        mergeMapsOneSided(base, override);

        final items = base['items'] as List;
        expect(items.length, equals(2));
        expect((items[0] as Map)['a'], equals(10));
        expect((items[1] as Map)['b'], equals(20));
      });

      test('should merge maps within arrays', () {
        final base = <String, dynamic>{
          'servers': [
            <String, Object>{'host': 'localhost', 'port': 8080},
            <String, Object>{'host': 'backup', 'port': 8081},
          ],
        };
        final override = <String, dynamic>{
          'servers': [
            <String, Object>{'host': 'production'},
            <String, Object>{'port': 9090},
          ],
        };

        mergeMapsOneSided(base, override);

        final servers = base['servers'] as List;
        expect(servers[0]['host'], equals('production'));
        expect(servers[0]['port'], equals(8080));
        expect(servers[1]['host'], equals('backup'));
        expect(servers[1]['port'], equals(9090));
      });

      test('should add array if base does not have it', () {
        final base = <String, dynamic>{'name': 'config'};
        final override = <String, dynamic>{
          'items': [1, 2, 3],
        };

        mergeMapsOneSided(base, override);

        expect(base['items'], equals([1, 2, 3]));
      });

      test('should not throw when override array is shorter than base', () {
        // The base array has more map elements than the override — a normal
        // "override only the first N" config-layering case. A merge loop
        // driven by the base's length would index overrideMapArray[i] past
        // its end and throw RangeError.
        final base = <String, dynamic>{
          'servers': [
            <String, Object>{'host': 'a', 'port': 1},
            <String, Object>{'host': 'b', 'port': 2},
            <String, Object>{'host': 'c', 'port': 3},
          ],
        };
        final override = <String, dynamic>{
          'servers': [
            <String, Object>{'host': 'A'},
          ],
        };

        expect(() => mergeMapsOneSided(base, override), returnsNormally);

        final servers = base['servers'] as List;
        expect(servers.length, equals(3));
        expect(servers[0]['host'], equals('A')); // merged from override
        expect(servers[0]['port'], equals(1)); // preserved from base
        expect(servers[1]['host'], equals('b')); // untouched (no override)
        expect(servers[2]['host'], equals('c')); // untouched (no override)
      });

      test('a differing scalar element is replaced by the override', () {
        // The most ordinary layering operation there is: change one entry of a
        // string list. The overlap used to keep the base element and only log
        // a warning, so an override that restated a list with different values
        // had no effect at all.
        final base = <String, dynamic>{
          'features': ['auth', 'logging', 'metrics'],
        };
        final override = <String, dynamic>{
          'features': ['oauth', 'tracing'],
        };

        mergeMapsOneSided(base, override);

        // Overlap takes the override; the base tail beyond the override's
        // length is still preserved.
        expect(base['features'], equals(['oauth', 'tracing', 'metrics']));
      });

      test('a longer override replaces the overlap and appends its tail', () {
        // Previously this produced ['a', 'b', 'C'] — base wins at 0-1, override
        // wins at 2 — a blend of two rules that matched neither the documents
        // nor any coherent merge policy.
        final base = <String, dynamic>{
          'f': ['a', 'b'],
        };
        final override = <String, dynamic>{
          'f': ['A', 'B', 'C'],
        };

        mergeMapsOneSided(base, override);

        expect(base['f'], equals(['A', 'B', 'C']));
      });

      test('nested lists merge positionally at every depth', () {
        // "Merged element-by-element" has to hold for a list element that is
        // itself a list, or the rule stops being true one level down.
        final base = <String, dynamic>{
          'matrix': [
            [1, 2],
            [3, 4],
          ],
        };
        final override = <String, dynamic>{
          'matrix': [
            [10],
            [30, 40],
          ],
        };

        mergeMapsOneSided(base, override);

        expect(
          base['matrix'],
          equals([
            [10, 2],
            [30, 40],
          ]),
        );
      });

      test('a scalar override element replaces a base map element', () {
        // Mirrors the top-level rule, where a scalar override replaces
        // whatever the base held, subtree included.
        final base = <String, dynamic>{
          'items': [
            <String, Object>{'a': 1},
          ],
        };
        final override = <String, dynamic>{
          'items': ['plain'],
        };

        mergeMapsOneSided(base, override);

        expect(base['items'], equals(['plain']));
      });

      test('keeps the base element when a map override lands on a scalar', () {
        // Also mirrors the top level, which refuses to merge a subtree into a
        // non-subtree and keeps the base value. Structural mismatches stay
        // refusals; only same-shaped and scalar pairs changed.
        final base = <String, dynamic>{
          'items': ['plain'],
        };
        final override = <String, dynamic>{
          'items': [
            <String, Object>{'a': 1},
          ],
        };

        mergeMapsOneSided(base, override);

        expect(base['items'], equals(['plain']));
      });

      test('a narrowly typed base list accepts an override of another type', () {
        // A Dart list literal is reified at its element type, so `<int>[1, 2]`
        // is a List<int> and cannot hold a String. Writing the override
        // element into the base list in place would throw a TypeError here;
        // the merged list must therefore be freshly allocated as
        // List<dynamic>. Decoded JSON is always List<dynamic>, which is why
        // this only bites callers who hand-build the base map.
        final base = <String, dynamic>{
          'mixed': <int>[1, 2],
        };
        final override = <String, dynamic>{
          'mixed': <String>['one'],
        };

        mergeMapsOneSided(base, override);

        expect(base['mixed'], equals(['one', 2]));
      });
    });

    group('edge cases', () {
      test('should handle empty base map', () {
        final base = <String, dynamic>{};
        final override = <String, dynamic>{'a': 1, 'b': 2};

        mergeMapsOneSided(base, override);

        expect(base['a'], equals(1));
        expect(base['b'], equals(2));
      });

      test('should handle empty override map', () {
        final base = <String, dynamic>{'a': 1, 'b': 2};
        final override = <String, dynamic>{};

        mergeMapsOneSided(base, override);

        expect(base['a'], equals(1));
        expect(base['b'], equals(2));
        expect(base.length, equals(2));
      });

      test('should handle both empty maps', () {
        final base = <String, dynamic>{};
        final override = <String, dynamic>{};

        mergeMapsOneSided(base, override);

        expect(base.isEmpty, isTrue);
      });

      test('should handle null values in override', () {
        final base = <String, dynamic>{'value': 'original'};
        final override = <String, dynamic>{'value': null};

        mergeMapsOneSided(base, override);

        expect(base['value'], isNull);
      });
    });

    group('type-mismatch error branches', () {
      test('keeps base scalar when override tries to merge a map over it', () {
        final base = <String, dynamic>{'x': 5};
        final override = <String, dynamic>{
          'x': <String, dynamic>{'a': 1},
        };

        mergeMapsOneSided(base, override);

        // Cannot merge a subtree into a scalar — base is left unchanged.
        expect(base['x'], equals(5));
      });

      test(
        'keeps base scalar when override tries to merge an array over it',
        () {
          final base = <String, dynamic>{'x': 5};
          final override = <String, dynamic>{
            'x': [1, 2],
          };

          mergeMapsOneSided(base, override);

          // Cannot merge an array into a scalar — base is left unchanged.
          expect(base['x'], equals(5));
        },
      );
    });

    group('decoded JSON inputs', () {
      test('deep-merges nested maps coming from jsonDecode', () {
        final base =
            jsonDecode('{"db":{"host":"localhost","port":5432}}')
                as Map<String, dynamic>;
        final override =
            jsonDecode('{"db":{"host":"prod"}}') as Map<String, dynamic>;

        mergeMapsOneSided(base, override);

        final db = base['db'] as Map;
        expect(db['host'], equals('prod')); // overridden
        // A reified-type guard would reject the decoded Map<String, dynamic>,
        // and the nested base map — 'port' with it — would be discarded by the
        // wholesale-replace fallback.
        expect(db['port'], equals(5432));
      });
    });

    group('override ownership', () {
      // The merge must leave `override` and the merged tree completely
      // independent. Sharing structure between them is action at a distance:
      // an edit to one document silently rewrites the other, long after the
      // merge that connected them.

      test('an inserted map subtree is not shared with the override', () {
        final base = <String, dynamic>{};
        final override = <String, dynamic>{
          'db': {'host': 'h'},
        };

        mergeMapsOneSided(base, override);
        (override['db'] as Map)['host'] = 'MUTATED';

        expect((base['db'] as Map)['host'], equals('h'));
        expect(identical(base['db'], override['db']), isFalse);
      });

      test('an inserted list is not shared with the override', () {
        final base = <String, dynamic>{};
        final override = <String, dynamic>{
          'l': [1, 2],
        };

        mergeMapsOneSided(base, override);
        (override['l'] as List).add(3);

        expect(base['l'], equals([1, 2]));
        expect(identical(base['l'], override['l']), isFalse);
      });

      test('a null-valued base key is filled without sharing', () {
        // `base[key] == null` is the same branch as an absent key, so an
        // explicit null placeholder — the natural way to declare a slot a
        // later layer fills — must not alias either.
        final base = <String, dynamic>{'l': null, 'm': null};
        final override = <String, dynamic>{
          'l': [1],
          'm': {'k': 'v'},
        };

        mergeMapsOneSided(base, override);

        expect(identical(base['l'], override['l']), isFalse);
        expect(identical(base['m'], override['m']), isFalse);
      });

      test('ownership holds at every depth of an inserted subtree', () {
        // A shallow copy would pass the first assertion and fail this one,
        // which is exactly the trap the documented `Map.from` recipe fell
        // into.
        final base = <String, dynamic>{};
        final override = <String, dynamic>{
          'a': {
            'b': {
              'c': [
                {'d': 1},
              ],
            },
          },
        };

        mergeMapsOneSided(base, override);

        final overrideLeaf = ((override['a'] as Map)['b'] as Map)['c'] as List;
        (overrideLeaf[0] as Map)['d'] = 99;

        final baseLeaf = ((base['a'] as Map)['b'] as Map)['c'] as List;
        expect((baseLeaf[0] as Map)['d'], equals(1));
      });

      test('a narrowly typed base subtree accepts an inserted subtree', () {
        // `{'host': 'h'}` is a Map<String, String>, and Dart generics are
        // covariant, so it satisfies `is Map<String, dynamic>` and is merged
        // into — then throws on the first entry of another type. The map
        // counterpart of the reified-list hazard, and reached by the ordinary
        // act of adding a subtree to an existing section.
        final base = <String, dynamic>{
          'db': {'host': 'h'},
        };
        final override = <String, dynamic>{
          'db': {
            'pool': {'max': 10},
          },
        };

        mergeMapsOneSided(base, override);

        final db = base['db'] as Map;
        expect(db['host'], equals('h'));
        expect((db['pool'] as Map)['max'], equals(10));
      });

      test('a subtree added by a recursive merge is not shared', () {
        // The key exists on both sides, so the merge recurses; the sharing
        // then happens one level down, where 'added' is absent from base.
        final base = <String, dynamic>{
          'db': {'host': 'h'},
        };
        final override = <String, dynamic>{
          'db': {
            'added': {'k': 'v'},
          },
        };

        mergeMapsOneSided(base, override);

        final baseDb = base['db'] as Map;
        final overrideDb = override['db'] as Map;
        expect(identical(baseDb['added'], overrideDb['added']), isFalse);
      });

      test('a list tail appended from the override is not shared', () {
        // The tail travels through `sublist`, which copies the list but not
        // the elements, so a structured element in the tail stayed shared.
        final base = <String, dynamic>{
          'l': [
            {'n': 0},
          ],
        };
        final override = <String, dynamic>{
          'l': [
            {'n': 0},
            {'n': 1},
          ],
        };

        mergeMapsOneSided(base, override);

        final baseList = base['l'] as List;
        final overrideList = override['l'] as List;
        expect(identical(baseList[1], overrideList[1]), isFalse);
      });

      test('the merge leaves the override document untouched', () {
        final override = <String, dynamic>{
          'db': {'host': 'h', 'port': 5432},
          'l': [1, 2],
        };
        final before = jsonEncode(override);

        mergeMapsOneSided(<String, dynamic>{'db': {}}, override);

        expect(jsonEncode(override), equals(before));
      });

      test('layering two override documents keeps them independent', () {
        // The flow the module exists for, and where the sharing did real
        // damage: `base` used to hold live references into *both* override
        // documents, so the second merge wrote through into the first.
        final base = <String, dynamic>{};
        final envConfig = <String, dynamic>{
          'db': {'host': 'env-host'},
        };
        final localConfig = <String, dynamic>{
          'db': {'host': 'local-host'},
        };

        mergeMapsOneSided(base, envConfig);
        mergeMapsOneSided(base, localConfig);

        expect((base['db'] as Map)['host'], equals('local-host'));
        // The second merge must not have reached back into the first
        // document through the reference the first merge stored.
        expect((envConfig['db'] as Map)['host'], equals('env-host'));
      });
    });
  });

  group('deepCopyJsonTree', () {
    test('returns an equal tree that shares no map or list', () {
      final source = <String, dynamic>{
        'scalar': 1,
        'map': {'nested': true},
        'list': [
          1,
          {'inner': 'x'},
        ],
      };

      final copy = deepCopyJsonTree(source);

      expect(copy, equals(source));
      expect(identical(copy, source), isFalse);
      expect(identical(copy['map'], source['map']), isFalse);
      expect(identical(copy['list'], source['list']), isFalse);
      expect(
        identical((copy['list'] as List)[1], (source['list'] as List)[1]),
        isFalse,
      );
    });

    test('normalises narrowly reified maps and lists', () {
      // A copy exists to be written into, so it must accept values of any
      // type — a `List<int>` copied as a `List<int>` would throw on the
      // first override that replaced an element with a string.
      final source = <String, dynamic>{
        'm': <String, int>{'a': 1},
        'l': <int>[1, 2],
      };

      final copy = deepCopyJsonTree(source);

      expect(copy['m'], isA<Map<String, dynamic>>());
      expect(copy['l'], isA<List<dynamic>>());
    });

    test('shares scalar leaves, which are immutable in a JSON tree', () {
      final source = <String, dynamic>{'s': 'text', 'n': 42, 'nil': null};

      final copy = deepCopyJsonTree(source);

      expect(copy['s'], equals('text'));
      expect(copy['n'], equals(42));
      expect(copy.containsKey('nil'), isTrue);
      expect(copy['nil'], isNull);
    });
  });

  group('traverseAndProcess', () {
    test('should process matching string values in flat map', () {
      final tree = <String, Object>{'url': r'${BASE}/api', 'name': 'MyApp'};

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${'),
        (s) => s.replaceAll(r'${BASE}', 'https://example.com'),
      );

      expect(tree['url'], equals('https://example.com/api'));
      expect(tree['name'], equals('MyApp'));
    });

    test('should process nested map values', () {
      final tree = <String, Object>{
        'config': <String, Object>{'endpoint': r'${HOST}/v1'},
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${'),
        (s) => s.replaceAll(r'${HOST}', 'api.example.com'),
      );

      expect((tree['config'] as Map)['endpoint'], equals('api.example.com/v1'));
    });

    test('should process string arrays', () {
      final tree = <String, Object>{
        'urls': <String>[r'${BASE}/a', r'${BASE}/b'],
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${'),
        (s) => s.replaceAll(r'${BASE}', 'https://api.com'),
      );

      final urls = tree['urls'] as List<String>;
      expect(urls[0], equals('https://api.com/a'));
      expect(urls[1], equals('https://api.com/b'));
    });

    test('should process map arrays recursively', () {
      final tree = <String, Object>{
        'items': <Map<String, Object>>[
          {'url': r'${BASE}/1'},
          {'url': r'${BASE}/2'},
        ],
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${'),
        (s) => s.replaceAll(r'${BASE}', 'https://test.com'),
      );

      final items = tree['items'] as List<Map<String, Object>>;
      expect(items[0]['url'], equals('https://test.com/1'));
      expect(items[1]['url'], equals('https://test.com/2'));
    });

    test('should not process non-matching strings', () {
      final tree = <String, Object>{'name': 'unchanged', 'value': 'also same'};

      traverseAndProcess(tree, (s) => s.contains(r'${'), (s) => 'REPLACED');

      expect(tree['name'], equals('unchanged'));
      expect(tree['value'], equals('also same'));
    });

    test('should handle empty tree', () {
      final tree = <String, Object>{};

      traverseAndProcess(tree, (s) => true, (s) => 'REPLACED');

      expect(tree.isEmpty, isTrue);
    });

    test('should handle deeply nested structures', () {
      final tree = <String, Object>{
        'a': <String, Object>{
          'b': <String, Object>{
            'c': <String, Object>{'d': r'${VAR}'},
          },
        },
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${'),
        (s) => s.replaceAll(r'${VAR}', 'resolved'),
      );

      expect(
        (((tree['a'] as Map)['b'] as Map)['c'] as Map)['d'],
        equals('resolved'),
      );
    });

    test('descends into maps and lists coming from jsonDecode', () {
      final tree =
          jsonDecode(r'{"a":{"b":"${X}"},"list":["${X}",{"c":"${X}"}]}')
              as Map<String, dynamic>;

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${X}'),
        (s) => s.replaceAll(r'${X}', 'Y'),
      );

      // Reified-type guards would reject the decoded Map<String, dynamic> /
      // List<dynamic>, and traversal would never descend.
      expect((tree['a'] as Map)['b'], equals('Y'));
      expect((tree['list'] as List)[0], equals('Y'));
      expect(((tree['list'] as List)[1] as Map)['c'], equals('Y'));
    });

    group('nested lists', () {
      // A list inside a list is ordinary JSON — a matrix, a list of coordinate
      // pairs, a list of tag groups. Per-element dispatch must recurse into a
      // List element as well as handling a map and a string one — otherwise
      // only the outermost array is ever reached.

      test('descends into a list nested inside a list', () {
        final tree = <String, dynamic>{
          'outer': <dynamic>[
            <dynamic>[r'${X}'],
            r'${X}',
          ],
        };

        traverseAndProcess(
          tree,
          (s) => s.contains(r'${X}'),
          (s) => s.replaceAll(r'${X}', 'Y'),
        );

        final outer = tree['outer'] as List;
        expect((outer[0] as List)[0], equals('Y'));
        expect(outer[1], equals('Y'));
      });

      test('descends through several list levels', () {
        final tree = <String, dynamic>{
          'matrix': <dynamic>[
            <dynamic>[
              <dynamic>[r'${X}'],
            ],
          ],
        };

        traverseAndProcess(
          tree,
          (s) => s.contains(r'${X}'),
          (s) => s.replaceAll(r'${X}', 'Y'),
        );

        final level1 = (tree['matrix'] as List)[0] as List;
        expect((level1[0] as List)[0], equals('Y'));
      });

      test('reaches a map held inside a nested list', () {
        final tree = <String, dynamic>{
          'groups': <dynamic>[
            <dynamic>[
              <String, dynamic>{'url': r'${X}/api'},
            ],
          ],
        };

        traverseAndProcess(
          tree,
          (s) => s.contains(r'${X}'),
          (s) => s.replaceAll(r'${X}', 'https://h'),
        );

        final inner = (tree['groups'] as List)[0] as List;
        expect((inner[0] as Map)['url'], equals('https://h/api'));
      });

      test(r'resolves ${VAR} inside a nested decoded array', () {
        // The shape the completion doc's claim is really about: configuration
        // read from a JSON file, whose arrays are `List<dynamic>` throughout.
        final tree =
            jsonDecode(r'{"m":[["${A}"],"${A}"]}') as Map<String, dynamic>;

        substituteEnvVars(tree, <String, String>{'A': 'ok'});

        final m = tree['m'] as List;
        expect((m[0] as List)[0], equals('ok'));
        expect(m[1], equals('ok'));
      });
    });
  });

  group('substituteEnvVars', () {
    test('substitutes a present environment variable', () {
      final tree = <String, dynamic>{'host': r'${DB_HOST}'};

      substituteEnvVars(tree, {'DB_HOST': 'prod.db'});

      expect(tree['host'], equals('prod.db'));
    });

    test('uses the default value when the variable is absent', () {
      final tree = <String, dynamic>{'host': r'${DB_HOST:localhost}'};

      substituteEnvVars(tree, {});

      expect(tree['host'], equals('localhost'));
    });

    test('uses the default value when the variable is set but empty', () {
      final tree = <String, dynamic>{'host': r'${DB_HOST:localhost}'};

      substituteEnvVars(tree, {'DB_HOST': ''});

      expect(tree['host'], equals('localhost'));
    });

    group('an empty environment value counts as unset', () {
      // `${VAR:default}` is the colon form, and follows the shell's `:-`
      // convention: an empty value is treated the same as an unset one. The
      // three tests below pin all three arms of that rule, so a future change
      // to the `isNotEmpty` guard cannot pass unnoticed.

      test('the placeholder survives when the value is empty and there '
          'is no default', () {
        final tree = <String, dynamic>{'host': r'${DB_HOST}'};

        substituteEnvVars(tree, {'DB_HOST': ''});

        // Not the empty string: `{'DB_HOST': ''}` is indistinguishable from
        // DB_HOST being absent, so this is the no-value-no-default arm and the
        // placeholder is left visible.
        expect(tree['host'], equals(r'${DB_HOST}'));
      });

      test('an empty default is honoured', () {
        // The counterpart that makes the rule look asymmetric until the shell
        // convention is named: an empty *default* is a default that happens to
        // be empty and resolves, while an empty *value* does not.
        final tree = <String, dynamic>{'host': r'${DB_HOST:}'};

        substituteEnvVars(tree, {});

        expect(tree['host'], equals(''));
      });

      test('an empty value with an empty default resolves to empty', () {
        final tree = <String, dynamic>{'host': r'${DB_HOST:}'};

        substituteEnvVars(tree, {'DB_HOST': ''});

        expect(tree['host'], equals(''));
      });
    });

    test('leaves the placeholder when absent with no default', () {
      final tree = <String, dynamic>{'host': r'${DB_HOST}'};

      substituteEnvVars(tree, {});

      expect(tree['host'], equals(r'${DB_HOST}'));
    });

    test('resolves multiple placeholders within a single string', () {
      final tree = <String, dynamic>{'pair': r'${A}-${B}'};

      substituteEnvVars(tree, {'A': '1', 'B': '2'});

      expect(tree['pair'], equals('1-2'));
    });

    test('substitutes within nested maps', () {
      final tree = <String, dynamic>{
        'db': <String, dynamic>{'host': r'${H}'},
      };

      substituteEnvVars(tree, {'H': 'x'});

      expect((tree['db'] as Map)['host'], equals('x'));
    });

    test('substitutes within string lists', () {
      final tree = <String, dynamic>{
        'urls': <String>[r'${A}/1', r'${A}/2'],
      };

      substituteEnvVars(tree, {'A': 'host'});

      expect(tree['urls'], equals(['host/1', 'host/2']));
    });

    test('substitutes inside decoded JSON config', () {
      final tree =
          jsonDecode(r'{"server":{"url":"${BASE}/api"},"tags":["${BASE}/x"]}')
              as Map<String, dynamic>;

      substituteEnvVars(tree, {'BASE': 'https://h'});

      expect((tree['server'] as Map)['url'], equals('https://h/api'));
      expect((tree['tags'] as List)[0], equals('https://h/x'));
    });
  });

  group('traverseAndCreate', () {
    test('should call creator for matching key names', () {
      final tree = <String, dynamic>{'special@key': 'value', 'normal': 'data'};
      final createdKeys = <String>[];

      traverseAndCreate(tree, (name) => name.contains('@'), (
        key,
        value,
        location,
      ) {
        createdKeys.add(key);
      });

      expect(createdKeys, contains('special@key'));
      expect(createdKeys.length, equals(1));
    });

    test('should traverse nested maps', () {
      final tree = <String, dynamic>{
        'outer': <String, dynamic>{'inner@key': 'value'},
      };
      final foundKeys = <String>[];

      traverseAndCreate(tree, (name) => name.contains('@'), (
        key,
        value,
        location,
      ) {
        foundKeys.add(key);
      });

      expect(foundKeys, contains('inner@key'));
    });

    test('should traverse map arrays', () {
      final tree = <String, dynamic>{
        'items': <Map<String, dynamic>>[
          {'item@1': 'value1'},
          {'item@2': 'value2'},
        ],
      };
      final foundKeys = <String>[];

      traverseAndCreate(tree, (name) => name.contains('@'), (
        key,
        value,
        location,
      ) {
        foundKeys.add(key);
      });

      expect(foundKeys, contains('item@1'));
      expect(foundKeys, contains('item@2'));
    });

    test('should pass location map to creator for potential modification', () {
      final tree = <String, dynamic>{'ref@pattern': 'targetValue'};
      Map<String, dynamic>? capturedLocation;

      traverseAndCreate(tree, (name) => name.contains('@'), (
        key,
        value,
        location,
      ) {
        capturedLocation = location;
      });

      expect(capturedLocation, isNotNull);
      expect(capturedLocation, same(tree));
    });

    test('should only match string values', () {
      final tree = <String, dynamic>{
        'string@key': 'stringValue',
        'map@key': <String, dynamic>{'nested': 'value'},
        'num@key': 123,
      };
      final foundKeys = <String>[];

      traverseAndCreate(tree, (name) => name.contains('@'), (
        key,
        value,
        location,
      ) {
        foundKeys.add(key);
      });

      expect(foundKeys, equals(['string@key']));
    });

    group('the creator can insert', () {
      test('an insert into the location map succeeds', () {
        final tree = <String, dynamic>{'ref@pattern': 'targetValue'};

        traverseAndCreate(tree, (name) => name.contains('@'), (
          key,
          value,
          location,
        ) {
          location['resolved'] = value.toUpperCase();
        });

        expect(tree['resolved'], equals('TARGETVALUE'));
        expect(tree['ref@pattern'], equals('targetValue'));
      });

      test('a key inserted by the creator is not itself traversed', () {
        // The walk iterates a snapshot, so an inserted key is not revisited.
        // Without that, a creator inserting a key its own nameTest matches
        // would call itself forever.
        final tree = <String, dynamic>{'seed@key': 'v'};
        var calls = 0;

        traverseAndCreate(tree, (name) => name.contains('@'), (
          key,
          value,
          location,
        ) {
          calls++;
          location['spawned@$calls'] = 'v';
        });

        expect(calls, equals(1));
        expect(tree.containsKey('spawned@1'), isTrue);
      });

      test('an insert into a nested location succeeds', () {
        final tree = <String, dynamic>{
          'outer': <String, dynamic>{'inner@key': 'v'},
        };

        traverseAndCreate(tree, (name) => name.contains('@'), (
          key,
          value,
          location,
        ) {
          location['added'] = 1;
        });

        expect((tree['outer'] as Map<String, dynamic>)['added'], equals(1));
      });

      test('an insert into a map inside a list succeeds', () {
        final tree = <String, dynamic>{
          'items': <Map<String, dynamic>>[
            {'item@1': 'a'},
            {'item@2': 'b'},
          ],
        };

        traverseAndCreate(tree, (name) => name.contains('@'), (
          key,
          value,
          location,
        ) {
          location['added'] = value;
        });

        final items = tree['items'] as List<Map<String, dynamic>>;
        expect(items[0]['added'], equals('a'));
        expect(items[1]['added'], equals('b'));
      });

      test('the creator can remove the key it was called for', () {
        // A snapshot key whose entry has since gone reads back as null, which
        // matches no branch — so removal is as safe as insertion.
        final tree = <String, dynamic>{'drop@me': 'v', 'keep@me': 'v'};

        traverseAndCreate(tree, (name) => name.startsWith('drop'), (
          key,
          value,
          location,
        ) {
          location.remove(key);
        });

        expect(tree.containsKey('drop@me'), isFalse);
        expect(tree.containsKey('keep@me'), isTrue);
      });

      test('an insert into an ancestor map during a subtree walk succeeds', () {
        // The creator holds a reference to the root, which the outer recursion
        // level is itself walking. Every level snapshots, so this is safe too.
        final tree = <String, dynamic>{
          'a': 'plain',
          'outer': <String, dynamic>{'inner@key': 'v'},
        };

        traverseAndCreate(tree, (name) => name.contains('@'), (
          key,
          value,
          location,
        ) {
          tree['fromNested'] = key;
        });

        expect(tree['fromNested'], equals('inner@key'));
      });
    });
  });

  group('getPathFromTree', () {
    test('should get value at single level path', () {
      final tree = <String, dynamic>{
        'settings': <String, dynamic>{'theme': 'dark'},
      };

      final result = getPathFromTree(tree, 'settings', 'result');

      expect(result['theme'], equals('dark'));
    });

    test('should get value at multi-level path', () {
      final tree = <String, dynamic>{
        'db': <String, dynamic>{
          'connection': <String, dynamic>{
            'pool': <String, dynamic>{'size': 10},
          },
        },
      };

      final result = getPathFromTree(tree, 'db.connection.pool', 'result');

      expect(result['size'], equals(10));
    });

    test('should wrap non-map terminal value', () {
      final tree = <String, dynamic>{
        'config': <String, dynamic>{'port': 8080},
      };

      final result = getPathFromTree(tree, 'config.port', 'portValue');

      expect(result['portValue'], equals(8080));
    });

    test('should throw for non-existent path', () {
      final tree = <String, dynamic>{
        'a': <String, dynamic>{'b': 'value'},
      };

      expect(
        () => getPathFromTree(tree, 'a.missing', 'result'),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw for path through non-map', () {
      final tree = <String, dynamic>{'value': 'string'};

      expect(
        () => getPathFromTree(tree, 'value.nested', 'result'),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle single segment path returning map', () {
      final tree = <String, dynamic>{
        'data': <String, dynamic>{'x': 1, 'y': 2},
      };

      final result = getPathFromTree(tree, 'data', 'result');

      expect(result['x'], equals(1));
      expect(result['y'], equals(2));
    });

    group('present-but-null values', () {
      test('a terminal null is wrapped like any other non-map value', () {
        // null is a non-map terminal, so it takes the documented wrapping rule
        // rather than a special case of its own.
        final tree = <String, dynamic>{'cleared': null};

        final result = getPathFromTree(tree, 'cleared', 'result');

        expect(result, equals(<String, dynamic>{'result': null}));
      });

      test('the wrapper records the key as present', () {
        // containsKey is what separates this from an absent path, which throws.
        final tree = <String, dynamic>{
          'db': <String, dynamic>{'replica': null},
        };

        final result = getPathFromTree(tree, 'db.replica', 'replica');

        expect(result.containsKey('replica'), isTrue);
        expect(result['replica'], isNull);
      });

      test('an absent path still throws', () {
        final tree = <String, dynamic>{'cleared': null};

        expect(
          () => getPathFromTree(tree, 'absent', 'result'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('getObjectFromTree', () {
    test('should get map at path', () {
      final tree = <String, dynamic>{
        'settings': <String, dynamic>{'option': 'value'},
      };

      final result = getObjectFromTree(tree, 'settings');

      expect(result, isA<Map>());
      expect((result as Map)['option'], equals('value'));
    });

    test('should get primitive value at path', () {
      final tree = <String, dynamic>{
        'config': <String, dynamic>{'port': 8080},
      };

      final result = getObjectFromTree(tree, 'config.port');

      expect(result, equals(8080));
    });

    test('should get string value at path', () {
      final tree = <String, dynamic>{
        'app': <String, dynamic>{'name': 'MyApp'},
      };

      final result = getObjectFromTree(tree, 'app.name');

      expect(result, equals('MyApp'));
    });

    test('should get boolean value at path', () {
      final tree = <String, dynamic>{
        'features': <String, dynamic>{'enabled': true},
      };

      final result = getObjectFromTree(tree, 'features.enabled');

      expect(result, isTrue);
    });

    test('should get list at path', () {
      final tree = <String, dynamic>{
        'data': <String, dynamic>{
          'items': [1, 2, 3],
        },
      };

      final result = getObjectFromTree(tree, 'data.items');

      expect(result, isA<List>());
      expect(result, equals([1, 2, 3]));
    });

    test('should throw for non-existent key', () {
      final tree = <String, dynamic>{'a': 'value'};

      expect(
        () => getObjectFromTree(tree, 'missing'),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw for path through primitive', () {
      final tree = <String, dynamic>{'value': 123};

      expect(
        () => getObjectFromTree(tree, 'value.nested'),
        throwsA(isA<Exception>()),
      );
    });

    test('should get deeply nested value', () {
      final tree = <String, dynamic>{
        'l1': <String, dynamic>{
          'l2': <String, dynamic>{
            'l3': <String, dynamic>{
              'l4': <String, dynamic>{'value': 'deep'},
            },
          },
        },
      };

      final result = getObjectFromTree(tree, 'l1.l2.l3.l4.value');

      expect(result, equals('deep'));
    });

    group('the walk always terminates inside itself', () {
      // The function used to end with a trailing `throw Exception("...
      // IllegalState detected. This is an anomaly.")` guarding a fall-through
      // that cannot happen. These pin the two shapes where the interior loop
      // body never runs at all, which is the region that trailing throw
      // nominally covered: every path still leaves through a return or a
      // throw that names the segment and its position.

      test('a single-segment path skips the interior loop entirely', () {
        // pathParts.length - 1 == 0, so the loop body never executes and the
        // terminal read after it is the only thing that runs.
        final tree = <String, dynamic>{'only': 'value'};

        expect(getObjectFromTree(tree, 'only'), equals('value'));
      });

      test(
        'an empty path throws a segment-naming exception, not an anomaly',
        () {
          // ''.split('.') is [''] — one segment, not zero — so the loop is
          // skipped and the terminal read reports the missing key by position.
          final tree = <String, dynamic>{'a': 1};

          expect(
            () => getObjectFromTree(tree, ''),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                allOf(contains('position 0'), isNot(contains('anomaly'))),
              ),
            ),
          );
        },
      );
    });

    group('present-but-null values', () {
      // A deliberate null is a value, not an absence — the position
      // makeCleanJsonMap already takes. The path reader used to collapse the
      // distinction the sanitiser exists to protect, in the same file.

      test('a terminal null is returned, not reported as missing', () {
        final tree = <String, dynamic>{'cleared': null};

        expect(getObjectFromTree(tree, 'cleared'), isNull);
      });

      test('a nested terminal null is returned', () {
        final tree = <String, dynamic>{
          'db': <String, dynamic>{'host': 'h', 'replica': null},
        };

        expect(getObjectFromTree(tree, 'db.replica'), isNull);
      });

      test('an absent key still throws', () {
        final tree = <String, dynamic>{'cleared': null};

        expect(
          () => getObjectFromTree(tree, 'absent'),
          throwsA(isA<Exception>()),
        );
      });

      test('a null and an absent key are told apart', () {
        // The whole point: before, both produced the same sentence differing
        // only in the key name, so a caller could not distinguish them by
        // anything but re-reading the tree it had just asked about.
        final tree = <String, dynamic>{'cleared': null};

        expect(getObjectFromTree(tree, 'cleared'), isNull);
        expect(
          () => getObjectFromTree(tree, 'absent'),
          throwsA(isA<Exception>()),
        );
      });

      test('a null cannot be walked through', () {
        // Distinct from a terminal null: there is no subtree to descend into,
        // so the path genuinely does not resolve.
        final tree = <String, dynamic>{'db': null};

        expect(
          () => getObjectFromTree(tree, 'db.host'),
          throwsA(isA<Exception>()),
        );
      });

      test('an interior null reports that it stopped at the null', () {
        final tree = <String, dynamic>{'db': null};

        expect(
          () => getObjectFromTree(tree, 'db.host'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('holds null'),
            ),
          ),
        );
      });

      test('an absent interior key reports that it is absent', () {
        final tree = <String, dynamic>{'other': 1};

        expect(
          () => getObjectFromTree(tree, 'db.host'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('no key'),
            ),
          ),
        );
      });
    });
  });

  group('processTree', () {
    test('should resolve profile-based references', () {
      final tree = <String, dynamic>{'config@profiles.db@production': '@'};

      processTree(tree, (keyName, path, profileName) {
        expect(keyName, equals('config'));
        expect(path, equals('profiles.db'));
        expect(profileName, equals('production'));
        return <String, dynamic>{'config': 'resolved_value'};
      });

      expect(tree['config'], equals('resolved_value'));
    });

    test('should spread values with ... directive', () {
      final tree = <String, dynamic>{'spread@source.data@profile': '...'};

      processTree(tree, (keyName, path, profileName) {
        return <String, dynamic>{'newKey1': 'value1', 'newKey2': 'value2'};
      });

      expect(tree['newKey1'], equals('value1'));
      expect(tree['newKey2'], equals('value2'));
    });

    test('should not overwrite existing keys with spread', () {
      final tree = <String, dynamic>{
        'existingKey': 'original',
        'spread@source@profile': '...',
      };

      processTree(tree, (keyName, path, profileName) {
        return <String, dynamic>{
          'existingKey': 'should_not_replace',
          'newKey': 'new_value',
        };
      });

      expect(tree['existingKey'], equals('original'));
      expect(tree['newKey'], equals('new_value'));
    });

    test('should replace with entire tree for other directives', () {
      final tree = <String, dynamic>{'data@source@profile': 'replace'};

      processTree(tree, (keyName, path, profileName) {
        return <String, dynamic>{
          'nested': <String, dynamic>{'value': 123},
        };
      });

      expect(tree['data'], isA<Map>());
      expect((tree['data'] as Map)['nested'], isA<Map>());
    });

    test('should process nested references', () {
      final tree = <String, dynamic>{
        'outer': <String, dynamic>{'ref@path@profile': '@'},
      };

      processTree(tree, (keyName, path, profileName) {
        return <String, dynamic>{'ref': 'nested_resolved'};
      });

      expect((tree['outer'] as Map)['ref'], equals('nested_resolved'));
    });

    test('should handle multiple references', () {
      final tree = <String, dynamic>{
        'first@path1@profile1': '@',
        'second@path2@profile2': '@',
      };

      int callCount = 0;
      processTree(tree, (keyName, path, profileName) {
        callCount++;
        return <String, dynamic>{keyName: 'resolved_$callCount'};
      });

      expect(callCount, equals(2));
      expect(tree.containsKey('first') || tree.containsKey('second'), isTrue);
    });

    test('should not match keys without @ pattern', () {
      final tree = <String, dynamic>{
        'normalKey': 'normalValue',
        'anotherKey': 'anotherValue',
      };

      int callCount = 0;
      processTree(tree, (keyName, path, profileName) {
        callCount++;
        return <String, dynamic>{};
      });

      expect(callCount, equals(0));
    });

    group('a key that is not exactly three parts', () {
      test('rejects a four-part key instead of using its first three', () {
        final tree = <String, dynamic>{'a@b@c@d': 'replace'};

        expect(
          () => processTree(
            tree,
            (keyName, path, profileName) => <String, dynamic>{'x': 1},
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('a@b@c@d'),
            ),
          ),
        );
      });

      test('does not resolve a four-part key against a truncated path', () {
        final tree = <String, dynamic>{'a@b@c@d': 'replace'};
        final calls = <String>[];

        expect(
          () => processTree(tree, (keyName, path, profileName) {
            calls.add('$keyName|$path|$profileName');
            return <String, dynamic>{'x': 1};
          }),
          throwsA(isA<Exception>()),
        );

        expect(calls, isEmpty);
        expect(tree.containsKey('a'), isFalse);
        expect(tree.keys, equals(['a@b@c@d']));
      });

      test('rejects a leading empty part rather than dropping it', () {
        final tree = <String, dynamic>{'@a@b@c': 'replace'};

        expect(
          () => processTree(
            tree,
            (keyName, path, profileName) => <String, dynamic>{'x': 1},
          ),
          throwsA(isA<Exception>()),
        );
        expect(tree.containsKey('a'), isFalse);
      });

      test('leaves an email-shaped key alone', () {
        final tree = <String, dynamic>{'user@example.com': 'v'};
        int callCount = 0;

        processTree(tree, (keyName, path, profileName) {
          callCount++;
          return <String, dynamic>{'x': 1};
        });

        expect(callCount, equals(0));
        expect(tree, equals({'user@example.com': 'v'}));
      });

      test('leaves a two-part key with an empty segment alone', () {
        final tree = <String, dynamic>{'a@@c': 'v', '@b@c': 'v', 'a@b@': 'v'};
        int callCount = 0;

        processTree(tree, (keyName, path, profileName) {
          callCount++;
          return <String, dynamic>{'x': 1};
        });

        expect(callCount, equals(0));
        expect(tree.length, equals(3));
      });

      test('leaves a serialized zoned value alone as a key', () {
        // The timezoned module writes `@D@<iso>_<offset>_<zone>`, which has two
        // '@' and so is an ordinary key, not a mistyped directive.
        final tree = <String, dynamic>{
          '@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo': 'v',
        };
        int callCount = 0;

        processTree(tree, (keyName, path, profileName) {
          callCount++;
          return <String, dynamic>{'x': 1};
        });

        expect(callCount, equals(0));
        expect(tree.length, equals(1));
      });
    });

    group('the "@" directive without the key', () {
      test('reports a missing key as an Exception, not a TypeError', () {
        final tree = <String, dynamic>{'wanted@some.path@prod': '@'};

        expect(
          () => processTree(
            tree,
            (keyName, path, profileName) => <String, dynamic>{'other': 1},
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('names the key, the path, the profile and what came back', () {
        final tree = <String, dynamic>{'wanted@some.path@prod': '@'};

        expect(
          () => processTree(
            tree,
            (keyName, path, profileName) => <String, dynamic>{
              'other': 1,
              'another': 2,
            },
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('wanted'),
                contains('some.path'),
                contains('prod'),
                contains('other'),
                contains('another'),
              ),
            ),
          ),
        );
      });

      test('says the provider returned nothing when the map is empty', () {
        final tree = <String, dynamic>{'wanted@some.path@prod': '@'};

        expect(
          () => processTree(
            tree,
            (keyName, path, profileName) => <String, dynamic>{},
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('no keys'),
            ),
          ),
        );
      });

      test('leaves the tree untouched when the key is missing', () {
        final tree = <String, dynamic>{
          'wanted@some.path@prod': '@',
          'untouched': 'kept',
        };

        expect(
          () => processTree(
            tree,
            (keyName, path, profileName) => <String, dynamic>{'other': 1},
          ),
          throwsA(isA<Exception>()),
        );
        expect(tree['untouched'], equals('kept'));
        expect(tree.containsKey('wanted'), isFalse);
      });

      test('assigns a key that is present and null rather than throwing', () {
        final tree = <String, dynamic>{'wanted@some.path@prod': '@'};

        processTree(
          tree,
          (keyName, path, profileName) => <String, dynamic>{'wanted': null},
        );

        expect(tree.containsKey('wanted'), isTrue);
        expect(tree['wanted'], isNull);
      });
    });

    group('a failing provider', () {
      // processTree used to catch everything the provider threw and re-throw a
      // bare `Exception` whose message interpolated the original object and its
      // stack trace. That destroyed the type the caller would have caught on,
      // and reduced the frames to text inside a single-line string. The
      // provider's failure is now the caller's own failure, unaltered.

      test("a provider's own exception type survives processTree", () {
        final tree = <String, dynamic>{'db@profiles@prod': '@'};

        expect(
          () => processTree(tree, (keyName, path, profileName) {
            throw const _ProviderUnavailable('vault is sealed');
          }),
          throwsA(isA<_ProviderUnavailable>()),
        );
      });

      test('an Error is not laundered into an Exception', () {
        // The old catch was on `Object`, so an ArgumentError — which is an
        // Error, not an Exception — came back out as an Exception. Callers
        // distinguishing bugs from failures were told every bug was a failure.
        final tree = <String, dynamic>{'db@profiles@prod': '@'};

        expect(
          () => processTree(tree, (keyName, path, profileName) {
            throw ArgumentError.value(profileName, 'profileName', 'unknown');
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('the provider message is delivered whole, not embedded', () {
        final tree = <String, dynamic>{'db@profiles@prod': '@'};

        expect(
          () => processTree(tree, (keyName, path, profileName) {
            throw const _ProviderUnavailable('vault is sealed');
          }),
          throwsA(
            isA<_ProviderUnavailable>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('vault is sealed'),
                isNot(contains('Failed to get tree modification')),
                isNot(contains('stacktrace')),
              ),
            ),
          ),
        );
      });

      test('the stack trace stays a stack trace and names the provider', () {
        final tree = <String, dynamic>{'db@profiles@prod': '@'};
        StackTrace? caught;

        try {
          processTree(tree, (keyName, path, profileName) {
            throw const _ProviderUnavailable('vault is sealed');
          });
        } on _ProviderUnavailable catch (_, stack) {
          caught = stack;
        }

        // The frames are structured data the caller can walk, not characters
        // in someone else's message. The throwing closure is the top frame.
        expect(caught, isNotNull);
        expect(caught.toString(), contains('json_test.dart'));
      });

      test('a resolution failure inside the provider keeps its own type', () {
        // The documented provider shape resolves through getObjectFromTree,
        // whose exception names the segment and its position. That message is
        // the actionable one, so it must be what reaches the caller.
        final profiles = <String, dynamic>{
          'profiles': <String, dynamic>{'dev': 1},
        };
        final tree = <String, dynamic>{'db@profiles@prod': '@'};

        expect(
          () => processTree(
            tree,
            (keyName, path, profileName) =>
                getObjectFromTree(profiles, '$path.$profileName')
                    as Map<String, dynamic>,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('prod'),
                contains('position 1'),
                // Interpolating the original into a wrapper would satisfy the
                // two above while still burying it, so the discriminating
                // assertion is that nothing was wrapped around it at all.
                isNot(contains('Failed to get tree modification')),
              ),
            ),
          ),
        );
      });

      test('the tree is untouched when a later provider call throws', () {
        // Collect-before-apply still holds: the first directive resolved
        // successfully, but nothing is written because the second failed.
        final tree = <String, dynamic>{
          'first@profiles@prod': '@',
          'second@profiles@prod': '@',
          'untouched': 'kept',
        };

        expect(
          () => processTree(tree, (keyName, path, profileName) {
            if (keyName == 'second') {
              throw const _ProviderUnavailable('vault is sealed');
            }
            return <String, dynamic>{keyName: 'resolved'};
          }),
          throwsA(isA<_ProviderUnavailable>()),
        );

        expect(tree.containsKey('first'), isFalse);
        expect(tree['untouched'], equals('kept'));
      });
    });
  });

  group('makeCleanJsonMap', () {
    group('valid JSON types', () {
      test('should preserve string values', () {
        final dirty = {'name': 'Test', 'description': 'A test'};
        final clean = makeCleanJsonMap(dirty);

        expect(clean['name'], equals('Test'));
        expect(clean['description'], equals('A test'));
      });

      test('should preserve integer values', () {
        final dirty = {'count': 42, 'port': 8080};
        final clean = makeCleanJsonMap(dirty);

        expect(clean['count'], equals(42));
        expect(clean['port'], equals(8080));
      });

      test('should preserve double values', () {
        final dirty = {'price': 19.99, 'rate': 0.5};
        final clean = makeCleanJsonMap(dirty);

        expect(clean['price'], equals(19.99));
        expect(clean['rate'], equals(0.5));
      });

      test('should preserve boolean values', () {
        final dirty = {'enabled': true, 'disabled': false};
        final clean = makeCleanJsonMap(dirty);

        expect(clean['enabled'], isTrue);
        expect(clean['disabled'], isFalse);
      });
    });

    group('nested structures', () {
      test('should clean nested maps recursively', () {
        final dirty = {
          'outer': {
            'inner': {'value': 'deep'},
          },
        };
        final clean = makeCleanJsonMap(dirty);

        expect(
          ((clean['outer'] as Map)['inner'] as Map)['value'],
          equals('deep'),
        );
      });

      test('should clean lists', () {
        final dirty = {
          'items': [1, 2, 3],
        };
        final clean = makeCleanJsonMap(dirty);

        expect(clean['items'], equals([1, 2, 3]));
      });

      test('should clean lists containing maps', () {
        final dirty = {
          'users': [
            {'name': 'Alice'},
            {'name': 'Bob'},
          ],
        };
        final clean = makeCleanJsonMap(dirty);

        final users = clean['users'] as List;
        expect((users[0] as Map)['name'], equals('Alice'));
        expect((users[1] as Map)['name'], equals('Bob'));
      });

      test('should clean nested lists', () {
        final dirty = {
          'matrix': [
            [1, 2],
            [3, 4],
          ],
        };
        final clean = makeCleanJsonMap(dirty);

        final matrix = clean['matrix'] as List;
        expect(matrix[0], equals([1, 2]));
        expect(matrix[1], equals([3, 4]));
      });
    });

    group('filtering non-JSON types', () {
      test('should filter out DateTime values', () {
        final dirty = {'name': 'Test', 'created': DateTime(2024, 1, 1)};
        final clean = makeCleanJsonMap(dirty);

        expect(clean['name'], equals('Test'));
        expect(clean.containsKey('created'), isFalse);
      });

      test('should filter out custom objects', () {
        final dirty = {'valid': 'value', 'invalid': Object()};
        final clean = makeCleanJsonMap(dirty);

        expect(clean['valid'], equals('value'));
        expect(clean.containsKey('invalid'), isFalse);
      });

      test('should filter non-JSON types from lists', () {
        final dirty = {
          'mixed': [1, 'text', DateTime(2024, 1, 1), true],
        };
        final clean = makeCleanJsonMap(dirty);

        final mixed = clean['mixed'] as List;
        expect(mixed, contains(1));
        expect(mixed, contains('text'));
        expect(mixed, contains(true));
        expect(mixed.length, equals(3));
      });

      test('should filter entries with non-string keys', () {
        final dirty = <Object, Object>{
          'stringKey': 'value1',
          123: 'value2',
          true: 'value3',
        };
        final clean = makeCleanJsonMap(dirty);

        expect(clean['stringKey'], equals('value1'));
        expect(clean.length, equals(1));
      });
    });

    // `null` is a JSON value, and an absent field and a field that is present
    // and null mean different things to a PATCH-style update, a settings map
    // where null means "explicitly cleared", or a DTO whose schema declares
    // the field nullable. These assert the sanitiser keeps that distinction
    // while still dropping what it genuinely cannot encode.
    group('null values', () {
      test('should preserve a deliberate null value', () {
        final dirty = {'name': 'Test', 'discount': null};
        final clean = makeCleanJsonMap(dirty);

        expect(clean.containsKey('discount'), isTrue);
        expect(clean['discount'], isNull);
      });

      test('should preserve a null nested in a sub-map', () {
        final dirty = {
          'outer': {'inner': null, 'kept': 1},
        };
        final clean = makeCleanJsonMap(dirty);

        final outer = clean['outer'] as Map;
        expect(outer.containsKey('inner'), isTrue);
        expect(outer['inner'], isNull);
        expect(outer['kept'], equals(1));
      });

      test('should preserve nulls inside lists', () {
        final dirty = {
          'items': [1, null, 2],
        };
        final clean = makeCleanJsonMap(dirty);

        final items = clean['items'] as List;
        expect(items.length, equals(3));
        expect(items, equals([1, null, 2]));
      });

      // The interface promises a type can describe its own state, and its
      // dartdoc explicitly allows nulls; the sanitiser must not edit that
      // description on the way through.
      test('should preserve nulls reported by a serializable', () {
        final dirty = {'nullable': _NullableSerializable(null)};
        final clean = makeCleanJsonMap(dirty);

        final nullable = clean['nullable'] as Map;
        expect(nullable.containsKey('value'), isTrue);
        expect(nullable['value'], isNull);
      });

      // The point of the change: null and not-encodable were the same signal,
      // and must not be again.
      test('should keep dropping non-encodable values beside a null', () {
        final dirty = {'cleared': null, 'dropped': DateTime(2024, 1, 1)};
        final clean = makeCleanJsonMap(dirty);

        expect(clean.containsKey('cleared'), isTrue);
        expect(clean['cleared'], isNull);
        expect(clean.containsKey('dropped'), isFalse);
      });

      test('should drop non-encodable list entries but keep null ones', () {
        final dirty = {
          'mixed': [1, null, DateTime(2024, 1, 1), 'text'],
        };
        final clean = makeCleanJsonMap(dirty);

        expect(clean['mixed'], equals([1, null, 'text']));
      });

      test('should produce output that jsonEncode accepts with nulls', () {
        final dirty = {'cleared': null, 'kept': 'value'};
        final clean = makeCleanJsonMap(dirty);

        final decoded = jsonDecode(jsonEncode(clean)) as Map<String, dynamic>;
        expect(decoded.containsKey('cleared'), isTrue);
        expect(decoded['cleared'], isNull);
        expect(decoded['kept'], equals('value'));
      });
    });

    group('edge cases', () {
      test('should return empty map for empty input', () {
        final dirty = <String, Object>{};
        final clean = makeCleanJsonMap(dirty);

        expect(clean.isEmpty, isTrue);
      });

      test('should return empty map if all values are invalid', () {
        final dirty = {'a': DateTime(2024, 1, 1), 'b': Object()};
        final clean = makeCleanJsonMap(dirty);

        expect(clean.isEmpty, isTrue);
      });

      test('should create new map instance', () {
        final dirty = {'name': 'Test'};
        final clean = makeCleanJsonMap(dirty);

        expect(identical(dirty, clean), isFalse);
      });

      test('should handle deeply nested mixed structures', () {
        final dirty = {
          'level1': {
            'level2': {
              'valid': 'value',
              'invalid': DateTime(2024, 1, 1),
              'list': [1, DateTime(2024, 1, 1), 'text'],
            },
          },
        };
        final clean = makeCleanJsonMap(dirty);

        final level2 = (clean['level1'] as Map)['level2'] as Map;
        expect(level2['valid'], equals('value'));
        expect(level2.containsKey('invalid'), isFalse);

        final list = level2['list'] as List;
        expect(list.length, equals(2));
        expect(list, contains(1));
        expect(list, contains('text'));
      });
    });

    // A TomJsonSerializable used to fall through the type dispatch to the
    // catch-all `return null` and be filtered out by the caller, so a value
    // object nested in a config map vanished with no error and no log line.
    // These assert it is present *and* converted.
    group('TomJsonSerializable values', () {
      test('should convert a serializable at the top level', () {
        final dirty = {
          'name': 'App',
          'service': _ExampleSerializable('svc', 8080, true),
        };
        final clean = makeCleanJsonMap(dirty);

        expect(clean.containsKey('service'), isTrue);
        final service = clean['service'] as Map;
        expect(service['name'], equals('svc'));
        expect(service['port'], equals(8080));
        expect(service['enabled'], isTrue);
      });

      test('should convert a serializable nested in a sub-map', () {
        final dirty = {
          'outer': {
            'inner': {'service': _ExampleSerializable('nested', 1234, false)},
          },
        };
        final clean = makeCleanJsonMap(dirty);

        final inner = (clean['outer'] as Map)['inner'] as Map;
        final service = inner['service'] as Map;
        expect(service['name'], equals('nested'));
        expect(service['port'], equals(1234));
      });

      test('should convert serializables inside a list', () {
        final dirty = {
          'services': [
            _ExampleSerializable('first', 1, true),
            'plain',
            _ExampleSerializable('second', 2, false),
          ],
        };
        final clean = makeCleanJsonMap(dirty);

        final services = clean['services'] as List;
        expect(services.length, equals(3));
        expect((services[0] as Map)['name'], equals('first'));
        expect(services[1], equals('plain'));
        expect((services[2] as Map)['name'], equals('second'));
      });

      // The reason the branch recurses through makeCleanJsonMap rather than
      // returning toJson() as it stands: a toJson that nests a serializable of
      // its own must be cleaned too, or the nested one is dropped again.
      test('should clean a serializable returned by another toJson', () {
        final dirty = {
          'wrapper': _NestingSerializable(
            _ExampleSerializable('inner', 99, true),
          ),
        };
        final clean = makeCleanJsonMap(dirty);

        final wrapper = clean['wrapper'] as Map;
        expect(wrapper['label'], equals('wrapped'));
        final inner = wrapper['inner'] as Map;
        expect(inner['name'], equals('inner'));
        expect(inner['port'], equals(99));
      });

      // The same recursion has to keep filtering: a toJson that returns a
      // genuinely unserializable value must not smuggle it past the sanitiser.
      test('should still filter unserializable values from a toJson', () {
        final dirty = {'wrapper': _DirtySerializable(DateTime(2024, 1, 1))};
        final clean = makeCleanJsonMap(dirty);

        final wrapper = clean['wrapper'] as Map;
        expect(wrapper['label'], equals('dirty'));
        expect(wrapper.containsKey('when'), isFalse);
      });

      test('should produce output that jsonEncode accepts', () {
        final dirty = {
          'service': _ExampleSerializable('svc', 8080, true),
          'dropped': DateTime(2024, 1, 1),
        };
        final clean = makeCleanJsonMap(dirty);

        final decoded = jsonDecode(jsonEncode(clean)) as Map<String, dynamic>;
        expect((decoded['service'] as Map)['port'], equals(8080));
        expect(decoded.containsKey('dropped'), isFalse);
      });
    });
  });

  // ===========================================================================
  // json_serializable.dart tests
  // ===========================================================================

  group('TomJsonSerializable', () {
    test('implementations expose their state via toJson', () {
      final serializable = _ExampleSerializable('svc', 8080, true);
      final json = serializable.toJson();

      expect(json['name'], equals('svc'));
      expect(json['port'], equals(8080));
      expect(json['enabled'], isTrue);
    });

    test('toJson output round-trips through jsonEncode/jsonDecode', () {
      final serializable = _ExampleSerializable('svc', 8080, true);

      final encoded = jsonEncode(serializable.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['name'], equals('svc'));
      expect(decoded['port'], equals(8080));
      expect(decoded['enabled'], isTrue);
    });

    test('toJson output is JSON-clean for makeCleanJsonMap', () {
      final serializable = _ExampleSerializable('svc', 8080, true);

      final clean = makeCleanJsonMap(serializable.toJson());

      expect(clean.length, equals(3));
      expect(clean['name'], equals('svc'));
      expect(clean['port'], equals(8080));
    });

    test('supports null values in the serialized map', () {
      final serializable = _NullableSerializable(null);

      final json = serializable.toJson();

      expect(json.containsKey('value'), isTrue);
      expect(json['value'], isNull);
    });
  });

  // ===========================================================================
  // Cross-function contract: string-keyed maps of any reified type
  // ===========================================================================

  group('a Map<dynamic, dynamic> child', () {
    // A nested-map guard testing `is Map<String, dynamic>` is a reified test,
    // which a Map<dynamic, dynamic> fails — the same trap as a typed guard on
    // a list, one level down. Such a
    // map never comes out of jsonDecode, but TomYaml.loadYamlFile, hand-built
    // maps and anything round-tripped through an untyped container all produce
    // one — and the module already accepts a bare Map in makeCleanJsonMap, so
    // it knows they arrive. The whole group is stated per function because the
    // guard was repeated per function.

    test('traverseAndProcess descends into an untyped map child', () {
      final tree = <String, dynamic>{
        'typed': <String, dynamic>{'s': r'${X}'},
        'untyped': <dynamic, dynamic>{'s': r'${X}'},
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${X}'),
        (s) => s.replaceAll(r'${X}', 'Y'),
      );

      expect((tree['typed'] as Map)['s'], equals('Y'));
      expect((tree['untyped'] as Map)['s'], equals('Y'));
    });

    test('traverseAndProcess edits the original untyped map in place', () {
      // The cast is a view, not a copy: the caller still holds the map it
      // passed in, so the substitution has to be visible through that
      // reference and not only through the tree.
      final untyped = <dynamic, dynamic>{'s': r'${X}'};
      final tree = <String, dynamic>{'child': untyped};

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${X}'),
        (s) => s.replaceAll(r'${X}', 'Y'),
      );

      expect(untyped['s'], equals('Y'));
    });

    test('traverseAndProcess descends into an untyped map inside a list', () {
      final tree = <String, dynamic>{
        'list': <dynamic>[
          <dynamic, dynamic>{'s': r'${X}'},
        ],
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${X}'),
        (s) => s.replaceAll(r'${X}', 'Y'),
      );

      expect(((tree['list'] as List)[0] as Map)['s'], equals('Y'));
    });

    test('traverseAndCreate reports a key inside an untyped map child', () {
      final tree = <String, dynamic>{
        'child': <dynamic, dynamic>{'ref@a@b': 'value'},
      };

      traverseAndCreate(tree, (name) => name.contains('@'), (
        key,
        value,
        location,
      ) {
        location['resolved'] = value.toUpperCase();
      });

      expect((tree['child'] as Map)['resolved'], equals('VALUE'));
    });

    test('mergeMapsOneSided merges into an untyped base child', () {
      final base = <String, dynamic>{
        'db': <dynamic, dynamic>{'host': 'localhost', 'port': 5432},
      };

      mergeMapsOneSided(base, <String, dynamic>{
        'db': <String, dynamic>{'host': 'remote'},
      });

      final db = base['db'] as Map;
      expect(db['host'], equals('remote'), reason: 'the override applies');
      expect(db['port'], equals(5432), reason: 'the untouched key survives');
    });

    test('mergeMapsOneSided merges into an untyped map inside an array', () {
      final base = <String, dynamic>{
        'items': <dynamic>[
          <dynamic, dynamic>{'name': 'a', 'keep': 1},
        ],
      };

      mergeMapsOneSided(base, <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'name': 'b'},
        ],
      });

      final item = (base['items'] as List)[0] as Map;
      expect(item['name'], equals('b'));
      expect(item['keep'], equals(1));
    });

    test('getObjectFromTree descends through an untyped interior map', () {
      final tree = <String, dynamic>{
        'db': <dynamic, dynamic>{
          'primary': <dynamic, dynamic>{'port': 5432},
        },
      };

      expect(getObjectFromTree(tree, 'db.primary.port'), equals(5432));
    });

    test('getPathFromTree returns an untyped map rather than wrapping it', () {
      final tree = <String, dynamic>{
        'db': <dynamic, dynamic>{'port': 5432},
      };

      final result = getPathFromTree(tree, 'db', 'wrapped');

      expect(result['port'], equals(5432));
      expect(
        result.containsKey('wrapped'),
        isFalse,
        reason: 'a map at the path is a subtree, not a terminal value',
      );
    });

    test('substituteEnvVars reaches an untyped map child', () {
      final tree = <String, dynamic>{
        'child': <dynamic, dynamic>{'host': r'${DB_HOST}'},
      };

      substituteEnvVars(tree, <String, String>{'DB_HOST': 'db.internal'});

      expect((tree['child'] as Map)['host'], equals('db.internal'));
    });

    test('a map with a non-String key is left alone, not walked', () {
      // The boundary of the fix, pinned deliberately. Such a map cannot be a
      // JSON object, and the callbacks take a String key, so there is nothing
      // sensible to hand them. It is skipped rather than half-walked.
      final tree = <String, dynamic>{
        'child': <dynamic, dynamic>{1: r'${X}'},
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${X}'),
        (s) => s.replaceAll(r'${X}', 'Y'),
      );

      expect((tree['child'] as Map)[1], equals(r'${X}'));
    });
  });
}

/// Test double implementing [TomJsonSerializable] with typical scalar state.
class _ExampleSerializable implements TomJsonSerializable {
  _ExampleSerializable(this.name, this.port, this.enabled);

  final String name;
  final int port;
  final bool enabled;

  @override
  Map<String, Object?> toJson() => {
    'name': name,
    'port': port,
    'enabled': enabled,
  };
}

/// Test double whose serialized map carries a nullable value.
class _NullableSerializable implements TomJsonSerializable {
  _NullableSerializable(this.value);

  final String? value;

  @override
  Map<String, Object?> toJson() => {'value': value};
}

/// Test double whose `toJson` nests a second [TomJsonSerializable], so the
/// sanitiser has to keep recursing rather than trusting one `toJson` call.
class _NestingSerializable implements TomJsonSerializable {
  _NestingSerializable(this.inner);

  final _ExampleSerializable inner;

  @override
  Map<String, Object?> toJson() => {'label': 'wrapped', 'inner': inner};
}

/// Test double whose `toJson` returns a value that is not JSON-encodable, so
/// the sanitiser has to keep filtering inside a converted map.
class _DirtySerializable implements TomJsonSerializable {
  _DirtySerializable(this.when);

  final DateTime when;

  @override
  Map<String, Object?> toJson() => {'label': 'dirty', 'when': when};
}

/// Test double standing for a provider's own failure type.
///
/// Its only job is to be a type nothing in the json module knows about, so
/// that catching it after [processTree] proves the provider's exception
/// reached the caller unaltered rather than repackaged.
class _ProviderUnavailable implements Exception {
  const _ProviderUnavailable(this.reason);

  final String reason;

  @override
  String toString() => "_ProviderUnavailable: $reason";
}
