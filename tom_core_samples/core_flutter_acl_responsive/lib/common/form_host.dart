/// Owns the lifecycle of a single live [TomForm] inside a showcase cell.
///
/// A form is stateful: it must be created inside a [TomScope] (so its fields
/// resolve ids consistently) and disposed when the cell leaves the tree. Doing
/// that by hand in every group would be the kind of copy-paste this sample
/// exists to discourage, so the lifecycle lives here once and every
/// `code | rendered` cell hands [FormHost] a `create`, an optional `bind`, and a
/// `builder`. Shared in shape with `core_flutter_form_showcase`.
///
/// Binding is the *caller's* step and is optional: this class constructs no
/// domain entity, and an unbound form renders against the defaults its fields
/// declare. `form_host_test.dart` pins both paths.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A stateful preview that creates [create] inside the [scopeId] scope, runs
/// the optional [bind], renders [builder], and disposes the form on teardown.
// Why: extends [TomStatefulWidget] (paired with [TomState]) rather than raw
// StatefulWidget so the host conforms to G-UI-1/G-UI-2 and its [buildContent]
// re-enters the construction-time [TomScope]. It owns no tomId/resources of its
// own, so [TomStatefulWidget] — the sanctioned base for scope-participating
// stateful chrome — is the correct base, not a family base. Construction reads
// [TomScope.current] → the constructor is non-const.
class FormHost<F extends TomForm<TomClass>> extends TomStatefulWidget {
  FormHost({
    super.key,
    required this.scopeId,
    required this.create,
    required this.builder,
    this.bind,
  });

  /// The [TomScope] id the form is constructed in.
  final String scopeId;

  /// Builds the concrete form. Called exactly once, inside the scope.
  final F Function() create;

  /// Binds the freshly created form to a domain entity. Optional: a form can
  /// render its own initial values unbound, but binding is what demonstrates
  /// the reflection round-trip the sample is about.
  final void Function(F form)? bind;

  /// Renders the live form (typically a [TomAclBuilder] layout).
  final Widget Function(BuildContext context, F form) builder;

  @override
  State<FormHost<F>> createState() => _FormHostState<F>();
}

class _FormHostState<F extends TomForm<TomClass>>
    extends TomState<FormHost<F>> {
  late final F _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope(widget.scopeId, widget.create);
    widget.bind?.call(_form);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) => widget.builder(context, _form);
}
