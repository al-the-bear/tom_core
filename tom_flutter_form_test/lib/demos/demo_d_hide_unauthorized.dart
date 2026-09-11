import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/validation_form.dart';
import '../panels/info_panel.dart';
import '../state/phase1_state.dart';
import 'demo_widgets.dart';

// ---------------------------------------------------------------------------
// Demo D — Hide on Authorization (TomAuthState.none) + read/disabled states
// ---------------------------------------------------------------------------

/// Two-panel layout matching Demos A–C:
///
///   * **Left** — two ACL-hosted sections:
///       1. **Form** (ValidationForm) with `setAclDefaultHideUnauthorized(true)`.
///          Toggling a field to `none` removes the field from its row; toggling
///          every field in a row to `none` elides the whole row. `read` and
///          `disabled` states are visible on fields too so you can compare the
///          three auth-driven treatments side-by-side.
///       2. **Widget gallery** — ten non-form Tom* widgets laid out in three
///          rows. Same hide-unauthorized extension applies regardless of
///          whether the widget is a form field, a button, a chip, an icon, or
///          a container.
///
///   * **Right** — auth-state control panel. One dropdown per element lets you
///     drive its resource auth between `full` / `read` / `disabled` / `none`
///     and watch the left side re-layout live.
///
/// Exercises:
///   * [AclBuilder.setAclDefaultHideUnauthorized] / [setHideUnauthorized]
///   * Row elision when every component is hidden
///   * `read` (readonly style) and `disabled` (dimmed) treatments on both
///     form fields and regular Tom widgets
///   * `TomFieldWidgetAdapter` — every form-field widget surfaces its field's
///     auth state to ACL so the row-level filter works uniformly.
class DemoDHideUnauthorized extends StatefulWidget {
  const DemoDHideUnauthorized({super.key});

  @override
  State<DemoDHideUnauthorized> createState() => _DemoDHideUnauthorizedState();
}

// ── Per-demo auth adapter ───────────────────────────────────────────────────

class _DemoDAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules = {};

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      rules[resourceKeyPath] ?? TomAuthState.full;

  void set(String path, TomAuthState state) {
    if (state == TomAuthState.full) {
      rules.remove(path);
    } else {
      rules[path] = state;
    }
  }
}

// ── Form section field paths ────────────────────────────────────────────────

/// The demo's own scope id — the outer segment of every path below.
const _demoScope = 'demoD';

/// Resource *path* of the form section. Never passed to `TomScope.withScope`:
/// the two forms are constructed inside `_demoScope` and carry their own
/// `validationForm` scope, so this is only ever the auth-key prefix.
const _formScope = '$_demoScope.validationForm';
const _formFieldIds = <String>[
  'username',
  'email',
  'password',
  'confirmPassword',
  'website',
];

// ── Gallery entries ─────────────────────────────────────────────────────────
//
// Ten non-form Tom widgets covering buttons, chips, icons, dividers, and
// containers. Each gets its own tomId so the right-hand panel can drive
// its auth independently.

class _GalleryEntry {
  final String tomId;
  final String label;
  final Widget Function() build;
  const _GalleryEntry({
    required this.tomId,
    required this.label,
    required this.build,
  });
}

/// Scope id of the gallery section — one segment, entered beneath
/// [_demoScope]. Keeping the id and the path apart is what stops the dotted
/// form from being handed to `TomScope.withScope`, which rejects it.
const _galleryScopeId = 'widgets';

/// Resource *path* of the gallery section, used to build its auth keys.
const _galleryScope = '$_demoScope.$_galleryScopeId';

class _DemoDHideUnauthorizedState extends State<DemoDHideUnauthorized> {
  late final _DemoDAuthAdapter _adapter;
  // Two separate form instances so we can render the same field set twice
  // (Flutter forbids reusing a widget in two places, and `.widget` is
  // cached per-field). Both forms live in the same `demoD` scope so their
  // field resource paths collapse to a single set of auth keys — one
  // dropdown in the right panel drives the matching field in BOTH forms.
  late final ValidationForm _formDefault;
  late final ValidationForm _formNonDefault;

  // Set by user via right-panel dropdowns.
  TomAuthState _formFieldAuth(String id) => _rulesFor('$_formScope.$id');
  TomAuthState _galleryAuth(String id) => _rulesFor('$_galleryScope.$id');
  TomAuthState _rulesFor(String path) =>
      _adapter.rules[path] ?? TomAuthState.full;

