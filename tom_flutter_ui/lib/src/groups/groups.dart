/// Tom UI Groups — collective visibility control for related widgets.
///
/// Groups provide semantic control over entire UI regions without requiring
/// individual IDs on every leaf widget.
///
/// Core classes:
/// - [TomGroup] — a single group with member tracking
/// - [TomGroups] — global registry for all groups
/// - [TomGroupScope] — widget that defines a group scope
/// - [TomWidgetMixin] — mixin for widgets that extend Flutter widgets
library;

export 'tom_group.dart';
export 'tom_group_scope.dart';
export 'tom_groups.dart';
export 'tom_widget_mixin.dart';
