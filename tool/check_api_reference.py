#!/usr/bin/env python3
"""Hold every package's `doc/api/` to the code it documents.

Run from anywhere::

    python3 tool/check_api_reference.py                   # every package
    python3 tool/check_api_reference.py tom_core_kernel   # one package
    python3 tool/check_api_reference.py --self-test       # check the checker

Exits non-zero when any fault is found, so the runner can hold the count to its
baseline.

**Why.** An API reference claims, by existing, that it documents its package,
and nothing about writing code sends its author back to it. The server's
reference is held to that claim by `tom_core_server/test/api_reference_coverage_
test.dart`, and what that suite keeps finding is not typos: whole files absent
from the reference, dozens of exported names in no index table. Every other
package's reference was measured by nothing. This gate carries the generic half
of that suite to every package at once, as the corpus's other cross-package
document checks already are; the server-specific checks stay in its suite.
(`tom_core_kernel/test/api_reference_coverage_test.dart` checks only that each
module has a guide, a summary and a sample -- the file-level layer, not this
one.)

**What is checked**, per module directory under `lib/src/<layer>/`:

- **summary** -- the module has `doc/api/api_summary_<module>.md`, no
  summary documents a module that does not exist, and the index links every
  summary;
- **source** -- the summary's `Source:` list names every file the barrel
  exports for the module and nothing it does not, and writes every entry as a
  full path. A bare file name is resolved against the module of the full path
  before it -- which is what a reader does -- and reported separately as an
  abbreviation, so a list written in that form is not mistaken for one missing
  its files;
- **index** -- `api_summary_index.md` names every exported type and function;
- **unnamed** -- the summary names every exported type and function, in a
  heading or a code span outside a fenced block;
- **functions** -- the summary has a `## Global Functions and Constants`
  section, it names every exported free function, and nothing it names is
  undeclared;
- **enums** -- every exported enum has a heading, and an `## Enums` section
  accounts for every one and heads no subsection for a name that is not one;
- **members** -- every class section names each public member its class
  declares, or an ancestor's section does. `toString`, `hashCode`,
  `noSuchMethod` and `runtimeType` are not demanded.

A package with no `doc/api/` at all is one fault: the absence is
recorded as debt rather than passed over in silence.
So is a package listed in `UNWRITTEN`, whose summaries exist but predate the
gate: the one fault names the detail count, and naming the package on the
command line (or `--full`) prints the detail.

`fill_api_reference.py` writes what this gate finds missing -- Source lists,
function tables, index rows, member rows and whole summaries -- from the source
and its dartdoc, so a reference brought short by new API is completed by one
command and then edited where the generated words are not the best ones.

The parsers are ports of the server suite's, including its fixes: block
comments are opened only where Dart would open one, multi-line strings are
emptied before any scan, wrapped class headers are read whole, and a member
table split by subject (`##### Methods -- aggregates`) stays attributed to its
class. Run against `tom_core_server`, whose suite already enforces all of this,
the gate reports zero -- which is how the port is known to read as the suite
does.
"""

from __future__ import annotations

import posixpath
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent

#: Each package and the directory under `lib/src/` its modules live in. An
#: empty layer means the modules sit directly under `lib/src/`.
PACKAGES = {
    "tom_core_kernel": "tombase",
    "tom_core_server": "tomserver",
    "tom_core_flutter": "tomclient",
    "tom_flutter_ui": "",
    "tom_core_agentic": "",
}

#: Packages whose summaries in `doc/api/` were written before this gate read
#: them and have not yet been brought to its standard. In a default run each
#: counts as ONE fault naming how many it would report, so the debt stays
#: visible without a thousand detail lines drowning the packages that are at
#: zero; name the package on the command line (or pass `--full`) for the
#: detail. An entry whose package now audits clean is itself a fault, so the
#: set cannot outlive what it records.
UNWRITTEN: set[str] = set()

#: Members no class section has to name: the `Object` members, as in the
#: server's suite, and `createState`, which every `StatefulWidget` overrides for
#: the framework to call -- a caller never does, so a row for it would teach
#: nothing.
UNIVERSAL_MEMBERS = {"toString", "hashCode", "noSuchMethod", "runtimeType",
                     "createState"}

