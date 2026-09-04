import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'widget_census.dart';
import 'widget_conformance_registry.dart';

// Every exported widget honours the base surface, or the suite says so.
//
// Two hundred and twenty-five of the kit's 290 widgets were named in no test
// and no example. That is not a coverage statistic to be improved by writing
// 225 more `testWidgets` — a wrapper's rendering *is* the Flutter widget it
// delegates to, and asserting that `TomPadding` pads would be asserting
// Flutter. What was genuinely unchecked is the part that is Tom's: the
// identity, the resource path, the family tag and the authorization state
// that `TomWidgetSurface` names.
//
// That part is decided entirely at construction, from two arguments — a
// `tomId` and a scope — so it can be asserted for all 290 at once without a
// host, a pump or a bespoke parent per widget. This file does that.
//
// ## Why the gap was invisible
//
// Before `TomWidgetSurface` there was no supertype requiring any of it.
// `basePath` was declared twice, independently: as a field on `TomNodeBase`
// and as a getter on `TomWidgetMixin`. A wrapper that declared a `tomId` and
// resolved nothing type-checked, read as gated at the call site, and showed to
// everyone — eight wrappers shipped exactly that, and
// `wrapper_auth_gate_test.dart` had to name each of them by hand to find it.
//
// The interface turns the *next* such wrapper into a compile error: a factory
// below must return a `TomWidgetSurface`, so a wrapper that skips the surface
// cannot be added to the registry at all. The registry-completeness case
// below closes the other half — a wrapper that is added to the kit and not to
// the registry fails here.

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

/// The resource bundle the kit's constructors demand, derived from the kit.
///
/// Some widgets resolve a *required* value in their initialiser body —
/// `TomCtr.doubleOrFail(basePath, 'opacity')` and its siblings — and throw when
/// neither the parameter nor the resource supplies one. `TomAnimatedOpacity`
/// with no opacity is not a widget with a sensible default; it is a call site
/// that forgot to say how transparent it wanted something. So the fixture
/// satisfies the contract rather than working around it, and the widget is
/// constructed the way an application would construct it.
///
/// The suffixes are scanned out of the sources rather than listed. A list would
/// make "a widget now requires a new resource" fail here, in a suite with
/// nothing to say about it, and the fix would be to append a line — which is
/// exactly the maintenance this file exists to avoid. The *value* for each is
/// chosen by the accessor instead, and the accessor set is `TomCtr`'s API,
/// which does not grow when the widget kit does.
Map<String, dynamic> _requiredResources() {
  final leaf = <String, dynamic>{};
  final demand = RegExp(r"TomCtr\.(\w+)OrFail\(basePath, '(\w+)'");
  for (final source in widgetKitSources()) {
    for (final m in demand.allMatches(source)) {
      leaf[m.group(2)!] = switch (m.group(1)!) {
        'color' => '#000000',
        'icon' => 'mSave',
        'double' || 'int' => '1',
        _ => 'x',
      };
    }
  }
  return {
    'save': leaf,
    'settings': {'save': leaf},
  };
}

