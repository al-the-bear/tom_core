import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Holds the resolved configuration tree and answers property lookups for
/// [TomConfig].
///
/// A single provider is shared process-wide through [getServerConfig]; install
/// a populated one at startup with [setServerConfigProvider] or by setting the
/// static [loader]. Keys may be dotted paths into the nested [resources] map
/// (resolved via the kernel's tree walker).
class TomServerConfigResourceProvider {
  static TomServerConfigResourceProvider? _configProvider;

  /// Optional factory for the default provider's [resources]. When set, it is
  /// invoked the first time [getServerConfig] lazily creates a provider.
  static Map<String, dynamic> Function()? loader;

  /// Installs [provider] as the process-wide configuration source.
  static void setServerConfigProvider(
    TomServerConfigResourceProvider provider,
  ) {
    _configProvider = provider;
  }

  /// Returns the active provider, creating a default one (using [loader] if
  /// set) on first access.
  static TomServerConfigResourceProvider getServerConfig() {
    _configProvider ??= TomServerConfigResourceProvider();
    return _configProvider!;
  }

  /// The configuration tree: a possibly-nested map of property values.
  Map<String, dynamic> resources = {};

  /// Creates a provider, populating [resources] from [loader] if it is set.
  TomServerConfigResourceProvider() {
    if (loader != null) {
      resources = loader!();
    }
  }

  /// Creates a provider whose [resources] are produced by [loader].
  TomServerConfigResourceProvider.load(Map<String, dynamic> Function() loader) {
    resources = loader();
  }

  /// Creates a provider directly from an existing [resources] map.
  TomServerConfigResourceProvider.from(this.resources);

  /// Whether property [s] exists, as a dotted tree path or a top-level key.
  ///
  /// A property configured explicitly as `null` **exists**: [getObjectFromTree]
  /// resolves it rather than throwing, so the tree leg returns `true` for it.
  /// That is the point of the distinction — a deliberately cleared setting is
  /// configured, and [TomConfig] must see it as configured so it does not
  /// silently substitute a default the operator was overriding.
  bool exists(String s) {
    try {
      getObjectFromTree(resources, s);
      return true;
    } catch (ex) {
      // fall through
    }
    return resources.containsKey(s);
  }

  /// Returns property [s] (dotted path or top-level key).
  ///
  /// Returns `null` when the property is present and explicitly `null`; gate on
  /// [exists] to tell that apart from an unknown key. As a deliberate fallback,
  /// an unknown key resolves to the key string [s] itself rather than throwing
  /// (callers that must distinguish absence use [exists], as [TomConfig] does).
  Object? get(String s) {
    try {
      return getObjectFromTree(resources, s);
    } catch (ex) {
      // fall through
    }
    return resources.containsKey(s) ? resources[s] : s;
  }
}

/// The process-wide application id, set from configuration at startup.
String tomAppId = "";

/// Reflected base class for a server's configuration.
///
/// Subclasses declare typed fields (port, TLS material, handlers, logging, …);
/// the reflection layer fills them from the merged configuration sources in the
/// constructor. The defaults below are sensible for local development — notably
/// [certificateChain] / [privateKey] hold a throwaway self-signed `localhost`
/// pair that MUST be overridden in production.
///
/// Sources are merged by [getDefaultValues] with later sources overriding
/// earlier ones: configuration resources, then the OS environment, then a
/// `.env` file, then command-line arguments (which win).
///
/// JWT signing keys ([jwtRsaPubKey] / [jwtRsaPrivKey] /
/// [jwtSharedSecretKey]) are present as fields; richer JWT-creation settings
/// are a tracked follow-up (see the quest completion steps).
@tomReflector
abstract class TomBaseServerConfiguration {
  String appId = "";

  /// The command-line arguments this configuration was built from.
  ///
  /// The one **derived** field on this class: every other field answers "what
  /// was I told", this one answers "how was I invoked". It is not a
  /// configuration key — the constructor assigns it from its own parameter
  /// after [setValues] has run, so a merged key spelled `args` cannot displace
  /// the real invocation. Such a key is still merged and still visible in
  /// [getDefaultValues]'s result; it just does not land here.
  ///
  /// Note that a merged `args` key whose value is not a `List<String>` — an
  /// `args=x` argument parses to a `String` — still fails inside [setValues]
  /// before this assignment is reached. That is deliberate: the message names
  /// the field and the offending value, which is the right answer for a
  /// configuration that set a key it should not have.
  ///
  /// **This may hold a secret.** The command line is one of the out-of-band
  /// channels a deployment uses to supply [smtpPassword], [smsApiKey] and the
  /// rest, so the invocation recorded here can contain them verbatim. Log or
  /// serialize individual fields, never this list.
  List<String> args = [];