MEMBER_SECTION_HEADINGS = {
    "Properties", "Methods", "Static Methods", "Constructors", "Constructor",
    "Factory Constructors", "Static Properties", "Static Fields", "Fields",
    "Enum Values", "Values", "Operators", "Static Members", "Static Constants",
    "Properties and Methods", "Constants",
}
MEMBER_SECTION_QUALIFIER = re.compile(r"\s(?:[—–-]\s.*|\(.*\))$")

TYPE_DECLARATION = re.compile(
    r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*"
    r"(?:class|enum|mixin|extension\s+type|extension|typedef)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)",
    re.M)
FUNCTION_DECLARATION = re.compile(
    r"^[A-Za-z_][\w<>,?\s.]*?\s+([A-Za-z_]\w*)\s*(?:<[^<>]*>)?\s*\(", re.M)
RECORD_FUNCTION_DECLARATION = re.compile(
    r"^\([^()]*(?:\([^()]*\)[^()]*)*\)\s+([A-Za-z_]\w*)\s*\(", re.M)
GETTER_DECLARATION = re.compile(
    r"^[A-Za-z_][\w<>,?\s.]*?\s+get\s+([A-Za-z_]\w*)\b", re.M)
VARIABLE_DECLARATION = re.compile(
    r"^(?:const|final)\s+(?:[\w<>,?\s.]+\s+)?([A-Za-z_]\w*)\s*=", re.M)
ENUM_DECLARATION = re.compile(r"^enum\s+([A-Za-z_]\w*)", re.M)
OWNER_DECLARATION = re.compile(
    r"^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*"
    r"(?:class|mixin|enum|extension type)\s+([A-Za-z_][A-Za-z0-9_]*)")

MEMBER_MODIFIERS = re.compile(
    r"^\s*(?:@\w+(?:\s*\((?:[^()]|\([^()]*\))*\))?\s*|static\s+|final\s+"
    r"|late\s+|const\s+|external\s+|abstract\s+|covariant\s+|factory\s+)*")
CONTINUATION_LINE = re.compile(r"^\s*[)\]}:]")
PARAMETER_LIST = re.compile(r"(\w+)\s*(?:<[^<>]*>)?\s*\(")
TRAILING_IDENTIFIER = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*$")
ENUM_VALUE = re.compile(r"^  ([a-z]\w*)\s*[,;(]")
SUPERTYPE_CLAUSE = re.compile(r"\b(?:extends|implements|with)\s+([\w\s,]+)")
SUPERTYPE_NAME = re.compile(r"\b([A-Z]\w+)")


# ---------------------------------------------------------------------------
# Source blanking
# ---------------------------------------------------------------------------

def without_multiline_strings(source: str) -> str:
    """[source] with its triple-quoted strings emptied."""
    source = re.sub(r"'''[\s\S]*?'''", "''", source)
    return re.sub(r'"""[\s\S]*?"""', '""', source)


def without_block_comments(source: str) -> str:
    """[source] with its block comments emptied, newlines kept.

    A `/*` opens a comment only where Dart would open one: not inside a `//`
    line and not inside a string literal. A `*/` inside a comment closes it
    whatever surrounds it.
    """
    out: list[str] = []
    index = 0
    length = len(source)
    while index < length:
        char = source[index]
        nxt = source[index + 1] if index + 1 < length else ""
        if char == "/" and nxt == "/":
            end = source.find("\n", index)
            end = length if end < 0 else end
            out.append(source[index:end])
            index = end
            continue
        if char == "/" and nxt == "*":
            close = source.find("*/", index + 2)
            end = length if close < 0 else close + 2
            out.append("\n" * source[index:end].count("\n"))
            index = end
            continue
        if char in "'\"":
            raw = index > 0 and source[index - 1] == "r"
            triple = source[index:index + 3] == char * 3
            quote = char * 3 if triple else char
            j = index + len(quote)
            while j < length:
                if not raw and source[j] == "\\":
                    j += 2
                    continue
                if source.startswith(quote, j):
                    j += len(quote)
                    break
                if not triple and source[j] == "\n":
                    break
                j += 1
            out.append(source[index:j])
            index = j
            continue
        out.append(char)
        index += 1
    return "".join(out)