  @override
  void initState() {
    super.initState();
    _adapter = _DemoDAuthAdapter();
    TomAuthorization.adapter = _adapter;
    _formDefault = TomScope.withScope(_demoScope, () => ValidationForm());
    _formDefault.bind(_seedValidationProfile());
    _formNonDefault = TomScope.withScope(_demoScope, () => ValidationForm());
    _formNonDefault.bind(_seedValidationProfile());
  }

  ValidationProfile _seedValidationProfile() {
    final s = ValidationProfile();
    s.username | 'janedoe';
    s.email | 'jane.doe@example.com';
    s.website | 'https://example.com';
    return s;
  }

  @override
  void dispose() {
    _formDefault.dispose();
    _formNonDefault.dispose();
    super.dispose();
  }

  void _setFormAuth(String id, TomAuthState s) {
    setState(() => _adapter.set('$_formScope.$id', s));
  }

  void _setGalleryAuth(String id, TomAuthState s) {
    setState(() => _adapter.set('$_galleryScope.$id', s));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo D — Hide on Authorization',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final left = _buildLeftColumn(context);
          final right = _buildRightColumn(context);
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: SingleChildScrollView(child: left)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: SingleChildScrollView(child: right)),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 16), right],
            ),
          );
        },
      ),
    );
  }

  // ── Left column: intro card + form ACL + widget gallery ACL ──────────────

  Widget _buildLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _buildDefaultFormSection(context),
        const SizedBox(height: 12),
        _buildNonDefaultFormSection(context),
        const SizedBox(height: 12),
        _buildGallerySection(context),
      ],
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this demo covers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const DemoBullet(
              'Both ACLs below call '
              '`setAclDefaultHideUnauthorized(true)` — when a child '
              'resolves to `TomAuthState.none` it is dropped from the '
              'row entirely and the following gap collapses.',
            ),
            const DemoBullet(
              'Row elision: set every field in a row (e.g. '
              'password + confirmPassword) to `none` and the whole row '
              'disappears, with the next row\'s gap dropped so the '
              'layout tightens up.',
            ),
            const DemoBullet(
              '`read` and `disabled` keep the element in place '
              'but change its visual treatment — readonly style from the '
              'theme scope, vs. dimmed & ignoring input.',
            ),
            const DemoBullet(
              'Form-field widgets participate via '
              'TomFieldWidgetAdapter; regular Tom widgets via '
              'TomNodeBase / TomWidgetMixin. Same ACL filter for both.',
            ),
            const DemoBullet(
              'Two form sections show the rule with default '
              'gaps (no explicit `dist:` anywhere) and with non-default '
              'gaps (explicit 32 / 48 px per append, 24 / 40 px between '
              'rows). Toggling a field\'s auth on the right drives both '
              'forms at once so you can compare side-by-side.',
            ),
          ],
        ),
      ),
    );
  }

  // ── Form section (default gaps) ──────────────────────────────────────────

  Widget _buildDefaultFormSection(BuildContext context) {
    // Same field set, NO explicit `dist:` anywhere — every gap comes from
    // the ACL's built-in default. This is the baseline view of the
    // carry-forward rule: hiding a component drops the following default
    // gap and (for row elision) the following default row gap.
    final layout =
        TomAclBuilder(id: 'demoDFormAclDefault', elementProvider: _formDefault)
            .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
            .setAclExpandXDefault(true)
            .setAclDefaultHideUnauthorized(true)
            .append((p) => p.username.widget)
            .append((p) => p.email.widget)
            .newRow()
            .append((p) => p.password.widget)
            .append((p) => p.confirmPassword.widget)
            .newRow()
            .append((p) => p.website.widget)
            .build(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Form A — hide on auth, default gaps',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TomFormStyleScope(style: TomFormStyle.material3, child: layout),
          ],
        ),
      ),
    );
  }

  // ── Form section (non-default gaps) ──────────────────────────────────────

  Widget _buildNonDefaultFormSection(BuildContext context) {
    // Row layout with deliberately-mixed gaps so the hide-unauthorized
    // carry-forward rule is observable on explicit (non-default) values:
    //   row 0:  username  ←32→  email                (in-row gap 32)
    //   row 1:  password  ←48→  confirmPassword      (in-row gap 48)
    //   row 2:  website                              (newRow gap 40)
    // Between rows:
    //   r0 → r1 : 24   (explicit newRow dist)
    //   r1 → r2 : 40   (explicit newRow dist)
    //
    // Expected behaviour:
    //   * Hide `email` → `email`'s own 32 px gap is carried to the next
    //     visible component in the row; there is no next component here
    //     so the row simply narrows (nothing to push).
    //   * Hide `password` (keep confirmPassword) → confirmPassword
    //     slides into password's slot, inheriting the 48 px gap that
    //     sat between password and confirmPassword.
    //   * Hide BOTH password + confirmPassword → whole row 1 is elided;
    //     row 1's own dist (24) is carried onto row 2 and row 2's own
    //     dist (40) is dropped, so `website` sits at
    //     `row0.bottom + 24` — exactly the old slot of row 1.
    final layout =
        TomAclBuilder(
              id: 'demoDFormAclNonDefault',
              elementProvider: _formNonDefault,
            )
            .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
            .setAclExpandXDefault(true)
            .setAclDefaultHideUnauthorized(true)
            .append((p) => p.username.widget)
            .append((p) => p.email.widget, dist: 32)
            .newRow(dist: 24)
            .append((p) => p.password.widget)
            .append((p) => p.confirmPassword.widget, dist: 48)
            .newRow(dist: 40)
            .append((p) => p.website.widget)
            .build(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Form B — hide on auth, non-default gaps '
              '(32 / 48 / 24 / 40 px)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TomFormStyleScope(style: TomFormStyle.material3, child: layout),
          ],
        ),
      ),
    );
  }

  // ── Widget gallery (10 Tom widgets with hide-unauthorized) ───────────────

  List<_GalleryEntry> get _galleryEntries => [
    _GalleryEntry(
      tomId: 'saveBtn',
      label: 'TomElevatedButton',
      build: () => TomElevatedButton(
        tomId: 'saveBtn',
        scope: TomScope.current,
        onPressed: () {},
        label: 'Save',
      ),
    ),
    _GalleryEntry(
      tomId: 'cancelBtn',
      label: 'TomTextButton',
      build: () => TomTextButton(
        tomId: 'cancelBtn',
        scope: TomScope.current,
        onPressed: () {},
        label: 'Cancel',
      ),
    ),
    _GalleryEntry(
      tomId: 'detailsBtn',
      label: 'TomOutlinedButton',
      build: () => TomOutlinedButton(
        tomId: 'detailsBtn',
        scope: TomScope.current,
        onPressed: () {},
        label: 'Details',
      ),
    ),
    _GalleryEntry(
      tomId: 'submitBtn',
      label: 'TomFilledButton',
      build: () => TomFilledButton(
        tomId: 'submitBtn',
        scope: TomScope.current,
        onPressed: () {},
        label: 'Submit',
      ),
    ),
    _GalleryEntry(
      tomId: 'refreshBtn',
      label: 'TomIconButton',
      build: () => TomIconButton(
        tomId: 'refreshBtn',
        scope: TomScope.current,
        onPressed: () {},
        icon: const Icon(Icons.refresh),
      ),
    ),
    _GalleryEntry(
      tomId: 'featuredChip',
      label: 'TomFilterChip',
      build: () => TomFilterChip(
        tomId: 'featuredChip',
        scope: TomScope.current,
        label: const Text('Featured'),
        selected: true,
        onSelected: (_) {},
      ),
    ),
    _GalleryEntry(
      tomId: 'statusIcon',
      label: 'TomIcon',
      build: () => TomIcon(
        tomId: 'statusIcon',
        scope: TomScope.current,
        icon: Icons.verified,
        size: 24,
      ),
    ),
    _GalleryEntry(
      tomId: 'hairline',
      label: 'TomDivider',
      build: () => SizedBox(
        width: 120,
        child: TomDivider(tomId: 'hairline', scope: TomScope.current),
      ),
    ),
    _GalleryEntry(
      tomId: 'badge',
      label: 'TomContainer',
      build: () => TomContainer(
        tomId: 'badge',
        scope: TomScope.current,
        color: Colors.amber.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: const Text('badge'),
      ),
    ),
    _GalleryEntry(
      tomId: 'infoCard',
      label: 'TomCard',
      build: () => TomCard(
        tomId: 'infoCard',
        scope: TomScope.current,
        child: const Padding(padding: EdgeInsets.all(10), child: Text('Card')),
      ),
    ),
  ];

  Widget _buildGallerySection(BuildContext context) {
    final entries = _galleryEntries;
    // Deliberately non-default per-component AND per-row gaps so the
    // carry-forward rule is observable on explicit values rather than
    // the ACL's built-in default. Layout:
    //
    //   row 0 (gap 0):
    //     saveBtn  ←20→ cancelBtn  ←40→ detailsBtn  ←12→ submitBtn
    //   row 1 (dist 32):
    //     refreshBtn  ←28→ featuredChip  ←20→ statusIcon
    //   row 2 (dist 56):
    //     hairline  ←16→ badge  ←24→ infoCard
    //
    // Things to observe while flipping rows on the right panel:
    //   * Hide `cancelBtn`  → cancelBtn's 20 px gap is kept (saveBtn →
    //     detailsBtn now sit 20 px apart); detailsBtn's 40 px gap drops.
    //   * Hide every widget in row 1 → row 1 is elided; row 1's own
    //     dist (32) carries onto row 2 and row 2's dist (56) drops, so
    //     row 2 lands at `row0.bottom + 32`.
    //   * Hide every widget in row 2 → row 2 elided; with row 1 kept
    //     the change is purely vertical (no trailing row, so the
    //     carried dist has nothing to apply to).
    const inRowGaps = <List<double>>[
      [0, 20, 40, 12], // row 0: explicit gaps after row-start and
      //         between each pair. First element's
      //         gap is ignored (no predecessor).
      [0, 28, 20], // row 1
      [0, 16, 24], // row 2
    ];
    const rowDists = <double>[0, 32, 56];
    final rowRanges = <(int, int)>[(0, 4), (4, 7), (7, 10)];

    // Entered as the two segments it is, not as the dotted path: `TomScope`
    // rejects a "." inside a scope *id* precisely because "demoD.widgets"
    // would otherwise be indistinguishable from this nesting. The resulting
    // path is the same `_galleryScope` the auth keys below are built from.
    final layout = TomScope.withScope(_demoScope, () {
      return TomScope.withScope(_galleryScopeId, () {
        final instances = entries.map((e) => e.build()).toList();
        final b = AclBuilder()
            .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
            .setAclDefaultHideUnauthorized(true);
        for (int rowIndex = 0; rowIndex < rowRanges.length; rowIndex++) {
          if (rowIndex > 0) b.newRow(dist: rowDists[rowIndex]);
          final (start, end) = rowRanges[rowIndex];
          for (int i = start; i < end; i++) {
            final gap = inRowGaps[rowIndex][i - start];
            if (i == start) {
              b.append(instances[i]);
            } else {
              b.append(instances[i], dist: gap);
            }
          }
        }
        return b.build();
      });
    });

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Non-form Tom widgets — same hide-unauthorized rule',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            layout,
          ],
        ),
      ),
    );
  }

  // ── Right column: auth control panel ─────────────────────────────────────

  Widget _buildRightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'Form field auth',
          children: [
            for (final id in _formFieldIds)
              _buildAuthRow(
                label: id,
                path: '$_formScope.$id',
                current: _formFieldAuth(id),
                onChanged: (s) => _setFormAuth(id, s),
              ),
            const SizedBox(height: 8),
            _buildResetAllButton(
              label: 'Reset form fields',
              onPressed: () => setState(() {
                for (final id in _formFieldIds) {
                  _adapter.set('$_formScope.$id', TomAuthState.full);
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoPanel(
          title: 'Widget gallery auth',
          children: [
            for (final e in _galleryEntries)
              _buildAuthRow(
                label: '${e.label}  (tomId: ${e.tomId})',
                path: '$_galleryScope.${e.tomId}',
                current: _galleryAuth(e.tomId),
                onChanged: (s) => _setGalleryAuth(e.tomId, s),
              ),
            const SizedBox(height: 8),
            _buildResetAllButton(
              label: 'Reset widgets',
              onPressed: () => setState(() {
                for (final e in _galleryEntries) {
                  _adapter.set('$_galleryScope.${e.tomId}', TomAuthState.full);
                }
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthRow({
    required String label,
    required String path,
    required TomAuthState current,
    required ValueChanged<TomAuthState> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          DropdownButton<TomAuthState>(
            isExpanded: true,
            value: current,
            items: TomAuthState.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResetAllButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.restart_alt, size: 16),
        label: Text(label),
      ),
    );
  }
}
