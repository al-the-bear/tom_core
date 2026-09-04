import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// A resource path is `<scopePath>.<tomId>`, with the dot dropped when the
// scope path is empty. That is one rule, and it was written out by hand in
// nine places — the widget base, the group mixin, four custom widgets, the
// ACL container widget and both halves of the form layer. Nine copies pass
// every existing test because they currently agree; they stop agreeing the
// moment the rule changes (a different separator, a normalisation step, a
// guard on an empty id), and the copy that is missed fails silently by
// resolving a path that exists but belongs to something else.
//
// `TomScopePath` is now the one implementation. These tests hold both halves
// of that: the composition rule behaves as documented, and no file in `lib/`
// re-derives it.

/// Files permitted to call `TomScope.getScopePath()` directly, mapped to the
/// number of calls each is allowed.
///
/// Everything else must go through [TomScopePath], which is the only place the
/// scope path and an id are joined. The entries here are not exemptions granted
/// for convenience — each one needs the *raw* scope path for something other
/// than a two-segment join:
///
/// - `tom_scope_path.dart` is the implementation itself.
/// - `tom_form.dart` exposes the scope path as a public getter, and derives a
///   field's base path from either its form's `basePath` or the ambient scope
///   path — a `String` either way, so it joins with [TomScopePath.join] and
///   still has to read the scope path to produce one of the two operands.
/// - `acl_container.dart` builds *multi-segment* policy paths whose middle
///   segments are opt-in (`idScope`), which is a different rule, not this one
///   with extra steps.
/// - `tom_screen_elements_provider.dart` forwards its own scope path to the
///   scope it passes through to, and to `super` otherwise. It composes
///   nothing: both operands of a join would have to exist for that, and here
///   there is one path and no id.
const _rawScopePathReaders = <String, int>{
  'lib/src/widget_base/tom_scope_path.dart': 1,
  'lib/src/forms/tom_form.dart': 2,
  'lib/src/advanced_container_layout/acl_container.dart': 2,
  'lib/src/widget_base/tom_screen_elements_provider.dart': 2,
};

/// Every `.dart` file under `lib/`, as workspace-relative paths.
List<String> _libSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.dart'))
        .toList()
      ..sort();

/// Matches the signature of a `getScopePath()` override, which declares the
/// method rather than calling it.
final _scopePathDeclaration = RegExp(r'\bString\s+getScopePath\s*\(');