def without_line_comment(line: str) -> str:
    quote = None
    i = 0
    while i < len(line):
        char = line[i]
        if quote is not None:
            if char == "\\":
                i += 2
                continue
            if char == quote:
                quote = None
        elif char in "'\"":
            quote = char
        elif char == "/" and i + 1 < len(line) and line[i + 1] == "/":
            return line[:i]
        i += 1
    return line


def declaration_end(line: str) -> int:
    depth = 0
    for i, char in enumerate(line):
        if char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
        elif depth == 0:
            if char == "{":
                return i
            if char != "=":
                continue
            previous = line[i - 1] if i else ""
            nxt = line[i + 1] if i + 1 < len(line) else ""
            if previous in "=!<>" or nxt == "=":
                continue
            return i
    return len(line)


def without_type_arguments(text: str) -> str:
    previous = None
    while previous != text:
        previous = text
        text = re.sub(r"<[^<>]*>", "", text)
    return text


# ---------------------------------------------------------------------------
# Declarations
# ---------------------------------------------------------------------------

def declared_functions(source: str) -> set[str]:
    stripped = without_multiline_strings(source)
    names: set[str] = set()
    for pattern in (FUNCTION_DECLARATION, RECORD_FUNCTION_DECLARATION,
                    GETTER_DECLARATION):
        names.update(m.group(1) for m in pattern.finditer(stripped)
                     if not m.group(1).startswith("_"))
    return names


def declared_api(source: str) -> set[str]:
    stripped = without_multiline_strings(source)
    types = {m.group(1) for m in TYPE_DECLARATION.finditer(stripped)
             if not m.group(1).startswith("_")}
    return types | declared_functions(source)


def declared_names(source: str) -> set[str]:
    stripped = without_multiline_strings(source)
    return declared_api(source) | {
        m.group(1) for m in VARIABLE_DECLARATION.finditer(stripped)
        if not m.group(1).startswith("_")}


def declared_enums(source: str) -> set[str]:
    return {m.group(1) for m in ENUM_DECLARATION.finditer(
        without_multiline_strings(source)) if not m.group(1).startswith("_")}


def member_name_of(raw_line: str) -> str | None:
    if not raw_line.startswith("  ") or raw_line.startswith("   "):
        return None
    line = without_line_comment(raw_line).rstrip()
    if CONTINUATION_LINE.match(line):
        return None
    head = line[:declaration_end(line)]
    prefix = MEMBER_MODIFIERS.match(head)
    head = head[prefix.end() if prefix else 0:]
    for match in PARAMETER_LIST.finditer(head):
        if match.group(1) != "Function":
            return match.group(1)
    remainder = head.rstrip()
    if remainder.endswith(";"):
        remainder = remainder[:-1].rstrip()
    match = TRAILING_IDENTIFIER.search(remainder)
    return match.group(1) if match else None


@dataclass
class Declaration:
    name: str
    members: set[str] = field(default_factory=set)
    supertypes: set[str] = field(default_factory=set)


def parse_declarations(root: Path) -> dict[str, Declaration]:
    """Every type declared under [root] with its members and supertypes."""
    declarations: dict[str, Declaration] = {}
    if not root.is_dir():
        return declarations
    for path in sorted(root.rglob("*.dart")):
        if path.name.endswith((".reflection.dart", ".g.dart")):
            continue
        source = without_block_comments(without_multiline_strings(
            path.read_text(encoding="utf-8")))
        current: Declaration | None = None
        header: list[str] = []
        for line in source.split("\n"):
            if line.lstrip().startswith("///"):
                continue
            if header:
                header.append(line)
                if "{" not in line and ";" not in line:
                    continue
                read_supertypes(current, " ".join(header))
                header = []
                continue
            declared = OWNER_DECLARATION.match(line)
            if declared:
                name = declared.group(1)
                current = declarations.setdefault(name, Declaration(name))
                if "{" in line:
                    read_supertypes(current, line)
                else:
                    header = [line]
                continue
            if current is None:
                continue
            if line and not line.startswith(" "):
                current = None
                continue
            member = member_name_of(line)
            if member is not None:
                current.members.add(member)
            value = ENUM_VALUE.match(line)
            if value:
                current.members.add(value.group(1))
    return declarations


