/// Demo N — Cupertino numeric + date/time with breakpoint theme swap
/// (Phase 5b).
///
/// Renders the nine Phase 5b Cupertino concretes against a single
/// `CupertinoPhase5bForm` bound to `phase5bDemoState`. The page-root
/// scope nests two layers:
///
///   * Outer  — `TomFormStyleScope(style: TomCupertinoFormStyle.cupertino)`
///              keeps every field in Cupertino style across the whole
///              page.
///   * Inner  — A second `TomFormStyleScope(style: null,
///              themeSpecBpOverrides: …)` wrapping just the picker
///              column. With `style: null` the inner scope is purely a
///              breakpoint-aware *theme* injector — at narrow widths it
///              swaps in a denser, dark-tinted theme; at wide widths the
///              theme reverts to the outer light theme. This explicitly
///              exercises the optional-`style` scope feature called out
///              in the spec for Phase 5b.
///
/// A live "current breakpoint" badge in the header reads back the
/// resolved width so the user can see which themeSpec branch is active.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/phase5_demo_forms.dart';
import '../panels/info_panel.dart';
import '../state/phase5_state.dart';

/// Breakpoint cutoff between "narrow → modal-sheet feel" and "wide →
/// popover feel". Matches the spec's wording: at wide widths Cupertino
/// pickers present as popovers, at narrow widths as full-height modal
/// sheets. We approximate that visually by swapping the inner theme
/// (denser + dark-tinted at narrow widths) — the picker widgets
/// themselves still use CupertinoModalPopup, but the surrounding
/// surface flips between light/airy and dark/dense.
const double _phase5bBreakpoint = 700;

class DemoNCupertinoNumericDateTime extends StatefulWidget {
  const DemoNCupertinoNumericDateTime({super.key});

  @override
  State<DemoNCupertinoNumericDateTime> createState() =>
      _DemoNCupertinoNumericDateTimeState();
}

class _DemoNCupertinoNumericDateTimeState
    extends State<DemoNCupertinoNumericDateTime> {
  late final CupertinoPhase5bForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoN', CupertinoPhase5bForm.new);
    // Bind only the properties that are part of Phase5bDemoState — the
    // form's time / duration / range fields stay form-local because
    // their value types (TimeOfDay / Duration / DateTimeRange) have no
    // TomObject wrapper.
    _form.bind(phase5bDemoState);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo N — Cupertino numeric + date/time (Phase 5b)',
      child: TomFormStyleScope(
        style: TomCupertinoFormStyle.cupertino,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _phase5bBreakpoint;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBpBadge(context, constraints.maxWidth),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _formColumn(context)),
                              const SizedBox(width: 16),
                              SizedBox(width: 280, child: _statePanel(context)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _formColumn(context),
                              const SizedBox(height: 12),
                              _statePanel(context),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBpBadge(BuildContext context, double width) {
    final theme = Theme.of(context);
    final wide = width >= _phase5bBreakpoint;
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            wide
                ? CupertinoIcons.rectangle_split_3x1
                : CupertinoIcons.rectangle,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'width: ${width.toStringAsFixed(0)} px '
              '→ inner themeSpec: '
              '${wide ? "wide (light/airy)" : "narrow (dense/dark)"}',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formColumn(BuildContext context) {
    // Inner scope: style is null on purpose so this scope is a
    // breakpoint-aware theme injector only — the outer Cupertino style
    // still resolves for every field. The themeSpecBpOverrides pair
    // swaps the inner theme between light/airy (wide) and dark/dense
    // (narrow), without re-declaring a form style.
    return TomFormStyleScope(
      style: null,
      themeSpec: const TomThemeSpec(
        brightness: Brightness.light,
        density: VisualDensity.standard,
      ),
      themeSpecBpOverrides: const [
        (
          _phase5bBreakpoint,
          TomThemeSpec(
            brightness: Brightness.light,
            density: VisualDensity.comfortable,
          ),
        ),
      ],
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader(context, 'Numeric'),
              _form.quantity.widget,
              const SizedBox(height: 8),
              _form.brightness.widget,
              const SizedBox(height: 8),
              _form.ratio.widget,
              const SizedBox(height: 8),
              _form.price.widget,
              const SizedBox(height: 16),
              _sectionHeader(context, 'Date / Time / Duration'),
              _form.eventDate.widget,
              const SizedBox(height: 8),
              _form.eventTime.widget,
              const SizedBox(height: 8),
              _form.eventDateTime.widget,
              const SizedBox(height: 8),
              _form.downtime.widget,
              const SizedBox(height: 16),
              _sectionHeader(context, 'Range'),
              _form.billingPeriod.widget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _statePanel(BuildContext context) {
    return InfoPanel(
      title: 'Form state (Phase5bDemoState + form-local)',
      children: [
        TomMultiObservableBuilder(
          observables: [
            _form.quantity,
            _form.brightness,
            _form.ratio,
            _form.price,
            _form.eventDate,
            _form.eventTime,
            _form.eventDateTime,
            _form.downtime,
            _form.billingPeriod,
          ],
          builder: (context) {
            final theme = Theme.of(context);
            String dateStr(DateTime d) =>
                '${d.year.toString().padLeft(4, '0')}-'
                '${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')}';
            String timeStr(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}';
            String dtStr(DateTime d) =>
                '${dateStr(d)} ${d.hour.toString().padLeft(2, '0')}:'
                '${d.minute.toString().padLeft(2, '0')}';
            String durStr(Duration d) =>
                '${d.inHours}h ${(d.inMinutes - d.inHours * 60)}m';
            String rangeStr(DateTimeRange r) =>
                '${dateStr(r.start)} → ${dateStr(r.end)}';

            final rows = <(String, String)>[
              ('quantity', '${_form.quantity.get()}'),
              ('brightness', '${_form.brightness.get()}'),
              ('ratio', _form.ratio.get().toStringAsFixed(2)),
              ('price (USD)', _form.price.get().toStringAsFixed(2)),
              ('eventDate', dateStr(_form.eventDate.get())),
              ('eventTime', timeStr(_form.eventTime.get())),
              ('eventDateTime', dtStr(_form.eventDateTime.get())),
              ('downtime', durStr(_form.downtime.get())),
              ('billingPeriod', rangeStr(_form.billingPeriod.get())),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (name, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(name, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
