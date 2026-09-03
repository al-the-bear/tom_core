/// The client-application descriptor a CodeSpec's `@CsClient` (CE-CL) is built on.
///
/// **Why this is a gap (csm2r7 survey `codespecs_mapping.md` §1.1
/// pillar (b)).** `tom_core` has no client-application *descriptor* root:
/// `TomAuthenticationData` carries a `client` id string and
/// `TomClientRemoteContext` models a live connection, but neither names the
/// client application as a first-class, spec-authorable unit (its id,
/// platforms, entry route, and the server it talks to). CodeSpecs needs that
/// unit, so it lands here — a concrete `tom_core`-family class, not an abstract
/// `Cs*` base (the framework carries annotations only, `codespecs_mapping.md`
/// §1.1).
///
/// A CodeSpec `@CsClient` class *is a* `TomClientApplication`; the client-only
/// project (`<app>_codespec_client`, `codespecs_mapping.md` §4.2) instantiates
/// it.
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

  /// The screens this client comprises, by screen id (CE-EL / CE-FM).
  ///
  /// A client is more than its entry route: two clients over the same route
  /// registry differ by which screens they ship. Empty for a client that has
  /// no screens at all — a command-line client, or another server calling in.
  List<String> screenIds;

  /// The base URL of the server this client talks to. Empty until wired by the
  /// client configuration (CE-CC — a `TomSetting<String>` declared on the
  /// client's `TomBaseClientConfiguration`, `tom_core_flutter`).
  String serverBaseUrl;

  /// Creates a client-application descriptor.
  TomClientApplication({
    this.clientId = '',
    this.displayName = '',
    List<String>? platforms,
    this.entryRoute = '',
    List<String>? screenIds,
    this.serverBaseUrl = '',
  }) : platforms = platforms ?? <String>[],
       screenIds = screenIds ?? <String>[];
}