def read_supertypes(current: Declaration | None, text: str) -> None:
    if current is None:
        return
    clause = SUPERTYPE_CLAUSE.search(without_type_arguments(text))
    if clause:
        current.supertypes.update(
            m.group(1) for m in SUPERTYPE_NAME.finditer(clause.group(1)))


# ---------------------------------------------------------------------------
# Summaries
# ---------------------------------------------------------------------------

def source_list_span(summary: str) -> str | None:
    """The text of [summary]'s Source list, or None when it has none.

    It runs from the `Source:` line to the first blank line after it. When that
    paragraph names no `.dart` file, the list is the block after it instead --
    a bulleted list or a `| File | Declares |` table, the two shapes the
    kernel's and tom_core_flutter's summaries use -- and runs to the blank line
    after that block.
    """
    start = re.search(r"^Sources?:", summary, re.M)
    if start is None:
        return None
    lines = summary[start.start():].split("\n")
    blocks: list[list[str]] = [[]]
    for line in lines:
        if line.strip():
            blocks[-1].append(line)
        elif blocks[-1]:
            if len(blocks) == 2:
                break
            if re.search(r"`(?:lib/src/[^`]*|[^/`]+)\.dart`",
                         "\n".join(blocks[0])):
                break
            blocks.append([])
    span = blocks[0] + (blocks[1] if len(blocks) > 1 else [])
    return "\n".join(span)


def source_entry(layer: str) -> re.Pattern[str]:
    prefix = f"lib/src/{layer}/" if layer else "lib/src/"
    return re.compile(
        r"`(?:" + re.escape(prefix) + r"([^/`]+)/)?((?!lib/)(?:[^/`]+/)*[^/`]+\.dart)`")


def source_list_of(summary: str, layer: str) -> list[str] | None:
    """The `<module>/<file>` entries of [summary]'s Source list, or None."""
    span = source_list_span(summary)
    if span is None:
        return None
    entries: list[str] = []
    module = None
    for match in source_entry(layer).finditer(span):
        module = match.group(1) or module
        if module is not None:
            entries.append(f"{module}/{match.group(2)}")
    return entries


def abbreviated_entries(summary: str, layer: str) -> list[str]:
    span = source_list_span(summary)
    if span is None:
        return []
    return [m.group(2) for m in source_entry(layer).finditer(span)
            if m.group(1) is None]


def heading_names(summary: str) -> set[str]:
    return {re.sub(r"&lt;.*&gt;|<[^<>]*>", "", m.group(1)).strip()
            for m in re.finditer(r"^#{2,6}\s+(.*?)\s*$", summary, re.M)}


def names_in(summary: str) -> set[str]:
    prose = re.sub(r"^```[\s\S]*?^```", "", summary, flags=re.M)
    names = set(heading_names(summary))
    for span in re.finditer(r"`([^`\n]+)`", prose):
        names.update(m.group(0) for m in
                     re.finditer(r"[A-Za-z_]\w*", span.group(1)))
    return names


def section(summary: str, title: str) -> str | None:
    heading = re.search(r"^## " + re.escape(title) + r"$", summary, re.M)
    if heading is None:
        return None
    rest = summary[heading.end():]
    nxt = re.search(r"^## ", rest, re.M)
    return rest if nxt is None else rest[:nxt.start()]


def global_function_names(summary: str) -> list[str] | None:
    body = section(summary, "Global Functions and Constants")
    if body is None:
        return None
    names: list[str] = []
    for line in body.split("\n"):
        if not line.startswith("|"):
            continue
        cell = line.split("|")[1]
        if "---" in cell:
            continue
        names.extend(m.group(1) for m in
                     re.finditer(r"`([A-Za-z_]\w*)", cell))
    return names


def index_names(index: str, api: str) -> bool:
    return re.search("`" + re.escape(api) + "[<`]", index) is not None


