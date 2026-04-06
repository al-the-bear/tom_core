import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A [StatelessWidget] that captures the [TomScope] at construction time
/// and re-enters it during [build].
///
/// Use this as a base class for non-Tom widgets (no tomId/resources) that
/// still need to participate in scope propagation — e.g., demo pages,
/// screen containers, or layout wrappers that contain Tom widgets.
///
/// For Tom widgets with resource resolution, use [TomNodeBase] subclasses
/// instead — they handle scope propagation automatically.
abstract class TomStatelessWidget extends StatelessWidget {
  TomStatelessWidget({super.key})
      : _constructionScope = TomScope.current;

  final TomScope _constructionScope;

  @override
  Widget build(BuildContext context) {
    return _constructionScope.runInScope(() => buildContent(context));
  }

  /// Builds the widget content within the construction-time scope.
  ///
  /// Subclasses implement this instead of [build].
  Widget buildContent(BuildContext context);
}

/// A [StatefulWidget] that captures the [TomScope] at construction time
/// and makes it available to its [TomState].
///
/// Pair with [TomState] to ensure scope propagation through stateful widgets.
abstract class TomStatefulWidget extends StatefulWidget {
  TomStatefulWidget({super.key})
      : constructionScope = TomScope.current;

  /// The scope that was active when this widget was constructed.
  final TomScope constructionScope;
}

/// A [State] subclass that re-enters the widget's construction-time scope
/// during [build].
///
/// Use with [TomStatefulWidget].
abstract class TomState<T extends TomStatefulWidget> extends State<T> {
  @override
  Widget build(BuildContext context) {
    return widget.constructionScope.runInScope(() => buildContent(context));
  }

  /// Builds the widget content within the construction-time scope.
  ///
  /// Subclasses implement this instead of [build].
  Widget buildContent(BuildContext context);
}
