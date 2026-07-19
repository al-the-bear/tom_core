/// The client-application descriptor a CodeSpec's `@CsClient` (CE-CL) is built on.
///
/// **Why this is a gap (csm2r7 survey `codespecs_new_parts_basis.md` §3).**
/// `tom_core` has no client-application *descriptor* root: `TomAuthenticationData`
/// carries a `client` id string and `TomClientRemoteContext` models a live
/// connection, but neither names the client application as a first-class,
/// spec-authorable unit (its id, platforms, entry route, and the server it talks
/// to). CodeSpecs needs that unit, so it lands here — a concrete `tom_core`-family
/// class, not an abstract `Cs*` base (the framework carries annotations only, §0).
///
/// A CodeSpec `@CsClient` class *is a* `TomClientApplication`; the client-only
/// project (`<app>_codespec_client`, §4.2) instantiates it.
class TomClientApplication {
  /// Stable identifier of the client application (e.g. `admin_console`).
  ///
  /// Matches the `client` field the server sees in `TomAuthenticationData`, so a
  /// login can be attributed to this client.
  String clientId;

  /// Human-readable name of the client application.
  String displayName;

  /// The target platforms this client is built for (e.g. `web`, `android`,
  /// `ios`, `macos`, `windows`, `linux`). A client may target several.
  List<String> platforms;

  /// The route id the client opens on launch (a `TomPageRoute` id — CE-NV).
  String entryRoute;

  /// The base URL of the server this client talks to. Empty until wired by the
  /// client configuration (CE-CC, [TomClientConfiguration.apiBaseUrl]).
  String serverBaseUrl;

  /// Creates a client-application descriptor.
  TomClientApplication({
    this.clientId = '',
    this.displayName = '',
    List<String>? platforms,
    this.entryRoute = '',
    this.serverBaseUrl = '',
  }) : platforms = platforms ?? <String>[];
}
