## Unreleased

### Fixed

- **`setAclGroup` groups the container.** `AclContainer.aclGroup` was stored,
  forwarded and read by nothing, so a container grouped with
  `AclBuilder.setAclGroup` got no error and no effect. A component's group now
  resolves as its own, else its row's, else the container's — for its
  visibility mode, its policy path and the group `AclScope` reports.
  `acl_container_group_test.dart` pins it, and `acl_inert_parameter_test.dart`
  now holds the unit to no inert fields at all. The design specification's §25
  no longer claims groups propagate from a nested container to its parent's
  controllers, which nothing implemented; it says how to toggle a nested `Acl`
  from the parent instead.
- **Four module barrel dartdocs read as an index and were not one.**
  `advanced_container_layout`, `custom` and `resource_auth` now link every type
  their barrel exports (7, 6 and 6 were missing); `AclComponent`, `AclRow` and
  `AclBuilderExtensions` gained the dartdocs they lacked. `widget_base` orients
  instead of indexing, and says so: it names the base chain and points at its
  readme and API summary, which hold all of its types.
  `module_readme_inventory_test.dart` classifies the three as `complete` and
  `widget_base` as `orientation`, and no barrel is `partial` any more.
- **Eighteen broken markdown reference links in
  `doc/advanced_container_layout.md`.** Type names written as
  `` [`AclBuilder`] `` — dartdoc's square-bracket syntax in a markdown file,
  which renders as literal brackets around a code span rather than as a link.
  The same page already wrote sixty-nine type names as plain code spans, so the
  bracketed ones were the anomaly; the brackets are gone and no anchor was
  invented, because none existed to point at.

### Added

- **`widgets` says where its signatures are, and the inventory gate stops
  losing two of them (tcopen292).** The catalogue module is not owed a
  `doc/api/` summary — its 299 public types are derived from the sources by
  `test/widgets/widget_census.dart`, held in both directions by
  `widget_conformance_test.dart`, and *constructed* by
  `widget_conformance_registry.dart`, so a wrapper whose constructor changes
  shape fails to compile. `doc/api/api_summary_index.md` and `doc/widgets.md`
  now say which suite answers names, which answers signatures and which answers
  counts, rather than leaving the absence of a summary to be read as an
  omission.

  The measurement found a defect in `test/module_readme_inventory_test.dart`:
  its private-declaration stripper assumed a declaration spans lines, so a
  single-line `enum _FABVariant { … }` put it into skip mode until the next `}`
  in column 0 — 450 lines later — and `TomFloatingActionButton` and
  `TomIconButton` fell outside every inventory check in the package. The
  symptom was two scans disagreeing with nothing comparing them: the census
  counts 299 public types in `widgets`, the gate counted 297. A new case now
  asserts the property directly — whatever the stripper removes, no public
  declaration may be among it.

- **An API summary for the widget_base module (tcopen291).**
  `doc/api/api_summary_widget_base.md` gives each of the 34 exported types a
  section and names all 62 public statics with their signatures — parameter
  nullability, optional-positional defaults, and what each resolver returns
  when it finds nothing, none of which the prose carried. With it the module's
  symbol list has two homes instead of three: the module readme lists the same
  surface by responsibility, the summary by signature, both held complete by
  `test/module_readme_inventory_test.dart`, and `doc/widget_base.md` now
  explains the chain rather than tabulating it a third time.

  This is the last module the threshold owed a summary, so the test's backlog
  set is empty — and still held exactly, so a module that grows past ten
  exported public types without one fails rather than joining a list nobody
  reads.

- **`theme` keeps one symbol list instead of three (tcopen290).** At four
  exported public types the module sits below the threshold at which a module
  earns a summary under `doc/api/`, so `lib/src/theme/readme.md` is its mirror —
  named as such, and held to every public type and static by the same test that
  holds the summaries. `doc/theme.md` carried a fourth copy of that list above
  its own per-type sections and no longer does; it explains the module and
  points at the readme. Three hand-maintained tables over twelve members is what
  produced the earlier disagreement between two documents about
  `updateShouldNotify`.

- **An API summary for the resource_auth module (tcopen289).**
  `doc/api/api_summary_resource_auth.md` gives each of the thirteen exported
  types a section and names all twelve public statics. This is the module where
  the question was what a summary does with generated data, and the barrel had
  already answered it: `tom_colors_generated.dart` and `tom_icons_generated.dart`
  are declared `not-exported`, so they are not public surface and listing their
  entries would copy a machine-written file into a hand-written one. What the
  summary states instead is what an application needs — the catalogues resolve
  against 355 colours and 10,147 icons, and a name is added by registering
  rather than by editing a table.

- **Which modules get an API summary is a rule, and the rule is enforced
  (tcopen288).** A module earns one at **ten exported public types**; below
  that its own `lib/src/<module>/readme.md` is the mirror, and is held to every
  public type and static by the same test that holds the summaries. Counting
  types rather than lines is what sorts the package correctly — `resource_auth`
  declares 13 of them across 11,352 lines and wants a summary, `theme` declares
  4 across 365 and does not.

  `test/module_readme_inventory_test.dart` derives each module's count from its
  barrel and fails when one reaches the threshold without a summary;
  `resource_auth` and `widget_base` are named in a backlog set held exactly, so
  writing either summary fails the suite until the module comes off it.
  `doc/api/api_summary_index.md` states the rule and tabulates every module
  that has none with the reason. Before this, an absent summary read the same
  for `groups` — two exported types, whose readme is the mirror — as for
  `widget_base`, which is 34 types nobody has written up.

- **An API summary for the forms module (tcopen286).**
  `doc/api/api_summary_forms.md` gives every exported type its own section —
  all 212 of them — and names all 84 public statics, arranged for lookup where
  `doc/forms.md` and `doc/tom_ui_widgets_forms.md` are arranged for reading.
  The module readme is a *rule* readme by design — a table of the 103-class
  catalogue in it would be a second copy of a list already kept — and it now
  names both complete lists rather than only Appendix C, which covers the field
  catalogue and not the rest of the barrel.

  `test/module_readme_inventory_test.dart` discovers the summary from
  `doc/api/` and derives its required set from `tom_forms.dart`, so it cannot
  fall behind the code. Writing it found two defects in that gate's
  static-member pattern: a function-typed return made the match land on
  `Function` rather than on the member's name, and a record return or a generic
  static was not matched at all — so `TomValidatorRegistry.parseSpec` and
  `Validators.compose` were exempt from every summary and readme in the
  package. Both are now required.

- **The shared authorization table is held against all three composites
  (tcopen269).** `doc/custom.md` and the completion document state one
  four-outcome table for `TomAuthGuard`, `TomChoiceGroup` and `TomAuthTreeView`,
  and add that pointer-blocking means an `IgnorePointer` in all three so that
  arbitrary content inside is genuinely inert. Nothing held that: each widget
  was tested in its own file, and between them the table had holes —
  `TomAuthGuard` had no `read` case and its `disabled` case asserted only the
  fade under a name that promised pointer blocking, while `TomChoiceGroup` had
  only `none` and `full`.

  `test/custom/auth_composite_table_test.dart` drives every composite through
  every state against one interactive child and **taps** it, so a barrier that
  is present but lets a tap through fails. The documented opt-out
  (`blockPointerOnRead: false`) and the radio group's second mechanism (every
  `Radio` also `enabled: false`) are asserted beside it.

### Fixed

- **The ten reserved decoration mixins say what they are (tcopen287).**
  `TomSliderDecorationMixin` and its nine siblings declare no members and no
  field in the catalogue lists any of them — every family they name ships and
  takes `TomGenericFieldDecorationMixin` instead. Their library dartdoc
  described them as placeholders "for field types whose widgets are not yet
  implemented", which stopped being true as each of those widgets landed, and
  left ten exported names a reader would take for a decoration layer that runs.
  The dartdoc and `doc/api/api_summary_forms.md` now both state the position.
  Whether the ten should exist at all is a separate question.

- **`TomLoadingOverlay.blocksPointerEvents: false` blocked pointers anyway
  (tcopen284).** The overlay wrapped its scrim in
  `AbsorbPointer(absorbing: blocksPointerEvents)`, but the scrim is a
  `ColoredBox` and its hit-test behaviour is opaque — so it swallowed a tap on
  its own and the parameter changed nothing. A caller who wanted a progress
  hint over content that stays usable got content exactly as unreachable as
  the default, and the two look identical on screen.

  The overlay is now taken out of hit testing when it is not blocking. Found
  by writing the parameter's first test.

### Added

- **The `custom` kit's leaf status is recorded and checked (tcopen285).**
  Nothing in the package consumes the eight composites, and that is a decision
  rather than an omission — but it was written down nowhere, and one widget had
  claimed the opposite.

  Wiring `TomEmptyState` into the list renderers' empty slot was considered and
  declined: it deletes no duplicate, since those renderers resolve an empty
  list through `emptyBuilder`, then a bare `Text`, then nothing. What it would
  add is a default, and an empty slot is the one place a default should not
  arrive unasked. `doc/custom.md` records that, and
  `test/custom/module_boundary_test.dart` holds both directions — nothing
  depends on `custom/`, and `custom/` reaches only for `widget_base`.

- **Per-widget coverage for the `custom` kit (tcopen284).** Five of the eight
  had only incidental coverage — a smoke case each in the example's test file
  — so `hiddenBuilder`, `disabledOpacity`, an explicit `scope`, a null group
  key, per-item descriptions, `blocksPointerEvents`, `scrimColor`, `progress`,
  `borderRadius`, `initiallyExpanded` and `indentation` were all unexercised.

  `tom_auth_guard_test.dart`, `tom_choice_group_test.dart` and
  `tom_loading_overlay_test.dart` are new; the skeleton and tree files gained
  their own presentation parameters. The four-state contract stays in
  `auth_composite_table_test.dart`, driven across all three auth-gated
  composites at once, rather than being restated per widget.

  `custom_example_test.dart` is reduced to running the example, which is what
  it is for. Its per-widget smoke cases have moved to the files that own those
  widgets — a second, thinner copy of a claim is the one that goes stale
  unnoticed.

- **A rendered example for `custom` (tcopen283).** The module shipped one
  example and it never pumped a widget — it printed auth lattice foldings and
  asserted the fields of context-free constructions. For a kit of composites
  that is close to no example, and two of the eight, `TomAuthTreeView` and
  `TomInfiniteScroll`, were rendered nowhere a reader would look.

  `example/custom/custom_rendered_example.dart` assembles all eight into one
  runnable app, and its `run` renders that same gallery under a `WidgetTester`
  and checks each: the withheld guard gone and the granted one beside it, the
  read-only tree section with live entries under it, every radio disabled, the
  boundary's throw turned into a panel, the overlay's content still painted,
  both skeleton forms, a page fetched without anyone scrolling, and the empty
  state's action.

  `doc/custom.md` and the module readme link to it.

- **An API summary for `custom` (tcopen282).**
  `doc/api/api_summary_custom.md` covers all fifteen declarations the module's
  barrel exports, with a section each, every public constructor parameter and
  what it does, and the one public static. Nothing in the unit had said what
  any of the eight constructors took — `TomAuthGuard`'s `blockPointerOnRead`,
  `TomInfiniteScroll`'s `prefetchOffset`, `TomSkeletonLoader`'s `period` — so a
  consumer's only route to any of them was the source.

  `doc/api/api_summary_index.md`, `doc/README.md`, `doc/custom.md` and the
  module readme link to it; `test/module_readme_inventory_test.dart` already
  derives each summary's required set from its barrel, so it cannot fall
  behind.

### Changed

- **`TomEmptyState` resolves its base path and its precedence once each
  (tcopen281).** The three strings each carried their own copy of "resolve the
  base path, read the resource, fall back to the parameter" — three
  `TomCtr.resolvePath` calls for a widget whose job is to render three strings,
  and three places a change to how the path is qualified had to land.

  The path is resolved once, and the precedence lives in one closure the three
  call sites share. Only the headline chains past it, because it is the one
  that may not come out null. Behaviour is unchanged; flipping the precedence
  now fails three tests instead of one, which is the point.

- **`TomRadioGroup` is renamed `TomChoiceGroup` (tcopen280).** The forms module
  declares `TomRadioGroupStyle` and `TomRadioGroupDecorationMixin`, which theme
  the radio-group *field*. The custom composite shared their name and ignored
  them entirely — it references no style type, no `TomUIColors` and no
  `TomCtr` — so a consumer who found the style class and set it saw no effect
  on the widget that shared its name, and nothing in either file said why.

  `TomRadioGroupItem` becomes `TomChoiceGroupItem` and
  `lib/src/custom/tom_radio_group.dart` becomes `tom_choice_group.dart`. The
  widget is unchanged: it is not a field, takes no part in the form style tree,
  and — as the rest of `custom/` does — takes its appearance from the ambient
  `ThemeData`. What changes is that the name no longer promises an integration
  that was never there, and its dartdoc now names the two types it is *not*.

### Added

- **Shipped analyzer suppressions are gated (tcopen279).**
  `test/analyzer_suppressions_test.dart` holds two rules over `lib/`: nothing
  may suppress `deprecated_member_use`, and every suppression that does ship
  carries its reason on the line above it.

  A deprecation is a deadline rather than a lint — silencing one converts a
  warning somebody would act on into a build break nobody expects — and a
  suppression with no reason cannot be told from an oversight. `TomRadioGroup`
  had both `// ignore: deprecated_member_use` comments on `Radio.groupValue`
  and `Radio.onChanged`; the migration to a `RadioGroup<T>` ancestor has since
  been made, and this is what keeps it made.

### Fixed

- **The default loading skeleton made a consumer's `pumpAndSettle` hang
  (tcopen278).** `TomSkeletonLoader` repeats its shimmer whenever `enabled` is
  true, and `TomInfiniteScroll`'s default skeleton builds six of them that the
  caller never names. A repeating animation schedules frames forever, so the
  binding never reaches a quiescent one and the usual first line of a
  downstream widget test hung for its full timeout before failing about
  something unrelated.

  The loader now honours `MediaQuery`'s disable-animations flag as it does
  `enabled: false` — the ticker is stopped *and* the mask dropped, since a
  frozen mask still overpaints and a running ticker still schedules frames. An
  enclosing `TickerMode(enabled: false)` already worked through
  `SingleTickerProviderStateMixin` and is now documented beside it. Either lets
  a test settle with a skeleton on screen, and a user who asked for reduced
  motion gets the static placeholder.

### Added

- **`TomInfiniteScrollState` exposes the current failure (tcopen277).** The
  class is public so a `GlobalKey` holder can inspect it, and the failure was
  the one thing it could not see: `loadedCount`, `isPending` and `isExhausted`
  read identically for a list showing an error panel and one showing an empty
  state, and `errorBuilder` receives the error only inside the widget's own
  build. A caller driving the list from outside could see that it had stopped
  and not why.

  `error` returns the failure itself and `hasError` reads beside the other
  predicates. Both are cleared by `refresh()` and by the error slot's Retry.

### Fixed

