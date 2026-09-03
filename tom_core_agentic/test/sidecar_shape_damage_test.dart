import 'dart:io';

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

// The sidecar stores promise one thing: a damaged file costs the user a
// reset, never a crash. Their `try` covers *parse* damage, because a
// `YamlException` is a `FormatException`. It did not cover *shape* damage —
// a file that parses cleanly but whose entry is missing the one field the
// model reads with an unguarded cast. That threw a `TypeError`, which is
// neither of the two types caught, so the promise failed on the damage shape
// a hand-edit actually produces.
//
// The existing malformed-file tests could not see this: every one of them
// writes `': not a mapping :'`, a *syntax* error, which is the one shape the
// catch already handled.
//
// Two properties are asserted here, per store, from one table — a per-store
// hand-written test is how the trail store came to have no shape test at all.
//
//   * a shape-damaged entry does not propagate out of `load()`;
//   * it costs *that entry only*. The all-or-nothing catch would have
//     returned an empty list, so one bad row silently discarded the file.

/// One list store, described by what its file looks like rather than by which
/// class reads it, so the same two assertions run against all seven.
class _ListStore {
  const _ListStore({
    required this.name,
    required this.listKey,
    required this.identity,
    required this.entry,
    required this.identitiesOf,
  });

  /// The store class under test, for the group name.
  final String name;

  /// The root key its list hangs under.
  final String listKey;

  /// The field the store treats as the entry's identity.
  final String identity;

  /// A well-formed entry carrying [id], as YAML list-item lines.
  final String Function(String id) entry;

  /// Loads the file and projects each entry to its identity.
  final List<String> Function(File file) identitiesOf;
}

/// An entry that is valid YAML and a mapping, but carries no identity field —
/// the shape a hand-edit produces when a line is deleted.
const _damaged = '  - description: an entry with no identity\n';