  String serverHeader = "";

  bool autoCompress = true;

  String poweredByHeader = "tom";

  bool noSsl = false;

  bool listenToAnyIP = false;

  /// HTTP bind port. `0` is the "unconfigured" sentinel: [setValues] (config /
  /// env / `port=`) overwrites it when a port is supplied, otherwise a
  /// subclass constructor — which runs *after* the base constructor's
  /// [setValues] call — applies its own default via `if (port == 0) port = …`.
  /// A literal default here (e.g. `8080`) would defeat that guard, since the
  /// field would never be `0` for the subclass to detect "no port configured".
  ///
  /// The command-line spelling is `port=8080`, **not** `--port=8080`: a key is
  /// the argument text before the first `=`, dashes included, so the dashed
  /// form fills the key `--port`, which names no field and is silently dropped
  /// (see `doc/cmdline.md`).
  int port = 0;

  String certificateChain = '''
-----BEGIN CERTIFICATE-----
MIIFgzCCA2ugAwIBAgIUIQjzx85IYfitPxv3DWFnvTsKKYYwDQYJKoZIhvcNAQEL
BQAwXzELMAkGA1UEBhMCR0IxEDAOBgNVBAgMB0VuZ2xhbmQxETAPBgNVBAcMCEJy
aWdodG9uMRcwFQYDVQQKDA5IYWxsbWFya2Rlc2lnbjESMBAGA1UEAwwJbG9jYWxo
b3N0MB4XDTI0MDMxOTE0MzMzN1oXDTM0MDMxNzE0MzMzN1owXzELMAkGA1UEBhMC
R0IxEDAOBgNVBAgMB0VuZ2xhbmQxETAPBgNVBAcMCEJyaWdodG9uMRcwFQYDVQQK
DA5IYWxsbWFya2Rlc2lnbjESMBAGA1UEAwwJbG9jYWxob3N0MIICIjANBgkqhkiG
9w0BAQEFAAOCAg8AMIICCgKCAgEAxTZNpBvalsYr0XS9jnwg24k8vJmrjX+VODih
jKEoneghj/TYGpRZXFNF5s0J/Dg58gCrSEV6CAmjr5PS08FhBHQyfpb2uvgO5Dr7
nOx2+vQxZjyWKRZS2IRk8heoOsr3aGNrAqZ4747GcCaH36ki18LFZNUZbSBTMtzH
KCYutrKwl5B782R26V4XVooSLaXDmsSqi5HiSnW5gZHOyn3z0cQqtnSejH25qDNo
VKLD0wvxFs37CjDJS2eEsN/n8KrHvu7eGyYi/7Q3Ai7lm2jbhaZ1UKgk0hULOCq4
2mrQw/cvIUiCum4hSB5FuCzsm2wFpIgSgREcyPChTVUHTZg1dOFKaYcqjQTbP30w
yCylUsGv4AK94sF1NzK7v3HUDiioT1nbTJZaiLHuCu8Hk6nPYw2l36SSWRVY1S6g
sFX3Gv/+kDp7YxkFx9WXsvGlNI9CAiXFaRcJdkKX6xLESd7PiGcuj0x3gctdMxtP
jSdGPYYeOHRK+pi5ktpjaPzWIZNxPQM7nuWcramI5Mi5b0EOlAayQFkMxc5QMg5r
qSj/dTL97nhxuVhlaGcQYLD1kwGMEulkrpqwkeGWcPzWPHOMbG5PqHXGnLBIP2vy
cL0txmNF/6uEnyQUeV1bSxjBcHEObyCmSxWAhLDP8TZKEWRu2/LV37B2XiVjcXa5
8UAaB78CAwEAAaM3MDUwFAYDVR0RBA0wC4IJbG9jYWxob3N0MB0GA1UdDgQWBBQz
dxlPiTQZGKk/FuAtxXa+O6+0vDANBgkqhkiG9w0BAQsFAAOCAgEAGs5LqQcokOqc
gafFphrtQqLlHJWmu4k+gzSwO1K1viRpnwnwIRnnrsRYeGOHk43QGLc2E6Ze8/b9
snvGDIUJ5vP3C5G+7G4tj4/kdUEDy7dkQs/hznwkZsgUdfjigq2ykEevC6TB5cwH
vL0ZNYF3745xuMmsG4/WzkCpJ5Wb9WbyIYPAUW3vKdA+7pR6atC/EWGlCXMeiwCY
s9QHncYW71zwJDVoUygkCPe/hATJeZTd/sDGDF5j96b6e3FOkeTN+5Zi/sLDC0f8
/B19NZfWvnO9X6GS57+izspbkSejHVf9rjitpAykeha91MQje7rsP52Ymc+RMxGI
gVF8x3gX1oUINLnmq8jHhq03/b/tcQx1vqxw37uyn0QGEkef0OfD9Tgo6K02HUkn
F/8+7Hqq8e2ZoFWhws4LVGIp0UnScKn8+fCu1holc4112pBo0Fy8s+uZXZcAdiFv
WaW2zEEkYzCHc1XKiIjMBWO9YbTzQeWz7RCiiO6FoKo5CKur4iHxVm4gewCebBeC
n7809H7FuopWpa5JhGCTyRQRSCv9IXvtJd6oH/dZyq5yhypyjtAzDfpRcD6Ut3Wp
Fge3ejxMrwsq13az1+esJSH161qunB6Zsrs1/bx4zwQfJc0a90CAjqQESjLv+dUC
A1KMqQJg19+OXA5eF2Fs7N1UwFLrVsI=
-----END CERTIFICATE-----
  ''';
  String privateKey = '''
-----BEGIN PRIVATE KEY-----
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
utj3flRQDLaDAl91lySpAjUp9aM8
-----END PRIVATE KEY-----
    ''';

