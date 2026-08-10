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
      final data = {'nested': {'value': 1}};
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

      test('should not throw when override array is shorter than base (§44)',
          () {
        // The base array has more map elements than the override — a normal
        // "override only the first N" config-layering case. Before the fix the
        // merge loop indexed overrideMapArray[i] past its end and threw
        // RangeError.
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

      test('keeps base scalar when override tries to merge an array over it',
          () {
        final base = <String, dynamic>{'x': 5};
        final override = <String, dynamic>{
          'x': [1, 2],
        };

        mergeMapsOneSided(base, override);

        // Cannot merge an array into a scalar — base is left unchanged.
        expect(base['x'], equals(5));
      });
    });

    group('decoded JSON inputs (§45)', () {
      test('deep-merges nested maps coming from jsonDecode', () {
        final base =
            jsonDecode('{"db":{"host":"localhost","port":5432}}')
                as Map<String, dynamic>;
        final override =
            jsonDecode('{"db":{"host":"prod"}}') as Map<String, dynamic>;

        mergeMapsOneSided(base, override);

        final db = base['db'] as Map;
        expect(db['host'], equals('prod')); // overridden
        // Before the fix the reified-type guard rejected the decoded
        // Map<String, dynamic>, so the nested base map (and 'port') was
        // discarded by the wholesale-replace fallback.
        expect(db['port'], equals(5432));
      });
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
        'config': <String, Object>{
          'endpoint': r'${HOST}/v1',
        },
      };

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${'),
        (s) => s.replaceAll(r'${HOST}', 'api.example.com'),
      );

      expect(
        (tree['config'] as Map)['endpoint'],
        equals('api.example.com/v1'),
      );
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

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${'),
        (s) => 'REPLACED',
      );

      expect(tree['name'], equals('unchanged'));
      expect(tree['value'], equals('also same'));
    });

    test('should handle empty tree', () {
      final tree = <String, Object>{};

      traverseAndProcess(
        tree,
        (s) => true,
        (s) => 'REPLACED',
      );

      expect(tree.isEmpty, isTrue);
    });

    test('should handle deeply nested structures', () {
      final tree = <String, Object>{
        'a': <String, Object>{
          'b': <String, Object>{
            'c': <String, Object>{
              'd': r'${VAR}',
            },
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

    test('descends into maps and lists coming from jsonDecode (§45)', () {
      final tree =
          jsonDecode(r'{"a":{"b":"${X}"},"list":["${X}",{"c":"${X}"}]}')
              as Map<String, dynamic>;

      traverseAndProcess(
        tree,
        (s) => s.contains(r'${X}'),
        (s) => s.replaceAll(r'${X}', 'Y'),
      );

      // Before the fix the reified-type guards rejected the decoded
      // Map<String, dynamic> / List<dynamic>, so traversal never descended.
      expect((tree['a'] as Map)['b'], equals('Y'));
      expect((tree['list'] as List)[0], equals('Y'));
      expect(((tree['list'] as List)[1] as Map)['c'], equals('Y'));
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

    test('substitutes inside decoded JSON config (§45)', () {
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

      traverseAndCreate(
        tree,
        (name) => name.contains('@'),
        (key, value, location) {
          createdKeys.add(key);
        },
      );

      expect(createdKeys, contains('special@key'));
      expect(createdKeys.length, equals(1));
    });

    test('should traverse nested maps', () {
      final tree = <String, dynamic>{
        'outer': <String, dynamic>{
          'inner@key': 'value',
        },
      };
      final foundKeys = <String>[];

      traverseAndCreate(
        tree,
        (name) => name.contains('@'),
        (key, value, location) {
          foundKeys.add(key);
        },
      );

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

      traverseAndCreate(
        tree,
        (name) => name.contains('@'),
        (key, value, location) {
          foundKeys.add(key);
        },
      );

      expect(foundKeys, contains('item@1'));
      expect(foundKeys, contains('item@2'));
    });

    test('should pass location map to creator for potential modification', () {
      // Note: The creator receives the location map but should not modify it
      // during traversal to avoid concurrent modification errors.
      // Modifications should be collected and applied after traversal.
      final tree = <String, dynamic>{'ref@pattern': 'targetValue'};
      Map<String, dynamic>? capturedLocation;

      traverseAndCreate(
        tree,
        (name) => name.contains('@'),
        (key, value, location) {
          capturedLocation = location;
        },
      );

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

      traverseAndCreate(
        tree,
        (name) => name.contains('@'),
        (key, value, location) {
          foundKeys.add(key);
        },
      );

      expect(foundKeys, equals(['string@key']));
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
        'config': <String, dynamic>{
          'port': 8080,
        },
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
      final tree = <String, dynamic>{
        'value': 'string',
      };

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
  });

  group('processTree', () {
    test('should resolve profile-based references', () {
      final tree = <String, dynamic>{
        'config@profiles.db@production': '@',
      };

      processTree(tree, (keyName, path, profileName) {
        expect(keyName, equals('config'));
        expect(path, equals('profiles.db'));
        expect(profileName, equals('production'));
        return <String, dynamic>{'config': 'resolved_value'};
      });

      expect(tree['config'], equals('resolved_value'));
    });

    test('should spread values with ... directive', () {
      final tree = <String, dynamic>{
        'spread@source.data@profile': '...',
      };

      processTree(tree, (keyName, path, profileName) {
        return <String, dynamic>{
          'newKey1': 'value1',
          'newKey2': 'value2',
        };
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
      final tree = <String, dynamic>{
        'data@source@profile': 'replace',
      };

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
        'outer': <String, dynamic>{
          'ref@path@profile': '@',
        },
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
          'outer': {'inner': {'value': 'deep'}},
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
        final dirty = {
          'name': 'Test',
          'created': DateTime(2024, 1, 1),
        };
        final clean = makeCleanJsonMap(dirty);

        expect(clean['name'], equals('Test'));
        expect(clean.containsKey('created'), isFalse);
      });

      test('should filter out custom objects', () {
        final dirty = {
          'valid': 'value',
          'invalid': Object(),
        };
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
        final dirty = {
          'cleared': null,
          'dropped': DateTime(2024, 1, 1),
        };
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
        final dirty = {
          'a': DateTime(2024, 1, 1),
          'b': Object(),
        };
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
