# Suite figures

The advanced sample's shared figure store: nine hand-authored SVG diagrams in
`architecture/`, embedded by the suite's guide documents one directory up. The
figures live here rather than in a package because they describe relationships
*between* packages — layering, the shared signing key, a call crossing from
client to server, a grant reaching a widget — and a cross-package figure inside
one package would claim an ownership the diagram contradicts.

**This is not a runtime asset folder.** No `pubspec.yaml` declares it, nothing
lists it under `assets:`, and nothing loads it; it is referenced only by
relative path from markdown. The suite has four other folders named `assets/`
that are the opposite: `advanced_auth_server/assets/`,
`advanced_app_server/assets/`, `advanced_ops_server/assets/` and
`core_server_sample/assets/` hold the configuration each server **loads at
boot** by a path relative to its working directory — `datasources_default.yaml`,
`config-resources_default.yaml` and its per-environment overlay, and, where the
server has them, `blobstores_default.yaml` and its text bundles (`resources_*.json`,
`text_*.yaml`). Nothing said here about this folder applies to those.

## The figures and who embeds them

Each figure has one subject and is embedded from the chapter that argues it; two
are also embedded in the suite overview or an appendix.

| Figure | Draws | Embedded by |
| ------ | ----- | ----------- |
| `advanced_01_layering` | four horizontal bands with every dependency arrow pointing down | [01](../README_advanced_01_architecture.md) |
| `advanced_02_jwt_shared_key` | the auth server signs, the client carries, the app server verifies — one shared key | [01](../README_advanced_01_architecture.md) |
| `advanced_03_grant_propagation` | an admin's grant edit reaching an end-user's per-field grades, and a share revealing a project to a second user | [01](../README_advanced_01_architecture.md) |
| `advanced_04_overall_architecture` | two clients, two servers, two databases, ports and the shared signing key | [the suite overview](../README_advanced_sample.md), [01](../README_advanced_01_architecture.md) |
| `advanced_05_call_api_service_routing` | a typed client call travelling to a routed service method and back as a reflection-serialized result | [01](../README_advanced_01_architecture.md) |
| `advanced_06_token_refresh` | refresh exactly once on a 401, retry exactly once | [01](../README_advanced_01_architecture.md) |
| `advanced_07_request_lifecycle` | the two round-trips: login plus roles map, then bearer-authenticated reads with local grading | [01](../README_advanced_01_architecture.md), [A3](../README_advanced_A3_request_lifecycle.md) |
| `advanced_08_domain_ownership` | the containment chain `Workspace → Project → TodoList → TodoItem` with `User` and `Share` as satellites | [03](../README_advanced_03_domain_reflection.md) |
| `advanced_09_grade_data_path` | a grant row becoming the grade a single field renders at | [A1](../README_advanced_A1_authorization_state_machine.md) |

## Three representations of every figure

No reader should depend on a renderer, so every figure exists three ways:

1. **The SVG** — hand-authored, no generator, `viewBox`-scaled with a system font
   stack, so it renders the same in a browser, a markdown preview and on GitHub.
2. **An HTML comment at the top of the SVG** describing what it draws, numbered
   where the figure is a sequence. The comment is the figure's own source of
   truth: readable in a terminal and diffable in review.
3. **A mermaid equivalent in the embedding document**, inside a
   `<details><summary>Text / mermaid equivalent</summary>` disclosure beside the
   image.

The embed's alt text is a full sentence rather than a label, so the figure also
survives a screen reader and a text-only reading.

## Embedding a figure

An embed site has three parts, in this order:

1. an HTML comment, `<!-- Figure: … -->`, stating what the figure shows — the
   embedding document's own account, so its source reads without the image;
2. the image, `![full-sentence alt text](assets/architecture/<file>.svg)`;
3. the `<details><summary>Text / mermaid equivalent</summary>` disclosure
   holding the mermaid diagram, and a line of prose where it helps.

**The worked example is the first figure in
[01 · Layering and dependency arrows](../README_advanced_01_architecture.md#layering-and-dependency-arrows)** —
copy it rather than a snippet here, since it is a live embed that renders and
is read. All eleven embed sites across the five guides follow the same shape.

Paths are relative to the embedding document. The guides sit one directory up
from this folder, so from a guide the path is `assets/architecture/…`; from a
package README, one directory further down, prefix `../`.

## Reading a figure without rendering it

Print the opening description by its delimiters:

```bash
awk '/<!--/,/-->/{print} /-->/{exit}' architecture/advanced_09_grade_data_path.svg
```

Not `head -N`: the descriptions vary several-fold in length, so any fixed line
count either truncates the longest — silently, since a cut-off comment still
looks complete — or prints markup for the shortest. Drop `/-->/{exit}` to see
every comment; the figures also carry inline markers naming each section, and
some a note explaining a layout decision where it is made.

## Adding a figure

1. Author the SVG by hand with a `viewBox` and the system font stack the others
   use, and keep it to a few kilobytes so it stays diffable.
2. Open it with an HTML comment describing what it draws, numbering the steps
   of a sequence.
3. Embed it from the chapter that argues it, as the three-part embed site
   above: the `<!-- Figure: … -->` comment, the image with full-sentence alt
   text, and the `Text / mermaid equivalent` disclosure beneath.
4. Add a row to the table above.

Name it `advanced_<nn>_<subject>.svg`, where `<nn>` orders it within the
narrative, not by creation date.

Every step is checked: `tom_ai/core/tool/check_suite_figures.py` fails when a
figure is embedded nowhere, an embed names a missing file, this table disagrees
with the tree or with who embeds what, an embed site lacks its comment or its
disclosure, alt text is a label rather than a sentence, or an SVG lacks its
`viewBox` or opening comment.