  String? jwtRsaPubKey;

  String? jwtRsaPrivKey;

  // currently not in use...
  String? jwtSharedSecretKey = "config-secret-passphrase";

  // ---------------------------------------------------------------------------
  // Server self-login (server-as-principal)
  //
  // A deployed server is itself a principal: it logs in against the auth server
  // with a service credential and the token it gets back carries *this
  // deployment's* feature grants, which cap every user's grants (the
  // `min(user, server)` meet in `TomAccessControl`). These fields say who the
  // deployment is and where it presents that identity.
  //
  // All of them are optional and default to `null`. A deployment that leaves
  // them unset never logs itself in and runs uncapped — exactly as every server
  // built before server-as-principal existed. See
  // `authentication/server_self_login.dart`.
  // ---------------------------------------------------------------------------

  /// Absolute URI of the auth server's login endpoint, e.g.
  /// `https://auth.example.com/auth/login`.
  ///
  /// Not secret, but deployment-specific: it belongs in the deployed config
  /// tree / environment, not in a spec (`codespecs_mapping.md` §5.16, CE-CF).
  /// `null` or blank disables server self-login.
  String? authServerLoginUri;

  /// The login name of this deployment's service account.
  ///
  /// `null` or blank disables server self-login.
  String? serviceAccountName;

  /// The service account's secret — **secret-bearing** per
  /// `codespecs_mapping.md` §5.16.
  ///
  /// Its *declaration* lives here (so the shape and the source key are known);
  /// its **value is never authored**. It is supplied out-of-band at deploy time
  /// through the ordinary CE-CF precedence chain — OS environment, `.env`, or
  /// command line — and must never be written into a spec or a checked-in
  /// configuration tree, the same rule that governs [privateKey] and the JWT
  /// keys above.
  ///
  /// `null` or blank disables server self-login.
  String? serviceAccountCredential;

  /// Organization presented with the deployment's own login; `null` for a
  /// single-tenant deployment.
  String? serviceAccountOrganization;

  /// Application the deployment logs into; `null` when the auth server does not
  /// scope service logins by application.
  String? serviceAccountApplication;

  /// Process (sub-context of [serviceAccountApplication]) the deployment logs
  /// into; `null` when unscoped.
  String? serviceAccountProcess;

  /// Client identifier the deployment's own login originates from; `null` when
  /// the auth server does not scope service logins by client.
  String? serviceAccountClient;

  // ---------------------------------------------------------------------------
  // Outbound mail (SMTP)
  //
  // The declarations behind `TomSmtpSettings.fromConfiguration`. Every field is
  // optional: [smtpHost] unset is how a deployment says "this server does not
  // send mail", and the messaging module answers it by registering a no-op
  // transport rather than failing to start. That default matters — a test run,
  // a local build and a CI job all want a server that composes messages and
  // never delivers them.
  //
  // See `messaging/smtp_transport.dart` and `doc/messaging.md`.
  // ---------------------------------------------------------------------------

