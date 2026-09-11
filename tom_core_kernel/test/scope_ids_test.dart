import 'dart:async';

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

      test('defaultScope has an empty path (the sentinel adds no segment)', () {
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
              expect(
                TomScope.current.getScopePath(),
                equals('app.checkout.orderForm'),
              );
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

      // `withScope` always builds a *new* scope parented to `current`, so
      // re-entering the same id nests rather than recognising itself: the path
      // repeats the segment. `runInScope` behaves differently for the same
      // nesting, because it short-circuits on instance identity and there is
      // one instance to recognise.
      //
      // The repetition is the contract. Two nested bodies that each asked for
      // `app` are two namespaces; collapsing them by name would give the inner
      // one the outer one's resource keys, which is the by-name rule this
      // module replaced with an identity one. Code that can be nested inside
      // itself — a widget subtree that installs its own scope — holds the
      // scope and uses `runInScope`, which the next test pins.
      test('re-entering the same id nests and repeats the path segment', () {
        final repeated = TomScope.withScope(
          'app',
          () => TomScope.withScope('app', () {
            expect(
              TomScope.current.parent?.getScopePath(),
              equals('app'),
              reason: 'the inner scope is a distinct child, not the outer one',
            );
            return TomScope.current.getScopePath();
          }),
        );
        expect(repeated, equals('app.app'));
      });

      test('re-entering the same instance does NOT repeat the segment', () {
        // The contrast that makes the case above a property of `withScope`
        // rather than of scopes: given an instance, `runInScope` recognises it.
        final app = TomScopeBase(scopeId: 'app');
        final path = app.runInScope(
          () => app.runInScope(() => TomScope.current.getScopePath()),
        );
        expect(path, equals('app'));
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
          final zoneOutside = Zone.current;
          var ran = false;

          // It is the zone that is elided, not the call: the body still runs
          // and its result is still returned. Asserting only that
          // `TomScope.current` is unchanged would not pin this — installing
          // the identical scope on a child zone resolves to the same value,
          // so that assertion holds on both branches. `Zone.current` is what
          // tells them apart.
          final result = current.runInScope(() {
            ran = true;
            expect(TomScope.current, same(current));
            expect(Zone.current, same(zoneOutside));
            return 'body-result';
          });

          expect(ran, isTrue);
          expect(result, equals('body-result'));
        });
      });

      test('installs a child zone when the scope is not already current', () {
        TomScope.withScope('app', () {
          final zoneOutside = Zone.current;
          final other = TomScopeBase(scopeId: 'widget', parentScope: null);

          final result = other.runInScope(() {
            expect(TomScope.current, same(other));
            expect(Zone.current, isNot(same(zoneOutside)));
            return 'body-result';
          });

          expect(result, equals('body-result'));
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
      test('elides the root sentinel from a chain rooted at it', () {
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
        expect(TomScope.buildScopePath(leaf), equals('app.checkout.orderForm'));
      });

      // Only the actual root sentinel (defaultScope) is elided from the path.
      // A legitimate domain scope whose local id happens to be 'default' is
      // NOT the root sentinel and must appear in its path.
      test('keeps a non-root scope named "default" in the path', () {
        final root = TomScopeBase(scopeId: 'app', parentScope: null);
        final named = TomScopeBase(scopeId: 'default', parentScope: root);
        final leaf = TomScopeBase(scopeId: 'child', parentScope: named);

        expect(TomScope.buildScopePath(named), equals('app.default'));
        expect(TomScope.buildScopePath(leaf), equals('app.default.child'));
      });

      test(
        'a scope named "default" parented to defaultScope keeps its segment',
        () {
          // Chain: named('default') -> defaultScope. The sentinel is skipped by
          // identity; the same-named domain scope is not the sentinel, so it stays.
          final named = TomScopeBase(
            scopeId: 'default',
            parentScope: TomScope.defaultScope,
          );
          expect(TomScope.buildScopePath(named), equals('default'));
        },
      );

      test('withScope("default") yields a "default" path segment', () {
        final path = TomScope.withScope(
          'default',
          () => TomScope.current.getScopePath(),
        );
        expect(path, equals('default'));
      });

      // The path is the module's entire output — a resource-lookup and
      // authorization prefix. A '.' inside an id is therefore not a cosmetic
      // problem: it forges a segment boundary, so one scope renders as a path
      // belonging to a different, deeper chain. An empty id is the same defect
      // from the other side, and worse at the root, where it renders as '' —
      // the string consumers are told means "no scope at all".
      group('scope ids are validated', () {
        void expectRejected(String id, void Function() build) {
          expect(
            build,
            throwsA(
              isA<TomScopeException>().having(
                (e) => e.parameters?['scopeId'],
                'the offending id',
                equals(id),
              ),
            ),
            reason: 'id "$id" must be refused',
          );
        }

        // Every route runs through initScope, so all three are one check —
        // but all three are public, so all three are pinned.
        for (final id in const ['a.b', '.', 'a.', '.a', '']) {
          test('withScope refuses "$id"', () {
            expectRejected(id, () => TomScope.withScope(id, () {}));
          });

          test('the TomScopeBase constructor refuses "$id"', () {
            expectRejected(id, () => TomScopeBase(scopeId: id));
          });

          test('initScope refuses "$id"', () {
            expectRejected(id, () => _LazyMixinScope().initScope(scopeId: id));
          });
        }

        // The defect itself: without the check these two chains are byte-equal,
        // so a scope named from data can name another scope's resources.
        test('a dotted id can no longer forge a deeper chain', () {
          final threeSegments = TomScopeBase(
            scopeId: 'c',
            parentScope: TomScopeBase(
              scopeId: 'b',
              parentScope: TomScopeBase(scopeId: 'a'),
            ),
          );
          expect(threeSegments.getScopePath(), equals('a.b.c'));

          // The chain that used to render identically cannot be built at all.
          expect(
            () => TomScopeBase(scopeId: 'a.b'),
            throwsA(isA<TomScopeException>()),
          );
        });

        // Rejecting must not mutate: the instance is still a blank slate, so a
        // caller that catches the error and retries with a clean id succeeds.
        test('a refused id leaves the instance still initialisable', () {
          final lazy = _LazyMixinScope();
          expect(
            () => lazy.initScope(scopeId: 'bad.id'),
            throwsA(isA<TomScopeException>()),
          );

          lazy.initScope(scopeId: 'good');
          expect(lazy.getScopePath(), equals('good'));
        });

        // The check must reject the ambiguity, not police the alphabet:
        // anything that cannot forge a segment boundary stays legal.
        test('ids that cannot forge a boundary are still accepted', () {
          for (final id in const [
            'orderForm',
            'ft_text',
            'lay-pair',
            'row/42',
            'tenant name',
            'Ünïcödé',
            '默认',
            'a·b', // U+00B7, a middle dot — not the separator
          ]) {
            expect(
              () => TomScopeBase(scopeId: id).getScopePath(),
              returnsNormally,
              reason: 'id "$id" is unambiguous and must be allowed',
            );
          }
        });

        test('the message names the id and the rule it broke', () {
          expect(
            () => TomScopeBase(scopeId: 'a.b'),
            throwsA(
              isA<TomScopeException>()
                  .having((e) => e.key, 'key', contains('scope_ids'))
                  .having(
                    (e) => e.defaultUserMessage,
                    'message',
                    allOf(contains('a.b'), contains('.')),
                  ),
            ),
          );
        });
      });

      // The walk up the parent chain has no cycle guard: it is iterative, so a
      // loop does not raise StackOverflowError — it spins silently, growing the
      // segment list until the heap is exhausted and the isolate dies.
      //
      // That is safe only because a scope built through this module cannot form
      // a cycle, and these tests are what make "cannot" checkable. Each one
      // closes one of the three ways a parent link could ever be bent back:
      // there is no fourth, because `_parent` is written once and only by
      // initScope. The cycle itself is deliberately not tested — a test that
      // hangs the isolate until the VM dies takes the suite with it.
      group('the parent chain cannot be made cyclic', () {
        test('a parent that has no identity yet is refused', () {
          // The only ordering that could close a loop: point A at B while B is
          // still unborn, then give B its identity with A as *its* parent.
          // Refusing the first half is what makes a parent strictly older than
          // its child, and a strictly-increasing chain cannot return to itself.
          final a = _LazyMixinScope();
          final b = _LazyMixinScope();

          expect(
            () => a.initScope(scopeId: 'a', parentScope: b),
            throwsA(isA<TomScopeException>()),
          );
        });

        test('a scope cannot be its own parent', () {
          final a = _LazyMixinScope();
          expect(
            () => a.initScope(scopeId: 'a', parentScope: a),
            throwsA(isA<TomScopeException>()),
          );
        });

        test('an established parent link cannot be re-pointed', () {
          // Every parent being older than its child only rules out cycles while
          // the links stay put. They do: the identity is written once, so a
          // second initScope is refused rather than bending the chain back.
          final root = _MixinScope(scopeId: 'root');
          final child = _MixinScope(scopeId: 'child', parentScope: root);

          expect(
            () => child.initScope(scopeId: 'child', parentScope: root),
            throwsA(
              isA<TomScopeException>().having(
                (e) => e.key,
                'key',
                equals('scope_ids.init_scope.already_initialised'),
              ),
            ),
          );
          expect(child.parent, same(root), reason: 'the link must be intact');
        });
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

    test('the custom mixin scope integrates with ScopeCapture', () {
      final section = _MixinScope(scopeId: 'section');
      final wrapped = ScopeCapture(
        scope: section,
      ).wrap0<String>(() => TomScope.current.getScopePath());
      expect(wrapped(), equals('section'));
    });

    // initScope need not run from a constructor — it is the single write-once
    // entry point, so a scope may also be identified after construction. There
    // is no setter for `id` or `parent`: both are `late final`, and a
    // write-once identity must not offer an API that looks assignable.
    test('initScope assigns the identity after construction', () {
      final root = _MixinScope(scopeId: 'root');
      final lazy = _LazyMixinScope()
        ..initScope(scopeId: 'lazy', parentScope: root);
      expect(lazy.id, equals('lazy'));
      expect(lazy.parent, same(root));
      expect(lazy.getScopePath(), equals('root.lazy'));
    });

    // =========================================================================
    // The window between construction and initScope
    // =========================================================================
    //
    // Because initScope may run after construction, an instance exists for a
    // while that is not yet a scope. Reading its identity has always failed;
    // what these tests pin is that *installing* it fails too, and at the point
    // of installation rather than at whichever unrelated call later asks for a
    // path. A scope reaching `TomScope.current` is therefore always usable.
    group('before initScope has run', () {
      // The failure has to name the class and the missing call, because the
      // stack it surfaces on is otherwise about resource lookup or
      // authorization and says nothing about scopes at all.
      void expectNamesTypeAndInitScope(void Function() action) {
        expect(
          action,
          throwsA(
            isA<TomScopeException>().having(
              (e) => e.defaultUserMessage,
              'message',
              allOf(contains('_LazyMixinScope'), contains('initScope')),
            ),
          ),
        );
      }

      test(
        'runInScope refuses to install the scope, and the body never runs',
        () {
          final lazy = _LazyMixinScope();
          var ran = false;
          expectNamesTypeAndInitScope(() => lazy.runInScope(() => ran = true));
          expect(
            ran,
            isFalse,
            reason: 'the body must not run in a broken scope',
          );
          expect(TomScope.current, same(TomScope.defaultScope));
        },
      );

      // Guarding only the installed scope would leave this hole open: the
      // child is a perfectly good scope, so installing it passes, and the
      // chain walk only reaches the broken parent when someone asks for a
      // path. Rejecting the parent at initScope keeps the check O(1) — every
      // initialised scope then has a fully initialised chain by induction.
      test("it cannot be used as another scope's parent", () {
        expectNamesTypeAndInitScope(
          () => _MixinScope(scopeId: 'child', parentScope: _LazyMixinScope()),
        );
      });

      test('ScopeCapture refuses to run a callback in the captured scope', () {
        final wrapped = ScopeCapture(
          scope: _LazyMixinScope(),
        ).wrap0<String>(() => TomScope.current.getScopePath());
        expectNamesTypeAndInitScope(wrapped);
      });

      // Reading the identity directly already threw, but as a
      // LateInitializationError naming a mangled private field. The diagnosis
      // is the same whichever door you came through, so the message is too.
      test('reading the identity names the type and the missing call', () {
        expectNamesTypeAndInitScope(() => _LazyMixinScope().id);
        expectNamesTypeAndInitScope(() => _LazyMixinScope().parent);
        expectNamesTypeAndInitScope(() => _LazyMixinScope().getScopePath());
      });

      // The guard must close the window, not the pattern: assigning the
      // identity after construction is documented and supported.
      test('once initScope has run the scope installs normally', () {
        final root = _MixinScope(scopeId: 'root');
        final lazy = _LazyMixinScope()
          ..initScope(scopeId: 'lazy', parentScope: root);
        lazy.runInScope(() {
          expect(TomScope.current, same(lazy));
          expect(TomScope.current.getScopePath(), equals('root.lazy'));
        });
      });
    });

    // The identity is write-once. That is not a stylistic preference: the
    // acyclicity argument for the unguarded walk in `buildScopePath` holds only
    // because links, once written, stay written, and `runInScope`'s identity
    // short-circuit assumes a scope's path does not change under it.
    //
    // `late final` supplies the enforcement, so the tests below are pinning a
    // language guarantee rather than a hand-written check. They earn their
    // place anyway: nothing stops someone relaxing the fields to plain
    // mutables, and the failure that would cause — a path that changes after
    // something cached it — surfaces nowhere near the change.
    group('after initScope has run', () {
      // A second call is refused in the module's own words. Left to the
      // `late final` fields, it surfaced as a LateInitializationError naming a
      // VM-mangled private field (`_id@23310018`) — correct, and unreadable to
      // anyone who does not know the mixin's internals.
      Matcher refusedAsAlreadyInitialised({
        required String type,
        required String existing,
        required String attempted,
      }) => throwsA(
        isA<TomScopeException>()
            .having(
              (e) => e.key,
              'key',
              equals('scope_ids.init_scope.already_initialised'),
            )
            .having((e) => e.parameters, 'parameters', {
              'type': type,
              'scopeId': existing,
              'attemptedScopeId': attempted,
            })
            .having(
              (e) => e.defaultUserMessage,
              'message',
              allOf(contains(type), contains(existing), contains('initScope')),
            ),
      );

      test('a second initScope is refused, naming the scope it would move', () {
        final lazy = _LazyMixinScope()..initScope(scopeId: 'first');
        expect(
          () => lazy.initScope(scopeId: 'second'),
          refusedAsAlreadyInitialised(
            type: '_LazyMixinScope',
            existing: 'first',
            attempted: 'second',
          ),
        );
      });

      test('repeating the same values is refused too', () {
        // Write-once means once: a base and a subclass constructor that both
        // initialise are two owners of the identity, even when they agree.
        final scope = _MixinScope(scopeId: 'same');
        expect(
          () => scope.initScope(scopeId: 'same'),
          refusedAsAlreadyInitialised(
            type: '_MixinScope',
            existing: 'same',
            attempted: 'same',
          ),
        );
      });

      test('a refused second call moves neither the id nor the parent', () {
        final root = _MixinScope(scopeId: 'root');
        final other = _MixinScope(scopeId: 'other');
        final child = _MixinScope(scopeId: 'child', parentScope: root);

        // Both fields differ from the established ones, so a partial write
        // would show up as a changed id even if the parent survived.
        expect(
          () => child.initScope(scopeId: 'renamed', parentScope: other),
          refusedAsAlreadyInitialised(
            type: '_MixinScope',
            existing: 'child',
            attempted: 'renamed',
          ),
        );

        expect(child.id, equals('child'));
        expect(child.parent, same(root));
        expect(child.getScopePath(), equals('root.child'));
      });

      test('an unusable id is refused before the write-once field is', () {
        // When both rules are broken at once the id check wins, because it runs
        // first: an id that can never be valid is the more fundamental mistake,
        // and fixing only the double call would leave it in place.
        final scope = _LazyMixinScope()..initScope(scopeId: 'kept');
        expect(
          () => scope.initScope(scopeId: 'a.b'),
          throwsA(
            isA<TomScopeException>().having(
              (e) => e.key,
              'key',
              equals('scope_ids.init_scope.separator_in_id'),
            ),
          ),
        );
        expect(scope.id, equals('kept'));
      });
    });

    // `defaultScope` is the root of every scope path, so a reassignment would
    // change resource resolution for the whole process. It is `final`;
    // `withScope` / `runInScope` are the supported ways to change the current
    // scope, and they change it only for that body and the callbacks it
    // schedules — never for the caller. (What they do *not* bound is the
    // scope's lifetime; see the `zone propagation` group.)
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
  // Zone propagation — what a scope's lifetime actually is
  // ===========================================================================
  //
  // A zone bounds *reachability*, not *lifetime*. These tests pin both halves
  // of that, because "a scope cannot outlive its body" is the sentence a
  // reader reaches for when deciding whether a scope needs tearing down — and
  // it is false the moment the body schedules anything.
  //
  // The distinction between the two groups below is also the entire reason
  // ScopeCapture exists: async-scheduled callbacks inherit the zone for
  // free, and directly-invoked stored closures do not.
  group('zone propagation', () {
    group('a scope DOES outlive the body it was installed for', () {
      test('a Timer scheduled inside the body observes the scope', () async {
        final fired = Completer<String>();
        TomScope.withScope('app', () {
          Timer.run(() => fired.complete(TomScope.current.getScopePath()));
        });

        // The body has already returned by the time the timer fires.
        expect(TomScope.current, same(TomScope.defaultScope));
        expect(await fired.future, equals('app'));
      });

      test(
        'an unawaited Future started inside the body keeps the scope',
        () async {
          final ran = Completer<String>();
          TomScope.withScope('background', () {
            // Fire-and-forget: nothing awaits this, and it outlives the body.
            unawaited(
              Future<void>.microtask(
                () => ran.complete(TomScope.current.getScopePath()),
              ),
            );
          });

          expect(await ran.future, equals('background'));
        },
      );

      test(
        'a stream subscription opened inside the body keeps the scope',
        () async {
          final controller = StreamController<int>();
          final seen = Completer<String>();
          TomScope.withScope('stream', () {
            controller.stream.listen(
              (_) => seen.complete(TomScope.current.getScopePath()),
            );
          });

          controller.add(1);
          expect(await seen.future, equals('stream'));
          await controller.close();
        },
      );

      test('the scope survives an await inside an async body', () async {
        late String beforeAwait;
        late String afterAwait;
        await TomScope.withScope('outer', () async {
          beforeAwait = TomScope.current.getScopePath();
          await Future<void>.delayed(Duration.zero);
          afterAwait = TomScope.current.getScopePath();
        });

        expect(beforeAwait, equals('outer'));
        expect(afterAwait, equals('outer'));
      });
    });

    group('what a zone DOES guarantee', () {
      test(
        'the caller continues in its own scope, never the installed one',
        () async {
          TomScope.withScope('installed', () {
            Timer.run(() {});
          });

          // The guarantee is about the caller, not about elapsed time: no matter
          // what the body scheduled, this code is unaffected.
          expect(TomScope.current, same(TomScope.defaultScope));
          await Future<void>.delayed(Duration.zero);
          expect(TomScope.current, same(TomScope.defaultScope));
        },
      );

      test('a plain closure stored in the body runs in the INVOKER scope', () {
        late String Function() stored;
        TomScope.withScope('origin', () {
          stored = () => TomScope.current.getScopePath();
        });

        // Zone inheritance covers callbacks the async machinery schedules, not
        // a closure someone else calls directly later. This is the gap that
        // ScopeCapture closes.
        expect(stored(), isEmpty);
        TomScope.withScope('elsewhere', () {
          expect(stored(), equals('elsewhere'));
        });
      });

      test('ScopeCapture closes that gap for a stored closure', () {
        late String Function() wrapped;
        TomScope.withScope('origin', () {
          wrapped = ScopeCapture().wrap0<String>(
            () => TomScope.current.getScopePath(),
          );
        });

        // Same shape as the previous test, but the callback keeps its own
        // scope instead of adopting the invoker's.
        expect(wrapped(), equals('origin'));
        TomScope.withScope('elsewhere', () {
          expect(wrapped(), equals('origin'));
        });
      });
    });
  });

  // ===========================================================================
  // ScopeCapture — wraps callbacks so they run in a captured scope
  // ===========================================================================
  group('ScopeCapture', () {
    test('captures the current scope at construction by default', () {
      late ScopeCapture builder;
      TomScope.withScope('captured', () {
        builder = ScopeCapture();
      });
      // Called outside the original zone — wrap0 must restore the scope.
      final wrapped = builder.wrap0<String>(
        () => TomScope.current.getScopePath(),
      );
      expect(wrapped(), equals('captured'));
    });

    test('uses an explicitly supplied scope over current', () {
      final explicit = TomScopeBase(scopeId: 'explicit', parentScope: null);
      final builder = ScopeCapture(scope: explicit);
      final wrapped = builder.wrap0<String>(
        () => TomScope.current.getScopePath(),
      );
      expect(wrapped(), equals('explicit'));
    });

    test('wrap1 restores the scope and forwards the argument', () {
      late ScopeCapture builder;
      TomScope.withScope('captured', () {
        builder = ScopeCapture();
      });
      final wrapped = builder.wrap1<String, int>(
        (a) => '${TomScope.current.getScopePath()}:$a',
      );
      expect(wrapped(7), equals('captured:7'));
    });

    test('wrap2..wrap5 restore the scope and forward all arguments', () {
      late ScopeCapture builder;
      TomScope.withScope('captured', () {
        builder = ScopeCapture();
      });
      final w2 = builder.wrap2<String, int, int>(
        (a, b) => '${TomScope.current.getScopePath()}:${a + b}',
      );
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
      final builder = ScopeCapture(
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
      late ScopeCapture builder;
      TomScope.withScope('captured', () {
        builder = ScopeCapture();
      });

      // Every arity, not just wrap1n: each `wrapNn` is a separate hand-written
      // forwarding body, so "one of them installs the scope" says nothing about
      // the other five. Each also forwards its full argument list, which is
      // where a copy-paste arity bug would hide.
      final w0 = builder.wrap0n<String>(() => TomScope.current.getScopePath());
      final w1 = builder.wrap1n<String, int>(
        (a) => '${TomScope.current.getScopePath()}:$a',
      );
      final w2 = builder.wrap2n<String, int, int>(
        (a, b) => '${TomScope.current.getScopePath()}:$a$b',
      );
      final w3 = builder.wrap3n<String, int, int, int>(
        (a, b, c) => '${TomScope.current.getScopePath()}:$a$b$c',
      );
      final w4 = builder.wrap4n<String, int, int, int, int>(
        (a, b, c, d) => '${TomScope.current.getScopePath()}:$a$b$c$d',
      );
      final w5 = builder.wrap5n<String, int, int, int, int, int>(
        (a, b, c, d, e) => '${TomScope.current.getScopePath()}:$a$b$c$d$e',
      );

      expect(w0!(), equals('captured'));
      expect(w1!(1), equals('captured:1'));
      expect(w2!(1, 2), equals('captured:12'));
      expect(w3!(1, 2, 3), equals('captured:123'));
      expect(w4!(1, 2, 3, 4), equals('captured:1234'));
      expect(w5!(1, 2, 3, 4, 5), equals('captured:12345'));
    });

    // Every test above captures a scope and invokes the wrapper outside it, so
    // all of them pass whether the wrapper *installs* the captured scope or
    // merely fails to disturb the ambient one — at the point of invocation the
    // ambient scope is the root either way.
    //
    // These two run it the other way round. That direction is the whole point
    // of the class: a Flutter builder captured at the top of a tree can be
    // invoked from deep inside an unrelated scope, and it must resolve
    // resources against where it was *built*, not where it happened to be
    // called from.
    group('the captured scope replaces the ambient one, not just the root', () {
      test('a builder captured outside any scope resets an ambient scope', () {
        final builder = ScopeCapture();
        final wrapped = builder.wrap0<String>(
          () => TomScope.current.getScopePath(),
        );

        TomScope.withScope('elsewhere', () {
          expect(
            TomScope.current.getScopePath(),
            equals('elsewhere'),
            reason:
                'the ambient scope must be non-empty for this to prove '
                'anything',
          );
          expect(
            wrapped(),
            isEmpty,
            reason:
                'the wrapper captured the root, so it must install the '
                'root — not inherit "elsewhere"',
          );
        });
      });

      test('a builder captured in one scope overrides a different one', () {
        late ScopeCapture builder;
        TomScope.withScope('a', () => builder = ScopeCapture());
        final wrapped = builder.wrap1<String, int>(
          (n) => '${TomScope.current.getScopePath()}:$n',
        );

        TomScope.withScope('b', () {
          expect(wrapped(7), equals('a:7'));
        });

        // And nesting does not accumulate: the captured scope is absolute, not
        // a prefix applied to wherever the call happens.
        TomScope.withScope('b', () {
          TomScope.withScope('c', () {
            expect(wrapped(7), equals('a:7'));
          });
        });
      });
    });

    test('wrapCounter restores the scope and forwards named arguments', () {
      late ScopeCapture builder;
      TomScope.withScope('captured', () {
        builder = ScopeCapture();
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
