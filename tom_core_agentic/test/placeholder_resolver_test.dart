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
        throwsA(isA<PlaceholderUnresolvedException>()
            .having((e) => e.reference, 'reference', 'env:MISSING')),
      );
    });

    test('an undefined env var renders empty in lenient mode', () {
      final r =
          PlaceholderResolver(environment: const {}, strict: false);
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
        throwsA(isA<PlaceholderUnresolvedException>()
            .having((e) => e.reference, 'reference', 'NAME')),
      );
    });

    test(r'an unbound ${name} renders empty in lenient mode', () {
      final r = PlaceholderResolver(environment: const {}, strict: false);
      expect(r.resolveSync(r'[${nope}]'), '[]');
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

    test('resolve evaluates through the injected backing with the scope', () async {
      final r = PlaceholderResolver(
        environment: const {},
        expressions: _FakeExpressions(),
      );
      r.stack.bind('who', 'world');
      // Bound name → the backing returns the scope value.
      expect(await r.resolve(r'hello ${{ who }}'), 'hello world');
      // Unbound body → the fake renders <body>.
      expect(await r.resolve(r'${{ other }}'), '<other>');
    });
  });

  group('PlaceholderResolver — reserved prefixes', () {
    test(r'${file:…} / ${state:…} pass through verbatim and do not recurse', () {
      final r = PlaceholderResolver(environment: const {});
      expect(
        r.resolveSync(r'${file:/etc/x} and ${state:run.id}'),
        r'${file:/etc/x} and ${state:run.id}',
      );
    });
  });

  group('PlaceholderResolver — recursion', () {
    test('a binding that references another binding expands transitively', () {
      final r = PlaceholderResolver(environment: const {'ROOT': '/srv'});
      r.stack.bindAll({'base': r'${env:ROOT}/brain', 'full': r'${base}/db'});
      expect(r.resolveSync(r'${full}'), '/srv/brain/db');
    });

    test('a self-referential binding errors at the recursion cap', () {
      final r =
          PlaceholderResolver(environment: const {}, maxRecursion: 5);
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
}