def class_sections(lines: list[str], declarations: dict[str, Declaration]):
    """`(type, mentions)` for every class section of one summary."""
    heading = re.compile(r"^#{2,6}\s+(.*?)\s*$")
    sections: list[tuple[str, set[str]]] = []
    current: tuple[str, set[str]] | None = None
    for line in lines:
        title = heading.match(line)
        if title:
            text = title.group(1)
            if MEMBER_SECTION_QUALIFIER.sub("", text) in MEMBER_SECTION_HEADINGS:
                continue
            type_name = re.sub(r"&lt;.*&gt;|<[^<>]*>", "", text).strip()
            if (re.fullmatch(r"[A-Z]\w*", type_name)
                    and type_name in declarations):
                current = (type_name, set())
                sections.append(current)
            else:
                current = None
            continue
        if current is not None:
            current[1].update(re.findall(r"[A-Za-z_]\w*", line))
    return sections


# ---------------------------------------------------------------------------
# The package audit
# ---------------------------------------------------------------------------

@dataclass
class Package:
    name: str
    layer: str

    @property
    def root(self) -> Path:
        return REPO_ROOT / self.name

    @property
    def modules_root(self) -> Path:
        src = self.root / "lib" / "src"
        return src / self.layer if self.layer else src

    @property
    def reference(self) -> Path:
        return self.root / "doc" / "api"

    def modules(self) -> list[str]:
        return sorted(p.name for p in self.modules_root.iterdir()
                      if p.is_dir())

    def exports(self) -> dict[str, list[str]]:
        barrel = (self.root / "lib" / f"{self.name}.dart").read_text(
            encoding="utf-8")
        prefix = f"src/{self.layer}/" if self.layer else "src/"
        pattern = re.compile(
            r"^export '" + re.escape(prefix) + r"([^/']+)/([^']+)';", re.M)
        found: dict[str, list[str]] = {}
        for match in pattern.finditer(barrel):
            module, file = match.group(1), match.group(2)
            for reached in self.reexported(module, file, set()):
                if reached not in found.setdefault(module, []):
                    found[module].append(reached)
        return found

    def reexported(self, module: str, file: str, seen: set[str]) -> list[str]:
        """[file] and every module file it re-exports, transitively.

        A conditional export -- `export 'a.dart' if (dart.library.js)
        'b.dart';` -- reaches every alternative it names, because which one a
        consumer gets is the platform's choice and all of them are the API on
        some platform. A file in a sub-folder of the module is reached through
        its relative path, and a `part` is reached too: its declarations belong to the
        library that names it, so they are exported wherever that library is.
        """
        if file in seen:
            return []
        seen.add(file)
        reached = [file]
        path = self.modules_root / module / file
        if not path.exists():
            return reached
        source = without_block_comments(path.read_text(encoding="utf-8"))
        for directive in re.finditer(r"^(?:export|part(?!\s+of\b))\s+([^;]*);", source,
                                     re.M):
            for target in re.findall(r"'([^']+\.dart)'", directive.group(1)):
                if target.startswith(("package:", "dart:")):
                    continue
                inside = posixpath.normpath(
                    posixpath.join(posixpath.dirname(file), target))
                if inside.startswith("../"):
                    continue
                reached.extend(self.reexported(module, inside, seen))
        return reached

    def over(self, module: str, files: list[str], scan) -> set[str]:
        names: set[str] = set()
        for file in files:
            path = self.modules_root / module / file
            if path.exists():
                names |= scan(path.read_text(encoding="utf-8"))
        return names


