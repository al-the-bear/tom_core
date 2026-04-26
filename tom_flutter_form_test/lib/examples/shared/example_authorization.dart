import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Static authorization adapter for the Examples section.
///
/// In a real app this comes from a server / token claims / user role lookup.
/// Here we use a simple `Map<String, TomAuthState>` lookup so each example
/// can demonstrate per-resource auth without any backend.
///
/// Key matching uses prefix semantics: looking up `example.customer.email`
/// returns the closest registered ancestor — e.g. an entry for
/// `example.customer.*` covers all customer fields.
///
/// Unknown keys default to [TomAuthState.full].
class ExampleAuthAdapter implements TomAuthorizationAdapter {
  ExampleAuthAdapter(this._map);

  /// Mapping from resource key path → effective auth state.
  ///
  /// Both exact paths and prefix paths (no special syntax — longest matching
  /// prefix wins) are supported.
  final Map<String, TomAuthState> _map;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    // Exact-match first.
    final exact = _map[resourceKeyPath];
    if (exact != null) return exact;

    // Longest-prefix-match next: walk parent paths.
    var path = resourceKeyPath;
    while (true) {
      final dot = path.lastIndexOf('.');
      if (dot < 0) break;
      path = path.substring(0, dot);
      final hit = _map[path];
      if (hit != null) return hit;
    }

    // Default — fully authorized.
    return TomAuthState.full;
  }
}

/// The static authorization table the Examples section installs at startup.
///
/// - `example.customer.tier`  → disabled (visible but greyed — demonstrates
///   the `disabled` auth state so the examples show a real auth scenario)
/// - everything else          → fully authorized (default)
final Map<String, TomAuthState> exampleAuthMap = <String, TomAuthState>{
  'example.customer.tier': TomAuthState.disabled,
};

/// Installs the example authorization adapter as the global adapter.
///
/// Idempotent — safe to call more than once.
void installExampleAuthorization() {
  TomAuthorization.adapter = ExampleAuthAdapter(exampleAuthMap);
}
