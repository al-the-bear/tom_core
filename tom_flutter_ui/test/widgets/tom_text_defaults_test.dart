import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// A Tom widget with an unfilled `child:` (or `content:`) slot fills it from
// resources, and what it fills it with is a `TomText`. `TomText.defaultFor` and
// `TomText.defaultOrEmpty` are the two constructors of that filler, used by
// eight slots across `tom_tables`, `tom_dialogs`, `tom_containers` and
// `tom_animated`.
//
// They are a pair, not two spellings of one thing, and the difference is the
// slot they serve: `defaultFor` is for an optional slot a caller may leave
// null, `defaultOrEmpty` for a non-nullable one that must always hold a widget.
// Neither throws — an unidentified slot is not an error, it simply has nothing
// to resolve.
//
// They live here rather than in `widget_base/`, because there they would make
// the foundation import the layer built on top of it. Returning a widget is the tell for which layer a helper belongs to; see
// `test/widget_base/widget_base_layering_test.dart` for what that inversion
// cost.

void install(Map<String, dynamic> tree) =>
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(tree),
    );

void main() {
  tearDown(() => install(<String, dynamic>{}));

  group('TomText default slot widgets', () {
    test('defaultFor builds a TomText carrying id, scope and group', () {
      install({
        'card': {'title': 'Hello'},
      });
      final scope = TomScopeBase(scopeId: 'admin');
      final group = TomAuthorizationGroup('editors');
      final widget = TomText.defaultFor('card.title', scope, group);
      expect(widget, isNotNull);
      expect(widget!.tomId, 'card.title');
      expect(widget.scope, same(scope));
      expect(widget.tomGroup, same(group));
    });

    test('defaultFor returns null without an id', () {
      expect(TomText.defaultFor(null), isNull);
    });

    test('defaultOrEmpty builds the same widget when given an id', () {
      install({
        'card': {'title': 'Hello'},
      });
      final widget = TomText.defaultOrEmpty('card.title');
      expect(widget, isA<TomText>());
      expect((widget as TomText).tomId, 'card.title');
    });

    test('defaultOrEmpty substitutes an empty box without an id', () {
      // The whole difference between the two: one is for an optional slot a
      // caller may leave null, the other for a required slot that must always
      // produce a widget. Neither throws.
      final widget = TomText.defaultOrEmpty(null);
      expect(widget, isA<SizedBox>());
      expect((widget as SizedBox).width, 0.0);
      expect(widget.height, 0.0);
    });

    test('the id is relative — the widget resolves its own scope prefix', () {
      // The callers pass `TomCtr.childTomId(tomId, 'child')`, which is the
      // parent's *own* tomId plus a suffix, not a canonical path. Handing the
      // widget a pre-resolved path here would double the scope prefix, so the
      // helper must pass the id through untouched.
      final scope = TomScopeBase(scopeId: 'admin');
      final widget = TomText.defaultFor('card.child', scope);
      expect(widget!.tomId, 'card.child');
    });
  });
}