- **A full first page that fitted the viewport never loaded page 2
  (tcopen276).** After the initial fetch, the only thing that asked for another
  page was the scroll listener — and a list that does not overflow cannot be
  scrolled. Exhaustion did not save it: `_exhausted` means a page came back
  short, so a *full* page that happens to fit leaves it false. A small
  `pageSize`, a tall viewport or short rows left the list showing one page with
  more data available and nothing able to ask for it.

  A page landing now re-checks, once it is laid out, whether the list has any
  scrollable extent, and fetches again if it has none. Deliberately stricter
  than the scroll rule, which fires within `prefetchOffset` of the end: using
  that here would turn every load into an immediate second request. Anything
  scrollable is left to the gesture.

### Changed

- **A failed page no longer hides the items already loaded (tcopen275).**
  `TomInfiniteScroll` returned its error slot in place of the whole `ListView`
  whenever a fetch failed. That is right for an initial-load failure, where
  there is nothing to preserve, and wrong once the user has scrolled: ten
  screens of content vanished because page six failed, and came back only on a
  successful retry.

  The two cases are now separate. With nothing loaded the report takes the
  surface as before; with items on screen it is the list's last tile and the
  rows stay where they are, at the boundary the user reached.

  `errorBuilder` is called in both placements and its signature carries which:
  `TomInfiniteScrollErrorBuilder` takes a `TomInfiniteScrollErrorPlacement`. A
  builder that assumed it owned the surface would otherwise render a
  full-height panel inside a tile. The default answers both — the centred panel
  for the surface, a compact row for the tile.

- **The error boundary's process-wide state is recoverable (tcopen273).** The
  mounted-boundary count and the builder it saved were two library variables
  nothing could reset, so a boundary whose `dispose` never ran — a test that
  tears down its binding — held `ErrorWidget.builder` for the rest of the
  process and every later test inherited a hook belonging to a widget that was
  gone. They now live in one private registry, with
  `TomErrorBoundary.debugReleaseGlobalHook()` (`@visibleForTesting`) to hand
  the slot back.

  Each share of the count is tagged with the run it was taken out in, so a
  boundary disposing after a reset is recognised and ignored instead of taking
  the slot from whoever holds it now. The unreachable `?? ErrorWidget.builder`
  fallback on the release path — which would have assigned the builder to
  itself — is gone.

### Fixed

- **A boundary stopped guarding once it had caught something (tcopen272).**
  The ref count that owns the global hook lived on a helper widget the boundary
  rendered only while `_captured == null`, so capturing an error unmounted the
  helper and dropped the count — and for a lone boundary, put the previous
  builder straight back. A boundary showing its fallback was guarding nothing,
  including its own `fallbackBuilder`, which is caller code and can throw. In a
  list of guarded rows the count fell with each row that failed, so the hook
  survived only while one row was still healthy.

  The install and release moved onto the boundary itself, where they follow it
  being in the tree — which is what "this subtree is guarded" means. The helper
  had no other purpose and is gone.

- **A mounted error boundary swallowed every error outside it (tcopen271).**
  The global `ErrorWidget.builder` hook returned a reporter for *every* error
  in the process, and the reporter rendered a blank whenever it found no
  enclosing boundary — so one `TomErrorBoundary` anywhere, on one row of one
  list, turned every unguarded build error into empty space: no red box in
  debug, and in release nothing the application had installed, including a
  crash reporter's hook. The builder that held the slot beforehand was saved
  and only ever used to restore it on unmount.

  An unguarded error now renders what it would have rendered had no boundary
  been mounted. The ancestor lookup moved from a post-frame callback into
  `build`, because whose error it is decides what the failing slot renders and
  has to be answered while that slot is being built.

- **A withheld tree node could not be collapsed (tcopen270).** Expansion and
  activation shared one handler, and that handler was null at `read` and
  `disabled` — so the chevron on a withheld node did nothing, and after the
  row gained its pointer barrier no tap reached it at all. A `read` tree was
  stuck at whatever `initiallyExpanded` left it at, with no way round it:
  expansion state is private and there is no `onExpansionChanged`.

  The expander is now a control of its own, outside the barrier and outside the
  fade. Collapsing a section is navigation, not activation; the header most
  likely to be withheld is exactly the one a user wants to fold away. It is
  deliberately *not* dimmed — a greyed control that still works is the failure
  the barrier exists to prevent, run backwards. At `full` the whole row remains
  a target and both toggles and activates, as before.

- **A tree node's key ignored its position in the tree (tcopen268).**
  `TomAuthTreeView` handed one qualifier down to every descendant, so each node
  resolved `<parentPath>.<own id>` however deep it sat. A two-level tree under
  `app` produced `app.reports` and `app.view`, never `app.reports.view` — which
  both the node's own dartdoc and the module documentation had always
  described.

  Two things followed. Sibling ids collided across branches: a `view` under
  `reports` and a `view` under `invoices` were one key and could not be granted
  apart, which is the distinction a permissions tree exists to draw. And every
  id had to be globally unique within the tree — a constraint nothing stated
  and nothing checked.

  Keys now compose along the branch, so an id need only be unique among its
  siblings. Each node builds its children's qualifier from the path it resolved
  itself, which keeps the composition in one place.

### Changed

- **`acl_container.dart` is split into a library and eleven parts
  (tcopen267).** It held 3552 lines: the model, the value types, the widgets,
  the measurement caches, three row-selection passes, the policy-path builders,
  the width-fitting engine, the geometry pass and the render pipeline. Three
  defects found in one review were the same shape — a rule enforced in one half
  of the file and quietly not enforced in the other, hundreds of lines away.

  Nothing about the exported surface changes: the barrel names one library and
  the parts come with it. Parts rather than separate libraries because privacy
  in Dart is per *library*, and the stages share private declarations; separate
  libraries would have meant making those public. The state's non-lifecycle
  members moved verbatim into one extension per part, so the split reads as a
  move. `setState` is `@protected` and an extension may not call it, so the
  three rebuild sites go through a `_rebuild()` forwarder on the class.

  The largest file in the module is now 559 lines, and
  `acl_container_parts_test.dart` holds the ceiling, the part declarations, and
  that no file in the module is orphaned.

### Added

- **A rendered example for `advanced_container_layout` (tcopen264).** The
  module shipped one example, and it demonstrated four surfaces that need no
  `BuildContext` — flag composition, the device-context resolvers, the
  visibility controllers, and a builder chain that returns an `Acl`. For a unit
  whose proposition is declarative layout, that is close to no example: a
  fluent chain reads plausibly on the page whatever it does, and the questions
  a reader arrives with are all answered at layout time.

  `example/advanced_container_layout/advanced_container_layout_rendered_example.dart`
  renders five of them and reads the result back off the render tree — a
  responsive variant (one row at 900 px, three at 400), a row breakpoint (four
  fields across, then two and two), a grid and a wrap, authorization-aware
  rendering (a withheld component shown inert, then hidden with its width
  reclaimed by the row), and the composed id a component ends up carrying.

  Its layout-building functions take no tester and no context, so each is
  ordinary builder code a reader can lift unchanged; a test holds that, since a
  helper that quietly needed the harness would still pass the run.

- **An API summary for `advanced_container_layout` (tcopen263).**
  `doc/api/api_summary_advanced_container_layout.md` lists all thirty-five
  public types the module's barrel exports, with a section each, the six
  top-level functions and constants, and every public static. The module is the
  largest in the package and had no single place its surface was listed; the
  prose reference is organised by task, which is the right shape for writing a
  layout and the wrong one for looking a symbol up.

  `doc/api/api_summary_index.md` joins it, naming both summaries and the seven
  modules that have none — an index of two files that says nothing about the
  rest reads as a package of two modules.

  `test/module_readme_inventory_test.dart` already derived each summary's
  required set from the barrel; it now also holds the index complete.

### Fixed

- **Every phone browser was classified as a pointer device (tcopen265).**
  `AclDeviceContext.resolveInputMode` returned `pointer` for any web target
  before reading the platform at all. Flutter web on a phone reports
  `TargetPlatform.iOS` or `.android`, so the switch that maps those to `touch`
  was never reached — pointer-sized hit targets and pointer spacing on the
  device class where touch accuracy matters most.

  The resolver now reads its argument and nothing else. `isWeb` stays on
  `AclDeviceContext` as its own fact, so `input: pointer` together with
  `isWeb: true` still names a desktop browser — and now excludes the phone one.
  A touchscreen laptop still resolves to `pointer`; telling those apart needs a
  pointer-capability query, and this resolver is pure and synchronous by
  contract.

- **`Flexible`, `Expanded` and `Spacer` could not be used at all (tcopen262).**
  The container has a whole `isFlexNativeChild` path that keeps every sizing
  and alignment wrapper off them — but the `AclScope` wrap ran before it, and
  unconditionally. A `ParentDataWidget` separated from the flex it describes
  cannot apply its parent data, so a single `Expanded` in a row was an
  assertion at first paint. They now reach the `Row` as its direct child.

### Changed

- **`append`'s duplicate guard covers the flex wrappers (tcopen262).** It
  compared only widgets that get a component key, so the three that do not —
  `Flexible`, `Expanded`, `Spacer` — passed through it, and those are exactly
  the widgets a layout declares once and reuses.

  A flex wrapper is now unwrapped for the comparison, down the whole chain:
  `append(w)` followed by `append(Expanded(child: w))` is the same duplicate
  written two ways. The unwrapping stops at `Flexible` and its subclasses. Any
  other wrapper is a component in its own right, so what it holds is content —
  a widget may reappear inside a later component without being a second
  component, and walking the whole subtree would have refused that.

- **Every size and alignment reference must name a component the builder has
  (tcopen261).** `sameWidthAs` / `sameHeightAs` / `sameSize` accepted any
  object: an unknown widget was given a freshly minted `GlobalKey` attached to
  nothing, the cross-dimension flag was set anyway, and the layout built
  cleanly. Nothing resolved, so the component silently kept its own size — a
  typo in the captured variable read as "these two do not match" with nothing
  pointing at the call. `doc/acl_design_specification.md` §15 already stated
  the rule for all five reference methods; `alignX*` and `alignY*` enforced it
  and the size references did not.

  All five now go through one guard. A widget appended *later* is refused
  rather than resolved — it cannot be told from a typo, and accepting it also
  made a same-row size reference legal that the row rules forbid. `Flexible`,
  `Expanded` and `Spacer` are refused by name, since the row lays those out
  itself and they carry no key. The reference parameter is now `Widget`, so a
  raw `Key` — never resolvable, and already documented as unsupported — is a
  compile error instead.

  `setComp(reference, otherAttr)` rejects an `otherAttr` carrying neither
  `AclFlags.otherDimX` nor `otherDimY`: only those bits were ever read, so the
  masking silently recorded a link nothing resolves.

- **Every per-component builder setter refuses when there is no current
  component (tcopen260).** Fourteen returned silently and `setHideUnauthorized`
  threw — inconsistent in the one respect a caller wants consistency in, and
  the silent majority was the worse half: `append(x).gap().setPSize(200)` sizes
  nothing, and nothing reports it. The layout merely comes out subtly wrong,
  which costs far more to find than a throw at the call that is wrong.

  All fifteen now throw a `StateError` naming the setter, through one guard.
  The three ways to arrive without a component — before the first `append`, and
  after `gap()`, `newRow()` or `gapRow()` — give the same message.

  This costs the conditional-append pattern (`if (x) b.append(…);
  b.setPSize(…)`), which now has to put the setter inside the condition. That
  is where it belonged: outside, it was silently doing nothing on the branch
  the author was not thinking about.

### Fixed

- **A grid at unbounded width produced cells about 9e307 wide (tcopen259).**
  `AclFlowContainer` substituted `double.maxFinite` for an unbounded width
  constraint — right for `wrap`, where it means "never break", and fatal for
  `grid`, which divides the width among its columns. The result was not an
  exception but a nonsense layout, which is harder to diagnose than a throw.

  The width now reaches `buildRows` as `null` and each kind answers it: `wrap`
  substitutes the largest finite double at the one call that wants that
  meaning, and `grid` keeps each component's own preferred width, so the grid
  is as wide as its content. `aclGridRows` guards a non-finite width the same
  way for callers reaching it directly. `AclFlowContainer.buildRows` now takes
  `double?`.

  Answered rather than asserted because unbounded width is ordinary — a
  horizontal `ListView`, an unconstrained `Row` child and Flutter's own
  intrinsic passes all produce it.

- **A variant's rows were built against framework defaults, not the
  container's (tcopen258).** `addVariant` harvests its rows from a second,
  throwaway `AclBuilder`, and that builder was constructed bare — so all eight
  `setAclDefault*` values the outer builder carried were absent inside the
  callback. A container configured for a 40 px append gap and right-aligned
  rows got 8 px and left below the breakpoint: the layout changed in ways the
  author never asked for, at precisely the widths they are least likely to be
  looking at.

  The outer builder now copies its row-level defaults onto the variant builder
  *before* the callback runs, since `append` and `newRow` read them as they go;
  the row alignment is additionally restamped onto the first row, which the
  constructor creates before any default arrives. A `setAclDefault*` call
  inside the variant still overrides the inherited value.

  Container-level settings — chrome, `aclId`, `idScope`, `aclGroup`,
  `defaultHideUnauthorized` — are deliberately not copied: they are read from
  the outer builder at `build()` and land on the container widget, which a
  variant never replaces.

- **A row kept its properties above a breakpoint and lost four below it
  (tcopen257).** The two responsive passes rebuilt `AclRow` by naming fields:
  the breakpoint split dropped `defaultRowCrossAlignment`, `gapRowWeight`,
  `separator` and `gapRowMinSize`, and the inline-variant filter dropped
  `defaultRowCrossAlignment`. A row aligned to the bottom aligned to the top
  once it wrapped — correct at the width the developer tests at, wrong at the
  width their user has.

  `AclRow.copyWith` now covers all sixteen fields and all three rebuild passes
  go through it, so a field added to `AclRow` reaches every pass without being
  named again. Two tests keep it that way: `copyWith`'s parameters and
  forwarding expressions are compared against the constructor's own (for
  `AclRow` and `AclComponent` from one list), and no pass may construct an
  `AclRow` directly.

### Removed

- **`parentIdPath` is gone from `AclContainer`, `AclLayout`, `Acl` and
  `AclFlowContainer` (tcopen255).** It was declared on four types, bound in four
  constructors, forwarded four times and read nowhere: every occurrence was a
  declaration, a `this.`/`super.` binding, or a forward into another
  constructor's parameter of the same name. `AclBuilder` even held a field for
  it with no setter, so the fluent API could never set it to anything but null.

  The path builders compose from `TomScope.current`, which is the framework's
  answer to the same question; an explicit second channel would invite the two
  to disagree with no rule for which wins. A container that needs a different
  parent pushes a scope.

  `test/advanced_container_layout/acl_inert_parameter_test.dart` now holds the
  general property — no public field of the unit is stored without being read —
  across all 97 of them.

### Changed

- **A recorded undo state is checked against the action that produced it
  (tcopen252).** `TomActionTransaction` held `(TomAction, dynamic undoState)`
  pairs and reversed them with an unchecked dynamic dispatch, so recording one
  action's state against another compiled, analyzed clean, and threw a
  `TypeError` from inside the history the first time anyone pressed undo.

  An entry now stores the two *calls* — `undo`, and `redo` or null — closed over
  both typed values where they are still statically typed. `TomAction.recordInto
  (tx, undoState)` replaces `TomActionTransaction.record(action, undoState)`.

  It is on the **action** deliberately. Tightening the transaction's signature
  to `record<TUndo>(TomAction<_, TUndo>, TUndo)` looks equivalent and is not:
  Dart's class type parameters are covariant, so inference widens `TUndo` to
  `TomActionUndo` and accepts anything — verified against the analyzer, which
  reports no error for the inference form and an error for the receiver-pinned
  one.

