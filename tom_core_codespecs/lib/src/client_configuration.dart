/// The per-machine client-configuration holder a CodeSpec's `@CsClientConfig`
/// (CE-CC) is built on.
///
/// **Why this is a gap (csm2r7 survey `codespecs_mapping.md` §1.1b).** The
/// *values* reuse the `tom_core_flutter` `TomProperty`* family (each field
/// reads one client-side config key at construction). What `tom_core` lacks is
/// a **holder** that groups those values as the deployment/per-machine
/// configuration of one client — the settings keyed by the **(client app,
/// machine)** pair, with **no user identity in the key**
/// (`codespecs_mapping.md` §11). That key is the whole discriminator: a value
/// that is the same for every user of an install is CE-CC; a value that differs
/// per signed-in user is CE-DS (device-persisted) or CE-UP (server-persisted,
/// follows the user). CodeSpecs needs that holder, so it lands here as a
/// concrete `tom_core`-family class (never an abstract `Cs*` base,
/// `codespecs_mapping.md` §1.1).
///
/// A CodeSpec `@CsClientConfig` class *is a* `TomClientConfiguration`. Its scalar
/// fields are backed by `TomProperty` reads in the running client.
class TomClientConfiguration {
  /// The server API base URL this client instance points at.
  String apiBaseUrl;

  /// The deployment environment name (e.g. `dev`, `staging`, `prod`).
  String environment;

  /// The update channel this installed client follows (e.g. `stable`, `beta`).
  String updateChannel;

  /// Per-machine feature toggles keyed by feature id.
  Map<String, bool> featureToggles;

  /// Free-form per-machine device options (keyed values fixed at the install).
  Map<String, Object?> deviceOptions;

  /// Creates a per-machine client-configuration holder.
  TomClientConfiguration({
    this.apiBaseUrl = '',
    this.environment = '',
    this.updateChannel = '',
    Map<String, bool>? featureToggles,
    Map<String, Object?>? deviceOptions,
  })  : featureToggles = featureToggles ?? <String, bool>{},
        deviceOptions = deviceOptions ?? <String, Object?>{};
}
