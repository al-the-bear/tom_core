#!/usr/bin/env python3
"""Every kernel type in a public tom_flutter_ui signature must be bridged.

`tom_flutter_ui` does not re-export `tom_core_kernel` wholesale — the two
packages both declare a `TomEnvironment` and a `TomPlatform`, so a blanket
re-export would reach consumers as an `ambiguous_import`. The single bridge is
the `show` list in `lib/src/kernel_types.dart`, and a kernel type that appears
in a public signature without appearing there is invisible from inside the
package: the ~85 files declaring those signatures import the kernel barrel
unfiltered, so they compile either way. Only a consumer sees the gap.

`TomScope` is what this gate exists for. It is the type of `scope:`, a
parameter on every Tom widget, and it sat outside the bridge unnoticed.

The gate checks one direction — a public *declaration position* naming a kernel
type. `test/kernel_types_test.dart` checks the other, by importing nothing but
the package barrel and using each bridged type.

Exit status is 1 when a type is missing, 0 otherwise.
"""

from __future__ import annotations

import os
import re
import sys

CORE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(CORE, 'tom_flutter_ui')
BRIDGE = os.path.join(UI, 'lib', 'src', 'kernel_types.dart')

KERNEL_PACKAGES = (
    os.path.join(CORE, 'tom_core_kernel', 'lib'),
    os.path.join(os.path.dirname(CORE), 'basics', 'tom_basics', 'lib'),
    os.path.join(os.path.dirname(CORE), 'basics', 'tom_crypto', 'lib'),
)

DECL = re.compile(
    r'^\s*(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+|mixin\s+)*'
    r'(?:class|mixin|enum|extension\s+type|typedef)\s+([A-Za-z_$][\w$]*)'
)

# Dart keywords that can follow a type name without making it a declaration.
NOT_A_NAME = {
    'extends', 'implements', 'with', 'on', 'get', 'set', 'return', 'is', 'as',
    'in', 'if', 'else', 'new', 'const', 'final', 'var', 'late', 'required',
    'covariant', 'static', 'this', 'super', 'await', 'yield', 'throw',
}


def strip_noise(src: str) -> str:
    """Remove comments and string literals so their contents cannot match."""
    src = re.sub(r'/\*.*?\*/', ' ', src, flags=re.S)
    src = re.sub(r'^\s*///.*$', '', src, flags=re.M)
    src = re.sub(r'//.*$', '', src, flags=re.M)
    src = re.sub(r"r?'''.*?'''", "''", src, flags=re.S)
    src = re.sub(r'r?""".*?"""', "''", src, flags=re.S)
    src = re.sub(r"r?'(?:\\.|[^'\\\n])*'", "''", src)
    src = re.sub(r'r?"(?:\\.|[^"\\\n])*"', "''", src)
    return src


def dart_files(base: str):
    for dirpath, _dirs, files in os.walk(base):
        for name in sorted(files):
            if name.endswith('.dart'):
                yield os.path.join(dirpath, name)


def kernel_type_names() -> set[str]:
    """Public top-level type names the kernel barrel can hand out."""
    names: set[str] = set()
    for lib in KERNEL_PACKAGES:
        if not os.path.isdir(lib):
            continue
        for path in dart_files(lib):
            for line in strip_noise(open(path, encoding='utf-8')
                                    .read()).splitlines():
                match = DECL.match(line)
                if match and not match.group(1).startswith('_'):
                    names.add(match.group(1))
    return names


def bridged_names() -> set[str]:
    raw = open(BRIDGE, encoding='utf-8').read()
    raw = re.sub(r'^\s*///.*$', '', raw, flags=re.M)
    raw = re.sub(r'//.*$', '', raw, flags=re.M)
    match = re.search(r'show\s+([^;]+);', raw)
    if not match:
        return set()
    return {n.strip() for n in match.group(1).split(',') if n.strip()}