### Added

- **A second, advanced example for the actions module (tcopen251).** The single
  example had grown to 432 lines and still reached none of the undo/redo
  coordinator actions, the authorization surface an action exposes to a widget,
  resource-resolved captions, or the transaction API's `rollback` / `record` /
  `undoAll` / `redoAll`.

  It is now a 271-line quick start plus
  `example/actions/actions_advanced_example.dart`, which reuses the quick
  start's domain and covers all of the above. Both assert their own results and
  each has its own test file. The advanced one installs an authorization adapter
  and a text bundle and puts both back — asserted, not trusted, since a provider
  is process-wide.

- **The barrel's library dartdoc lists every type the module exports
  (tcopen250).** It enumerated ten of thirteen, omitting `TomSimpleAction`,
  `TomCompositeStep` and `TomUndoRedoContext` — each the only way to do
  something the module is for. The module `readme.md`'s key-type table likewise
  omitted `TomActionUndo`. A partial enumeration misleads more than a missing
  one: it reads as complete, so absence says the type does not exist.

  Both now list all thirteen, and the dartdoc's groupings say what each group is
  *for*. `module_readme_inventory_test` gained a `barrel library dartdocs`
  group that classifies every module's dartdoc — complete index, deliberate
  orientation, or partial with its gap measured — and holds each to it, so the
  four modules that are still partial can neither slip further nor quietly
  improve into passing a weaker check.

- **An API summary for the actions module (tcopen249).**
  `doc/api/` existed and was empty — the package had no symbol-level mirror for
  any module, where every other scanned tom_core unit has one.
  `doc/api/api_summary_actions.md` lists all thirteen public types with their
  members, signatures and defaults, the file each is exported from, and the
  class hierarchy. `doc/actions.md` remains the explanation and the two link to
  each other; `doc/README.md` gained an *API summaries* section.

- **A duplicate action id is refused (tcopen248).**
  `TomActionController.registerAction` was `_actions.add(action)` with no check,
  so two actions could share an `actionId` on one controller: the second was
  unreachable through `findAction` for the controller's lifetime, and both
  resolved the canonical path `<controllerId>.<actionId>` — one authorization
  decision and one set of label, tooltip and icon keys for two behaviours. It
  now throws `StateError`, naming the id, the controller and the path they would
  share. The same id on a different controller is a different path and is still
  fine.

  `TomActionController.addUniquely` is the single definition of the rule, static
  because `TomForm` implements the controller interface rather than extending it
  and keeps its own list; both registrations route through it. Registration
  happens in the `TomAction` constructor, so with the canonical `late final`
  fields the throw surfaces when the second of two colliding fields is first
  read — reading only one constructs only one action, which collides with
  nothing.

- **Authorization refuses execution, not only display (tcopen247).**
  `TomActionTrigger.trigger()` read neither `authState` nor
  `effectiveAuthState`, so an action resolving to `none` executed when
  triggered — while `TomAction` implements `TomAuthorizable`, its dartdoc listed
  "Authorized" among four defining properties, and `doc/` gave authorization a
  section of its own. `TomAction.isAuthorized` (`effectiveAuthState
  .isInteractive`) is now read by the trigger before it dispatches and by
  `TomCompositeAction` before it runs a step, in both cases *before* the context
  builder runs, since a builder is application code that may read the data the
  refusal is about. The refusal reuses `onCannotExecute` rather than adding a
  callback — `action.isAuthorized` already distinguishes the two reasons.

  `isInteractive` rather than *not `none` and not `disabled`*, so the trigger
  and the button cannot disagree about a `read` action; `effectiveAuthState`
  rather than `authState`, so a group ceiling blocks an otherwise permitted
  action. Not a security boundary — the server enforces.

- **A controller's `tomGroup` reaches its actions (tcopen246).**
  `TomActionController.tomGroup` was declared, constructor-assigned and read
  nowhere, under a dartdoc promising "collective action control". Collective
  control was real but ran entirely off each action's own `tomGroup`, so a
  controller constructed with a group changed nothing about its actions — every
  one still had to be handed the same group by hand, which is the wiring the
  field's name says it removes. `TomAction.tomGroup` is now resolved rather than
  assigned: its own when given one, otherwise the controller's, computed in the
  initializer list because the constructor body registers with the result. The
  inherited group is a real membership, so the group can reach the action back;
  an action naming its own group overrides it, and the overridden group never
  sees that action. The ceiling is still looked up in the *action's* frame.

- **`TomActionContext.scope` is the invocation frame, and is now read
  (tcopen245).** It was declared, constructor-assigned and read nowhere, under a
  dartdoc naming a behaviour — "the scope in which this action is executing" —
  that nothing performed. `TomActionContext.runInScope` is now the one place the
  field is read, and every consult of an action with a context goes through it:
  `canExecute` from `TomActionTrigger` and from `TomCompositeAction`, `execute`
  from `TomActionTransaction.run`. Anything those reach that reads
  `TomScope.current` therefore sees where the invocation is happening. The gate
  and the body share the frame deliberately — a `canExecute` reading a different
  scope from the `execute` it guards would be worse than no guard.

  Distinct from `TomAction.scope` and `TomActionController.scope`, which are
  *construction* frames: they fix `canonicalPath` and the group ceiling and do
  not move. Null stays the ordinary case and means the ambient frame.

- **Redo re-applies the transaction (tcopen244).** `TomUndoHistory.redo`
  restored the stack position and re-applied nothing, while `canRedo`,
  `redoLabel`, `redoCount` and `TomRedoAction` all shipped as if it worked — so
  the toolbar the documentation described had a working Undo and a Redo button
  that enabled itself and did nothing. The cause was an asymmetry in
  `TomAction`, which had a reverse hook and no forward one. It now declares
  `redo(TUndo undoState)` and `isRedoable` beside `undo` and `isUndoable`;
  `TomActionTransaction` gained `redoAll()`, applying entries in the order they
  executed where `undoAll` reverses them; and `redo()` calls it. The forward
  hook takes the undo state rather than replaying `execute`, because the
  transaction never keeps the `TContext` an action ran with.

  Redo is opt-in per action, so `canRedo` is now true only when the redo stack
  is non-empty **and** the transaction on top reports `isRedoable` — otherwise
  the same inert button would have survived under a new mechanism. `redoLabel`
  is null in that case, and `redoAll` throws naming the action that lacks the
  hook. `isUndone` is now a direction rather than a latch: `undoAll` sets it,
  `redoAll` clears it, and each refuses when the transaction is already the way
  it would leave it.

### Fixed

- **`undo(); redo(); undo();` applied the same undo twice (tcopen243).**
  `TomUndoHistory.redo` re-executed nothing at the time, so a second `undo`
  asked `TomActionTransaction.undoAll` for undos that were already spent — and
  it applied them again. Invisible for an undo that assigns a previous value, a
  duplicated row for the module's own documented `DeleteOrderAction`, whose undo
  restores what was deleted. `undoAll` now refuses an already-undone
  transaction, before touching any entry, and `isUndone` reports the state;
  tcopen244 above made `redoAll` the way out of it. `rollback` also marks the
  transaction undone but stays a silent no-op on a second call — it runs from
  error handling that may be reached twice, where throwing would replace the
  original failure. `TomUndoHistory.undo` undoes before it moves either stack,
  so a refusal leaves the history untouched.

### Changed

- **The UI protection switch can be turned off by a define (tcopen75).**
  `flutter run --dart-define=tom.protection.ui=false` (or `tom.protection=false`)
  starts the app with the four-state model bypassed; application code can call
  the kernel's `TomResourceKeyProtection.applyArguments` or `disableAll()`.

- **`TomTextField.buildCounter` is wrapped around `ScopeCapture.run`
  (tcopen73).** The kernel's `wrapCounter` is gone; the named-parameter
  `InputCounterWidgetBuilder` is now wrapped here, still re-entering the scope
  the field was built in. A widget test pins the scope and every forwarded
  argument.

- **The README stated version 1.0.0 against a pubspec at 1.1.0 (tcincb153).**
  The version in a `## Status` block is what tells a reader which release the
  document describes, so a wrong one misleads rather than merely disappointing.
  Corrected, and the test count beside it removed — nothing connected that
  number to the suite, so it could only rot.
  `tom_ai/core/tool/check_readme_status.py` now holds both rules across every
  package here.

- **Two Overview tables did not list every type their module exports
  (tcincb151).** `doc/widget_base.md` covered the twenty family branch bases
  with one row ending in an ellipsis — `` `TomButtonBase`, `TomInputBase`,
  `TomSelectBase`, … `` — and omitted `TomAuthLayers`; `doc/actions.md` omitted
  `TomCompositeStep` and `TomUndoRedoContext`.

  The ellipsis is the defect rather than an abbreviation of it. A reader takes
  the silence of a list for an answer, and a list that trails off says nothing
  about what is not on it, so a branch base can go missing without contradicting
  anything. The row still covers the twenty on one line — grouping what is used
  as a set is what these tables are for — but it now names them.

  `tom_ai/core/tool/check_doc_overview_types.py` holds the tables to their
  modules from now on, across this package, `tom_core_server` and
  `tom_core_agentic`. It states its own totals when it runs; they are not
  repeated here, because a count in prose is a claim nothing recomputes.

- **The package is `dart format`-clean, and a gate keeps it that way
  (tcincb91).** The 245-file reformat this todo asked for landed on its own in
  an earlier pass, and the `Radio.onChanged` deprecation it flagged was closed
  by the `RadioGroup` migration a week before that — both verified here rather
  than assumed. What was still missing is the part that stops it recurring:
  this package had drifted twice and had no guard, unlike `tom_core_kernel` and
  `tom_core_server`, which each grew an in-suite `formatting_test.dart` after
  the same experience.

  `tom_ai/core/tool/check_dart_format.py` holds every Dart file in the
  repository — 1537 across 23 packages — to `dart format`, with `--fix` to
  repair and a self-test that perturbs a file and requires the gate to object.
  One gate rather than a third copy of the test: nothing about the rule is per
  package, so copies would differ only in which files they walk, which is the
  part that goes stale.

- **This package's module documents follow the framework-wide Dependencies
  table (tcincb85).** `| Dependency | Kind | Imported by | For |`, ordered
  dart, package, module, and held to the module's real imports by
  `tom_ai/core/tool/check_module_dependencies.py` — in both directions, and per
  dependency for the files credited with it.

- **One spelling for the authorization group: `tomGroup`, everywhere.**
  `TomForm` and `TomActionController` took the same
  `TomAuthorizationGroup?` as `authorizationGroup` while the ~45 declarations of
  the `TomNodeBase` family took it as `tomGroup` — and the two spellings sat in
  one file on sibling types, so a reader who had just written a `TomForm` had
  no way to guess the field inside it used the other name. The analyzer's only
  feedback was `No named parameter with the name 'tomGroup'`, which reads like
  the group is unsupported there rather than renamed, and that trap had already
  produced one wrong kernel dartdoc. Both are now `tomGroup`; the generated
  reflection companions in this package, `tom_core_flutter`, five
  `tom_core_samples` packages and `tom_uam_client` are regenerated rather than
  edited, because the generator deduplicates a map key rather than substituting
  it and a hand-edit does not reproduce.

- **`kernel_types_coexist_test.dart` now compares the whole name set, not the
  four names it happens to write.** The file already imported both public
  barrels unprefixed and named `TomEnvironment`, `TomPlatform`,
  `TomConfigEnvironment` and `TomConfigPlatform`, so losing the rename stops it
  compiling. That is the strong half, and it is only strong about names it
  mentions: Dart reports an ambiguous import at the *use* site rather than at
  the import, so a future collision on any other name would leave this file
  green and silently strand whichever consumer named that type instead.

  The added case intersects every public type under `lib/src` with every public
  type reachable through the kernel barrel — the kernel's own, plus
  `tom_basics` and `tom_crypto`, both of which it re-exports in full, which is
  how `TomEnvironment` and `TomPlatform` collided in the first place. Measured
  today that is 628 names against 233, intersecting in **none**; so the
  environment/platform pair was the only collision the package ever had, rather
  than the only one anybody had noticed.

  Verified by declaring a `TomLogOutput` — a `tom_basics` name this file never
  writes — under `lib/src`: the compile-time half stays green and the set
  comparison fails naming it, which is the case the guard exists for.

- **Every module readme now declares what it claims about its surface, and the
  claim is checked.** `module_readme_inventory_test.dart` held four of the nine
  modules to "the table lists everything" through an opt-in list. An opt-in list
  says nothing about the modules outside it, so five sat uncovered without
  anyone having decided they should — `custom/` among them, which passed the
  inventory assertions all along and had simply never been added.

  The list is now an exhaustive classification, and a test fails when a module
  ships a readme the map does not classify (or the map names one that no longer
  exists). Seven modules are `inventory`; two are `rule`.

  **`advanced_container_layout` and `widget_base` joined the inventory**, which
  meant writing the missing rows rather than relaxing anything. ACL was short 16
  types and 10 statics — ordinary API (`AclDirection`, `AclScope`,
  `AclSeparatorStyle`, the four `AclFlags` cross-dimension constants, the
  `AclDeviceContext` resolvers), plain drift of the kind the check exists to
  stop. `widget_base` was short 22 types and 52 statics: the twenty family bases
  are now one section, and `TomCtr` and `TomStyleResolvers` have tables, so the
  resolver API an author actually calls is written down for the first time.

  **`widgets` and `forms` are `rule`**, and a `rule` readme has to carry a
  literal `**Not an inventory.**` callout — the classification is not licence to
  say nothing. Each names the rule it follows and points at its complete list,
  and in both cases that list is already machine-checked: the widget kit's is
  `test/widgets/widget_conformance_registry.dart`, held to the module in both
  directions by that suite's `tccm1` group, and the field catalogue's is
  Appendix C of `doc/tom_ui_widgets_forms.md`, held to `lib/src/forms/fields` by
  `tool/check_doc_class_inventories.py`. So a reader is never left without an
  exhaustive list, and no list is kept twice.

  Two supporting fixes the classification forced. `_exportedSources` hard-coded
  `<module>/<module>.dart`, which threw for `custom/` and `forms/` — they name
  their barrels after what they hold — so those two could not have been
  classified without a lookup; and the barrel file itself is now scanned, since
  a module may declare a type there rather than beneath it.

- **The inventory check stopped passing vacuously on short names.** It asked
  `readme.contains(symbol)`, and this module set is full of symbols that are
  substrings of ordinary English: `TomCtr` alone declares `text`, `list`, `map`,
  `value` and `exists`, and `AclScope` declares `of`. Each of those passed
  against any prose at all, so the check was weakest exactly where a reader
  needs the documentation most. A symbol now counts only as a whole word inside
  an inline code span, which is how these readmes write API — whole-word alone
  would not do, since "one **of** them" is a word. All seven inventory modules
  pass under the strict matcher.

