#!/usr/bin/env python3
"""Write into a package's `doc/api/` what `check_api_reference.py` finds missing.

Run from anywhere::

    python3 tool/fill_api_reference.py tom_flutter_ui     # one package
    python3 tool/fill_api_reference.py --dry-run tom_core_agentic

A reference is written by hand, and a hand cannot keep up with an API: every
exported member a class gains is a row some summary now owes. The gate says
*which* rows are owed; this writes them, from the source, so a package's
reference is completed by one command and then edited where the generated
words are not the best ones. It never rewrites what a person wrote -- it only
adds:

- a **summary** for a module that has none, with a section per exported type
  (its declaration kind and its members), an `## Enums` section where the
  module exports enums, and a `## Global Functions and Constants` table;
- the **Source list**, rewritten as the full paths the barrel exports;
- a `## Global Functions and Constants` table where a summary has none;
- **index rows** for exported names the index does not name;
- a `Properties and Methods — further members` table at the end of a class
  section, for each member the gate reports the section never names.

Every description is the first sentence of the declaration's own dartdoc, so
the reference says what the source says. A declaration without dartdoc gets an
empty cell, which is the honest entry: the gap is the source's, and filling it
there fills it here on the next run.

It imports the gate's parsers rather than carrying its own, so the writer and
the checker cannot disagree about what a module exports or a class declares.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

import check_api_reference as gate

FURTHER_MEMBERS = "Properties and Methods — further members"

KIND_DECLARATION = re.compile(
    r"^((?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*"
    r"(?:class|enum|mixin|extension\s+type|extension|typedef))\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)")


@dataclass
class Entry:
    """One declaration: what it is, how it is declared, what its doc says."""
    kind: str
    signature: str
    doc: str


# ---------------------------------------------------------------------------
# Reading the source
# ---------------------------------------------------------------------------

def first_sentence(lines: list[str]) -> str:
    text = " ".join(line.strip().lstrip("/").strip() for line in lines)
    text = re.sub(r"\s+", " ", text).strip()
    match = re.match(r"(.+?[.!?])(?:\s|$)", text)
    sentence = match.group(1) if match else text
    return sentence.replace("|", "\\|")


def doc_above(lines: list[str], index: int) -> str:
    """The first sentence of the `///` block above `lines[index]`."""
    block: list[str] = []
    i = index - 1
    while i >= 0:
        stripped = lines[i].strip()
        if stripped.startswith("///"):
            block.insert(0, stripped)
        elif stripped.startswith("@") or not stripped:
            if block:
                break
        else:
            break
        i -= 1
    return first_sentence(block) if block else ""


def signature_at(lines: list[str], index: int) -> str:
    """The declaration starting at `lines[index]`, up to its body or end."""
    parts: list[str] = []
    depth = 0
    for line in lines[index:index + 40]:
        code = gate.without_line_comment(line).strip()
        parts.append(code)
        for char in code:
            if char in "([":
                depth += 1
            elif char in ")]":
                depth -= 1
        if depth <= 0 and re.search(r"[{;]|=>", code):
            break
    text = re.sub(r"\s+", " ", " ".join(parts))
    text = re.sub(r",\s*([)}\]])", r"\1", text)
    for stop in (" {", "{", " =>", ";"):
        cut = _top_level(text, stop)
        if cut >= 0:
            text = text[:cut]
            break
    return text.strip().replace("|", "\\|").replace("`", "'")


def _top_level(text: str, token: str) -> int:
    depth = 0
    for i, char in enumerate(text):
        if char in "([<":
            depth += 1
        elif char in ")]>" and depth:
            depth -= 1
        elif depth == 0 and text.startswith(token, i):
            return i
    return -1


def read_package(package: gate.Package):
    """`(top-level entries, member entries)` keyed by name / (type, member)."""
    top: dict[str, Entry] = {}
    members: dict[tuple[str, str], Entry] = {}
    for path in sorted(package.modules_root.rglob("*.dart")):
        if path.name.endswith((".reflection.dart", ".g.dart")):
            continue
        raw = path.read_text(encoding="utf-8")
        lines = gate.without_block_comments(
            gate.without_multiline_strings(raw)).split("\n")
        original = raw.split("\n")
        current: str | None = None
        for i, line in enumerate(lines):
            if line.lstrip().startswith("///"):
                continue
            declared = KIND_DECLARATION.match(line)
            if declared:
                kind = re.sub(r"\s+", " ", declared.group(1))
                name = declared.group(2)
                top.setdefault(name, Entry(
                    kind, signature_at(lines, i), doc_above(original, i)))
                owner = gate.OWNER_DECLARATION.match(line)
                current = owner.group(1) if owner else None
                continue
            if line and not line.startswith((" ", "}", ")")):
                current = None
                for pattern in (gate.FUNCTION_DECLARATION,
                                gate.RECORD_FUNCTION_DECLARATION,
                                gate.GETTER_DECLARATION,
                                gate.VARIABLE_DECLARATION):
                    match = pattern.match(line)
                    if match and not match.group(1).startswith("_"):
                        kind = ("getter" if pattern is gate.GETTER_DECLARATION
                                else "constant"
                                if pattern is gate.VARIABLE_DECLARATION
                                else "function")
                        top.setdefault(match.group(1), Entry(
                            kind, signature_at(lines, i),
                            doc_above(original, i)))
                        break
                continue
            if current is None:
                continue
            member = gate.member_name_of(line)
            if member and not member.startswith("_"):
                members.setdefault((current, member), Entry(
                    "member", signature_at(lines, i), doc_above(original, i)))
            value = gate.ENUM_VALUE.match(line)
            if value:
                members.setdefault((current, value.group(1)), Entry(
                    "value", value.group(1), doc_above(original, i)))
    return top, members


# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------

def title_of(module: str) -> str:
    return " ".join(part.capitalize() for part in module.split("_"))


def module_path(package: gate.Package, module: str) -> str:
    layer = f"{package.layer}/" if package.layer else ""
    return f"lib/src/{layer}{module}/"


def sources_line(package: gate.Package, module: str, files: list[str]) -> str:
    base = module_path(package, module)
    return "Sources: " + ", ".join(f"`{base}{f}`" for f in sorted(files)) + "."


def member_table(rows: list[tuple[str, Entry]]) -> list[str]:
    out = ["| Member | Declaration | Description |",
           "| ------ | ----------- | ----------- |"]
    for name, entry in rows:
        out.append(f"| `{name}` | `{entry.signature}` | {entry.doc} |")
    return out


def functions_table(names: list[str], top: dict[str, Entry]) -> list[str]:
    if not names:
        return ["None — this module exports types only."]
    out = ["| Name | Declaration | Description |",
           "| ---- | ----------- | ----------- |"]
    for name in names:
        entry = top.get(name, Entry("function", name, ""))
        out.append(f"| `{name}` | `{entry.signature}` | {entry.doc} |")
    return out


def new_summary(package, module, files, top, members, declarations) -> str:
    api = sorted(package.over(module, files, gate.declared_api))
    functions = sorted(package.over(module, files, gate.declared_functions))
    enums = sorted(package.over(module, files, gate.declared_enums))
    types = [n for n in api if n not in functions and n not in enums]
    out = [f"# {package.name} API Reference: {title_of(module)} Module", "",
           f"The public surface of `{module_path(package, module)}`, as its "
           "barrel exports it.", "", "## Overview", "",
           sources_line(package, module, files), "", "## Classes", ""]
    for name in types:
        entry = top.get(name, Entry("class", name, ""))
        out += [f"### {name}", "", f"**Kind:** `{entry.kind}`", ""]
        if entry.doc:
            out += [entry.doc, ""]
        rows = sorted((m, e) for (t, m), e in members.items() if t == name
                      and m != name and m not in gate.UNIVERSAL_MEMBERS)
        if rows:
            out += ["#### Properties and Methods", ""] + member_table(rows) + [""]
    if enums:
        out += ["## Enums", ""]
        for name in enums:
            entry = top.get(name, Entry("enum", name, ""))
            values = sorted((m, e) for (t, m), e in members.items() if t == name)
            out += [f"### {name}", ""]
            if entry.doc:
                out += [entry.doc, ""]
            if values:
                out += ["#### Values", ""] + member_table(values) + [""]
    out += ["## Global Functions and Constants", ""]
    out += functions_table(functions, top) + [""]
    return "\n".join(out)


def replace_sources(summary: str, line: str) -> str:
    """Put the full Source list in front of the existing Source paragraph.

    The paragraph a person wrote usually says more than which files -- how the
    barrel is organised, how many libraries it re-exports -- so it is kept,
    reworded from a `Source:` line into a sentence, and the generated list
    becomes the paragraph the gate reads.
    """
    span = gate.source_list_span(summary)
    if span is None:
        anchor = re.search(r"^## Overview\s*\n", summary, re.M)
        if anchor:
            return (summary[:anchor.end()] + "\n" + line + "\n"
                    + summary[anchor.end():])
        first_break = summary.find("\n\n")
        return summary[:first_break] + "\n\n" + line + summary[first_break:]
    prose = re.sub(r"^Sources?:\s*`(lib/src/[^`]*/)`,\s*barrelled\s+by",
                   r"The module `\1` is barrelled by", span)
    if prose == span:
        return summary.replace(span, line, 1)
    return summary.replace(span, line + "\n\n" + prose, 1)


def add_function_rows(summary: str, functions: list[str],
                      top: dict[str, Entry]) -> str:
    """Add a row to an existing function table for each function it omits."""
    body = gate.section(summary, "Global Functions and Constants")
    if body is None:
        return summary
    listed = set(gate.global_function_names(summary) or [])
    listed |= {m.group(1) for m in re.finditer(
        r"^###\s+`?([A-Za-z_]\w*)`?", body, re.M)}
    missing = [name for name in functions if name not in listed]
    if not missing:
        return summary
    start = summary.index(body)
    rows = [line for line in body.split("\n") if line.startswith("|")]
    if rows and rows[0].startswith("| Name |"):
        last = body.rindex(rows[-1]) + len(rows[-1])
        added = "\n".join(functions_table(missing, top)[2:])
        new_body = body[:last] + "\n" + added + body[last:]
    else:
        table = "\n".join(functions_table(missing, top))
        new_body = body.rstrip("\n") + "\n\n" + table + "\n\n"
    return summary[:start] + new_body + summary[start + len(body):]


def add_to_contents(summary: str, title: str, anchor: str) -> str:
    """List an appended `## [title]` section at the end of the contents."""
    start = summary.find("## Table of Contents")
    if start < 0:
        return summary
    end = summary.find("\n## ", start + 5)
    if end < 0:
        return summary
    contents = summary[start:end].rstrip("\n")
    return (summary[:start] + contents + f"\n- [{title}](#{anchor})\n"
            + summary[end:])


def add_further_members(summary: str, owed: dict[str, list[str]],
                        members: dict[tuple[str, str], Entry]) -> str:
    lines = summary.split("\n")
    heading = re.compile(r"^(#{2,6})\s+(.*?)\s*$")
    for type_name, names in owed.items():
        if not names:
            continue
        start = level = None
        for i, line in enumerate(lines):
            match = heading.match(line)
            if not match:
                continue
            title = re.sub(r"&lt;.*&gt;|<[^<>]*>", "", match.group(2)).strip()
            if title == type_name:
                start, level = i, len(match.group(1))
                break
        if start is None:
            continue
        end = len(lines)
        in_fence = False
        for j in range(start + 1, len(lines)):
            if lines[j].startswith("```"):
                in_fence = not in_fence
            if in_fence:
                continue
            match = heading.match(lines[j])
            if match and len(match.group(1)) <= level:
                end = j
                break
        while end > start + 1 and not lines[end - 1].strip():
            end -= 1
        rows = [(n, members.get((type_name, n), Entry("member", n, "")))
                for n in sorted(names)]
        block = ["", f"{'#' * min(level + 1, 6)} {FURTHER_MEMBERS}", ""]
        block += member_table(rows)
        lines[end:end] = block
    return "\n".join(lines)


def add_index_rows(index: str, package, module: str, names: list[str],
                   top: dict[str, Entry]) -> str:
    path = module_path(package, module)
    rows = []
    for name in names:
        entry = top.get(name, Entry("class", name, ""))
        rows.append(f"| `{name}` | {entry.kind} | {entry.doc} |")
    lines = index.split("\n")
    for i, line in enumerate(lines):
        if line.startswith("### ") and f"`{path}`" in line:
            j = i + 1
            while j < len(lines) and not lines[j].startswith("|"):
                if lines[j].startswith("#"):
                    break
                j += 1
            if j < len(lines) and lines[j].startswith("|"):
                while j < len(lines) and lines[j].startswith("|"):
                    j += 1
                lines[j:j] = rows
                return "\n".join(lines)
            lines[i + 1:i + 1] = ["", "| Type | Kind | Description |",
                                  "| ---- | ---- | ----------- |"] + rows
            return "\n".join(lines)
    block = ["", f"### {title_of(module)} (`{path}`)", "",
             f"Summary: [api_summary_{module}.md](api_summary_{module}.md)", "",
             "| Type | Kind | Description |", "| ---- | ---- | ----------- |"]
    return index.rstrip("\n") + "\n" + "\n".join(block + rows) + "\n"


def fill(package: gate.Package, dry_run: bool) -> int:
    reference = package.reference
    reference.mkdir(parents=True, exist_ok=True)
    exports = package.exports()
    declarations = gate.parse_declarations(package.modules_root)
    top, members = read_package(package)
    written = 0

    index_path = reference / "api_summary_index.md"
    index = index_path.read_text(encoding="utf-8") if index_path.exists() \
        else f"# {package.name} API Reference: Index\n"

    for module in package.modules():
        files = sorted(exports.get(module, []))
        if not files:
            continue
        path = reference / f"api_summary_{module}.md"
        if path.exists():
            summary = path.read_text(encoding="utf-8")
        else:
            summary = new_summary(package, module, files, top, members,
                                  declarations)
        original = summary
        listed = gate.source_list_of(summary, package.layer)
        expected = [f"{module}/{f}" for f in files]
        if (listed is None or sorted(listed) != sorted(expected)
                or gate.abbreviated_entries(summary, package.layer)):
            summary = replace_sources(summary,
                                      sources_line(package, module, files))
        functions = sorted(package.over(module, files, gate.declared_functions))
        summary = add_function_rows(summary, functions, top)
        if gate.section(summary, "Global Functions and Constants") is None:
            functions = sorted(package.over(module, files,
                                            gate.declared_functions))
            summary = (summary.rstrip("\n") + "\n\n## Global Functions and "
                       "Constants\n\n"
                       + "\n".join(functions_table(functions, top)) + "\n")
            summary = add_to_contents(summary, "Global Functions and Constants",
                                      "global-functions-and-constants")
        if summary != original or not path.exists():
            written += 1
            if not dry_run:
                path.write_text(summary, encoding="utf-8")
        if f"api_summary_{module}.md" not in index:
            index = add_index_rows(index, package, module, [], top)
        api = sorted(package.over(module, files, gate.declared_api))
        missing = [n for n in api if not gate.index_names(index, n)]
        if missing:
            index = add_index_rows(index, package, module, missing, top)

    if not dry_run:
        index_path.write_text(index, encoding="utf-8")

    # Member rows last: the summaries now exist, so the gate's own reading of
    # them says which rows are still owed.
    owed: dict[str, dict[str, list[str]]] = {}
    pattern = re.compile(r"^[^/]+/(api_summary_\w+\.md): `(\w+)` section never "
                         r"names its member `(\w+)`$")
    for fault in gate.member_faults(package, declarations):
        match = pattern.match(fault)
        if match:
            owed.setdefault(match.group(1), {}).setdefault(
                match.group(2), []).append(match.group(3))
    for file, by_type in owed.items():
        path = reference / file
        summary = add_further_members(path.read_text(encoding="utf-8"),
                                      by_type, members)
        written += 1
        if not dry_run:
            path.write_text(summary, encoding="utf-8")
    return written


def main(argv: list[str]) -> int:
    dry_run = "--dry-run" in argv
    names = [a for a in argv if not a.startswith("--")]
    if not names:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    for name in names:
        if name not in gate.PACKAGES:
            print(f"{name} is not a package check_api_reference.py audits",
                  file=sys.stderr)
            return 2
        package = gate.Package(name, gate.PACKAGES[name])
        count = fill(package, dry_run)
        print(f"{name}: {count} summary file(s) "
              f"{'would change' if dry_run else 'written'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