  /// The mail server's host name; `null` or blank means this deployment sends
  /// no mail.
  ///
  /// Deployment-specific but not secret, like [authServerLoginUri]
  /// (`codespecs_mapping.md` §5.16, CE-CF).
  String? smtpHost;

  /// The mail server's port. `0` is the "unconfigured" sentinel — the same
  /// convention as [port] — and lets the transport pick the default that goes
  /// with [smtpSecurity] (25, 587 or 465) rather than forcing every deployment
  /// to restate a number the protocol already implies.
  int smtpPort = 0;

  /// How the connection is secured: `none`, `startTls` or `implicitTls`.
  ///
  /// Defaults to `startTls`, which is both the common case on port 587 and the
  /// safe one: an unrecognised value falls back to it too, because failing
  /// *closed* on a typo is the only acceptable direction for a setting that
  /// decides whether a password crosses the network in the clear.
  String smtpSecurity = 'startTls';

  /// The login name presented to the mail server; `null` or blank for an
  /// unauthenticated relay.
  String? smtpUsername;

  /// The mail server password — **secret-bearing** per
  /// `codespecs_mapping.md` §5.16.
  ///
  /// Its *declaration* lives here (so the shape and the source key are known);
  /// its **value is never authored**. It is supplied out-of-band at deploy time
  /// through the ordinary CE-CF precedence chain — OS environment, `.env`, or
  /// command line — and must never be written into a spec or a checked-in
  /// configuration tree, the same rule that governs [serviceAccountCredential],
  /// [privateKey] and the JWT keys above.
  ///
  /// Supplying [smtpUsername] without this value is rejected when the settings
  /// are built, so the omission surfaces at startup naming the setting rather
  /// than as a `535` on the first notification.
  String? smtpPassword;

  /// The address mail is sent from when a message does not name its own.
  ///
  /// Most relays require the envelope sender to be an address they are
  /// authorised to send for, so this is effectively mandatory for any
  /// deployment that actually sends.
  String? smtpFromAddress;

  /// The display name shown beside [smtpFromAddress]; `null` to send the bare
  /// address.
  String? smtpFromName;

  /// The name announced in `EHLO`.
  ///
  /// Some relays check that it resolves. `localhost` is accepted by most and is
  /// the honest answer for a server that has no public name.
  String smtpClientName = 'localhost';

  /// Whether to accept a mail server certificate that does not validate.
  ///
  /// `false`, and it should stay that way in any deployment. It exists because
  /// self-signed certificates are common on internal relays, and a developer
  /// who cannot turn this on will set [smtpSecurity] to `none` instead — which
  /// is strictly worse, since it sends [smtpPassword] in the clear.
  bool smtpAllowInsecureCertificate = false;

  // ---------------------------------------------------------------------------
  // Outbound SMS (HTTP gateway)
  //
  // The declarations behind `TomSmsGatewaySettings.fromConfiguration`, and the
  // same bargain the SMTP block above strikes: [smsEndpoint] unset is how a
  // deployment says "this server sends no SMS", answered with a no-op transport
  // rather than a boot failure.
  //
  // Unlike SMTP there is no protocol here — every gateway is an HTTP API of its
  // own invention. These settings carry only what all of them need (where, with
  // which credential, as whom); the field names, body format and error codes of
  // a particular vendor live in a `TomSmsGatewayProtocol`, which is code the
  // deployment supplies rather than configuration.
  //
  // See `messaging/sms_transport.dart` and `doc/messaging.md`.
  // ---------------------------------------------------------------------------

  /// The gateway's submit URL; `null` or blank means this deployment sends no
  /// SMS.
  ///
  /// Deployment-specific but not secret, like [smtpHost]
  /// (`codespecs_mapping.md` §5.16, CE-CF). Must be `http` or `https`; anything
  /// else is rejected when the settings are built, so a typo surfaces at
  /// startup rather than as an unroutable request at 03:00.
  String? smsEndpoint;

  /// The gateway credential — **secret-bearing** per
  /// `codespecs_mapping.md` §5.16.
  ///
  /// Its *declaration* lives here; its **value is never authored**. Supplied
  /// out-of-band at deploy time through the ordinary CE-CF precedence chain,
  /// exactly as [smtpPassword] is.
  String? smsApiKey;

  /// The second half of a two-part gateway credential — **secret-bearing**.
  ///
  /// Required only by [smsAuthScheme] `basic`, where [smsApiKey] is the user
  /// and this is the password. Gateways that authenticate with a single bearer
  /// token leave it unset.
  String? smsApiSecret;