- **The config enums are `TomConfigEnvironment` / `TomConfigPlatform`, so this
  package and `tom_core_kernel` can be imported into one library.** They were
  `TomEnvironment` and `TomPlatform` — the names two *classes* in `tom_basics`
  already had, and the kernel barrel re-exports `tom_basics` in full. Both
  spellings of each name therefore reached any library importing both barrels,
  and every use of either was an `ambiguous_import` error.

  That hit a consumer following this package's own advice.
  `doc/kernel_types.md` tells you to import the kernel directly for anything
  off the 26-name bridge — wiring `TomHttpFileTransferClient`, say — so doing
  the documented thing and also naming a `TomEnvironment` did not compile
  without a `hide` or a prefix.

  It is a naming defect rather than a design tension, and it is fixed on this
  side of it. `tom_basics` keeps the plain names: it is published, and its pair
  describe the *runtime the process executes in* (they select beans by
  environment and platform). This package's pair are *configuration inputs a
  widget resolves against* — the two fields of `TomConfigProvider` — and are
  now named for it. Different concepts that happened to share two words; the
  narrower one moved.

  `test/kernel_types_coexist_test.dart` keeps it fixed. It imports both public
  barrels unprefixed, with no `hide` and no `as`, and names types from each, so
  a future common name stops the library compiling and the suite fails to load.
  The collision was originally found with a throwaway probe file, and could
  only be found that way — neither package's suite imports the other's barrel.
  That probe is now checked in.

  One consequence worth recording: with the collision gone, a blanket
  re-export of the kernel from this package would compile. The `show` list in
  `lib/src/kernel_types.dart` stays, on the scoping argument that was always
  its other reason — the two packages answer different questions, and an
  application doing kernel work should import the kernel and say so. The
  dartdoc and `doc/kernel_types.md` no longer claim the collision forces it.

- **`tool/generate_icons.dart` emits no timestamp, and both resource-table
  generators format what they write, so re-running either produces no diff.**

  A checked-in generated table is only checkable one way: regenerate it and
  look for a diff. `generate_icons.dart` stamped
  `// Generated on: ${DateTime.now()...}` into
  `lib/src/resource_auth/tom_icons_generated.dart`, so every run diffed whether
  or not an icon had moved — which cost the 10147-entry table the one property
  that made it verifiable. The header now records only what the contents
  determine: the source files it parsed, and the three counts, all computed
  from the maps' `.length`.

  Both generators also run `dart format` over their output. The emitter writes
  one entry per line and lets the formatter decide the wrapping; without this
  step the raw output differed from the committed file on about a hundred
  lines, so reproducibility depended on the caller remembering a second
  command rather than on the generator.

  Regenerating against Flutter 3.44.6 changed nothing but that header — 8825
  Material and 1322 Cupertino icons, the same 10147 keys the March table held,
  so no name that `AllIconsAdapter` / `MaterialOnlyIconAdapter` /
  `CupertinoOnlyIconAdapter` or the widget tests resolve has gone.

  `test/resource_auth/resource_auth_test.dart` holds **both** tables to both
  properties — counts justified by the entries, no timestamp — through one
  `generatedTableHeaderTests` helper, replacing the colour-only pair.

