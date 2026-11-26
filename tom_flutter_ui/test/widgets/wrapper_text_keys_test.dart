import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../support/recording_text_resource_provider.dart';
import 'widget_census.dart';
import 'widget_conformance_registry.dart';

// `tomWrapperTextKeys` against the wrappers themselves.
//
// The catalogue says, per wrapper, which text keys it reads under its resource
// path and whether a resource file has to hold each. Written by hand it would
// go stale the first time a wrapper gained a key, and a resource checker would
// then pass a file the screen cannot show. So it is held to behaviour, not to
// a reading of the sources:
//
// - Every wrapper of the conformance registry is built with a `tomId` and a
//   resource provider that records each key it is asked for and holds no text.
//   A key asked through the String family (`exists`, `getText`,
//   `getTextOrNull`) and never as an object is a text key. Asked with
//   `exists` or `getText`, a missing resource shows the dotted key, so the key
//   is required; asked only with `getTextOrNull`, the text is shown only when
//   the resource exists, so it is optional.
// - A wrapper that reads a text at build time is not seen by construction.
//   Every `TomCtr.text*` call with a literal suffix inside a wrapper's class is
//   therefore also read from the source, and must be in the catalogue.
//
// Object keys (colours, sizes) are told apart from text keys that found
// nothing by what follows: an object read ends in `getObjectOrNull`. The
// provider answers the non-text values a wrapper demands (`colorOrFail`,
// `doubleOrFail`, ...) from a backing map, as `widget_conformance_test.dart`
// does, so every wrapper builds.

/// The non-text values the wrappers demand, under the path [id].
TomTextResourceProvider _objectValues(String id) {
  final leaf = <String, dynamic>{};
  final demand = RegExp(r"TomCtr\.(\w+)OrFail\(basePath, '(\w+)'");
  for (final source in widgetKitSources()) {
    for (final m in demand.allMatches(source)) {
      final value = switch (m.group(1)!) {
        'color' => '#000000',
        'icon' => 'mSave',
        'double' || 'int' => '1',
        _ => null,
      };
      if (value != null) leaf[m.group(2)!] = value;
    }
  }
  return TomTextResourceProvider.from({id: leaf});
}

/// The text keys [build] reads at construction, under the path [id].
Set<TomTextKey> _recorded(String id, TomWidgetFactory build) {
  final provider = RecordingTextResourceProvider(_objectValues(id));
  TomTextResourceProvider.setAppResourceProvider(provider);
  build(id, null);
  return {
    for (final entry in provider.textKeysUnder(id).entries)
      TomTextKey(
        entry.key,
        // The kind is the catalogue's word; the recording knows the presence.
        TomTextKeyKind.text,
        entry.value ? TomTextKeyPresence.required : TomTextKeyPresence.optional,
      ),
  };
}

/// Every `TomCtr.text*` call with a literal suffix in `lib/src/widgets/`, by
/// the class whose body holds it. A call outside every class (a top-level
/// helper) is left out: the recording sees it through the wrappers that call
/// it.
Map<String, Set<String>> _sourceReads() {
  final call = RegExp(
    r"TomCtr\.(?:textOrFail|textOrNull|text)\(\s*"
    r"(?:basePath|_p\(tomId,\s*scope),\s*'([A-Za-z.]+)'",
  );
  final out = <String, Set<String>>{};
  for (final file in Directory('lib/src/widgets').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final source = file.readAsStringSync();
    final classes = [
      for (final m in declarationPattern.allMatches(source))
        (start: m.start, name: m.group(1)!),
    ];
    for (final m in call.allMatches(source)) {
      String? owner;
      for (final c in classes) {
        if (c.start < m.start) owner = c.name;
      }
      if (owner != null) {
        out.putIfAbsent(owner, () => <String>{}).add(m.group(1)!);
      }
    }
  }
  return out;
}

/// [keys] without their kind, which only the catalogue states.
Set<(String, TomTextKeyPresence)> _withoutKind(Iterable<TomTextKey> keys) => {
  for (final k in keys) (k.suffix, k.presence),
};