def audit(package: Package) -> list[str]:
    """Every fault in [package], one line each."""
    faults: list[str] = []
    if not package.reference.is_dir():
        return [f"{package.name}: no doc/api/ — the package's API "
                "is documented nowhere a reader can look it up"]

    modules = package.modules()
    exports = package.exports()
    summaries = sorted(
        p.name[len("api_summary_"):-len(".md")]
        for p in package.reference.glob("api_summary_*.md"))
    index_path = package.reference / "api_summary_index.md"
    index = index_path.read_text(encoding="utf-8") if index_path.exists() \
        else ""
    if not index:
        faults.append(f"{package.name}: no api_summary_index.md")
    declarations = parse_declarations(package.modules_root)

    for summary_name in summaries:
        if summary_name != "index" and summary_name not in modules:
            faults.append(f"{package.name}: api_summary_{summary_name}.md "
                          "documents no module")

    for module in modules:
        files = sorted(exports.get(module, []))
        where = f"{package.name}/{module}"
        path = package.reference / f"api_summary_{module}.md"
        if not path.exists():
            if files:
                faults.append(f"{where}: no api_summary_{module}.md")
            continue
        if index and f"api_summary_{module}.md" not in index:
            faults.append(f"{where}: the index does not link "
                          f"api_summary_{module}.md")
        summary = path.read_text(encoding="utf-8")

        listed = source_list_of(summary, package.layer)
        if listed is None:
            faults.append(f"{where}: no Source: line")
        else:
            exported_files = [f"{module}/{f}" for f in files]
            for file in exported_files:
                if file not in listed:
                    faults.append(f"{where}: Source list omits {file}")
            for file in listed:
                if file not in exported_files:
                    faults.append(f"{where}: Source list names {file}, "
                                  "which the barrel does not export")
            for bare in abbreviated_entries(summary, package.layer):
                faults.append(f"{where}: Source entry `{bare}` is a bare "
                              "file name, not a path")

        api = sorted(package.over(module, files, declared_api))
        if index:
            for name in api:
                if not index_names(index, name):
                    faults.append(f"{where}: the index never names `{name}`")
        named = names_in(summary)
        for name in api:
            if name not in named:
                faults.append(f"{where}: the summary never names `{name}`")

        functions = sorted(package.over(module, files, declared_functions))
        listed_functions = global_function_names(summary)
        # A function may also be given a subsection of its own -- `###
        # clientPlatformUtils` with its signature in a fence -- which lists it
        # as surely as a table row does. Those headings count towards what the
        # section names, and are not read as claims to be checked for
        # staleness, because the same level also carries grouping headings
        # (`### Constants`, `### Functions`) that name nothing.
        subsections = set()
        body = section(summary, "Global Functions and Constants")
        if body is not None:
            subsections = {m.group(1) for m in re.finditer(
                r"^###\s+`?([A-Za-z_]\w*)`?\s*(?:\(.*\))?\s*$", body, re.M)}
        if listed_functions is None:
            faults.append(f"{where}: no '## Global Functions and Constants' "
                          "section")
        else:
            for name in functions:
                if name not in listed_functions and name not in subsections:
                    faults.append(f"{where}: Global Functions omits "
                                  f"`{name}`")
            every = package.over(module, files, declared_names)
            for name in listed_functions:
                if name not in every:
                    faults.append(f"{where}: Global Functions names "
                                  f"`{name}`, which is not declared")

        enums = sorted(package.over(module, files, declared_enums))
        headings = heading_names(summary)
        for name in enums:
            if name not in headings:
                faults.append(f"{where}: enum `{name}` has no section")
        enum_section = section(summary, "Enums")
        if enum_section is not None:
            mentioned = set(re.findall(r"[A-Za-z_]\w*", enum_section))
            for name in enums:
                if name not in mentioned:
                    faults.append(f"{where}: the Enums section leaves out "
                                  f"`{name}`")
            for match in re.finditer(r"^###\s+(.*?)\s*$", enum_section, re.M):
                name = re.sub(r"&lt;.*&gt;|<[^<>]*>", "", match.group(1)).strip()
                if name not in enums:
                    faults.append(f"{where}: the Enums section heads `{name}`, "
                                  "which is not an exported enum")

    faults.extend(member_faults(package, declarations))
    return faults


def member_faults(package: Package,
                  declarations: dict[str, Declaration]) -> list[str]:
    """Undocumented members of every class some summary gives a section."""
    mentions: dict[str, set[str]] = {}
    sectioned: list[tuple[str, str]] = []
    for path in sorted(package.reference.glob("api_summary_*.md")):
        for type_name, words in class_sections(
                path.read_text(encoding="utf-8").split("\n"), declarations):
            mentions.setdefault(type_name, set()).update(words)
            sectioned.append((path.name, type_name))

    def mentioned(type_name: str, member: str, seen: set[str]) -> bool:
        if type_name in seen:
            return False
        seen.add(type_name)
        if member in mentions.get(type_name, set()):
            return True
        declaration = declarations.get(type_name)
        return any(mentioned(parent, member, seen)
                   for parent in (declaration.supertypes if declaration
                                  else ()))

    faults: list[str] = []
    reported: set[str] = set()
    for file, type_name in sectioned:
        if type_name in reported:
            continue
        reported.add(type_name)
        for member in sorted(declarations[type_name].members):
            if (member.startswith("_") or member == type_name
                    or member in UNIVERSAL_MEMBERS):
                continue
            if not mentioned(type_name, member, set()):
                faults.append(f"{package.name}/{file}: `{type_name}` section "
                              f"never names its member `{member}`")
    return faults