final _stores = <_ListStore>[
  _ListStore(
    name: 'PromptQueueStore',
    listKey: 'items',
    identity: 'id',
    entry: (id) => '  - id: $id\n    originalText: hello\n',
    identitiesOf: (f) => PromptQueueStore(f).load().map((e) => e.id).toList(),
  ),
  _ListStore(
    name: 'AgentProfileStore',
    listKey: 'profiles',
    identity: 'id',
    entry: (id) => '  - id: $id\n    name: Builder\n',
    identitiesOf: (f) => AgentProfileStore(f).load().map((e) => e.id).toList(),
  ),
  _ListStore(
    name: 'ChatVariableStore',
    listKey: 'variables',
    identity: 'name',
    entry: (id) => '  - name: $id\n    value: v\n',
    identitiesOf: (f) =>
        ChatVariableStore(f).load().map((e) => e.name).toList(),
  ),
  _ListStore(
    name: 'PromptTemplateStore',
    listKey: 'templates',
    identity: 'id',
    entry: (id) => '  - id: $id\n    name: Greeting\n',
    identitiesOf: (f) =>
        PromptTemplateStore(f).load().map((e) => e.id).toList(),
  ),
  _ListStore(
    name: 'QueueTemplateStore',
    listKey: 'templates',
    identity: 'id',
    entry: (id) => '  - id: $id\n    name: Nightly\n',
    identitiesOf: (f) => QueueTemplateStore(f).load().map((e) => e.id).toList(),
  ),
  _ListStore(
    name: 'TimedRequestStore',
    listKey: 'requests',
    identity: 'id',
    entry: (id) => '  - id: $id\n    enabled: true\n',
    identitiesOf: (f) => TimedRequestStore(f).load().map((e) => e.id).toList(),
  ),
  _ListStore(
    name: 'PromptTrailStore',
    listKey: 'pairs',
    identity: 'id',
    entry: (id) =>
        '  - id: $id\n    request:\n'
        '      id: ${id}_req\n      text: hi\n',
    identitiesOf: (f) => PromptTrailStore(f).load().map((e) => e.id).toList(),
  ),
];

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('sidecar_shape_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File write(String name, String content) =>
      File('${dir.path}/$name')..writeAsStringSync(content);

  for (final store in _stores) {
    group(store.name, () {
      test('skips an entry with no ${store.identity} and keeps its '
          'neighbours', () {
        final file = write(
          'damaged.yaml',
          'version: 1\n${store.listKey}:\n'
              '${store.entry('first')}$_damaged${store.entry('second')}',
        );

        // Not merely "does not throw": the surrounding entries survive. An
        // all-or-nothing catch would satisfy the first half of that and
        // still lose the user's other rows.
        expect(store.identitiesOf(file), ['first', 'second']);
      });

      test('returns an empty list when every entry lacks an identity', () {
        final file = write(
          'all_damaged.yaml',
          'version: 1\n${store.listKey}:\n$_damaged',
        );

        expect(store.identitiesOf(file), isEmpty);
      });
    });
  }

  // Damage below the entry root. These cost the *element*, not the entry,
  // wherever the entry is still meaningful without it — and cost the entry
  // where it is not.

  group('nested shape damage', () {
    test('a non-mapping pre-prompt is dropped, the prompt survives', () {
      final file = write(
        'queue.yaml',
        'version: 1\nitems:\n  - id: q1\n    originalText: hello\n'
            '    prePrompts:\n      - just a string\n      - text: real\n',
      );

      final loaded = PromptQueueStore(file).load();
      expect(loaded.map((e) => e.id), ['q1']);
      expect(loaded.single.prePrompts?.map((p) => p.text), ['real']);
    });

    test('a non-mapping follow-up is dropped, the prompt survives', () {
      final file = write(
        'queue.yaml',
        'version: 1\nitems:\n  - id: q1\n    originalText: hello\n'
            '    followUps:\n      - 7\n      - id: f1\n',
      );

      final loaded = PromptQueueStore(file).load();
      expect(loaded.single.followUps?.map((f) => f.id), ['f1']);
    });

    test('a non-mapping scheduled time is dropped, the request survives', () {
      final file = write(
        'timed.yaml',
        'version: 1\nrequests:\n  - id: t1\n'
            '    scheduledTimes:\n      - nope\n      - time: "09:00"\n',
      );

      final loaded = TimedRequestStore(file).load();
      expect(loaded.single.scheduledTimes?.map((s) => s.time), ['09:00']);
    });

    test('a non-string enabled tool is dropped, the profile survives', () {
      final file = write(
        'profiles.yaml',
        'version: 1\nprofiles:\n  - id: p1\n'
            '    enabledTools:\n      - Read\n      - 42\n',
      );

      expect(AgentProfileStore(file).load().single.enabledTools, ['Read']);
    });

    test('a trail pair with no request is dropped, its neighbours survive', () {
      // The one nested field an entry cannot do without: `TrailPair.request`
      // is non-nullable, so a pair missing it is not a pair. Dropping the
      // entry is right here where dropping the element was right above.
      final file = write(
        'trail.yaml',
        'version: 1\npairs:\n'
            '  - id: a\n    request:\n      id: a_req\n      text: hi\n'
            '  - id: b\n    createdAt: today\n'
            '  - id: c\n    request:\n      id: c_req\n      text: ho\n',
      );

      expect(PromptTrailStore(file).load().map((p) => p.id), ['a', 'c']);
    });

    test('a mis-typed answer leaves the pair loaded with no answer', () {
      // `answer` is nullable, so unreadable and absent mean the same thing.
      final file = write(
        'trail.yaml',
        'version: 1\npairs:\n  - id: a\n    request:\n'
            '      id: a_req\n      text: hi\n    answer: 7\n',
      );

      final loaded = PromptTrailStore(file).load();
      expect(loaded.single.id, 'a');
      expect(loaded.single.answer, isNull);
    });
  });
}