  /// The sender shown to the recipient — a short code, a long number, or an
  /// alphanumeric sender id where the destination country permits one.
  ///
  /// A message may override it through [TomMessage.metadata]; this is the
  /// default for the ones that do not.
  String? smsSenderId;

  /// How the credential is presented: `none`, `bearer` or `basic`.
  ///
  /// Defaults to `bearer`, and an unrecognised value falls back to it. That
  /// fallback is safe in a way [smtpSecurity]'s is not — the worst outcome is a
  /// `401` from the gateway, not a credential sent in the clear — but it is
  /// still the setting to check first when a gateway rejects every request.
  ///
  /// Gateways that want the key *in the payload* rather than in a header use
  /// `none` here and name the field on the protocol.
  String smsAuthScheme = 'bearer';

  /// How long to wait for the gateway before treating the attempt as deferred.
  ///
  /// A timeout is transient: the message may well have been accepted, and the
  /// only honest answer is to retry and let the message id deduplicate.
  int smsTimeoutSeconds = 30;

  /// The most segments a single message may occupy, or `0` for no cap.
  ///
  /// Three is roughly a paragraph. The cap exists because segmentation is
  /// invisible at composition time — a template that gains one sentence, or a
  /// parameter that arrives with an umlaut in it, can quietly triple the cost
  /// of every message the deployment sends. Over the cap fails *permanently*
  /// at send: a message too long now is too long on the retry.
  int smsMaxSegments = 3;

  /// The bind host. Empty (the default) makes [TomServer.start] listen on
  /// [InternetAddress.anyIPv4]; set a concrete host to bind a specific address.
  /// The default must stay a genuine address or the empty string; a
  /// placeholder such as `"t"` or `"0"` binds nothing.
  String host = "";

  int isolateCount = 10;

  Middleware? authenticationMiddleware;

  Response? Function(Request, Object, StackTrace)? errorHandler;

  Response? Function(Request, Object, StackTrace)? authenticationErrorHandler;

  Handler? preExecutionHandler;

  Handler? postExecutionHandler;

  Middleware loggingMiddleware = tomLoggingMiddleware();
  /*
  logRequests( logger:
      (String s, bool error) => error ? tomLog.error(s) : tomLog.info(s)
  );
   */

  bool isolateLogging = true;

  String logLevelExceptions = "";

  String logLevel = "";

  String databaseMigrationsDirectory = "./database_migrations";

  /// Builds the merged value map used to populate a configuration instance.
  ///
  /// Starts from a **deep copy** of the active provider's
  /// [TomServerConfigResourceProvider.resources] and overlays, in increasing
  /// precedence: the OS environment, a `.env` file (`./.env`), then the parsed
  /// [args]. Command-line arguments therefore win. The copy is essential: the
  /// merges below mutate their first argument in place, so merging into the
  /// provider's own `resources` would permanently inject the environment, the
  /// `.env` file and the CLI args into the process-wide provider.
  /// [deepCopyJsonTree] is the kernel's primitive for exactly this; a shallow
  /// `Map.from` would leave every nested subtree shared and defeat the copy.
  static Map<String, Object?> getDefaultValues(List<String> args) {
    Map<String, Object?> values = deepCopyJsonTree(
      TomServerConfigResourceProvider.getServerConfig().resources,
    );
    mergeMapsOneSided(values, TomArgs.convertToObjectMap(Platform.environment));
    mergeMapsOneSided(values, TomEnvFile.read());
    mergeMapsOneSided(values, TomArgs.parseArgsToMap(args));
    return values;
  }

  /// Assigns the merged configuration [values] onto this instance.
  ///
  /// Implemented by the generated reflection for the concrete subclass; each
  /// known field is set from the matching key in [values].
  void setValues(Map<String, Object?> values);

  /// Creates the configuration, resolving and applying values from all sources
  /// (see [getDefaultValues]) for the given [args].
  ///
  /// [args] is assigned to the field of the same name **after** [setValues], so
  /// the record of the invocation survives a merged key that happens to be
  /// spelled `args`. Both are last for a reason: [setValues] runs first because
  /// a subclass's constructor body must see the resolved fields, and the `args`
  /// assignment runs after it because the invocation is the meaning this field
  /// promises.
  TomBaseServerConfiguration(List<String> args) {
    setValues(getDefaultValues(args));
    this.args = args;
  }
}