void main() {
  setUpAll(() {
    TomUIIcons.adapter = TomAllIconsAdapter();
    TomUIColors.adapter = TomAllColorsAdapter();
  });

  test('txtkeys-01: the catalogue lists every wrapper of the registry, and '
      'TomDataColumn', () {
    expect(tomWrapperTextKeys.keys.toSet(), {
      ...widgetConformanceRegistry.keys,
      'TomDataColumn',
    });
  });

  test('txtkeys-02: each wrapper reads at construction exactly the keys the '
      'catalogue gives it, with the presence it gives', () {
    final sourceReads = _sourceReads();
    final wrong = <String>[];
    for (final entry in widgetConformanceRegistry.entries) {
      final name = entry.key;
      final recorded = _recorded('w', entry.value);
      final listed = tomWrapperTextKeys[name]!;
      // A key read only at build time is in the source but not recorded.
      final buildOnly = {
        for (final k in listed)
          if (!recorded.any((r) => r.suffix == k.suffix) &&
              (sourceReads[name] ?? const <String>{}).contains(k.suffix))
            k,
      };
      final expected = _withoutKind(listed.toSet().difference(buildOnly));
      final actual = _withoutKind(recorded);
      if (actual.length != expected.length || !actual.containsAll(expected)) {
        wrong.add(
          '$name: recorded ${actual.toList()..sort((a, b) => a.$1.compareTo(b.$1))}, '
          'listed ${expected.toList()..sort((a, b) => a.$1.compareTo(b.$1))}',
        );
      }
    }
    expect(wrong, isEmpty);
  });

  test('txtkeys-03: every text a wrapper reads in its source is in the '
      'catalogue, build-time reads included', () {
    final missing = <String>[];
    for (final entry in _sourceReads().entries) {
      final listed = tomWrapperTextKeys[entry.key];
      if (listed == null) {
        missing.add('${entry.key}: not in the catalogue');
        continue;
      }
      for (final suffix in entry.value) {
        if (!listed.any((k) => k.suffix == suffix)) {
          missing.add('${entry.key}.$suffix');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('txtkeys-04: a setting is never required, and the semantics keys are '
      'the accessibility texts', () {
    const semantics = {'semanticLabel', 'semanticsLabel', 'semanticsValue'};
    for (final entry in tomWrapperTextKeys.entries) {
      for (final key in entry.value) {
        final leaf = key.suffix.split('.').last;
        if (key.kind == TomTextKeyKind.setting) {
          expect(
            key.presence,
            TomTextKeyPresence.optional,
            reason: '${entry.key}.${key.suffix}',
          );
        }
        if (semantics.contains(leaf)) {
          expect(
            key.kind,
            TomTextKeyKind.semantics,
            reason: '${entry.key}.${key.suffix}',
          );
        }
      }
    }
  });

  test('txtkeys-05: the keys the text fields and tiles gained are in the '
      'catalogue as optional texts', () {
    const optional = TomTextKeyPresence.optional;
    for (final field in ['TomTextField', 'TomTextFormField']) {
      for (final suffix in ['helper', 'prefix', 'suffix']) {
        expect(
          tomWrapperTextKeys[field],
          contains(TomTextKey(suffix, TomTextKeyKind.text, optional)),
          reason: '$field.$suffix',
        );
      }
    }
    for (final tile in [
      'TomListTile',
      'TomSwitchListTile',
      'TomCheckboxListTile',
      'TomRadioListTile',
      'TomCupertinoListTile',
    ]) {
      expect(
        tomWrapperTextKeys[tile],
        contains(const TomTextKey('subtitle', TomTextKeyKind.text, optional)),
        reason: tile,
      );
    }
  });

  test('txtkeys-06: no wrapper reads a parameter name as a second key for '
      'the same text', () {
    // `titleText` beside `label`, `hintText` beside `hint`: one text, one key.
    const aliases = {'titleText', 'hintText', 'helperText', 'errorText'};
    for (final entry in tomWrapperTextKeys.entries) {
      for (final key in entry.value) {
        expect(
          aliases.contains(key.suffix),
          isFalse,
          reason: '${entry.key}.${key.suffix}',
        );
      }
    }
  });

  test('txtkeys-07: the table in doc/widgets.md is the catalogue', () {
    final doc = File('doc/widgets.md').readAsStringSync();
    final row = RegExp(
      r'^\| `(Tom\w+)` \| (.*?) \| (.*?) \|$',
      multiLine: true,
    );
    String cell(Iterable<TomTextKey> keys) => keys.isEmpty
        ? '—'
        : keys
              .map(
                (k) =>
                    '`${k.suffix}`'
                    '${k.kind == TomTextKeyKind.text ? '' : ' (${k.kind.name})'}',
              )
              .join(', ');
    final expected = {
      for (final entry in tomWrapperTextKeys.entries)
        if (entry.value.isNotEmpty)
          entry.key: (
            cell(
              entry.value.where(
                (k) => k.presence == TomTextKeyPresence.required,
              ),
            ),
            cell(
              entry.value.where(
                (k) => k.presence == TomTextKeyPresence.optional,
              ),
            ),
          ),
    };
    final section = doc.substring(doc.indexOf('## Text keys per wrapper'));
    final actual = {
      for (final m in row.allMatches(section))
        m.group(1)!: (m.group(2)!, m.group(3)!),
    };
    expect(actual, expected);
    expect(section, contains('A wrapper not listed reads no text.'));
  });
}
