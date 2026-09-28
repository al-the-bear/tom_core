# Tom Core Agentic API Reference: Index

Symbol-level API summaries for this package's larger units, one file per unit,
under `doc/api/`. Each lists every public type, function and constant its unit's
barrel exports, with a section per name, and names every public static member.
Which units get one is a stated rule, below.

`test/api_summary_test.dart` holds that claim. Nothing in it is written out:
the summaries are discovered from this directory, the required set is derived
from each unit's barrel, and the rule below is applied to every directory under
`lib/src/`. So a summary that exists is complete, a summary that falls behind
the code fails rather than misleading, and a unit that grows past the threshold
without gaining one fails too.

## Summaries

| Unit | Summary | Covers |
| ---- | ------- | ------ |
| `agent` | [api_summary_agent.md](api_summary_agent.md) | The editor-facing agent layer: eleven YAML sidecars and their models, bridge discovery and binding, the reconnect loop, and the send engine. |
| `isolate_streaming` | [api_summary_isolate_streaming.md](api_summary_isolate_streaming.md) | The primitives a host and a worker isolate share: cancellation tokens, close signals, backpressure credit, request guards, and typed-error reconstruction. |
| `llm` | [api_summary_llm.md](api_summary_llm.md) | The provider contract and its value types, the Anthropic Agent SDK provider, and the three session strategies. |
| `placeholders` | [api_summary_placeholders.md](api_summary_placeholders.md) | The placeholder engine: the four forms, the lexical scope chain, the expression seam, and the three wire-coded failures. |

## Which units get one

**A unit earns a summary at ten exported public members.** Members, not types
and not lines: what a reader has to hold in their head to use a unit is the set
of things they can call, and a type with nine methods on it costs more than
three types with one each.

| Unit | Members | Types | Summary |
| ---- | ------: | ----: | ------- |
| `agent` | 344 | 52 | yes |
| `llm` | 107 | 20 | yes |
| `isolate_streaming` | 47 | 12 | yes |
| `placeholders` | 35 | 6 | yes |
| `bearer_auth` | 5 | 3 | `doc/bearer_auth.md` |
| `mcp_auth` | 0 | 0 | `doc/mcp_auth.md` |

Both columns are derived and pinned: `test/api_summary_test.dart` measures each
unit and fails this table when a figure drifts. A source-line column stood here
and was removed rather than pinned — the argument rests on members, and a length
nobody maintains is worse than no length.

**Counting types instead put `placeholders` on the wrong side**, which is what
the measure was changed for. On types it reads 6 against `isolate_streaming`'s
12 and lands beside `bearer_auth`'s 3; on members it reads 35 against 47 and
lands beside `isolate_streaming`, which is where its source size puts it too.
`PlaceholderResolver` and `PlaceholderStack` carry seventeen members between
them, and a type count cannot see any of them.

The member figure also partitions more decisively: 0, 5 | 35, 47, 107, 344 is a
sevenfold gap with nothing near the line, where 3, 6 | 12, 20, 52 is a factor of
two. A threshold is only worth stating rather than deciding case by case when
it has no borderline, and this one has none.

**`tom_flutter_ui` states the same threshold over types**, and deliberately so:
it is a widget catalogue where a type *is* the unit of surface — 299 widgets,
most of them a constructor and no more — so counting members there would
measure the base class's parameter list rather than the kit. The two rules
disagree because the packages have different shapes, not because one is stale
— so the number is the same and what it counts is not, and a reader who has met
one index should not assume the other.

**Below the threshold the unit's prose page is the mirror**, and that is a
checked claim rather than a courtesy: the `## Overview` table of
`doc/<unit>.md` is held to every public type, function and constant the unit
exports, by the same test. A small unit is mirrored; it is mirrored somewhere
else.

That check exists here rather than only in `tool/check_doc_overview_types.py`
because the repository gate compares **types**, and a unit that exports none is
skipped by it — `mcp_auth` is two constants and is named in that gate's source
as the reason the skip exists. Two constants are exactly the surface a reader
most expects a document to have got right, so the package's own suite asks the
question the repository gate cannot.

A summary for `mcp_auth` would be a third document over fifty lines of source,
restating two constants that `doc/mcp_auth.md` already tabulates, explains on
the wire, and shows in use — and each of which carries a dartdoc longer than
the summary entry would be. The threshold is what keeps that document from
being written to satisfy a rule.
