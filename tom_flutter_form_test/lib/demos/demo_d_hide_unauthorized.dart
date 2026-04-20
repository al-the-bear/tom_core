import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/validation_form.dart';
import '../panels/info_panel.dart';
import '../state/phase1_state.dart';

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

const _formScope = 'demoD.validationForm';
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

const _galleryScope = 'demoD.widgets';

class _DemoDHideUnauthorizedState extends State<DemoDHideUnauthorized> {
  late final _DemoDAuthAdapter _adapter;
  late final ValidationForm _form;

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
    _form = TomScope.withScope('demoD', () => ValidationForm());
    _form.bind(phase1ValidationState);
  }

  @override
  void dispose() {
    _form.dispose();
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
                  Expanded(
                      flex: 3,
                      child: SingleChildScrollView(child: left)),
                  const SizedBox(width: 16),
                  Expanded(
                      flex: 2,
                      child: SingleChildScrollView(child: right)),
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
        _buildFormSection(context),
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
            const _Bullet('Both ACLs below call '
                '`setAclDefaultHideUnauthorized(true)` — when a child '
                'resolves to `TomAuthState.none` it is dropped from the '
                'row entirely and the following gap collapses.'),
            const _Bullet('Row elision: set every field in a row (e.g. '
                'password + confirmPassword) to `none` and the whole row '
                'disappears, with the next row\'s gap dropped so the '
                'layout tightens up.'),
            const _Bullet('`read` and `disabled` keep the element in place '
                'but change its visual treatment — readonly style from the '
                'theme scope, vs. dimmed & ignoring input.'),
            const _Bullet('Form-field widgets participate via '
                'TomFieldWidgetAdapter; regular Tom widgets via '
                'TomNodeBase / TomWidgetMixin. Same ACL filter for both.'),
          ],
        ),
      ),
    );
  }

  // ── Form section (hide-unauthorized on a real form) ──────────────────────

  Widget _buildFormSection(BuildContext context) {
    // Row layout: (username, email) (password, confirmPassword) (website).
    // Setting both password + confirmPassword to `none` elides the whole
    // second row.
    final layout = TomAclBuilder(
      id: 'demoDFormAcl',
      elementProvider: _form,
    )
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .setAclDefaultHideUnauthorized(true)
        .append((p) => p.username.widget)
        .append((p) => p.email.widget, dist: 16)
        .newRow()
        .append((p) => p.password.widget)
        .append((p) => p.confirmPassword.widget, dist: 16)
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
            Text('Form — hide on auth (+ read / disabled)',
                style: Theme.of(context).textTheme.titleSmall),
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
            child: TomDivider(
              tomId: 'hairline',
              scope: TomScope.current,
            ),
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
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Text('Card'),
            ),
          ),
        ),
      ];

  Widget _buildGallerySection(BuildContext context) {
    final entries = _galleryEntries;
    // Three rows × up to four widgets each — arranged so that hiding every
    // widget on a row still gives an observable elision. Each row's dist
    // (24) makes the collapse visually obvious.
    Widget layout;
    layout = TomScope.withScope(_galleryScope, () {
      final instances = entries.map((e) => e.build()).toList();
      final b = AclBuilder()
          .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
          .setAclDefaultHideUnauthorized(true)
          .setAclDefaultAppendGap(16)
          .setAclDefaultRowGap(24);
      for (int i = 0; i < instances.length; i++) {
        if (i == 4 || i == 7) b.newRow();
        b.append(instances[i]);
      }
      return b.build();
    });

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Non-form Tom widgets — same hide-unauthorized rule',
                style: Theme.of(context).textTheme.titleSmall),
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
                  _adapter.set(
                      '$_galleryScope.${e.tomId}', TomAuthState.full);
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
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontFamily: 'monospace'),
          ),
          DropdownButton<TomAuthState>(
            isExpanded: true,
            value: current,
            items: TomAuthState.values
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResetAllButton(
      {required String label, required VoidCallback onPressed}) {
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

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text('• $text'),
    );
  }
}