# ---------------------------------------------------------------------------

SELF_TESTS = [
    ("Source: `lib/src/tombase/a/x.dart`.\n\nProse `lib/src/tombase/a/y.dart`.",
     ["a/x.dart"], []),
    ("Sources:\n\n- `lib/src/tombase/a/x.dart`\n- `y.dart`\n\nProse `z.dart`.",
     ["a/x.dart", "a/y.dart"], ["y.dart"]),
    ("Sources: `lib/src/tombase/a/x.dart`,\n`y.dart`.\n\n",
     ["a/x.dart", "a/y.dart"], ["y.dart"]),
    ("Source: `orphan.dart`.\n\n", [], ["orphan.dart"]),
    ("# No source line\n", None, []),
]


def self_test() -> int:
    failed = 0
    for text, expected, bare in SELF_TESTS:
        got = source_list_of(text, "tombase")
        if expected is not None and got != expected:
            failed += 1
            print(f"self-test: source list of {text!r}: expected {expected}, "
                  f"got {got}", file=sys.stderr)
        if bare is not None and abbreviated_entries(text, "tombase") != bare:
            failed += 1
            print(f"self-test: bare entries of {text!r}: expected {bare}",
                  file=sys.stderr)
    # A `/*` inside a dartdoc or a string opens nothing; a removed comment keeps
    # its newlines.
    cases = [
        ("/// a `/*` marker\nclass A {}\n", "/// a `/*` marker\nclass A {}\n"),
        ("var s = '/*';\nclass A {}\n", "var s = '/*';\nclass A {}\n"),
        ("/* one\ntwo */class A {}", "\nclass A {}"),
    ]
    for source, expected in cases:
        if without_block_comments(source) != expected:
            failed += 1
            print(f"self-test: blanking {source!r}", file=sys.stderr)
    if member_name_of("  ) async => grant;") is not None:
        failed += 1
        print("self-test: a continuation line read as a member", file=sys.stderr)
    if member_name_of("  final int count = 0;") != "count":
        failed += 1
        print("self-test: a field was not read", file=sys.stderr)
    if TYPE_DECLARATION.search("extension type TomOne._(String n) {}").group(1) \
            != "TomOne":
        failed += 1
        print("self-test: an extension type read as one named `type`",
              file=sys.stderr)
    if member_name_of("  Future<void> open(String name) async {") != "open":
        failed += 1
        print("self-test: a method was not read", file=sys.stderr)
    if failed:
        return 1
    print("self-test: source lists, blanking and member names read as expected")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
    full = "--full" in argv
    argv = [arg for arg in argv if arg != "--full"]
    explicit = bool(argv)
    chosen = argv or list(PACKAGES)
    unknown = [name for name in chosen if name not in PACKAGES]
    if unknown:
        print(f"unknown package: {', '.join(unknown)}", file=sys.stderr)
        return 2

    total = 0
    for name in chosen:
        package = Package(name, PACKAGES[name])
        if not package.modules_root.is_dir():
            print(f"{name}: no {package.modules_root}; not measured",
                  file=sys.stderr)
            return 2
        faults = audit(package)
        if name in UNWRITTEN and not (full or explicit):
            faults = ([f"{name}: doc/api/ is not yet written to this gate's "
                       f"standard -- {len(faults)} fault(s) in detail; run "
                       f"`check_api_reference.py {name}`"]
                      if faults else
                      [f"{name}: audits clean -- remove it from UNWRITTEN"])
        for fault in faults:
            print(fault)
        print(f"{name}: {len(faults)} fault(s)")
        total += len(faults)

    print()
    print(f"packages audited         : {len(chosen)}")
    print(f"faults                   : {total}")
    return report_faults(total)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
