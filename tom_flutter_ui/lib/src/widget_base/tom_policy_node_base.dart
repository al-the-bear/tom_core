import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import 'tom_node_base.dart';

/// Authorization enforcement layer for Tom UI elements.
///
/// Every Tom widget passes through this base class. It resolves authorization
/// via the global [TomUIAuthorization] singleton and enforces:
/// - **Hidden** → [SizedBox.shrink] (removed from layout).
/// - **Readonly** → [AbsorbPointer] with reduced opacity.
/// - **Full access** → normal rendering.
abstract class TomPolicyNodeBase extends TomNodeBase {
  const TomPolicyNodeBase({super.key, super.tomId, super.tomGroup});

  @override
  Widget build(BuildContext context) {
    final resourceKeyPath = resolveResourceBasePath(context);

    final authState = resourceKeyPath != null
        ? TomUIAuthorization.resolveAuth(resourceKeyPath)
        : TomAuthState.fullAccess;

    if (!authState.visible) return const SizedBox.shrink();

    final content = buildContent(context);

    if (authState.readonly) {
      return AbsorbPointer(
        child: Opacity(opacity: 0.6, child: content),
      );
    }

    return content;
  }

  /// Builds the actual widget content after authorization has been resolved.
  ///
  /// Subclasses implement this instead of [build].
  Widget buildContent(BuildContext context);
}
