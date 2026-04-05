import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import '../theme/tom_theme.dart';
import 'tom_node_base.dart';

/// Authorization enforcement layer for Tom UI elements.
///
/// Every Tom widget passes through this base class. It resolves authorization
/// via the global [TomUIAuthorization] singleton and enforces:
/// - **Hidden** → [SizedBox.shrink] (removed from layout).
/// - **Readonly** → visual treatment from [TomReadonlyStyle] via [TomThemeScope].
/// - **Full access** → normal rendering.
abstract class TomPolicyNodeBase extends TomNodeBase {
  const TomPolicyNodeBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
  });

  @override
  Widget build(BuildContext context) {
    final resourceKeyPath = resolveResourceBasePath();

    final authState = resourceKeyPath != null
        ? TomUIAuthorization.resolveAuth(resourceKeyPath)
        : TomAuthState.fullAccess;

    if (!authState.visible) return const SizedBox.shrink();

    if (authState.readonly) return buildReadonly(context);

    return buildContent(context);
  }

  /// Builds the actual widget content after authorization has been resolved.
  ///
  /// Subclasses implement this instead of [build].
  Widget buildContent(BuildContext context);

  /// Builds the readonly visual treatment.
  ///
  /// The default implementation resolves [TomReadonlyStyle] from the
  /// nearest [TomThemeScope] and applies it. When no theme scope exists,
  /// [TomReadonlyStyle.defaultStyle] is used (AbsorbPointer + 0.6 opacity).
  ///
  /// Family base classes can override this for family-specific readonly
  /// behavior (e.g., inputs may show a non-editable text field with a
  /// distinct background instead of a blanket opacity reduction).
  Widget buildReadonly(BuildContext context) {
    final style = TomThemeScope.readonlyStyleOf(context);
    return style.apply(buildContent(context));
  }
}
