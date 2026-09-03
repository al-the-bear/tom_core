// Tests for the shared `PlaceholderResolver` — the single `${…}` engine the
// whole brain stack resolves through (relocated to `tom_core_agentic` so the
// substrate / access / memory / run config loaders and the engine all share
// one mechanism; `tom_brain_procedure_specification.md` § 21.7, § 21.10).
//
// What this file pins (the four forms + the two entry points):
//   * `${env:NAME}` is the *only* way to reach the environment.
//   * a bare `${name}` reads a stack binding; unbound → strict error, or
//     empty in lenient mode.
//   * `${{ expr }}` evaluates through the injected `PlaceholderExpressions`
//     backing on the async path; on `resolveSync` (and with no backing) it
//     is a located error.
//   * reserved `${file:…}` / `${state:…}` pass through verbatim.
//   * recursive expansion converges, and over-deep expansion errors.
//
// The d4rt-backed `${{ … }}` evaluation is exercised end-to-end in
// `tom_brain_procedure` (where the evaluator lives); here the expression seam
// is a trivial fake so the resolver's wiring is tested in isolation.

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

/// A trivial [PlaceholderExpressions] backing: renders `${{ body }}` as
/// `<body=scope[body]>` so a test can assert both that the body and the
/// flattened scope reached the seam.
final class _FakeExpressions implements PlaceholderExpressions {
  @override
  Future<Object?> evaluate(String body, Map<String, Object?> scope) async =>
      scope.containsKey(body) ? scope[body] : '<$body>';
}

