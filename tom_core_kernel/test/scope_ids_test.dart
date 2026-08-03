import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // ===========================================================================
  // TomScope — zone-propagated hierarchical scope identifier
  // ===========================================================================
  group('TomScope', () {
    group('defaultScope / current', () {
      test('current resolves to defaultScope when no scope is installed', () {
        expect(TomScope.current, same(TomScope.defaultScope));
      });

      test('defaultScope has id "default" and no parent', () {
        expect(TomScope.defaultScope.id, equals('default'));
        expect(TomScope.defaultScope.parent, isNull);
      });

      test('defaultScope path is empty (default segment is skipped)', () {
        expect(TomScope.defaultScope.getScopePath(), isEmpty);
      });
    });

    group('withScope', () {
      test('installs a child scope parented to current for the body', () {
        TomScope.withScope('app', () {
          final scope = TomScope.current;
          expect(scope.id, equals('app'));
          expect(scope.parent, same(TomScope.defaultScope));
        });
      });

      test('restores the previous scope after the body returns', () {
        TomScope.withScope('app', () {
          expect(TomScope.current.id, equals('app'));
        });
        expect(TomScope.current, same(TomScope.defaultScope));
      });

      test('nests scopes and builds a dotted path', () {
        TomScope.withScope('app', () {
          TomScope.withScope('checkout', () {
            TomScope.withScope('orderForm', () {
              expect(TomScope.current.getScopePath(),
                  equals('app.checkout.orderForm'));
            });
          });
        });
      });

      test('returns the body result', () {
        final result = TomScope.withScope('app', () => 42);
        expect(result, equals(42));
      });

      test('single-level scope path equals the scope id', () {
        TomScope.withScope('app', () {
          expect(TomScope.current.getScopePath(), equals('app'));
        });
      });
    });

    group('runInScope', () {
      test('executes body within the receiver scope', () {
        final scope = TomScopeBase(scopeId: 'widget', parentScope: null);
        scope.runInScope(() {
          expect(TomScope.current, same(scope));
        });
      });

      test('is a no-op zone when the scope is already current (identity)', () {
        TomScope.withScope('app', () {
          final current = TomScope.current;
          // Re-entering the identical scope must not create a nested zone.
          current.runInScope(() {
            expect(TomScope.current, same(current));
          });
        });
      });

      test('restores the previous scope after the body returns', () {
        final scope = TomScopeBase(scopeId: 'widget', parentScope: null);
        scope.runInScope(() {
          expect(TomScope.current, same(scope));
        });
        expect(TomScope.current, same(TomScope.defaultScope));
      });
    });

    group('buildScopePath', () {
      test('skips the default scope segment', () {
        final scope = TomScopeBase(
          scopeId: 'app',
          parentScope: TomScope.defaultScope,
        );
        expect(TomScope.buildScopePath(scope), equals('app'));
      });

      test('joins a parent chain root-to-leaf with dots', () {
        final root = TomScopeBase(scopeId: 'app', parentScope: null);
        final mid = TomScopeBase(scopeId: 'checkout', parentScope: root);
        final leaf = TomScopeBase(scopeId: 'orderForm', parentScope: mid);
        expect(
          TomScope.buildScopePath(leaf),
          equals('app.checkout.orderForm'),
        );
      });

      // Bug §50 / tests §34a: only the actual root sentinel (defaultScope) is
      // elided from the path. A legitimate domain scope whose local id happens
      // to be 'default' is NOT the root sentinel and must appear in its path.
      test('keeps a non-root scope named "default" in the path', () {
        final root = TomScopeBase(scopeId: 'app', parentScope: null);
        final named = TomScopeBase(scopeId: 'default', parentScope: root);
        final leaf = TomScopeBase(scopeId: 'child', parentScope: named);

        expect(TomScope.buildScopePath(named), equals('app.default'));
        expect(TomScope.buildScopePath(leaf), equals('app.default.child'));
      });

      test('a scope named "default" parented to defaultScope keeps its segment', () {
        // Chain: named('default') -> defaultScope. The sentinel is skipped by
        // identity; the same-named domain scope is not the sentinel, so it stays.
        final named = TomScopeBase(
          scopeId: 'default',
          parentScope: TomScope.defaultScope,
        );
        expect(TomScope.buildScopePath(named), equals('default'));
      });

      test('withScope("default") yields a "default" path segment', () {
        final path = TomScope.withScope(
          'default',
          () => TomScope.current.getScopePath(),
        );
        expect(path, equals('default'));
      });
    });
  });

  // ===========================================================================
  // TomScopeBase — concrete TomScope built from id + optional parent
  // ===========================================================================
  group('TomScopeBase', () {
    test('exposes the supplied id and parent', () {
      final parent = TomScopeBase(scopeId: 'app', parentScope: null);
      final child = TomScopeBase(scopeId: 'checkout', parentScope: parent);
      expect(child.id, equals('checkout'));
      expect(child.parent, same(parent));
    });

    test('a null parent terminates the chain', () {
      final root = TomScopeBase(scopeId: 'app', parentScope: null);
      expect(root.parent, isNull);
      expect(root.getScopePath(), equals('app'));
    });
  });

  // ===========================================================================
  // TomScopeMixin — reusable scope identity mixed into an arbitrary class
  // ===========================================================================
  group('TomScopeMixin', () {
    test('a custom class using the mixin is a fully-formed TomScope', () {
      final app = _MixinScope(scopeId: 'app');
      final checkout = _MixinScope(scopeId: 'checkout', parentScope: app);
      expect(checkout, isA<TomScope>());
      expect(checkout.id, equals('checkout'));
      expect(checkout.parent, same(app));
      expect(checkout.getScopePath(), equals('app.checkout'));
    });

    test('runInScope installs and restores a custom mixin scope', () {
      final section = _MixinScope(scopeId: 'section');
      section.runInScope(() {
        expect(TomScope.current, same(section));
      });
      expect(TomScope.current, same(TomScope.defaultScope));
    });

    test('the custom mixin scope integrates with InScopeBuilder', () {
      final section = _MixinScope(scopeId: 'section');
      final wrapped = InScopeBuilder(scope: section)
          .wrap0<String>(() => TomScope.current.getScopePath());
      expect(wrapped(), equals('section'));
    });

    // initScope need not run from a constructor — it is the single write-once
    // entry point, so a scope may also be identified after construction.
    // (The `id` / `parent` setters this test used to exercise were removed in
    // tcca16: they wrote the same `late final` fields and only served to make
    // a supposedly write-once identity look assignable.)
    test('initScope assigns the identity after construction', () {
      final root = _MixinScope(scopeId: 'root');
      final lazy = _LazyMixinScope()
        ..initScope(scopeId: 'lazy', parentScope: root);
      expect(lazy.id, equals('lazy'));
      expect(lazy.parent, same(root));
      expect(lazy.getScopePath(), equals('root.lazy'));
    });

    // tcca16: `defaultScope` is the root of every scope path, so a reassignment
    // would change resource resolution for the whole process. It is `final`;
    // `withScope` / `runInScope` are the supported ways to change the current
    // scope, and they cannot outlive their body.
    test('the default scope is restored after every scoped body', () {
      final root = TomScope.defaultScope;
      TomScope.withScope('transient', () {
        expect(TomScope.current, isNot(same(root)));
      });
      expect(TomScope.current, same(root));
      expect(TomScope.defaultScope, same(root));
    });
  });

  // ===========================================================================
  // InScopeBuilder — wraps callbacks so they run in a captured scope
  // ===========================================================================
  group('InScopeBuilder', () {
    test('captures the current scope at construction by default', () {
      late InScopeBuilder builder;
      TomScope.withScope('captured', () {
        builder = InScopeBuilder();
      });
      // Called outside the original zone — wrap0 must restore the scope.
      final wrapped = builder.wrap0<String>(() => TomScope.current.getScopePath());
      expect(wrapped(), equals('captured'));
    });

    test('uses an explicitly supplied scope over current', () {
      final explicit = TomScopeBase(scopeId: 'explicit', parentScope: null);
      final builder = InScopeBuilder(scope: explicit);
      final wrapped =
          builder.wrap0<String>(() => TomScope.current.getScopePath());
      expect(wrapped(), equals('explicit'));
    });

    test('wrap1 restores the scope and forwards the argument', () {
      late InScopeBuilder builder;
      TomScope.withScope('captured', () {
        builder = InScopeBuilder();
      });
      final wrapped = builder.wrap1<String, int>(
        (a) => '${TomScope.current.getScopePath()}:$a',
      );
      expect(wrapped(7), equals('captured:7'));
    });

    test('wrap2..wrap5 restore the scope and forward all arguments', () {
      late InScopeBuilder builder;
      TomScope.withScope('captured', () {
        builder = InScopeBuilder();
      });
      final w2 = builder.wrap2<String, int, int>(
          (a, b) => '${TomScope.current.getScopePath()}:${a + b}');
      final w3 = builder.wrap3<int, int, int, int>((a, b, c) {
        expect(TomScope.current.getScopePath(), equals('captured'));
        return a + b + c;
      });
      final w4 = builder.wrap4<int, int, int, int, int>((a, b, c, d) {
        expect(TomScope.current.getScopePath(), equals('captured'));
        return a + b + c + d;
      });
      final w5 = builder.wrap5<int, int, int, int, int, int>((a, b, c, d, e) {
        expect(TomScope.current.getScopePath(), equals('captured'));
        return a + b + c + d + e;
      });
      expect(w2(2, 3), equals('captured:5'));
      expect(w3(1, 2, 3), equals(6));
      expect(w4(1, 2, 3, 4), equals(10));
      expect(w5(1, 2, 3, 4, 5), equals(15));
    });

    test('nullable wrappers return null for null callbacks', () {
      final builder = InScopeBuilder(
        scope: TomScopeBase(scopeId: 'x', parentScope: null),
      );
      expect(builder.wrap0n<int>(null), isNull);
      expect(builder.wrap1n<int, int>(null), isNull);
      expect(builder.wrap2n<int, int, int>(null), isNull);
      expect(builder.wrap3n<int, int, int, int>(null), isNull);
      expect(builder.wrap4n<int, int, int, int, int>(null), isNull);
      expect(builder.wrap5n<int, int, int, int, int, int>(null), isNull);
    });

    test('nullable wrappers wrap non-null callbacks in the captured scope', () {
      late InScopeBuilder builder;
      TomScope.withScope('captured', () {
        builder = InScopeBuilder();
      });
      final wrapped =
          builder.wrap1n<String, int>((a) => TomScope.current.getScopePath());
      expect(wrapped, isNotNull);
      expect(wrapped!(1), equals('captured'));
    });

    test('wrapCounter restores the scope and forwards named arguments', () {
      late InScopeBuilder builder;
      TomScope.withScope('captured', () {
        builder = InScopeBuilder();
      });
      final wrapped = builder.wrapCounter<String, int, int, int, bool>(
        (a, {required currentLength, required maxLength, required isFocused}) =>
            '${TomScope.current.getScopePath()}:$a:$currentLength:$maxLength:$isFocused',
      );
      expect(
        wrapped(1, currentLength: 2, maxLength: 3, isFocused: true),
        equals('captured:1:2:3:true'),
      );
    });
  });
}

/// A custom domain class that becomes a [TomScope] purely through the mixin,
/// initialising its identity via [TomScopeMixin.initScope].
class _MixinScope with TomScopeMixin {
  _MixinScope({required String scopeId, TomScope? parentScope}) {
    initScope(scopeId: scopeId, parentScope: parentScope);
  }
}

/// A mixin scope whose identity is assigned after construction, by calling
/// [TomScopeMixin.initScope] on the instance.
class _LazyMixinScope with TomScopeMixin {}