def public_signature_text(path: str) -> list[tuple[int, str]]:
    """The (line, text) pairs that can hold a public declaration.

    Brace depth 0 is top level and depth 1 is a class body, where member
    declarations and their parameter lists live. A method body opens depth 2,
    so implementation detail — a `TomScopeBase(...)` in an initialiser, say —
    never counts as a signature.
    """
    src = strip_noise(open(path, encoding='utf-8').read())
    depth = 0
    line_no = 1
    kept: list[tuple[int, str]] = []
    buf: list[str] = []
    start = 1
    for ch in src:
        if ch == '\n':
            line_no += 1
        if ch == '{':
            if depth <= 1 and buf:
                kept.append((start, ''.join(buf)))
            buf, start = [], line_no
            depth += 1
        elif ch == '}':
            depth -= 1
            buf, start = [], line_no
        elif depth <= 1:
            if not buf:
                start = line_no
            buf.append(ch)
    if buf:
        kept.append((start, ''.join(buf)))
    return kept


def declaration_hits(text: str, names: set[str]) -> set[str]:
    """Kernel names used as a type in [text], not merely mentioned."""
    found: set[str] = set()

    # `extends X`, `implements X, Y`, `with X, Y`, `on X`, and the bounds in
    # `<T extends X>` — a supertype clause runs to the next clause keyword.
    for match in re.finditer(
        r'\b(?:extends|implements|with|on)\s+([^{;=]+)', text
    ):
        for token in re.findall(r'[A-Za-z_$][\w$]*', match.group(1)):
            if token in names:
                found.add(token)

    # A type annotation: `Foo bar`, `Foo<Bar>? baz`, `Foo bar(`, including
    # parameter lists. Excludes `Foo(...)`, `Foo.member` and bare mentions.
    for match in re.finditer(
        r'\b([A-Z][\w$]*)\s*(?:<[^<>;{}=]*>)?\s*\??\s+([A-Za-z_$][\w$]*)', text
    ):
        name, following = match.group(1), match.group(2)
        if name in names and following not in NOT_A_NAME:
            # A private member is not part of the public surface.
            if not following.startswith('_'):
                found.add(name)

    # Generic arguments of an annotated declaration: `TomList<TomObject> items`.
    for match in re.finditer(
        r'\b[A-Z][\w$]*\s*<([^<>;{}=]*)>\s*\??\s+([A-Za-z_$][\w$]*)', text
    ):
        if match.group(2).startswith('_') or match.group(2) in NOT_A_NAME:
            continue
        for token in re.findall(r'[A-Za-z_$][\w$]*', match.group(1)):
            if token in names:
                found.add(token)

    return found


def main() -> int:
    names = kernel_type_names()
    bridged = bridged_names()

    # Names this package declares itself shadow the kernel's, so they never
    # travel through the bridge: `TomEnvironment` and `TomPlatform` are
    # declared in both `tom_basics` and `resource_auth/tom_config_provider.dart`.
    own: set[str] = set()
    for path in dart_files(os.path.join(UI, 'lib')):
        for line in strip_noise(open(path, encoding='utf-8')
                                .read()).splitlines():
            match = DECL.match(line)
            if match:
                own.add(match.group(1))
    names -= own

    used: dict[str, list[str]] = {}
    for path in dart_files(os.path.join(UI, 'lib')):
        rel = os.path.relpath(path, UI)
        if rel == os.path.join('lib', 'src', 'kernel_types.dart'):
            continue
        for start, text in public_signature_text(path):
            for name in declaration_hits(text, names):
                used.setdefault(name, []).append(f'{rel}:{start}')

    missing = {n: sites for n, sites in used.items() if n not in bridged}

    print(f'kernel type names        : {len(names)}')
    print(f'bridged by kernel_types  : {len(bridged)}')
    print(f'in public signatures     : {len(used)}')
    print(f'missing from the bridge  : {len(missing)}')

    if missing:
        print()
        for name in sorted(missing):
            sites = missing[name]
            print(f'  {name} — {len(sites)} site(s), e.g. {sites[0]}')
        print()
        print('Add each name to the show list in lib/src/kernel_types.dart, '
              'then exercise it from test/kernel_types_test.dart.')
        return 1

    unused = sorted(bridged - set(used))
    if unused:
        print()
        print('bridged but not in a declaration position (rule 2 companions):')
        print('  ' + ', '.join(unused))
    return 0


if __name__ == '__main__':
    sys.exit(main())