- **`doc/tom_ui_widgets_forms.md` now carries one inventory of the form field
  classes instead of five, and that one is checked against the source tree.**

  The document listed the field hierarchy in five places — §6 (the abstract
  types), §7 (a concrete table per type), §8 (a `Used by:` line per widget),
  Appendix B (a widget cross-reference, including a "Complete Widget
  Inventory"), Appendix C (the class hierarchy inventory), and again in §26's
  API-summary table. Five hand-maintained lists of one fact drift the moment
  any of them moves, and all five had.

  What they had drifted into is worth stating, because it decided the repair.
  Appendix C marked **81 rows** `**(TBD)** = class needs to be created` against
  classes that had shipped — `TomFormStringInput`, `TomFormIntSlider`,
  `TomFormBoolSwitch`, `TomFormDatePicker`, `TomFormFileUpload` among them. But
  clearing those markers would have made the document worse, not better: of the
  78 distinct names the appendix carried, **42 named nothing at all**, either
  because the class was built under a different name (`TomCupertinoFormDatePicker`,
  not `TomFormCupertinoDatePicker`) or because it was never built. Clearing a
  marker converts "wrongly says this does not exist" into "wrongly says this
  does", and a reader can falsify the first claim by opening the file while the
  second is unfalsifiable short of an exhaustive search. Three classes that had
  shipped — `TomFormFileDropzone`, `TomFormFileThumbnail`, `TomFormDateTextInput`
  — appeared in none of the five lists.

  So Appendix C was rebuilt from the tree and the other four reduced to
  pointers at it: §6 is now scheme (the naming convention, the twenty-three
  abstract types and what each binds, how nullable, multi-value and range
  fields differ), §7 keeps the selection machinery and drops its tables, §8's
  `Used by:` lines name real classes, Appendix B is eleven lines of pointer,
  and §26 is eight. The measured counts are **23 abstract types, 74 concretes
  (46 Material, 28 Cupertino), 97 classes** in the `TomField` hierarchy.

  Several claims in the surrounding prose fell with the tables. There is no
  `TomFormCupertinoStyle`: the 28 Cupertino fields read the same `TomFormStyle`
  as the Material ones. There is no `AsyncSelectableSource`, no
  `ObservableSelectableSource`, no `EnumSelectableSource` — the sources are
  `TomSelectableSource<T>` and its three implementations, and the only reactive
  binding a field offers is `itemsStream`. The decoration mixin is
  `TomGenericFieldDecorationMixin`, one of three, and every spec field carries
  exactly one of them. Sliders and range fields take plain `int`/`double`
  bounds, not observables.

  The six wrapper value types the document specified — `TomDuration`,
  `TomIntRange`, `TomDoubleRange`, `TomFileRef`, `TomNDuration`, `TomNFileRef`
  — were never built and are not going to be. `TomField<T> extends
  TomObject<T>`: the field *is* the observable over the plain Dart value, so a
  second observable wrapper around `Duration` would be one layer for no reader.

### Added

- **`test/example_instructions_test.dart`** — the guard on the command each
  shipped example tells a reader to run. All eleven named
  `flutter test example/<dir>/<name>_example.dart`, which *does* run the example
  — `main()` executes at load time, every print appears, every assert is
  evaluated — and then exits **79**, "No tests were found", because an example
  declares no `test()` of its own. A reader watching the output concludes it
  worked; anything reading the exit code sees a broken example that did exactly
  what it should, and it exits 79 whether the assertions held or not, so the
  code carried no information at all. Each header now names the suite that calls
  its `run()`, which exits 0 on success and non-zero on a failed assertion. The
  headers' premise was right and is kept: the barrel pulls in `flutter/material`
  and so `dart:ui`, and bare `dart run` genuinely cannot load one of these.

  The guard reads a header **unwrapped**. A dartdoc sentence breaks wherever the
  margin falls, and one of the eleven split the command down the middle —
  `flutter test` ending a line and `example/widget_base/…` starting the next —
  so a line-oriented search finds ten and reports the package clean. That is how
  the eleventh survived the sweep that measured this defect.

- **`tool/check_doc_class_inventories.py`**, which holds a marked inventory to
  the directory it inventories, in **both** directions. A region declares
  itself in the markdown source —

  ```markdown
  <!-- class-inventory: tom_flutter_ui/lib/src/forms/fields extends TomField -->
  ```

  — and the gate then reports `MISSING` for a class the directory declares that
  the region never names, and `PHANTOM` for a `Tom*` name the region lists that
  no `lib/` in the repository declares. Both directions had been live in the
  forms appendix simultaneously, which is why one direction would not have been
  enough: an inventory decays when code moves away from it just as readily as
  when it claims something that was never written.

  The gate refuses to be vacuously green — it exits 2 when its declaration
  index is empty, when no marked region is found, or when a region resolves to
  a directory declaring nothing of the named family — and `--self-test`
  perturbs a real region by one name in each direction and requires the checker
  to object.

- **`repo_doc_gates_test.dart` now asks whether the gates still detect
  anything**, not only whether they are quiet. Every assertion the file made
  until now passed in two states that look identical from the outside: the
  documents are right, or the checker stopped reading them. A gate held to a
  baseline of zero faults reports zero faults either way.

  That is not a hypothetical reading of the design. Eleven wrong figures once
  stood across six of the sample completion documents while
  `check_doc_inventories` sat at exactly its baseline both before and after they
  were corrected — it saw none of them, because at the time it read neither the
  census sentences nor the per-file lengths those figures lived in. The gate was
  green throughout.

  So a second group runs `--self-test` on every checker that implements one.
  `check_doc_inventories --self-test` takes each family of numeric claim it
  audits, finds a document that carries one and currently measures it
  correctly, raises a single figure by one **in memory**, and requires the audit
  to object. Five families are covered: a package census's file count, its Dart
  count, its per-directory split and its hand-written line total, and a
  per-file length label inside a layout fence. A family with no document to
  perturb fails too — coverage with nothing to run on is not coverage.

  The self-testing gates are discovered by reading `tool/` for the flag, the
  same way the gate list itself is discovered, so a checker that grows a
  self-test tomorrow is exercised tomorrow rather than whenever someone
  remembers to register it.

### Removed

- **`TomDualAction`**, a two-sided convenience wrapper that was fully
  expressible as a two-step `TomCompositeAction` and had no call site anywhere
  in the workspace — not in an application, not in an example. Its own test
  group asserted the equivalence: a dual matched the composite it was built to
  save the caller from writing, over all four guard combinations.

  Two classes for one shape also cost more than they saved. Each carried its
  own `canExecute` rule, so the "does the button do anything?" contract had to
  be stated and pinned twice; and their defaults disagreed on the one thing a
  caller migrating between them would never be warned about — a composite stops
  at a blocked step, whereas the dual always skipped past one.

  Both of its shapes are `TomCompositeAction`. The two sides need not share a
  context type, because `TomCompositeStep`'s type parameter is covariant and one
  `List<TomCompositeStep>` therefore holds steps with unrelated contexts; and
  where neither side should block the other, `stopOnBlockedStep: false` says so
  explicitly instead of leaving it implicit in the choice of class.
  `TomCompositeAction`'s dartdoc now carries the two-sided framing, and the test
  that pinned mixed context types moved to the composite group, where it always
  belonged.

### Documentation

- **ACL row cross-alignment is described by the edges it actually uses, not as
  a "baseline".** An ACL row aligns its components to the row's top, middle or
  bottom **edge**: `AclRowCrossAlignment.{top, center, bottom}` resolves to
  `CrossAxisAlignment.{start, center, end}` and never to
  `CrossAxisAlignment.baseline`, which would need a `TextBaseline` the engine
  never supplies. Four places said "baseline" anyway — including the §11
  heading of `doc/acl_design_specification.md`, which is where a reader goes to
  learn what the enum means. Calling edge alignment a baseline invites the
  reader to expect text to line up across fields of different font sizes, which
  it does not.

  The heading is now "Row Cross-Alignment (per-component vertical placement)",
  wording taken from the enum's own dartdoc so the specification and the source
  say the same thing. The section **number** is untouched: nineteen `§NN`
  citations in `lib/` resolve by number, and `acl_shipped_text_test.dart` pins
  them by number as well.

  The same repair corrected a snippet that would not compile: the layout
  rules-of-thumb told the reader to call `setAclDefaultRowAlignment(...)`, a
  method that exists nowhere in the framework. The builder's method is
  `setAclDefaultRowVerticalAlignment`, which is what all twenty-five call sites
  in the two test harnesses use.

  Genuine baselines are left alone — `TomBaseline`, `textBaseline` and
  `_kBaselineDescentAdjust` are Flutter's text baseline, and the forms
  framework's `commitBaselines` is a saved-state reference point. Three
  meanings of one word, and only the alignment one was wrong.

- **Work-item ids are now caught by their shape rather than by a list of
  prefixes, and the ids they were letting through are gone.** A comment naming
  `RCA5`, `CSEXF1` or `tcca17` points at a row in a quest document that ships
  with neither this package nor its tests, so to a reader it is noise that looks
  like it ought to mean something. The guards that were supposed to prevent that
  matched a list of known quest prefixes — an **open** set, which grows every
  time anyone mints one, so an unrecognised id was not merely permitted but
  invisible.

  All three guards — this package's sibling in `tom_core_kernel`, the one in
  `advanced_ops_server`, and the repo-wide
  `tom_ai/core/tool/check_comments_read_as_is.py` — now match the *shape* of an
  id against a **closed** vocabulary of ordinary and published technical words.
  Minting a new prefix cannot defeat that, because it does not make the new
  stem a word.

  Case had been a second way past them: every shape was lowercase, so an id
  written the way prose usually writes one — shouted — walked straight through.
  104 ALL-CAPS pointers in 18 families were shipping across the tree while every
  guard reported clean, 24 of them in this package's suite headers and three in
  `doc/container_widget_resources_authorization.md`. Each now states the fact
  the id stood in for, or is simply dropped where the sentence survives without
  it. Gate baseline lowered 38 → 21, with the 21 survivors all belonging to the
  separate history-narration rule.

- **`shipped_text_test.dart` now says why it is not the same guard.** It bans
  three specific outside vocabularies — `CE-LO`, `XDS`, `csexb2` — and two of
  them have no id shape at all (`CE-LO` is hyphenated with no digit run, `XDS`
  carries no digits), so folding it into the shape guards would silently lose
  those cases. The header records the division of labour so a future reader does
  not consolidate them.

- **43 source comments cited a section number of a document the reader does
  not have.** `(gap §15a)`, `bug §77`, `tests §59(d)`, `[Phase 2a §16]` — the
  numbers index workspace-only planning documents, which ship with neither the
  package nor its tests. From the rendered API docs, or from a `flutter test`
  failure message, they resolve to nothing at all: the reader cannot even
  determine *which* numbered document was meant, since the workspace has
  several.

  Each one now says in its own words what the number stood in for. Where the
  reference is genuinely to a document that ships — §17 and §26b of
  `doc/acl_design_specification.md` — the comment names that document beside
  the number, so the citation is followable from the source alone. `§`
  followed by a bare number is now a gate failure
  (`tom_ai/core/tool/check_section_refs.py`, baseline lowered 101 → 0).

  Several of the rewritten comments carried the number inside a sentence about
  the code's own past ("was previously dropped", "had zero coverage"), so they
  were rewritten to state the present contract instead; that also took
  `check_comments_read_as_is` from 40 to 38.

- **44 `Kind` cells across seven documents answered a question the column does
  not ask.** The `Kind` column exists so a reader can tell what they may *do*
  with a symbol before reading further — `abstract interface class` says
  implement me but do not extend me, `final class` says neither. Cells reading
  `StatefulWidget`, `widget`, `action`, `adapter`, `static helpers` or
  `interface` are all true statements about the symbol's *role*, and none of
  them answers that question; `interface` is worse than useless, because
  `TomScreenElementsProvider` is an `abstract interface class` and
  `TomScreenElementsProviderBase` is a plain `class`, and the row spent one word
  on both.

  Every such cell now carries the declaration exactly as Dart writes it. Where
  the cell also carried a *fact* — `Validators` being static factories,
  `TomScopePath` / `TomCtr` / `TomStyleResolvers` being static helpers — the
  fact moved into `Purpose` rather than being dropped, since the neighbouring
  column is where role belongs.

- **`src/resource_auth/resource_auth.dart` now states why it omits the two
  generated tables.** The barrel exports three of the five Dart files beside
  it; the other two, `tom_colors_generated.dart` and `tom_icons_generated.dart`,
  hold 355 `Color` and 10147 `IconData` constants that `tom_colors.dart` and
  `tom_icons.dart` wrap. That they are wrapped rather than re-exported is a
  decision — the catalogue is the public surface, an application extends it by
  registering an adapter, and the raw constants carry no `Tom` prefix, so
  exporting them would breach the package's namespacing rule as well. The
  reason is now written in the barrel, next to the decision, in two
  `// not-exported: <file> — <reason>` markers. A new repository gate,
  `tool/check_barrel_exports.py`, reports any Dart file beside a barrel that no
  barrel reaches and no marker declares, and holds the markers themselves to
  naming a file that exists and is genuinely unreachable.

### Fixed

- **A comment in `widget_base_malformed_type_test.dart` opened by pointing at a
  quest backlog, and the repo-wide gate could not see it.** The line read
  `bug §77 / tests §61(e):` — two numbers indexing lists that ship with neither
  the package nor its tests, so no reader of either can resolve them.

  It survived `tool/check_section_refs.py` for an instructive reason. That gate
  accepts a section number when a document is named *in view* of it — the same
  line, or an adjacent line in the same comment block — because a citation split
  across a line wrap is still one sentence. Two lines below, this comment cites
  `doc/widget_base.md`, which is a real document and a correct citation, made by
  a different sentence. Proximity vouched for the pointer.

  The comment now states the rule it was gesturing at: the resolvers' tolerance
  has to cover an entry that is present but of the wrong runtime type, not only
  one that is absent. The gate learned the distinction proximity cannot draw — a
  number whose nearest preceding word is `bug`, `tests`, `gap`, `phase`, `step`,
  `item`, `plan` or `todo` names a backlog rather than a document, and is a fault
  whatever else is on the page. Genuine citations are untouched, wrapped ones
  included, because a citation names something the reader can open.

- **The barrel rule's exemption list was granted per file, not per import.**
  A test may reach into `lib/src` only where the barrel cannot express what it
  needs, and `package_barrel_test.dart` records each such file with its reason.
  But the check was membership: once a file appeared on the list, *every* one of
  its `src/` imports was licensed, including the ones the barrel offered
  perfectly well. `file_opener_test.dart` earns its place with the `file_opener`
  trio, three files deliberately not exported because they are internal plumbing
  — and carried a fourth import in behind them,
  `src/forms/files/tom_file_picker_registry.dart`, exported all along through
  `src/forms/tom_forms.dart`. It now imports the package barrel like every other
  test, and the exemption is as narrow as its stated reason.

  A new check re-derives the licence from the export graph rather than trusting
  the list: `barrelReachableFiles()` walks the `export` chain from
  `lib/tom_flutter_ui.dart`, and an exempt file reaching a library in that set
  fails with the pair named. The exemption cannot silently widen again, because
  widening it now requires the library to be genuinely unexported.

- **A root screen provider prefixed every lookup with `default.`.**
  `TomScreenElementsProviderBase` built with no scope id is meant to add no
  segment, and it implemented that by copying the surrounding scope's `id` and
  `parent` onto itself. For an ordinary surrounding scope the copy renders the
  same path, so the intent held. For the root it did not:
  `TomScope.buildScopePath` elides the root by **identity** and never by name —
  deliberately, so that a domain scope legitimately named `default` keeps its
  segment — and a copy can reproduce an id and a parent but not an identity.
  So the copy stopped being elided and contributed a `default` segment the
  original does not have.

  A provider with no surrounding zone is the default shape, not an edge case,
  so the path affected was the common one: `default.field` instead of `field`
  for its own widgets, `default.order` for every provider nested beneath it,
  and a `default` segment injected into anything run through its `runInScope`.
  Resource and authorization lookups then addressed a subtree that does not
  exist, which does not throw — `TomCtr` echoes the unresolved key — so the
  screen renders with its keys showing rather than failing anywhere a stack
  trace would name.

  The provider now *holds* the scope it passes through to instead of copying
  its identity, and forwards `scope`, `getScopePath()` and `runInScope()` to
  it. Forwarding `scope` is what fixes the nested case, since a child provider
  parents onto `parent.scope` and so now reaches the original rather than the
  copy. It still initialises its own identity, so it remains usable wherever a
  scope with an identity is required.

  Six tests in `scope_propagation_test.dart` cover it, paired with two that
  pin what must **not** change: adoption of a non-root scope still yields that
  scope's path, and a provider whose scope id genuinely is `default` still
  keeps its segment.

- **Two documents said nine shipped widgets did not exist.** A planning table
  headed `Implemented` listed eleven custom widgets as `No`, and a verbatim copy
  of it sat in a second document. Nine of the eleven ship — seven of them with
  their own section in `custom.md` — and one row denied `TomTreeView` three
  hundred lines below the row in the *same* document recording it as wrapped.

  This kind of claim rots in a way review cannot catch. It was true when
  written; the moment it stopped being true left no trace in the diff of either
  file, because building `TomEmptyState` does not touch the document saying
  `TomEmptyState` does not exist. There is no edit to review, so only
  re-checking finds it — hence `tool/check_unimplemented_claims.py`, which fails
  when a table denies the existence of a `Tom*` type that `lib/` declares. It
  reports 9 against the previous revision and 0 now.

  The duplicate table is gone rather than corrected twice: `tom_ui_widgets_forms`
  §23 now points at the one in `tom_ui_flutter_widgets`, because two copies is
  what turned one stale fact into two. The two widgets that genuinely were never
  built are kept as rows saying **why** — `TomResourceText` is what `TomText`
  already does via `tomId`, and `TomPermissionBadge` is `TomBadge` plus a
  role vocabulary only an application can supply. A proposal deleted in silence
  is a proposal that gets made again.

  Corrected alongside them: the `TomRadioGroup` row, which described a widget
  that groups `TomRadio` children (it renders `Radio<T>` under a `RadioGroup<T>`
  ancestor, and never did group the wrappers); the `Radio` and `CupertinoRadio`
  survey rows, which predate `RadioGroup` and omitted that selection comes from
  an ancestor; the roadmap's Phase 6, which called the same nine widgets
  unscheduled when all of them ship — its demos Q and R are the part that really
  is outstanding; and the survey header, which now says outright that it is a
  Flutter 3.41.4 snapshot while the workspace builds against 3.44.6.

### Changed

- **`TomCtr.defaultText` / `defaultTextOrEmpty` are now `TomText.defaultFor` /
  `TomText.defaultOrEmpty`.** The two helpers that build the `TomText` filling
  an unclaimed `child:` slot lived on `TomCtr` in `widget_base/`, which made the
  foundation layer import `widgets/labels/` — and since `TomText` extends
  `TomFamilyBase` extends `TomPolicyNodeBase` extends `TomNodeBase`, a
  `widget_base/` member depended on three of its own siblings by routing through
  the layer built on top of them.

  That cost was real rather than stylistic: when `TomNodeBase` needed the
  scope-path rule that `TomCtr.resolvePath` already implemented, calling it
  would have closed the loop, so the rule had to move to a new Flutter-free
  `tom_scope_path.dart` instead. Returning a widget is the tell for which layer
  a helper belongs to; all eight call sites were already in `widgets/`, so they
  now import a sibling rather than reaching down.

  `TomCtr.childTomId` stays — it composes the *id*, which is a `String`, and is
  the half of the job the foundation is allowed to do.
  `test/widget_base/widget_base_layering_test.dart` holds the arrow down, and
  does so **transitively**: a direct-import check would pass the moment someone
  routed the same dependency through one intermediate file, which is the shape
  this kind of violation takes once a direct import has been forbidden.

### Fixed

- **`TomStyleResolvers.parseEdgeInsets` built an `EdgeInsets` out of a value it
  could read nothing from.** `{'all': 'x'}`, `{'nonsense': 1}`, `['x']` and
  `['x', 'y']` all resolved to `EdgeInsets.zero` — a real object assembled from
  four absent sides. `EdgeInsets.zero` is indistinguishable from a deliberate
  "no padding", so `TomCtr.edgeInsets(path, 'padding') ?? defaultPadding` never
  reached its fallback and a typo'd resource key rendered flush to the edge
  rather than reporting itself. This was the last parser in the class not
  holding the null-for-nothing-contributed contract; it holds it now, at every
  list length and for the map form, and `widget_base_resolvers_test.dart`
  asserts it alongside the other eighteen instead of naming it as an exception.

  Element tolerance is unchanged and remains a separate rule: a bad element
  still costs its own slot and nothing else, so `['x', 2]` is still a vertical
  inset of 2 and `[1, 'x', 3, 4]` still keeps three sides.

  The nested route inherits the fix — `parseInputDecoration`'s `contentPadding`
  feeds the enclosing map's nothing-contributed check, so a decoration whose
  only key is a typo'd padding now collapses to `null` rather than coming back
  non-null with zero insets.

- **`TomAuthState.disabled` was granted and never enforced by the ACL
  container.** `disabled.isVisible` is `true`, and both container sites were
  written as "return early if not visible, else dim if `read`" — so a component,
  a row, or a whole `TomAclBuilder` that a policy resolved to `disabled`
  rendered at full opacity with input live. A grant meant to withhold a control
  withheld nothing.

  Both sites now route through `TomThemeScope.applyAuthState`, which maps all
  four states from the one place that knows what each looks like. In
  `acl_container.dart` the three inputs that can withhold a component — the
  row's grant, its own grant, and its group's runtime mode — are first folded
  into a single effective state with `TomAuthState.narrow`, so the most
  restrictive wins and the treatment is applied once rather than stacked into a
  doubly-dimmed component.

  Enforcement is a paint-time wrapper, so the geometry is identical to `full`;
  a grant change does not reflow the screen.

- **A structural reset told observers the list was empty, and
  `TomMasterDetailListForm` believed it.** `TomListForm` tears its sub-forms
  down in `onBeforeClear` and rebuilds them one at a time in `onAfterReset`,
  and the forwarder installed in its constructor turned every one of those
  steps into a notification of its own — so an observer watching a three-row
  list through a reset saw the lengths `0, 1, 2, 3`. `TomList.resetWith`
  guarantees *its* observers a single notification once every element is
  installed; observers of the list form were getting the half-built states in
  between, and none of those is a state the list is ever really in.

  The visible symptom was "Discard all". A root form's discard resets every
  list below it, and `TomMasterDetailListForm` clears its selection when it
  hears the list has shrunk past the selected row — right for a real removal,
  wrong for the empty moment inside a reset. The rows came back; the selection
  did not, and the detail pane stayed blank. Discarding the *nested* form
  directly never showed it, because that reset lands on a different list than
  the one holding the selection.

  `onBeforeClear` now mutes the list form and `onAfterReset` unmutes it in a
  `finally`, so the whole rebuild surfaces as the one notification the reset
  always claimed to be. Holding the mute across the two callbacks is safe
  because `TomClass._setListMember` type-checks the entire payload before
  clearing anything, precisely so a reset that starts, finishes.

  The regression test asserts the whole observed sequence — `[3]` after a row
  is removed and the list discarded — rather than merely that `0` is absent
  from it. Withholding the transient notifications and then never sending the
  real one leaves the detail pane just as blank, and an assertion that only
  forbids the wrong length is satisfied by an observer that heard nothing at
  all. It exercises a removal before the discard for the same reason: a
  discard on an untouched list restores rows that never left.

- **`tom_observable_state_management.md` Part 5 pointed at a directory deleted
  two refactors ago.** The part header gave its source as
  `lib/src/tomclient/observing/ and lib/src/tomclient/forms/` under
  `**Package:** tom_core_flutter`. The first exists; the second does not, and
  has not since the forms framework moved to `tom_flutter_ui`. The document
  already knew this — its own third subsection points at
  `tom_flutter_ui/lib/src/forms/` — so the header was contradicted two screens
  below it, and had been since the move. The header now names both packages and
  only surfaces that exist.

  Two neighbouring pointers were corrected in the same pass, and one
  deliberately was not. Part 2's `**Source:**` was a bare package-relative path
  with no `**Package:**` line to be relative to, so the line was added; the
  UAM sample pointer was under-qualified and is now workspace-relative like the
  other cross-repo reference. Part 1's bare path was left alone: it sits
  directly under `**Package:** tom_core_kernel` and is correct *in context*.
  The new checker below is what proves that distinction rather than asserting
  it — Part 1's path resolves only because of that line, and stops resolving
  when it is removed.

  Prose naming removed types was also left alone, deliberately. The paragraph
  above the header names the legacy `tom_core_flutter.TomForm` and contrasts it
  with the shape that replaced it, which is the correct way to mention
  something deleted; the fault was never "mentions a removed thing" but
  "instructs the reader to go and read one".

### Added

- **`tool/check_doc_source_paths.py`** — checks that every `**Source:**`
  pointer in the documentation names a path that exists, resolving against the
  workspace root, the repo root, or a package named in an adjacent
  `**Package:**` line. Nine pointers, zero faults after the fix above.

  The rule earns a gate on the same grounds as `check_source_citations.py`: it
  is exact rather than heuristic (the file is on disk or it is not, so there is
  no triage burden), and the fault is invisible by construction — the markdown
  renders, no build step reads these paths, and the only signal is a reader
  following one and coming back empty, long after the cheap moment to fix it.

  It carries no exemption list, including for history documents, because
  `**Source:**` means "go and read this" whatever document it appears in.

### Changed

- **`AclGroupVisibilityMode.disabled` now renders through
  `TomTheme.disabledStyle`** instead of a hard-coded
  `IgnorePointer(child: Opacity(opacity: 0.4, …))`. The axes stay separate in
  who decides — one is a policy grant, the other a toggle the application drives
  — but not in how they look: a user cannot tell from the pixels why a control
  is inert, and 0.4 beside the grant's 0.38 was two shades of "off" visible in
  one container. `IgnorePointer` was additionally the wrong widget: it makes the
  subtree transparent to hit tests, so a tap fell through to whatever was behind
  it rather than being swallowed. An app that restyles the withheld state now
  restyles both axes at once.

- **Dropped the `flutter create` tutorial commentary from the pubspec.** The
  library's own description and dependency comments were already specific and
  are untouched; the last 37 lines were not. They were the generator's
  commented-out `assets:` and `fonts:` examples under an otherwise empty
  `flutter:` key, explaining how one *would* declare an asset bundle this
  library does not have and does not want — it ships no assets, no fonts, and
  leaves `uses-material-design` to the consuming application, which is now
  stated in one line instead of implied by 37 lines of unrelated example.

  Found by the new `tool/check_pubspec_boilerplate.py` on its first run, not by
  the search that preceded it: that search looked for placeholder *descriptions*
  and this package has a real one, so the commentary sitting underneath it went
  unseen. `pubspec.lock` is byte-identical after re-resolution.

### Added

- **Two ACL tests for the vertical extent an anchor relation produces**
  (`test/tom_flutter_ui_test.dart`, `AclContainer widget`). The existing
  alignment pair asserts `follower.top == anchor.bottom` and
  `follower.bottom == anchor.top`, which are statements about two children
  *relative to each other* and therefore survive any uniform translation of the
  layout; both also mount inside a fixed `SizedBox(height: 200)`, which hands
  the ACL slack it never has to account for. Between them the ACL's own height
  went unasserted, as did whether it places a child above its own top edge.

  The new pair mounts under unbounded height and pins the absolute answer: the
  ACL is exactly its 100 px content extent in both directions, and under
  `alignBottomToTop` — where the follower's offset is negative before
  resolution — the row shifts down so the follower sits at the ACL top rather
  than at a negative offset, with the anchor flush at the bottom. Get that wrong
  and a caller's first row renders clipped or with dead space, in exactly the
  unbounded-height case a scroll view supplies.

  The measurements came from `tom_flutter_ui_test`'s `debug_heights_test.dart`,
  which had been printing these numbers into the console since the day it was
  written and asserting none of them. That file built a raw `AclBuilder`, so it
  was a test of this package sitting in the demo app; it is deleted there, and
  the contract it was pointed at is asserted here instead.

  Both assertions were falsified before being trusted — the extent one against
  164 px (reported the real 100), the normalisation one against a −36 px offset
  (reported 0). Gate `+2410`, serial; `flutter analyze` clean.
- **`TomObservableObservation` on the kernel bridge** (`lib/src/kernel_types.dart`,
  26 → 27 names). It is the extension declaring `>>`, the kernel's documented
  way to register an observer and get back the `TomFunctionObserver` you must
  retain. In Dart an extension is in scope only if its own name is shown, so
  exporting the return type without the operator left `field >> (_) => …`
  undefined on a `TomField` for anyone importing only the package barrel — as
  evidenced by two of this package's own tests, which imported
  `package:tom_core_kernel/tom_core_kernel.dart` for no other reason. Those
  workarounds are removed. `doc/kernel_types.md` and the `hasLength` tripwire
  in `test/kernel_types_doc_test.dart` are updated to match.
- **`TomWidgetSurface`** (`widget_base/`) — the interface naming the four
  members a Tom wrapper adds over the Flutter widget it delegates to: `tomId`,
  `tomGroup`, `basePath` and `effectiveAuthState`. It extends the kernel's
  `TomAuthorizable`, which carries three of the four; `basePath` cannot live
  there because resolving a path reads the ambient `TomScope`. Both `TomNodeBase`
  and `TomWidgetMixin` now implement it, so the kit's two routes to the Tom
  surface are one contract instead of two independent declarations of
  `basePath` that nothing required.
- **A conformance suite over the whole widget kit**
  (`test/widgets/widget_conformance_test.dart`, 13 tests). It builds all 290
  exported widgets from a registry of factories and asserts, for each, that the
  id it was given is the id it reports, that its `basePath` resolves bare and
  under a scope, that it reports the family its base fixes or is one of the
  seventeen documented mixin users, and that it answers all four
  `TomAuthState` values from its own path — including that a rule on a
  *different* path does not reach it, which is the assertion that would have
  caught the eight ungated wrappers on its own. The registry is guarded from
  both sides: its factory type requires a `TomWidgetSurface`, so a wrapper that
  skips the surface cannot be added, and the suite rescans `lib/src/widgets/`
  and fails when a widget is in the kit but not the registry.
- **`TomAuthGate`** (`groups/`) — a one-child widget that resolves a
  `tomId` / `tomGroup` / `scope` / `authorizer` / `uiStateController` through
  `TomWidgetMixin` and applies the result to its child. It exists for the
  wrappers that cannot resolve their own authorization, and it promotes a
  private helper that `tables/` had already invented for that purpose into the
  shared, correct version. `TomAuthGate.resolve(...)` takes the same five
  inputs and answers the same question without building.
- **`authorizer` and `uiStateController` parameters on the eight wrappers that
  gate a slot** — `TomDataCell` (both constructors), `TomDataColumn`,
  `TomDataRow`, `TomExpansionPanel`, `TomSnackBar`, `TomSnackBarAction`,
  `TomAnimatedPositioned` and `TomAnimatedPositionedDirectional`. They now
  present the same authorization surface as every other Tom widget rather than
  one layer of four.
- **`TomDataCell.authState` / `isVisible` / `isReadonly`**, matching
  `TomDataColumn` and `TomDataRow`. `TomDataCell.empty` renders nothing either
  way, but now answers the same question from the same four layers instead of
  feeding its inputs to `basePath` alone.

### Changed

- **`TomRadio`, `TomRadioListTile` and `TomCupertinoRadio` read their selection
  from a `RadioGroup<T>` ancestor.** Their `groupValue` and `onChanged`
  parameters are gone — Flutter deprecated both in v3.32 and moved grouping
  onto the ancestor, which is also where arrow-key navigation and the APG
  radio-group semantics now live. Each wrapper gains a `bool? enabled`
  forwarded to the Flutter widget; `null` defers to the ancestor. Withholding
  `onChanged` is no longer how a radio is made inert, so a `TomAuthState` below
  `full` forces `enabled: false`: the `AbsorbPointer` that `TomStateStyle`
  applies stops the pointer, and `RadioGroup` makes the keyboard a second way
  in that it does not stop.
- **`TomRadioGroup` and the radio form fields supply that ancestor.**
  `TomRadioGroup`, `TomFormEnumRadioGroup` and the string radio group each wrap
  their option column in a single `RadioGroup<T>` carrying the group value and
  the write-back, and pass only `value` and `enabled` to each row. In
  `TomRadioGroup` the two withheld states now disable every radio *as well as*
  wrapping the column in `IgnorePointer`, for the same keyboard reason.
- **`TomCupertinoButton.minSize` forwards to `CupertinoButton.minimumSize`** as
  `Size.square(minSize)`, which is the conversion `CupertinoButton` itself
  performed on the `minSize` it deprecated. The Tom parameter stays a `double`
  because the resource layer resolves scalars.
- **`TomMessenger.showSnackBar` and `showSnackBarIfPresent` now return
  `null`** for a `TomSnackBar` whose authorization resolves to
  `TomAuthState.none`, instead of presenting an empty bar. Gating the content
  alone is not enough for a snack bar: it does not build where it is written,
  so presenting it is the last moment at which not-presenting is possible. The
  return type is now nullable.
- **`TomDataColumn` and `TomDataRow` expose `isVisible` / `isReadonly` as
  getters**, dropping the `BuildContext` parameter neither ever read, and gain
  an `authState` getter. This matches `TomForm`'s own `bool get isVisible`.
- **`TomExpansionPanel.authorizationGroup` is renamed `tomGroup`**, and the
  class gains a `scope`, matching the widget wrappers it sits among.
- **`TomAppBar` extends `TomContainerBase`** instead of `StatelessWidget` with
  `TomWidgetMixin`, joining `TomBottomAppBar` and `TomSliverAppBar` on the base
  its sub-folder implies. `PreferredSizeWidget` is an `implements` and so was
  never the obstacle. It now reports `TomWidgetFamily.container`, which is what
  `doc/widgets.md` had always claimed it did.
- **`example/widgets/widgets_example.dart` now covers all twenty families**
  instead of five widgets across four scenarios. It exports
  `oneWidgetPerFamily()`, a representative per branch base, and demonstrates
  each part of the Tom contract — family tag, `tomId` / `basePath`, scoped
  path, authorization, group ceiling — once over all twenty at a time rather
  than twenty times over. A reader arriving from the family catalogue finds
  their family named; a reader after the contract is not asked to read the
  same block twenty times to learn that it does not vary. A new section
  exhibits `TomExpanded`, one of the seventeen wrappers that reach the surface
  through `TomWidgetMixin`, which the old header asserted but never showed.
  `test/widgets/widgets_example_test.dart` derives the permitted family set
  from `widget_base/`, so a twenty-first branch base fails until the example
  demonstrates it too.

### Fixed

- **Every parameterised validation message reached the screen uninterpolated.**
  Two resolvers had drifted: `TomField.resolvedErrorMessage` substituted a
  `ValidationError`'s `params` into the resolved template, but
  `resolveFieldValidationMessage` — the one the three decoration mixins actually
  paint through — did not. So `minLength`, `maxLength`, `min`, `max`, `minItems`
  and `maxItems` all rendered their template verbatim, and a field told the user
  `Use at least {min} characters.` The substitution now lives on
  `ValidationError.interpolate`, beside the `params` it substitutes, and both
  resolvers call it; the duplicated private `_applyParams` is gone. The
  divergence was found by a sample suite asserting the resolved sentence rather
  than the presence of an error
  (`core_flutter_acl_responsive/test/validation_message_test.dart`).
- **`doc/forms.md` did not state how an error key becomes a sentence.** It said
  validation messages were per-field resources and stopped there, so neither the
  resolution chain nor its last step — returning *the key itself* as a
  development indicator, which makes an undeclared key render as plausible text
  rather than fail — was written down anywhere. A new *From key to sentence*
  subsection states the chain, the interpolation, and why an application adding
  its own `errorKey` must assert the resolved sentence.
- **`lib/src/widgets/readme.md` listed five of the six base parameters.** It
  omitted `key`, and before that `uiStateController` as well, while the family
  base constructor took all six the whole time. The list is now a table naming
  each parameter's type and purpose, with a paragraph on what
  `uiStateController` narrows and why it has to run last. A new suite,
  `test/widget_base/base_parameter_claims_test.dart` (6 tests), derives the
  list from `tom_family_base.dart` and writes no parameter name down as a
  fact: it checks that all twenty branch bases forward it unchanged, that
  `TomNodeBase` declares it and `TomWidgetMixin` exposes its five non-`key`
  members, that the readme's table matches it *in signature order*, and that
  any prose in the package counting the parameters counts them right.
- **`doc/form_authorizers.md` stated the authorization order backwards, in two
  places, while citing the source file that contradicts it.** Both the
  `Evaluation pipeline` code block and the two-lanes section ran the authorizer
  before the group and the group last; the real order is resource → group →
  authorizer → controller. Stated the other way round the document's own
  explanation collapses, since the controller can only keep its "narrows,
  never widens" promise by running after a group whose `applyMode` widens. The
  `applyMode(state, constructionScope)` signature and two stale line citations
  are corrected with it.
- **Six documents quoted a widget census two wrappers out of date.** Deleting
  the deprecated `TomMaterialButton` and `TomButtonBar` took the kit from 292
  widgets to 290, and an example header, a CHANGELOG entry, two design
  documents and two test preambles went on saying 292, 275 and 301. Nothing
  failed, because the only census guard in the package read exactly one file.
  `tccf1-14` now scans every markdown file and Dart comment in the package for
  a three-digit count of the kit and requires it to be a number the source scan
  produces — and rejects a trailing `+`, since a census the suite can count
  exactly does not need hedging. `tccf1-15` covers the one shape a prose scan
  cannot read, the wrapped-per-family table in `doc/tom_ui_flutter_widgets.md`,
  by checking its totals row against both its own rows and the scan.
- **`doc/tom_ui_flutter_widgets.md` listed two widgets that no longer exist.**
  It still recorded `MaterialButton` and `ButtonBar` as wrapped and advised
  wrapping them "to support migration of existing codebases" — the same reason
  the wrappers themselves were deleted for being untrue. Nothing here is
  published, so there are no codebases to migrate.
- **`TomAppBar` resolved its authorization and then ignored it.** Its `build`
  returned an `AppBar` directly, with no `checkHidden()` and no
  `applyAuthState()`, so a `none` app bar rendered in full and a `disabled` one
  stayed interactive — while `tomId`, `tomGroup`, `scope`, `authorizer` and
  `uiStateController` all type-checked. Extending `TomContainerBase` moves
  the body to `buildContent` and puts the four-state gate back in the path. The
  constructor also registered with `tomGroup` and never unregistered; the base
  owns that lifecycle now.
- **Four documents claimed every widget in the kit reports its family.** 17 of
  the 290 wrappers extend a Flutter widget directly (their parent type-checks
  for the Flutter subtype) and have no family base to get `family` from, and 9
  further types under `widgets/` are not widgets at all. The catalogue in
  `doc/widgets.md` also listed two widgets under families they do not report:
  `TomAppBar`, which had no `family` at all, and `TomSliverList`, which is a
  `TomContainerBase`. `test/widgets/widget_family_claims_test.dart` now reads
  the counts and the catalogue out of the sources, so neither can drift again.
- **The package README and the `widgets/` module readme both offered
  `TomLabel` as a representative of the label family, and no such type exists
  anywhere in the package.** The label family is `TomText`,
  `TomSelectableText`, `TomRichText`, `TomBadge`, `TomChip` and the other
  `TomLabelBase` subclasses; both tables now name `TomRichText`.
  `test/module_readme_inventory_test.dart` gained the reverse of the check it
  already made — every bare `Tom…` type a surface document names must be
  declared in this package or in `tom_core_kernel`, resolved through
  `.dart_tool/package_config.json` — so a document cannot invent one again. It
  covers the README and all nine module readmes; `TomLabel` was the only
  phantom among them. `doc/` is excluded on purpose: it carries design
  material that names unshipped types deliberately and says so.
- **The `widgets/` module readme promised platform-adaptive rendering the kit
  does not do.** It said each widget "renders Material or Cupertino per the
  ambient family". Nothing under `lib/src/widgets/` reads
  `defaultTargetPlatform`, `Platform.is` or `CupertinoUserInterfaceLevel`, and
  no wrapper delegates to one of Flutter's `.adaptive(` constructors — a
  wrapper renders the one Flutter widget it wraps. The sentence also used
  `family` for a design language, which it never was: `TomWidgetFamily` is a
  compile-time role tag (`button`, `input`, `label`) on the base class. The
  readme now describes what is there — 35 Cupertino wrappers the call site
  names explicitly, of which only 11 have a same-name Material sibling — and
  points at `forms/`, where `FormFieldFamily` is the kit's one
  Material-vs-Cupertino switch and is driven by the caller, not by a probe.
  `test/widgets/widget_family_claims_test.dart` now asserts the absence of the
  four probe idioms and holds the readme to the census the sources give.

- **Eight wrappers declared `tomId` / `tomGroup` / `scope` and never applied
  them.** `TomAnimatedPositioned`, `TomAnimatedPositionedDirectional`,
  `TomSnackBar`, `TomSnackBarAction` and `TomExpansionPanel` ignored their
  authorization entirely; `TomDataCell` and `TomDataColumn` applied it through
  a private helper that stored `tomGroup` without reading it, dropped `scope`,
  and treated `disabled` as `full`; `TomDataRow` reported through a
  `basePath`-only lookup with the same two omissions. All eight now route
  through `TomAuthGate`, so a group ceiling, an explicit scope, a per-widget
  authorizer and a UI-state controller count for them exactly as they do for
  every other Tom widget. Two of them cannot hide by gating a slot and say so
  instead: `TomDataRow` (a `DataTable` demands one cell per column from every
  row) reports for the caller to filter on, and `TomSnackBar` is declined at
  the point of presentation.
- **A `disabled` gated slot was rendered as if it were `full`.**
  `TomAuthState.disabled.isVisible` is true, so the "hide if not visible, else
  dim if read, else pass through" shape the replaced helper used let a disabled
  cell render fully interactive. Routing through `TomAuthGate` applies the
  theme's disabled treatment — dimmed and pointer-absorbing — for all four
  states rather than three. `test/widgets/wrapper_auth_layers_test.dart` pins
  it, along with both narrowing layers.
- **A plain `TomCupertinoSearchTextField()` can be constructed again.** Its
  placeholder resolved through an unguarded `TomCtr.textOrFail` into a
  non-nullable `String`, so a search box with no `placeholder` and no `tomId`
  threw a `StateError` — for a property Flutter treats as optional, and which
  `CupertinoSearchTextField` fills with the localized "Search" when handed
  `null`. Resolving it unconditionally therefore replaced a working default
  with either a resource requirement or an exception. It is now `String?` and
  looked up only when the widget has a `tomId`, matching its two siblings
  `TomCupertinoTextField` and `TomCupertinoTextFormFieldRow` and the sweep
  that had already made every other optional slot behave this way.
- **A `TomIconButton` with no icon now says so instead of rendering a warning
  glyph.** The icon *is* this widget, but it resolved through the nullable
  `TomCtr.icon` and fell back to `const Icon(Icons.error_outline)` — leaving a
  control that is present and tappable and names neither itself nor the key it
  looked for. Worse, that fallback was reached identically by a bundle naming
  no icon and a bundle naming a misspelt one, because `TomCtr.icon` answers
  `null` to both. It now resolves through the new `TomCtr.iconOrFail` and
  throws a `StateError` naming the missing key. **Behavioural change:** a
  `TomIconButton` with neither an `icon` argument nor a resolvable
  `<tomId>.icon` resource now throws from its constructor rather than
  building. An icon beside
  a label — `TomFloatingActionButton.extended` — is genuinely optional and
  deliberately keeps the nullable accessor.
- **`TomIcon` no longer drops an icon whose name ends in `.icon`.** It read the
  resource through `textOrFail` and decided whether it had found anything by
  asking whether the answer ended in `.icon`, because `textOrFail` returns the
  *key* when nothing is installed. That is a second implementation of what
  `TomCtr.icon` already does, and it reads a returned *value* as if it were a
  key: an icon actually named `brand.icon` was indistinguishable from a missing
  one and was silently discarded. It now calls `TomCtr.icon`.
- **`TomScope` is nameable from the package barrel.** `scope:` is a parameter
  on every Tom widget and its type is the kernel's `TomScope`, but the package
  does not re-export `tom_core_kernel` wholesale and `TomScope` was absent from
  the only `show` list it had — so a consumer could read the parameter in a
  signature and had no way to name its type or build an argument for it.
  Nothing inside `lib/` could catch that, because the ~85 files declaring those
  signatures import the kernel barrel unfiltered; the omission was visible only
  from outside. Every kernel type in a public signature is now audited and
  carried.
- **An explicit `decoration` on the text inputs is no longer overwritten.**
  `TomTextField` and `TomTextFormField` resolved their label from resources
  unconditionally and wrote it over the supplied `InputDecoration` at the end,
  so `decoration: InputDecoration(labelText: 'Name')` was silently discarded —
  and a caller who supplied a decoration but no `label` and no `tomId` was told
  the widget "requires either an explicit label or a tomId" for a string the
  decoration already carried. The label and hint now follow a chain rather than
  a merge: `label` → `decoration.labelText` → the `<tomId>.label` resource, with
  the resource lookup last and therefore only performed when nothing earlier
  supplied one. Omitting every source still throws. **Behavioural change:** a
  caller who passed *both* a `decoration.labelText` and a label resource now
  sees the decoration's value where they previously saw the resource's.
- **A one-dimensional `minimumSize` no longer makes a button demand the whole
  width.** `parseButtonStyle` completed a missing `width` / `height` with
  `double.infinity` for all three of `minimumSize`, `maximumSize` and
  `fixedSize`, so `minimumSize: {height: 40}` parsed to `Size(Infinity, 40)` —
  a minimum of every available pixel, from a resource that only asked for a
  height. Each slot now completes with what it means: an unspecified *minimum*
  is `0`, an unspecified *maximum* stays `double.infinity`, and a `fixedSize`
  missing either dimension is discarded, since neither value is what "fixed"
  means. A size map naming neither dimension is now discarded in all three
  slots rather than parsing to `Size(Infinity, Infinity)`, so `minimumSize: {}`
  can no longer be the sole reason a `ButtonStyle` comes back non-null.
- **`TomInputDatePickerFormField` no longer demands four resources.** Its
  label, hint and two error messages are optional in Flutter (defaulted from
  `MaterialLocalizations`), but all four were required, which made a plain
  `TomInputDatePickerFormField(...)` unconstructible. They are now looked up
  only when the widget has a `tomId`.

### Removed

- **`TomUIGroup` is gone; use `TomAuthorizationGroup`.** The alias was
  documented as deprecated yet was the declared type of `tomGroup` in ~20
  widget classes, while its two siblings (`TomUIAuthorization`,
  `TomUIAuthorizationAdapter`) had already been deleted — so the package
  carried one spelling that was simultaneously discouraged and canonical. Every
  declaration, example, test and document now names the kernel type directly,
  leaving one spelling per type across the framework. `lib/src/groups/` keeps
  only `TomWidgetMixin`; the group type reaches consumers through
  `kernel_types.dart`.
- **The assertions that the removed alias still existed are gone too.** That
  rename was applied inside the sentences explaining the alias, so the groups
  example and its test were left stating that `TomAuthorizationGroup` is a
  typedef for itself — and backing it with `identical(X, X)`, an assert that
  cannot fail. The example's header sentence and its tautological assert are
  deleted, and the `TomAuthorizationGroup typedef` test group goes with them;
  its one real test (`default mode is controlsWidest`) survives under
  `AuthGroupMode`, beside the mode behaviours it belongs with.
- **`TomMaterialButton` and `TomButtonBar` are gone**, together with the
  "DEPRECATED BUTTONS — Wrapped for migration support" banner they sat under.
  Nothing in this package is published, so there were no existing codebases to
  migrate: the deprecation markers were carrying weight for a population of
  zero, while both types still counted toward the kit's advertised surface and
  `doc/widgets.md` catalogued the button family without saying two of its
  members were on the way out. Their replacements already exist and are already
  demonstrated — `TomOverflowBar` for the bar, `TomElevatedButton` /
  `TomTextButton` / `TomOutlinedButton` for the button. The kit is 299 types,
  290 of them widgets, 273 of those on a family base.
  `test/widgets/widget_family_claims_test.dart` now fails on any `@Deprecated`
  under `lib/src/widgets/`: an unpublished kit deletes instead of deprecating,
  because deprecating defers a free removal until it is expensive.

### Added

- **`TomCtr.iconOrFail`, and a stated rule for which accessors get an
  `…OrFail` at all.** The family had grown to four with no criterion written
  anywhere, so its shape read as an accident and the one widget that most
  needed a throwing icon accessor did not have one. The rule is now stated in
  `doc/widget_base.md` and in the `TomCtr` dartdoc: an accessor gets an
  `…OrFail` when the resource it reads can be a widget's *only* source for a
  required parameter that has no default. `boolVal` and `edgeInsets` are
  excluded because Flutter always defaults those parameters, so a resource
  overrides rather than supplies; `value`, `list` and `map` because `TomCtr`
  is not told what the caller means to do with them and so cannot decide what
  "unusable" is. `tom_ctr_helpers_test.dart` scans the source and holds the
  set to exactly the five members and the five deliberate exclusions, so a
  sixth variant added without re-reading the rule fails the suite.
- **`lib/src/kernel_types.dart` — one bridge to `tom_core_kernel`, and two
  guards on it.** The package's kernel re-exports were split across
  `resource_auth/tom_auth_state.dart` (nine authorization names) and
  `widget_base/tom_authorizable.dart` (one), which is why nobody had ever
  audited what the bridge carries against what the public signatures need. Both
  files are replaced by one package-level list of 26 names, with the membership
  rules written down beside it. `tool/check_kernel_bridge.py` fails when a
  kernel type reaches a public declaration position without reaching the list;
  `test/kernel_types_test.dart` imports nothing but the package barrel and uses
  each bridged type, so a name that does not actually resolve stops the file
  compiling. A blanket re-export is not the alternative: the kernel barrel
  re-exports `tom_basics`, which declares a `TomEnvironment` and a `TomPlatform`
  colliding with this package's own enums of those names, so every use of
  either would be an `ambiguous_import`.
- **`MaterialOnlyColorAdapter` and `CupertinoOnlyColorAdapter`.** The icon side
  of `resource_auth/` shipped three adapters and the colour side one, although
  `GeneratedColors` has exposed `materialColors` and `cupertinoColors` as
  separate maps all along. Both reasons for the icon adapters apply equally to
  colours: an app targeting one platform stops carrying the other family's
  table, and — the reason that surfaces as a bug rather than a bundle size — a
  stray `cSystemBlue` in a Material-only resource file now resolves to `null`
  and is caught instead of quietly working. Registrations, hex and `rgb()` still
  resolve through them; only the other family's palette is gone.

### Changed

- **The test suite reaches the package through the barrel, so the exports are
  load-bearing.** 60 of the 114 test files reached into `lib/src` by path —
  230 imports in all — which meant a symbol dropped from a module
  barrel, or a module dropped from the package barrel, left the whole suite
  green and surfaced in a consumer instead. Every export line was load-bearing
  for consumers and inert for the tests that covered it. All 60 now import
  `package:tom_flutter_ui/tom_flutter_ui.dart`; no test body needed an edit,
  which is the evidence that the barrel already carried everything. Two files
  keep their `src/` imports for reasons the barrel cannot express and are
  exempted by name and reason: `file_opener_test.dart`, which asserts the two
  halves of a conditional import against the resolved one, and the generated
  `*.reflection.dart` fixture. `package_barrel_test.dart` now checks the
  property directly rather than relying on it as a side effect of imports
  somebody could rewrite, and holds the exemption list to being non-stale.
  Ten `tom_core_kernel` imports became redundant in the process and are gone —
  those files now name kernel types through the bridge, exactly as a consumer
  does.
- **The single-family icon adapters are renamed `MaterialOnlyIconAdapter` and
  `CupertinoOnlyIconAdapter`.** With colour siblings beside them, the old
  `MaterialOnlyAdapter` / `CupertinoOnlyAdapter` no longer said which family
  they carried.
- The colour adapters now share a `_RegistryFirstColorAdapter` base that holds
  the registry-then-hex-then-rgb order once, mirroring the icon side. Hex and
  `rgb()` live in the base because they are syntax rather than a palette, so a
  single-family adapter is a smaller palette and not a different contract.
- The two byte-identical private `_resolveDecoration` methods on the text
  inputs are replaced by one shared `_resolveInputDecoration` helper carrying
  the precedence rule and its rationale.
- **`AuthGroupMode` is carried by the kernel bridge.** It was absent from the
  package's `show` list, so group code that named a mode had to import
  `tom_core_kernel` as well. Importing `tom_flutter_ui` is now sufficient for
  the group type and its mode enum together.

### Documentation

- **`doc/widgets.md` describes what a widget does with a missing text
  resource, rather than what its resolver is named.** The section led with the
  claim that the `*OrFail` resolvers "throw so a missing required value fails
  loudly at construction rather than rendering blank". `textOrFail` — the text
  resolver of the whole kit, at some seventy call sites — throws only when
  there is no `tomId` to look under; given one and no resource it returns the
  dotted key, so a `TomText(tomId: 'nope')` paints `nope.label`. The contrast
  with "rendering blank" had it backwards: blank is the visibly wrong outcome
  that gets caught in review, and a key that reads like words, at the right
  size in the right place, is the one that ships.
  The section now tabulates the **three compositions** the wrappers actually
  use — required, `tomId`-guarded optional, and superseded-by-a-widget-slot —
  because the resolver's contract does not determine the widget's behaviour
  and the same missing resource gets three different answers depending on
  which composition the property got. The same correction is applied to the
  `_resolveInputDecoration` dartdoc, which had described only the throwing
  half. `test/widgets/missing_text_resource_test.dart` pins all three.
  and `doc/widget_base.md` described `families` as letting a widget "report
  more than one" and stopped there, which leaves the reader to assume the
  obvious composition. It is not the one in force: `isFamily` reads `families`
  alone and never consults `family`, and the base class does not fold the
  primary back in — so an override that omits `family` produces a widget that
  denies its own primary family while `family` keeps returning it. Both places
  now state the rule and the trap, and direct overrides to write `{family, …}`.
  Nothing in `lib/` overrides `families`, so the first widget to do so would
  otherwise have discovered this by accident;
  `test/widget_base/tom_widget_family_coverage_test.dart` now pins the
  behaviour, including the disowned-primary case, so the warning stays true.
  The same file also pins each of the twenty branch bases to the family its
  *name* claims. Every assertion it previously made was about sets — twenty
  bases, distinct families, covering exactly the Flutter-derived values — and
  no set assertion can see a permutation: swapping the bodies of
  `TomListBase.family` and `TomChipBase.family` left all of them passing while
  two bases lied about what they were. The bases are near-identical
  boilerplate differing in one line, which is the shape that invites exactly
  that slip, and neither the analyzer nor a rendering test can catch it.
- **`TomStyleResolvers` no longer opens with a type list that had fallen five
  types behind its own members.** The class dartdoc summarised the class as
  resolving twelve named Flutter objects, an enumeration written when that was
  true and never revisited as the class grew to nineteen parsers — so
  `VisualDensity`, `IconThemeData`, `StrutStyle`, `TextHeightBehavior` and
  `ScrollPhysics` were absent from the one paragraph a reader starts at. The
  summary now describes what the class produces by category and points at the
  `parse…` members as the list, and the counts the comment still states about
  its own members — nineteen parsers, seventeen with a `resolve…` partner here,
  twelve taking a map and seven a raw value — are checked against those members
  by `style_resolvers_layering_test.dart`, so the shorter claim cannot drift the
  way the list did.
- **`TomErrorBoundary`'s library comment describes the interception the widget
  performs (tcinc349).** It claimed two layers, the first of which was a wrapped
  `FlutterError.onError` hook catching errors "flagged with the boundary's
  `_TomErrorBoundaryMarker`". `FlutterError.onError` is never assigned anywhere
  in the file and no marker type exists — the dangling reference was the visible
  end of a paragraph describing a mechanism that had been replaced. There is one
  layer: a ref-counted global `ErrorWidget.builder` returning a reporter widget
  that walks the element tree to its nearest enclosing boundary, which is what
  makes nested boundaries route correctly regardless of mount order. That is now
  what the comment says, including why the indirection is there.
- **`TomForm._enclosingForm` points somewhere real.** It referred the reader to
  `[_resolveCommitBaselines]` for the nested-save rule; no such member exists,
  and the rule lives in `save`'s "Nested-save semantics" paragraph, which the
  comment now names.
- **All three `widget_base` pillars now have an executable example.**
  `doc/widget_base.md` opens by naming identity/scope, authorization and
  resource binding as the three things every Tom node does, but the module's
  only example covered resource binding — the two harder pillars were prose.
  `example/widget_base/widget_base_nodes_example.dart` covers them: it composes
  a nested `TomScreenElementsProviderBase`, asserts the base paths that come
  out, walks the authorization gate one layer at a time (resource grant → group
  ceiling → authorizer → the controller that cannot widen), and reports the
  family each widget declares. None of it needs a widget tree — `basePath` is
  computed in the constructor, `resolveEffectiveAuth()` takes no
  `BuildContext`, and `family` is a plain getter — so the example asserts on
  constructed nodes rather than pumping them, and
  `test/widget_base/widget_base_nodes_example_test.dart` runs it.

## 1.1.0

Adapts the widget set to the Flutter 3.44 scroll/reorder API changes. **This is
a breaking change with no backwards-compatibility shims** (per framework
policy).

### Changed

- **Reorder callback renamed `onReorder` → `onReorderItem`** on
  `TomReorderableListView`, `TomReorderableList`, and `TomSliverReorderableList`,
  mirroring Flutter's own rename. The new callback's `newIndex` is **already
  adjusted for the removed item**, so callers must drop the classic
  `if (newIndex > oldIndex) newIndex -= 1` fixup — the plain
  `removeAt(oldIndex)` / `insert(newIndex, item)` body is now correct. All
  demos and consumers updated accordingly.
- **`cacheExtent` now flows through `ScrollCacheExtent` internally.** The public
  `cacheExtent` field and the `cacheExtent` resource key stay `double?` (pixel)
  for API/config stability; the widgets wrap the resolved value via
  `ScrollCacheExtent.pixels(...)` and pass `scrollCacheExtent:` to the
  underlying Flutter widgets (`TomListView`, `TomGridView`,
  `TomCustomScrollView`, `TomReorderableList`, `TomReorderableListView`).
- The list-form widgets (`TomInlineListForm`, `TomExpandableListForm`) migrate
  their internal `ReorderableListView.builder` usage to `onReorderItem`; their
  public `onReorder(from, to)` domain callback is unchanged (still delivers the
  final destination index).

### Added

- Widget test asserting the reorder behaviour end-to-end: a real drag on
  `TomReorderableListView` moves the first row down one slot and reports the
  post-removal `newIndex` (proving the manual fixup is gone).

## 1.0.0

First versioned release of the Tom Flutter UI widget library. Promotes the
package from the `0.0.1` Flutter template stub to a real, documented `1.0.0`:
authored the package `README.md` (description + module/widget catalogue + form
field catalogue), the BSD 3-Clause `LICENSE`, and this changelog. No source
change — this release records the widget set that already exists.

### Added

- **`widget_base/`** — the foundational layer: the `TomAuthorizable` contract,
  construction-time helpers, the widget/family base classes (`TomNodeBase`,
  `TomPolicyNodeBase`, `TomWidgetFamily`), scope widgets, the screen-elements
  provider, and the style resolvers.
- **`theme/`** — `TomTheme`, the read-only style, and the style-variant system.
- **`actions/`** — the Tom Action system: typed, authorization-aware actions
  (`TomAction`, `TomActionController`, `TomActionContext`) with atomic
  transactions, undo/redo history, composite actions, and widget triggers.
- **`resource_auth/`** — `TomAuthState`, resource-resolved `TomColors` /
  `TomIcons`, and the config provider.
- **`forms/`** — the declarative form system: the `TomForm` data model,
  validators, selectable sources, the form event bus, the Material + Cupertino
  style/decoration system, and the full field catalogue behind a
  `FormFieldFamily` factory (string, bool, numeric, date/time, duration,
  enum/object, search/lookup, file, nullable, and list/master-detail forms).
- **`groups/`** — `TomUIGroup` collective-visibility control.
- **`advanced_container_layout/`** — the fluent, row-based `AdvancedContainerLike`
  layout engine with ACL integration.
- **`widgets/`** — the general widget kit (buttons, chips, containers, dialogs,
  inputs, labels, lists, navigation, progress, selects, sliders, slivers, tables,
  toggles, trees, plus animated/builder/effect/image/interaction helpers).
- **`custom/`** — non-form composite widgets (auth guard, auth tree, empty state,
  error boundary, infinite scroll, loading overlay, radio group, skeleton loader).
- **`TomFieldWidgetAdapter`** — now exported from the `forms/` barrel. It wraps
  every concrete field's rendered widget so `TomAuthorizable`-aware consumers
  (e.g. ACL hide-unauthorized) can reach a field's auth state; it appears in the
  public widget tree, so consumers must be able to name the type. (The generated
  `GeneratedColors` / `GeneratedIcons` lookup tables remain internal — they back
  the public `TomUIColors` / `TomUIIcons` resolvers.)

### Documentation

- **`widget_base/`** — authored `doc/widget_base.md` (the node hierarchy
  `TomNodeBase → TomPolicyNodeBase → TomFamilyBase`, the four-state
  authorization gate, the `TomWidgetFamily` taxonomy, scope propagation, screen-
  element providers, and the `TomCtr` / `TomStyleResolvers` resource helpers);
  added `example/widget_base/widget_base_example.dart`; added
  `test/widget_base/widget_base_resolvers_test.dart` covering `TomStyleResolvers`
  (previously untested) and the example end to end. No public API change.
- **`theme/`** — authored `doc/theme.md` (the "Tom layers on, never replaces,
  Flutter theming" principle; `TomReadonlyStyle`'s ordered `apply` composition;
  `TomTheme` / `TomThemeScope` delivery and default fallbacks; the
  `TomButtonVariants` semantic-style factory); added
  `example/theme/theme_example.dart`; added `test/theme/theme_test.dart`
  (previously zero theme tests) covering `TomReadonlyStyle.apply`, `TomTheme`,
  `TomButtonVariants`, and the `TomThemeScope` inherited-widget lookup. No public
  API change.
- **`actions/`** — authored `doc/actions.md` (the Tom Action system as the
  behavioural counterpart to widgets: `TomAction` / `TomSimpleAction`, controller
  grouping and `<controllerId>.<actionId>` canonical paths, typed
  `TomActionContext`, the `TomActionUndo` → `TomActionTransaction` →
  `TomUndoHistory` undo model, `TomActionTrigger` widget wiring, composite
  actions, and `TomAuthorizable` integration); added
  `example/actions/actions_example.dart`; added `test/actions/actions_test.dart`
  (previously zero action tests, 25 tests) covering the controller registry,
  action/simple-action contracts, transaction record/commit/rollback/undoAll,
  the undo-history stack invariants, the trigger execution path, composite guard
  behaviour, and the undo/redo coordinator actions. No public API change.
- **`resource_auth/`** — authored `doc/resource_auth.md` (the name → object
  resolution layer: `TomUIColors` / `AllColorsAdapter` for named/hex/rgb colours,
  `TomUIIcons` with the all / Material-only / Cupertino-only icon adapters,
  the `TomConfigProvider` environment/platform/feature-flag store, and the
  authorization types re-exported from `tom_core_kernel`); added
  `example/resource_auth/resource_auth_example.dart`; added
  `test/resource_auth/resource_auth_test.dart` (previously zero tests, 18 tests)
  covering colour/icon resolution and graceful no-adapter degradation, custom
  registration precedence, hex 3/6/8-digit and rgb clamping, the config
  provider's fail-fast and flag semantics, and the `TomAuthState` ordering plus
  the legacy typedef aliases. No public API change.
- **`forms/`** — authored `doc/forms.md` (the declarative form system: the
  `TomForm` / `TomField` data/presentation split and value/dirty/commit/reset
  contract, the `Validators` factory and sealed `ValidationResult` family plus
  cross-field `FormValidationError`, `SelectableItem` / `StaticSelectableSource`,
  the typed `TomFormEvent` bus with `TomFormEventListener` / `TomFormInspector`,
  the responsive `TomBreakpoint` ladder and anatomy placement enums, and the
  `FormFieldFamily` Material-vs-Cupertino factory over the field catalogue);
  added `example/forms/forms_example.dart` (pure-logic: validators,
  selectable sources, the event bus, family field construction, a cross-field
  error, and breakpoints); added `test/forms/forms_example_test.dart` (6 tests)
  exercising the example end to end plus direct checks on the family factory,
  unmodifiable source snapshots, inspector filtering, `FormValidationError`
  ids, and breakpoint resolution. The 62-file module was already documented and
  carried 20 test files (326 tests, still green); no public API change.
- **`groups/`** — authored `doc/groups.md` (collective-visibility control: the
  `TomUIGroup` typedef over `TomAuthorizationGroup`, weak-reference member
  tracking, the three `AuthGroupMode`s — `controlsAll` / `controlsWidest` /
  `controlsNarrowest` — and `TomWidgetMixin`'s id/group/auth/resource wiring and
  four-layer `getAuth` resolution); added
  `example/groups/groups_example.dart` (pure-logic: group membership, the three
  modes via `applyMode`, a `TomWidgetMixin` field resolving through its group,
  introspection, and scope-prefixed paths); added
  `test/groups/groups_example_test.dart` (9 tests) covering the example end to
  end plus the typedef identity, each mode's ceiling/floor/replace behaviour,
  effective-auth resolution, register/unregister tracking, and scope paths. The
  module had no prior tests or example; no public API change.
- **`advanced_container_layout/`** — authored `doc/advanced_container_layout.md`
  (the fluent, row-based ACL layout engine: the `AclBuilder` → `Acl` build
  pipeline and its append/gap/row/size/alignment vocabulary, the `AclFlags`
  AWT-style attribute bits, `RowAlignment`, responsive variants vs. row
  breakpoints, the `AclDeviceContext` static resolvers and AND-combined
  `buildConvenienceDetector`, the `AclBinaryVisibilityController` /
  `AclCallbackVisibilityController` group-visibility controllers, `AclScope`
  id/group propagation, and the `setAclDefaultHideUnauthorized` /
  `setHideUnauthorized` authorization-aware hiding); added
  `example/advanced_container_layout/advanced_container_layout_example.dart`
  (pure-logic: `AclFlags` bit composition, the device-context resolvers and
  convenience detector, the two visibility controllers driven by
  `ValueNotifier`s, and an `AclBuilder` fluent chain producing an `Acl`); added
  `test/advanced_container_layout/advanced_container_layout_example_test.dart`
  (11 tests) covering the example end to end plus the flag composition, the
  width/density/platform resolver thresholds, the convenience-detector
  null-vs-predicate contract, both controllers' notifier-driven mode updates,
  and `build()` producing an `Acl` (including the duplicate-instance guard). The
  module already carried `acl_hide_unauthorized_test.dart` (10 tests, still
  green); no public API change.
- **`widgets/`** — authored `doc/widgets.md` (the general widget kit: ~200 Tom
  wrappers over Flutter/Cupertino across 21 families behind `widgets.dart`, the
  shared `TomFamilyBase` → `TomPolicyNodeBase` → `TomNodeBase` contract — family
  tagging, `tomId`/`basePath`, `effectiveAuthState`, and construction-time
  `TomCtr` resource resolution — a full family catalogue, and the
  authorization/group/scope rules); added
  `example/widgets/widgets_example.dart` (pure-logic: family tagging across
  button/label/toggle/container/progress wrappers, `basePath` resolution and
  scope prefixing, and `effectiveAuthState` resolution via resource auth and a
  `TomUIGroup` ceiling — all without a `BuildContext`); added
  `test/widgets/widgets_example_test.dart` (7 tests) covering the example end to
  end plus direct checks on `family`/`families`/`isFamily`, `basePath` (top
  level and scoped), and auth resolution (resource read, default full, group
  narrowing). Scoped to module doc + pure-logic example/smoke test, not a
  ~23k-LOC refactor of thin Flutter wrappers; per-widget visual rendering stays
  with the `testWidgets` suites / `phase1_demo.dart`. No public API change.
- **`custom/`** — authored `doc/custom.md` (the eight non-form composite
  widgets: the auth-gated `TomAuthGuard`, the per-node `TomAuthTreeView` /
  `TomAuthTreeNode` with its `ownAuth.narrow(inheritedAuth)` inheritance rule,
  the group-gated `TomRadioGroup` / `TomRadioGroupItem`, and the
  `TomEmptyState` / `TomLoadingOverlay` / `TomSkeletonLoader` /
  `TomErrorBoundary` / `TomInfiniteScroll` state idioms — the shared
  four-outcome auth contract, the scope-qualified `TomAuthorization.resolveAuth`
  lookup, and the ref-counted nearest-boundary error routing); added
  `example/custom/custom_example.dart` (pure-logic: the four-state auth lookup,
  the `TomAuthState.narrow` lattice the tree inherits with, the
  `TomRadioGroupItem` / `TomAuthTreeNode` data models, and context-free
  construction of all eight widgets); added `test/custom/custom_example_test.dart`
  (13 tests) covering the example end to end, `TomAuthGuard.resolveAuthState`
  across the four states, and `testWidgets` render cases for the auth gate
  (none collapses / disabled fades / full renders), `TomRadioGroup` gating,
  `TomEmptyState` / `TomLoadingOverlay` / `TomSkeletonLoader` / `TomErrorBoundary`
  rendering, and the data models. The module had no prior doc, example, or test;
  no public API change.
- **`example/phase1_demo.dart`** — promoted the standalone demo from a
  forms-only `runApp` (which imported the `src/forms/` barrel and crashed on
  pump because its `@tomReflector` form models need reflection data this package
  never wires) into a runnable, reflection-free-by-default demo. It now imports
  the public `package:tom_flutter_ui/tom_flutter_ui.dart` barrel, installs the
  text-resource provider + `AllColorsAdapter` in `main()`, and pages a
  `NavigationBar` across three galleries: **Widgets** (the general kit —
  `TomElevatedButton` / `TomFilledButton` / `TomOutlinedButton`, `TomText`,
  `TomBadge`, `TomChip`, `TomCard` + `TomListTile`, `TomSwitch`, `TomCheckbox`,
  `TomSlider`, `TomCircularProgressIndicator` / `TomLinearProgressIndicator`),
  **Custom** (`TomAuthGuard`, `TomRadioGroup`, `TomSkeletonLoader`,
  `TomLoadingOverlay`, `TomEmptyState` inside a `TomErrorBoundary`), and the
  existing **Forms** screen. The default landing tab is Widgets, so the app
  pumps cleanly; the Forms screen now tolerates missing reflection (it catches
  the construction error and shows an explanatory panel instead of taking the
  app down). Added `test/phase1_demo_test.dart` (3 tests) pumping the app,
  asserting the Widgets gallery renders, navigating to the Custom gallery, and
  exercising a toggle. No public API change.
- **Documentation review (close-out)** — final cross-module pass confirming the
  nine module docs match the code: every `Tom*` type named in
  `doc/actions.md`, `doc/advanced_container_layout.md`, `doc/custom.md`,
  `doc/forms.md`, `doc/groups.md`, `doc/resource_auth.md`, `doc/theme.md`,
  `doc/widget_base.md`, and `doc/widgets.md` was checked against the actual
  `class` / `enum` / `mixin` / `typedef` / `extension` / `interface`
  declarations in `lib/src` (and the re-exported `tom_core_kernel` types). One
  stale reference was corrected — `doc/forms.md` described a non-existent
  `TomColorTokens` type; `tom_color_tokens.dart` actually exposes the `cs.*`
  token-resolver functions (`resolveColorSchemeToken` / `resolveAnyColor` /
  `isColorSchemeToken`), so the doc now names those plus `TomThemeSpec`. Each of
  the nine `lib/src` modules is exported from the public
  `lib/tom_flutter_ui.dart` barrel and has a matching `doc/*.md`; barrel
  coverage of the public symbol set was verified earlier (the only two
  unexported `lib/src` files are the generated `GeneratedColors` /
  `GeneratedIcons` lookup tables, intentionally internal behind the public
  `TomUIColors` / `TomUIIcons` resolvers). No public API change.