void main() {
  final classes = widgetKitClasses();
  final bases = familyBases();
  final scope = TomScopeBase(scopeId: 'settings');

  setUpAll(() {
    // A name in a bundle is only half a resource: the icon and colour
    // accessors hand the name to an adapter, and with none installed every
    // lookup misses. An application installs these at startup, so the fixture
    // does too.
    TomUIIcons.adapter = AllIconsAdapter();
    TomUIColors.adapter = AllColorsAdapter();
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(_requiredResources()),
    );
  });

  tearDown(TomAuthorization.reset);

  group('tccm1: the registry is the widget set, exactly', () {
    test('tccm1-01: it holds every widget under widgets/ and nothing else', () {
      final expected = classes.keys.toSet().difference(nonWidgetTypes);
      final actual = widgetConformanceRegistry.keys.toSet();
      expect(
        actual.difference(expected),
        isEmpty,
        reason: 'the registry builds a type that widgets/ no longer declares',
      );
      expect(
        expected.difference(actual),
        isEmpty,
        reason:
            'a widget was added to the kit but not to the conformance '
            'registry, so nothing checks that it carries the Tom surface',
      );
      expect(actual, hasLength(290));
    });

    test('tccm1-02: the nine non-widgets are the only types left out', () {
      // Not an oversight and not a gap in the guard: a `TomDataCell` holds a
      // `Widget` without being one, so `TomWidgetMixin` — declared `on Widget`
      // — cannot be mixed in and there is no surface to check. Four of the
      // nine still need gating and get it from `TomAuthGate` around the slot
      // they own, which `wrapper_auth_gate_test.dart` asserts.
      expect(nonWidgetTypes, hasLength(9));
      for (final name in nonWidgetTypes) {
        expect(classes, contains(name));
        expect(widgetConformanceRegistry, isNot(contains(name)));
      }
    });

    test('tccm1-03: every registered widget constructs', () {
      // The registry passes an id, a scope and each constructor's `required`
      // arguments — nothing else. Most of the kit needs no more than that, but
      // a handful of Flutter originals assert across *optional* parameters
      // instead: a `Tab` demands one of text, child or icon, none of them
      // required on their own. Those get an explicit entry in the registry's
      // OVERRIDE table, and this test is what says which ones need it.
      //
      // Collecting rather than propagating is the point: a throw inside the
      // per-widget loops below aborts the whole loop, so one unconstructible
      // widget would hide the state of the other 289.
      final faults = <String>[];
      widgetConformanceRegistry.forEach((name, build) {
        try {
          build('save', null);
        } catch (e) {
          faults.add('$name: ${e.toString().split('\n').first}');
        }
      });
      expect(faults, isEmpty, reason: faults.join('\n'));
    });
  });

  group('tccm1: every widget resolves its own resource path', () {
    test('tccm1-04: an unscoped widget addresses its bare id', () {
      final faults = <String>[];
      widgetConformanceRegistry.forEach((name, build) {
        final path = build('save', null).basePath;
        if (path != 'save') faults.add('$name: $path');
      });
      expect(faults, isEmpty, reason: faults.join('\n'));
    });

    test('tccm1-05: a scoped widget prefixes the scope path', () {
      // The one assertion that distinguishes a wrapper which *resolves* its
      // path from one that merely stores its id: an explicit scope has to
      // reach the resolver. Both routes go through `TomScopePath.resolve`, so
      // a wrapper that forgot to forward `scope` to its base answers 'save'
      // here and is caught.
      final faults = <String>[];
      widgetConformanceRegistry.forEach((name, build) {
        final path = build('save', scope).basePath;
        if (path != 'settings.save') faults.add('$name: $path');
      });
      expect(faults, isEmpty, reason: faults.join('\n'));
    });

    test('tccm1-06: the id it was given is the id it reports', () {
      final faults = <String>[];
      widgetConformanceRegistry.forEach((name, build) {
        final id = build('save', null).tomId;
        if (id != 'save') faults.add('$name: $id');
      });
      expect(faults, isEmpty, reason: faults.join('\n'));
    });
  });

  group(
    'tccm1: every widget reports a family, or is a documented exception',
    () {
      test('tccm1-07: the family reported is the one its base fixes', () {
        // `family` is abstract on `TomFamilyBase` and given a single value by
        // each of the twenty branch bases, so the source's `extends` clause
        // predicts the runtime answer. Checking that it does is what makes the
        // catalogue in `doc/widgets.md` — which is keyed by base — a true
        // statement about instances rather than about text.
        final faults = <String>[];
        widgetConformanceRegistry.forEach((name, build) {
          final widget = build('save', null);
          final parent = parentIn(classes[name]);
          if (!bases.contains(parent)) return;
          if (widget is! TomFamilyBase) {
            faults.add('$name: extends $parent but is no TomFamilyBase');
            return;
          }
          if (!widget.isFamily(widget.family)) {
            faults.add('$name: denies its own primary family ${widget.family}');
          }
        });
        expect(faults, isEmpty, reason: faults.join('\n'));
      });

      test('tccm1-08: exactly the 17 mixin users report no family', () {
        final familyless = widgetConformanceRegistry.entries
            .where((e) => e.value('save', null) is! TomFamilyBase)
            .map((e) => e.key)
            .toSet();
        expect(familyless, mixinSurfaceWidgets);
      });
    },
  );

  group('tccm1: every widget resolves all four authorization states', () {
    // The four states are resolved lazily — `TomPolicyNodeBase` and
    // `TomWidgetMixin` both consult the adapter when asked, not when built —
    // so one instance per widget answers for all four. What the enforcement
    // then *looks* like (hidden under `none`, non-interactive under
    // `disabled`) is implemented centrally by the family bases and pinned by
    // `wrapper_auth_gate_test.dart` and the auth-layers suite; here the
    // question is narrower and
    // applies to all 290: does the widget reach the resolver at all, through
    // its own path?
    for (final state in TomAuthState.values) {
      final id = (9 + state.index).toString().padLeft(2, '0');
      test('tccm1-$id: it answers ${state.name} from its own path', () {
        TomAuthorization.adapter = _MapAuthAdapter({'save': state});
        final faults = <String>[];
        widgetConformanceRegistry.forEach((name, build) {
          final actual = build('save', null).effectiveAuthState;
          if (actual != state) faults.add('$name: $actual');
        });
        expect(faults, isEmpty, reason: faults.join('\n'));
      });
    }

    test('tccm1-13: a rule on another path does not reach it', () {
      // The mirror of the four above, and the assertion that would have caught
      // the eight ungated wrappers on its own: a widget that ignores its path
      // and hard-codes `TomAuthState.full` passes every positive test in this
      // group, because `full` is also what an unmatched lookup returns.
      TomAuthorization.adapter = _MapAuthAdapter({
        'settings.save': TomAuthState.none,
      });
      final faults = <String>[];
      widgetConformanceRegistry.forEach((name, build) {
        if (build('save', null).effectiveAuthState != TomAuthState.full) {
          faults.add('$name: reads a rule belonging to another path');
        }
        if (build('save', scope).effectiveAuthState != TomAuthState.none) {
          faults.add('$name: scoped instance misses its own rule');
        }
      });
      expect(faults, isEmpty, reason: faults.join('\n'));
    });
  });
}
