import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Categorical filter for [EventLogPanel]. Matches the four groups called
/// out in §24b: "Filter buttons by event type (value change, validation,
/// auth, lifecycle)".
enum EventCategory {
  value,
  validation,
  auth,
  lifecycle,
}

/// Scrollable list of every [TomFormEvent] collected by [TomFormInspector].
///
/// Shows timestamp, event-type icon, source field, and description. Offers
/// per-category filter chips, a clear button, and an auto-scroll-to-latest
/// toggle (all exercised by Demos A and B per §24b).
///
/// The panel is **stateful** — it owns the filter/auto-scroll toggles — but
/// the event buffer lives on the caller's [TomFormInspector] so multiple
/// views could share it.
class EventLogPanel extends StatefulWidget {
  final TomFormInspector inspector;

  /// Rebuild trigger. Any Listenable that fires on form events will do —
  /// typically `form.changes` (aggregate notifier) or a merged listenable
  /// across several forms.
  final Listenable rebuildOn;

  const EventLogPanel({
    super.key,
    required this.inspector,
    required this.rebuildOn,
  });

  @override
  State<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends State<EventLogPanel> {
  final ScrollController _scroll = ScrollController();
  final Set<EventCategory> _enabled = {
    EventCategory.value,
    EventCategory.validation,
    EventCategory.auth,
    EventCategory.lifecycle,
  };
  bool _autoScroll = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  EventCategory _categoryOf(TomFormEvent event) {
    if (event is FieldValueChangedEvent) return EventCategory.value;
    if (event is FieldValidatedEvent || event is FormValidatedEvent) {
      return EventCategory.validation;
    }
    if (event is FieldAuthChangedEvent) return EventCategory.auth;
    return EventCategory.lifecycle;
  }

  IconData _iconOf(EventCategory c) => switch (c) {
        EventCategory.value => Icons.edit,
        EventCategory.validation => Icons.rule,
        EventCategory.auth => Icons.shield_outlined,
        EventCategory.lifecycle => Icons.history,
      };

  Color _colorOf(ThemeData theme, EventCategory c) => switch (c) {
        EventCategory.value => theme.colorScheme.primary,
        EventCategory.validation => theme.colorScheme.tertiary,
        EventCategory.auth => theme.colorScheme.secondary,
        EventCategory.lifecycle => theme.colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.rebuildOn,
      builder: (context, _) {
        final filtered = widget.inspector.events
            .where((e) => _enabled.contains(_categoryOf(e)))
            .toList();

        // Auto-scroll after the list renders so the latest event stays in
        // view without the user having to manage the scroll position.
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbar(theme, filtered.length, widget.inspector.length),
            const SizedBox(height: 6),
            _buildFilterChips(theme),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 300),
              child: filtered.isEmpty
                  ? _buildEmptyState(theme)
                  : Scrollbar(
                      controller: _scroll,
                      child: ListView.builder(
                        controller: _scroll,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _buildEventRow(theme, filtered[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(ThemeData theme, int shown, int total) {
    return Row(
      children: [
        Text(
          '$shown / $total events',
          style: theme.textTheme.labelSmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: _autoScroll ? 'Auto-scroll: on' : 'Auto-scroll: off',
          icon: Icon(
            _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
            size: 18,
          ),
          onPressed: () => setState(() => _autoScroll = !_autoScroll),
        ),
        IconButton(
          tooltip: 'Clear log',
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: () {
            widget.inspector.clear();
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final c in EventCategory.values)
          FilterChip(
            label: Text(c.name, style: theme.textTheme.labelSmall),
            selected: _enabled.contains(c),
            visualDensity: VisualDensity.compact,
            onSelected: (v) => setState(() {
              if (v) {
                _enabled.add(c);
              } else {
                _enabled.remove(c);
              }
            }),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Text(
        'No events yet — interact with the form to see entries.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEventRow(ThemeData theme, TomFormEvent event) {
    final category = _categoryOf(event);
    final color = _colorOf(theme, category);
    final ts = event.timestamp;
    final timeLabel =
        '${_pad(ts.hour)}:${_pad(ts.minute)}:${_pad(ts.second)}.${_pad(ts.millisecond, 3)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconOf(category), size: 14, color: color),
          const SizedBox(width: 4),
          Text(timeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          const SizedBox(width: 6),
          Text(
            event.source,
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${event.runtimeType}: ${event.description}',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static String _pad(int n, [int w = 2]) => n.toString().padLeft(w, '0');
}