void main() {
  group(r'PlaceholderResolver — env form (${env:NAME})', () {
    test('resolves an env var only through the env: prefix', () {
      final r = PlaceholderResolver(environment: const {'TOKEN': 'secret'});
      expect(r.resolveSync(r'Bearer ${env:TOKEN}'), 'Bearer secret');
    });

    test('an undefined env var is a strict error naming env:NAME', () {
      final r = PlaceholderResolver(environment: const {});
      expect(
        () => r.resolveSync(r'${env:MISSING}'),
        throwsA(
          isA<PlaceholderUnresolvedException>().having(
            (e) => e.reference,
            'reference',
            'env:MISSING',
          ),
        ),
      );
    });

    test('an undefined env var renders empty in lenient mode', () {
      final r = PlaceholderResolver(environment: const {}, strict: false);
      expect(r.resolveSync(r'[${env:MISSING}]'), '[]');
    });
  });

  group(r'PlaceholderResolver — simple form (${name})', () {
    test(r'a bare ${name} reads a stack binding, NOT the environment', () {
      final r = PlaceholderResolver(environment: const {'NAME': 'from-env'});
      r.stack.bind('NAME', 'from-binding');
      // The bare form never reaches the environment: it reads the binding.
      expect(r.resolveSync(r'${NAME}'), 'from-binding');
    });

    test(r'an unbound ${name} is a strict error (no env fallback)', () {
      final r = PlaceholderResolver(environment: const {'NAME': 'from-env'});
      expect(
        () => r.resolveSync(r'${NAME}'),
        throwsA(
          isA<PlaceholderUnresolvedException>().having(
            (e) => e.reference,
            'reference',
            'NAME',
          ),
        ),
      );
    });

    test(r'an unbound ${name} renders empty in lenient mode', () {
      final r = PlaceholderResolver(environment: const {}, strict: false);
      expect(r.resolveSync(r'[${nope}]'), '[]');
    });
  });

  group(r'PlaceholderResolver — optional form (${name?})', () {
    test(r'an unbound ${name?} renders empty even in strict mode', () {
      // strict is the default — the ? overrides it for this slot only.
      final r = PlaceholderResolver(environment: const {});
      expect(r.resolveSync(r'[${absent?}]'), '[]');
    });

    test(r'a bound ${name?} renders its value', () {
      final r = PlaceholderResolver(environment: const {});
      r.stack.bind('todo_list', '- buy milk');
      expect(r.resolveSync(r'${todo_list?}'), '- buy milk');
    });

    test(r'a bare ${name} (no ?) still throws in strict mode', () {
      // The ? is per-slot: the strict default is untouched for bare lookups.
      final r = PlaceholderResolver(environment: const {});
      expect(
        () => r.resolveSync(r'${absent}'),
        throwsA(
          isA<PlaceholderUnresolvedException>().having(
            (e) => e.reference,
            'reference',
            'absent',
          ),
        ),
      );
    });

    test(r'${name?} works identically on the async resolve() path', () async {
      final r = PlaceholderResolver(
        environment: const {},
        expressions: _FakeExpressions(),
      );
      expect(await r.resolve(r'[${absent?}]'), '[]');
      r.stack.bind('present', 'X');
      expect(await r.resolve(r'${present?}'), 'X');
    });

    test(r'a bound ${name?} re-scans its value like a bare binding', () {
      final r = PlaceholderResolver(environment: const {'ROOT': '/srv'});
      r.stack.bind('hint', r'${env:ROOT}/x');
      expect(r.resolveSync(r'${hint?}'), '/srv/x');
    });

    test(r'the optional marker does not apply to ${env:NAME?}', () {
      // Optionality is scoped to the simple binding form only (spec §13/§2);
      // an env name carrying a trailing ? is just an unresolvable env lookup.
      final r = PlaceholderResolver(environment: const {'TOKEN': 'secret'});
      expect(
        () => r.resolveSync(r'${env:TOKEN?}'),
        throwsA(
          isA<PlaceholderUnresolvedException>().having(
            (e) => e.reference,
            'reference',
            'env:TOKEN?',
          ),
        ),
      );
    });

    test(r'a literal ? outside a placeholder is untouched', () {
      final r = PlaceholderResolver(environment: const {});
      r.stack.bind('name', 'Tom');
      expect(r.resolveSync(r'${name}, are you there?'), 'Tom, are you there?');
    });

    test(r'whitespace around the ? is tolerated (${ name ? })', () {
      // The optional marker is as whitespace-forgiving as the bare form: the
      // trailing ? is stripped and the remainder right-trimmed, so `${ name ? }`
      // optionally resolves the binding `name`.
      final r = PlaceholderResolver(environment: const {});
      r.stack.bind('name', 'Tom');
      expect(r.resolveSync(r'[${ name ? }]'), '[Tom]');
      // …and an unbound spaced optional still vanishes rather than throwing.
      expect(r.resolveSync(r'[${ absent ? }]'), '[]');
    });

    test(r'optional overrides lenient mode identically to strict', () {
      // D1.5: an unbound ${name?} renders empty whether the resolver is strict
      // or lenient — the marker's whole purpose is "render empty".
      final lenient = PlaceholderResolver(strict: false, environment: const {});
      expect(lenient.resolveSync(r'[${absent?}]'), '[]');
      lenient.stack.bind('present', 'X');
      expect(lenient.resolveSync(r'${present?}'), 'X');
    });
  });

  group(r'PlaceholderResolver — expression form (${{ … }})', () {
    test('resolveSync rejects an expression form', () {
      final r = PlaceholderResolver(environment: const {});
      expect(
        () => r.resolveSync(r'${{ 1 + 1 }}'),
        throwsA(isA<PlaceholderExpressionException>()),
      );
    });

    test('resolve with no backing is a located expression error', () {
      final r = PlaceholderResolver(environment: const {});
      expect(
        () => r.resolve(r'${{ 1 + 1 }}'),
        throwsA(isA<PlaceholderExpressionException>()),
      );
    });

    test(
      'resolve evaluates through the injected backing with the scope',
      () async {
        final r = PlaceholderResolver(
          environment: const {},
          expressions: _FakeExpressions(),
        );
        r.stack.bind('who', 'world');
        // Bound name → the backing returns the scope value.
        expect(await r.resolve(r'hello ${{ who }}'), 'hello world');
        // Unbound body → the fake renders <body>.
        expect(await r.resolve(r'${{ other }}'), '<other>');
      },
    );

    // The docs used to call `${name}` "equivalent to `${{ name }}`". It is
    // not: the forms agree on exactly one case and diverge on three axes.
    // The three tests below pin each axis so the corrected wording in
    // `doc/placeholders.md` and the resolver header cannot drift back.

    test('the two forms agree only on a bound name via resolve + backing', () {
      // The single case in which substituting one form for the other is
      // behaviour-preserving.
      final r = PlaceholderResolver(
        environment: const {},
        expressions: _FakeExpressions(),
      );
      r.stack.bind('name', 'Tom');
      expect(r.resolve(r'${name}'), completion(equals('Tom')));
      expect(r.resolve(r'${{ name }}'), completion(equals('Tom')));
    });

    test('axis 1+2: the simple form needs neither a backing nor resolve', () {
      // Backing: without one, `${name}` resolves and `${{ name }}` throws.
      final bare = PlaceholderResolver(environment: const {});
      bare.stack.bind('name', 'Tom');
      expect(bare.resolveSync(r'${name}'), 'Tom');
      expect(
        () => bare.resolve(r'${{ name }}'),
        throwsA(isA<PlaceholderExpressionException>()),
      );

      // Entry point: even *with* a backing, the expression form is
      // unavailable synchronously — so the config loaders, which only ever
      // call resolveSync, can never reach an expression at all.
      final backed = PlaceholderResolver(
        environment: const {},
        expressions: _FakeExpressions(),
      );
      backed.stack.bind('name', 'Tom');
      expect(backed.resolveSync(r'${name}'), 'Tom');
      expect(
        () => backed.resolveSync(r'${{ name }}'),
        throwsA(isA<PlaceholderExpressionException>()),
      );
    });

    test('axis 3: an unbound expression body ignores strict AND lenient', () {
      // The simple form routes an unbound name through the resolver's mode;
      // the expression form hands it to the backing, which decides. So the
      // mode is not merely bypassed under strict — it is never consulted,
      // which is why the divergence survives switching to lenient.
      for (final strict in [true, false]) {
        final r = PlaceholderResolver(
          strict: strict,
          environment: const {},
          expressions: _FakeExpressions(),
        );
        // Simple form: mode-dependent.
        if (strict) {
          expect(
            () => r.resolveSync(r'${missing}'),
            throwsA(isA<PlaceholderUnresolvedException>()),
            reason: 'strict must reject an unbound simple name',
          );
        } else {
          expect(r.resolveSync(r'${missing}'), '');
        }
        // Expression form: identical under both modes — the backing owns it.
        expect(
          r.resolve(r'${{ missing }}'),
          completion(equals('<missing>')),
          reason: 'the backing decides, regardless of strict=$strict',
        );
      }
    });
  });

  group('PlaceholderResolver — the simple form has no grammar', () {
    test('a non-identifier body is a lookup key like any other', () {
      // `_classify` routes on prefix alone, so anything that is not env: /
      // file: / state: is a simple lookup. `isSimpleIdentifier` describes the
      // d4rt-locals shape, not this form's accepted shape — a dotted name
      // (the shape of the substrate's `role.anchor` built-in) resolves fine.
      final r = PlaceholderResolver(environment: const {});
      r.stack.bind('role.anchor', 'ANCHOR');
      r.stack.bind('a.b c', 'SPACED');
      expect(r.resolveSync(r'${role.anchor}'), 'ANCHOR');
      expect(r.resolveSync(r'${a.b c}'), 'SPACED');
    });

    test('an unbound non-identifier body fails as unresolved, not as a '
        'malformed name', () {
      // The failure names the reference, so a template typo like ${a.b}
      // reports the thing that was not found rather than a grammar error.
      final r = PlaceholderResolver(environment: const {});
      expect(
        () => r.resolveSync(r'${a.b}'),
        throwsA(
          isA<PlaceholderUnresolvedException>().having(
            (e) => e.reference,
            'reference',
            'a.b',
          ),
        ),
      );
    });

    test('the resolver hands the backing every binding, unfiltered', () {
      // The identifier filter belongs to the backing. If the resolver applied
      // it here, a backing with different name rules could not see bindings
      // it is perfectly able to express.
      final r = PlaceholderResolver(
        environment: const {},
        expressions: _FakeExpressions(),
      );
      r.stack.bind('role.anchor', 'ANCHOR');
      r.stack.bind('ok', 1);
      expect(
        r.stack.flatten().keys,
        containsAll(<String>['role.anchor', 'ok']),
      );
    });
  });

  group('PlaceholderResolver — reserved prefixes', () {
    test(
      r'${file:…} / ${state:…} pass through verbatim and do not recurse',
      () {
        final r = PlaceholderResolver(environment: const {});
        expect(
          r.resolveSync(r'${file:/etc/x} and ${state:run.id}'),
          r'${file:/etc/x} and ${state:run.id}',
        );
      },
    );
  });

  group('PlaceholderResolver — recursion', () {
    test('a binding that references another binding expands transitively', () {
      final r = PlaceholderResolver(environment: const {'ROOT': '/srv'});
      r.stack.bindAll({'base': r'${env:ROOT}/brain', 'full': r'${base}/db'});
      expect(r.resolveSync(r'${full}'), '/srv/brain/db');
    });

    test('a self-referential binding errors at the recursion cap', () {
      final r = PlaceholderResolver(environment: const {}, maxRecursion: 5);
      r.stack.bind('loop', r'${loop}');
      expect(
        () => r.resolveSync(r'${loop}'),
        throwsA(isA<PlaceholderRecursionException>()),
      );
    });
  });

  group('PlaceholderResolver — passthrough', () {
    test(r'an unterminated ${ (no closing brace) is left verbatim', () {
      final r = PlaceholderResolver(environment: const {});
      expect(r.resolveSync(r'cost ${UNCLOSED here'), r'cost ${UNCLOSED here');
    });

    test('a bare \$ without a brace is left verbatim', () {
      final r = PlaceholderResolver(environment: const {});
      expect(r.resolveSync(r'price $5'), r'price $5');
    });
  });

  // Characterization tests (tests §22). These pin behaviours the resolver and
  // its failure types already implement so a future refactor cannot silently
  // change them: the typed wire codes, the brace-balanced expression scan, and
  // the unterminated-`${{` passthrough. No production change accompanies them.
  group('PlaceholderResolver — typed failure wire codes (§22)', () {
    test('recursion failure carries its code and a descriptive message', () {
      const e = PlaceholderRecursionException(
        maxRecursion: 3,
        residue: r'${loop}',
      );
      expect(e.code, placeholderRecursionExceededCode);
      expect(e.message, allOf(contains('3'), contains('residue')));
      expect(e.toString(), contains(e.message));
    });

    test('unresolved failure carries its code and names the reference', () {
      const e = PlaceholderUnresolvedException('topic');
      expect(e.code, placeholderUnresolvedCode);
      expect(e.message, contains('topic'));
      expect(e.toString(), contains(e.message));
    });

    test('expression failure carries its code and names the expression', () {
      final e = PlaceholderExpressionException(
        expression: 'x + 1',
        cause: StateError('boom'),
      );
      expect(e.code, placeholderExpressionFailedCode);
      expect(e.message, allOf(contains('x + 1'), contains('boom')));
      expect(e.toString(), contains(e.message));
    });
  });

  group('PlaceholderResolver — expression brace balancing (§22)', () {
    test(r'a ${{ … }} body with a nested { } is captured whole', () async {
      // The scan must track the inner `{ }` of a map literal so the closing
      // `}}` is the *outer* one, not the inner brace.
      final r = PlaceholderResolver(
        environment: const {},
        expressions: _FakeExpressions(),
      );
      // The fake renders an unbound body as `<body>`; the body must arrive as
      // the full `{'a': 1}`, proving the nested brace did not close early.
      expect(
        await r.resolve(r"pre ${{ {'a': 1} }} post"),
        r"pre <{'a': 1}> post",
      );
    });

    test(r'an unterminated ${{ (no closing }}) is left verbatim', () {
      final r = PlaceholderResolver(environment: const {});
      expect(r.resolveSync(r'cost ${{ 1 + 1 here'), r'cost ${{ 1 + 1 here');
    });
  });
}