/// Counts `getScopePath()` calls in [path], ignoring comment lines and the
/// method's own declaration.
///
/// Dartdoc regularly names the method in prose (`[TomScope.current
/// .getScopePath()]`), and a documentation mention is not a second
/// implementation — only executable code can drift. A class that *implements*
/// the method is likewise not reading a scope path, so its signature line does
/// not count; the calls in its body still do.
int _scopePathCalls(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .where((line) => line.contains('getScopePath()'))
    .where((line) => !_scopePathDeclaration.hasMatch(line))
    .length;

void main() {
  group('TomScopePath composition', () {
    test('join puts a dot between a parent path and an id', () {
      expect(TomScopePath.join('checkout', 'field'), 'checkout.field');
    });

    test('join drops the dot when the parent path is empty', () {
      expect(TomScopePath.join('', 'field'), 'field');
    });

    test('join keeps a multi-segment parent path intact', () {
      expect(
        TomScopePath.join('checkout.payment', 'field'),
        'checkout.payment.field',
      );
    });

    test('qualify prefixes an id with an explicit scope', () {
      expect(
        TomScopePath.qualify('field', TomScopeBase(scopeId: 'admin')),
        'admin.field',
      );
    });

    test('qualify falls back to the ambient scope', () {
      TomScope.withScope('checkout', () {
        expect(TomScopePath.qualify('field'), 'checkout.field');
      });
    });

    test('qualify leaves the id bare outside any scope', () {
      // The root sentinel contributes no segment.
      expect(TomScopePath.qualify('field'), 'field');
    });

    test('resolve returns null for a null id', () {
      // A node without a tomId has no resource path at all — that is the
      // difference between `resolve` and `qualify`, and the reason widgets
      // whose id is optional call this one.
      TomScope.withScope('checkout', () {
        expect(TomScopePath.resolve(null), isNull);
      });
    });

    test('resolve qualifies a non-null id', () {
      TomScope.withScope('checkout', () {
        expect(TomScopePath.resolve('field'), 'checkout.field');
      });
    });

    test('resolve honours an explicit scope over the ambient one', () {
      final explicit = TomScopeBase(scopeId: 'admin');
      TomScope.withScope('checkout', () {
        expect(TomScopePath.resolve('field', explicit), 'admin.field');
      });
    });

    test('nested scopes compose left to right', () {
      TomScope.withScope('checkout', () {
        TomScope.withScope('payment', () {
          expect(TomScopePath.resolve('field'), 'checkout.payment.field');
        });
      });
    });
  });

  group('TomCtr.resolvePath forwards to TomScopePath', () {
    // `TomCtr.resolvePath` is the name ~30 widgets call, and nothing in the
    // suite exercised it — it was a second hand-written copy of the rule for
    // as long as it went unread. It is a forwarder now; these pin that it
    // agrees with what it forwards to, for every shape of input.

    test('a null id resolves to null', () {
      TomScope.withScope('checkout', () {
        expect(TomCtr.resolvePath(null), isNull);
      });
    });

    test('an ambient scope prefixes the id', () {
      TomScope.withScope('checkout', () {
        expect(TomCtr.resolvePath('field'), 'checkout.field');
      });
    });

    test('no ambient scope leaves the id unprefixed', () {
      expect(TomCtr.resolvePath('field'), 'field');
    });

    test('an explicit scope overrides the ambient one', () {
      final explicit = TomScopeBase(scopeId: 'admin');
      TomScope.withScope('checkout', () {
        expect(TomCtr.resolvePath('field', explicit), 'admin.field');
      });
    });

    test('it agrees with TomScopePath.resolve on every input', () {
      final explicit = TomScopeBase(scopeId: 'admin');
      TomScope.withScope('checkout', () {
        for (final id in <String?>[null, 'field', 'a.b']) {
          expect(TomCtr.resolvePath(id), TomScopePath.resolve(id));
          expect(
            TomCtr.resolvePath(id, explicit),
            TomScopePath.resolve(id, explicit),
          );
        }
      });
    });
  });

  group('no file re-derives the composition rule', () {
    // Source-reading on purpose: the claim is that the rule is written down
    // once, and a tenth hand-written copy would satisfy every behavioural test
    // above while reintroducing exactly the drift the single copy prevents.

    test('only the listed files read the raw scope path', () {
      final offenders = <String, int>{};
      for (final path in _libSources()) {
        final calls = _scopePathCalls(path);
        if (calls == 0) continue;
        if (_rawScopePathReaders[path] == calls) continue;
        offenders[path] = calls;
      }
      expect(offenders, isEmpty);
    });

    test('every listed file still reads it, and exactly as often', () {
      // The allowlist decays the other way too: an entry left behind after its
      // call was removed makes the guard above accept a file it should now
      // reject outright.
      final actual = <String, int>{
        for (final path in _rawScopePathReaders.keys)
          path: _scopePathCalls(path),
      };
      expect(actual, _rawScopePathReaders);
    });

    test('no file joins a scope path to an id inline', () {
      // The interpolation is the tell — `'$scopePath.$id'` in any form is the
      // rule being written out again rather than called.
      final inlineJoin = RegExp(r"'\$\w*[Ss]cope\w*\.\$");
      final offenders = <String>[];
      for (final path in _libSources()) {
        if (_rawScopePathReaders.containsKey(path)) continue;
        final source = File(path).readAsStringSync();
        if (inlineJoin.hasMatch(source)) offenders.add(path);
      }
      expect(offenders, isEmpty);
    });
  });
}
