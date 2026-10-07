import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../cmdline/args.dart';
import '../cmdline/env_file.dart';
import '../server/server.dart';
import 'tom_config.dart';

/// Holds the resolved configuration tree and answers property lookups for
/// [TomConfig].
///
/// A single provider is shared process-wide through [getServerConfig]; install
/// a populated one at startup with [setServerConfigProvider] or by setting the
/// static [loader]. Keys may be dotted paths into the nested [resources] map
/// (resolved via the kernel's tree walker).
///
/// A dotted key is tried as a **path first** and as a literal top-level key
/// only if the walk fails, so `server.port` reads the same value whether it was
/// written nested under `server:` or flat as `server.port:`. Where a tree
/// carries *both*, the path wins and the flat key is unreachable — never
/// merged and never reported. Use one spelling per key.
class TomServerConfigResourceProvider {
  static TomServerConfigResourceProvider? _configProvider;

  /// Optional factory for the default provider's [resources]. When set, it is
  /// invoked the first time [getServerConfig] lazily creates a provider.
  ///
  /// It is reachable **only before a provider exists**. The call is in the
  /// default constructor, which [getServerConfig] runs on its *creating*
  /// access, so once [setServerConfigProvider] has installed anything this hook
  /// can never fire — setting it afterwards is silently inert. Use
  /// [TomServerConfigResourceProvider.load] from that point on; it defers the
  /// same build, scoped to one provider instead of standing as a process-wide
  /// default.
  static Map<String, dynamic> Function()? loader;

  /// Installs [provider] as the process-wide configuration source.
  static void setServerConfigProvider(
    TomServerConfigResourceProvider provider,
  ) {
    _configProvider = provider;
  }

  /// Returns the active provider, creating a default one (using [loader] if
  /// set) on first access.
  ///
  /// The provider created here when [loader] is unset is a **placeholder**: it
  /// holds nothing, and nobody asked for it. It is returned rather than
  /// refused, so a direct `exists`/`get` still answers, but it is marked (see
  /// [isUnconfiguredPlaceholder]) and [TomConfig] refuses to resolve against
  /// it — a property that resolves before its configuration exists is the
  /// ordering mistake, and taking the placeholder's answer hides it.
  static TomServerConfigResourceProvider getServerConfig() {
    if (_configProvider == null) {
      final created = TomServerConfigResourceProvider();
      // Only when nothing filled it. A `loader` was set *on purpose* and the
      // provider it builds is as configured as an installed one — that is the
      // documented lazy path, not the mistake.
      created._isUnconfiguredPlaceholder = loader == null;
      _configProvider = created;
    }
    return _configProvider!;
  }

  /// Whether this provider is the placeholder [getServerConfig] creates when
  /// nothing has been installed and no [loader] was set.
  ///
  /// True of exactly one object: the one built because a caller asked for the
  /// active provider before anything supplied it. A provider passed to
  /// [setServerConfigProvider], built by [loader], or constructed directly is
  /// false however empty its [resources] are — an empty tree installed on
  /// purpose is a statement, and the distinction this flag carries is between
  /// *configured as nothing* and *not configured yet*, which is the same
  /// distinction [exists] draws one level down.
  ///
  /// [TomConfig] reads it and refuses; nothing else does. A caller reading the
  /// provider directly is unaffected, because it gets an answer it can judge —
  /// `exists` is false for every key, which is true.
  bool get isUnconfiguredPlaceholder => _isUnconfiguredPlaceholder;
  bool _isUnconfiguredPlaceholder = false;

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
  /// **Gate on [exists] first.** This method is total — it never throws, and it
  /// never answers `null` for a key the tree does not hold — so it cannot, by
  /// itself, report a key nobody configured. An unknown key resolves to the key
  /// string [s]; [exists] is what separates that from a value. [TomConfig]
  /// gates, and a caller reading through it inherits the gate.
  ///
  /// That is the contract rather than a gap, and the reason is the pair of
  /// answers it keeps apart. `null` means the property is present and
  /// explicitly **cleared**; the key string means **unknown**. Answering `null`
  /// for both would collapse them, and the distinction is the one [exists] was
  /// built to preserve: a cleared setting is configured, and [TomConfig] must
  /// see it as configured so it does not substitute the default the operator
  /// was overriding. Throwing instead would cost the other half — a read that
  /// cannot fail is what lets a caller walk a tree of optional settings without
  /// a `try` at every step.
  ///
  /// The fallback is *indistinguishable from a configured value that equals its
  /// own key*, which is the price and is why the gate is [exists] rather than a
  /// test on the value. The cost of forgetting it is the one this API cannot
  /// remove: a missing `host` reads back as the host name `host`, and the
  /// failure surfaces at connect time rather than at lookup. Every read in this
  /// package is gated, and `configuration_test.dart` fails on one that is not.
  Object? get(String s) {
    try {
      return getObjectFromTree(resources, s);
    } catch (ex) {
      // fall through
    }
    return resources.containsKey(s) ? resources[s] : s;
  }
}

/// The configuration this isolate most recently built, or `null` before it has
/// built one. Registered by [TomBaseServerConfiguration]'s constructor and read
/// only by [tomAppId].
TomBaseServerConfiguration? _activeConfiguration;

/// The process-wide application id: the [TomBaseServerConfiguration.appId] of
/// the configuration this isolate built, or `""` before it has built one.
///
/// Read it wherever a message has to say *which application* produced it. The
/// access line of [tomLoggingMiddleware] is the library's own use, and the
/// motivating one: several servers of one deployment collected into one place
/// are otherwise indistinguishable.
///
/// It is a **getter over the active configuration**, not a variable, and both
/// halves of that are deliberate.
///
/// Resolving the field on each read rather than copying it at some instant is
/// what makes it correct. A configuration is named in its *subclass*
/// constructor body (`appId = 'auth';`), which runs after the base constructor
/// — so any copy taken while the base constructor is still running captures the
/// merged value, which for an application that names itself in code is the
/// empty string. Every server in this workspace published `tomAppId = appId`
/// from inside its `setValues` override, and every one of them published `""`.
/// A read-at-use getter cannot be early.
///
/// Having no setter is what keeps it that way: an application states its name
/// once, as configuration, in the [TomBaseServerConfiguration.appId] field that
/// the merge can also supply. There is no second place to say it and therefore
/// no second answer.
///
/// Globals are per-isolate, and a server builds its configuration in the
/// isolate that serves with it, so this reports that isolate's application.
String get tomAppId => _activeConfiguration?.appId ?? "";

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
/// The JWT fields ([jwtRsaPubKey] / [jwtRsaPrivKey] / [jwtSharedSecretKey]) are
/// the server's signing key material, read by [installJwtSigning] — which a
/// boot calls once, after the runtime environment is selected and before
/// anything mints or verifies a token. A field left null falls back to the
/// framework's bundled sample key, which is permitted in a development or test
/// environment and refused anywhere else. The rest of a signing configuration —
/// algorithm, issuer, audience, expiry — is supplied in code, because there are
/// no configuration keys for those.
@tomReflector
abstract class TomBaseServerConfiguration {
  /// The application's own name — what this server calls itself in a log, a
  /// diagnostic, or anywhere else several servers meet.
  ///
  /// It is an ordinary configuration key, so the merge can supply it (`appId`
  /// in a resource file, the environment, `.env`, or `appId=…` on the command
  /// line). A server that has a fixed name states it in its constructor body
  /// instead, and one that wants both states it the way [port] does, so the
  /// configured value wins:
  ///
  /// ```dart
  /// MyConfiguration(super.args) {
  ///   if (appId.isEmpty) appId = 'billing';
  /// }
  /// ```
  ///
  /// Whichever way it is set, [tomAppId] reports it process-wide; nothing else
  /// needs to publish it.
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

  /// The `Server` response header. Empty (the default) sends none.
  ///
  /// Applied to the bound [HttpServer] after it is listening, so it names the
  /// *deployment*, not a route. An empty string is the "say nothing" value
  /// rather than a header with no value: [TomServer.start] translates it to
  /// `null`, which is what leaves the header off the wire. Naming the product
  /// and version here tells every client — and every scanner — what is running,
  /// so a deployment that would rather not say leaves this as it is.
  String serverHeader = "";

  /// Whether the bound [HttpServer] compresses responses it judges
  /// compressible.
  ///
  /// `true` by default, and only ever turned *on* by [TomServer.start] — the
  /// flag gates an assignment, so setting this `false` leaves the socket at
  /// Dart's own default rather than actively disabling compression. Turn it off
  /// where a proxy in front of the server already compresses, or where response
  /// bodies are encrypted or already compressed and the pass would only cost
  /// CPU.
  bool autoCompress = true;

  /// The `X-Powered-By` response header. Defaults to `"tom"`; empty sends none.
  ///
  /// Passed to `shelf_io.serve`, so unlike [serverHeader] it is fixed when the
  /// socket is bound. Empty is again the "say nothing" value, translated to
  /// `null` before the bind.
  String poweredByHeader = "tom";

  /// Whether to bind a plain HTTP socket instead of a TLS one.
  ///
  /// `false` by default, which is the safe direction: a deployment gets TLS
  /// unless it asks not to. When `true`, [TomServer.start] builds no
  /// [SecurityContext] at all and [certificateChain] / [privateKey] are never
  /// read — which is the supported way to run behind a TLS-terminating proxy,
  /// and the only honest way to run without a certificate. Reading
  /// [TomServer.securityContext] afterwards reports what was *built*; this
  /// field reports what was asked for.
  bool noSsl = false;

  /// Whether to bind every interface, overriding [host].
  ///
  /// Read *after* [host], so `true` wins: [TomServer.start] resolves the listen
  /// address from [host] (or [InternetAddress.anyIPv4] when it is empty) and
  /// then replaces it with `anyIPv4` if this is set. So it is not "also listen
  /// on any IP" — it is "ignore whatever host was configured", which is the
  /// setting a container image wants when the host it inherited from a
  /// configuration file names an address that does not exist inside the
  /// container.
  bool listenToAnyIp = false;

  /// HTTP bind port. `0` is the "unconfigured" sentinel: [setValues] (config /
  /// env / `port=`) overwrites it when a port is supplied, otherwise a
  /// subclass constructor — which runs *after* the base constructor's
  /// [setValues] call — applies its own default via `if (port == 0) port = …`.
  /// A literal default here (e.g. `8080`) would defeat that guard, since the
  /// field would never be `0` for the subclass to detect "no port configured".
  ///
  /// Either command-line spelling reaches it: a key is the argument text before
  /// the first `=` with its leading dashes stripped, so `port=8080` and
  /// `--port=8080` are one argument naming this field (see `doc/cmdline.md`).
  int port = 0;

  /// The PEM certificate chain [certificateChain] defaults to: a throwaway
  /// self-signed `localhost` pair committed to this repository.
  ///
  /// Named rather than written inline so that [usesDevelopmentTlsMaterial]
  /// compares against the very text the field defaults to. A fingerprint or a
  /// copy would be a second statement of the same value, and the check would
  /// go quiet the day the two drifted apart.
  static const String developmentCertificateChain = '''
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

  /// The PEM private key [privateKey] defaults to, and the reason
  /// [usesDevelopmentTlsMaterial] exists: **it is published**, in this
  /// repository, so a server serving it authenticates itself with a key
  /// anyone can read.
  static const String developmentPrivateKey = '''
-----BEGIN PRIVATE KEY-----
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
utj3flRQDLaDAl91lySpAjUp9aM8
-----END PRIVATE KEY-----
''';

  /// The PEM-encoded TLS certificate chain [TomServer.start] binds with, unless
  /// [noSsl] is set.
  ///
  /// **The default is a throwaway self-signed `localhost` pair committed to
  /// this repository, and its private key is public.** It exists so a
  /// development machine can speak HTTPS without a certificate authority.
  /// Nothing refuses to start when a deployment leaves it in place, so
  /// overriding this and [privateKey] together is the deployment's
  /// responsibility — a server still serving this chain in production is
  /// authenticating itself with a key anyone can read.
  ///
  /// Supplied as PEM text rather than a path, which is what lets a container
  /// inject it through the environment; the bytes are handed to
  /// [SecurityContext.useCertificateChainBytes] unparsed, so a malformed value
  /// fails at bind time and not before.
  String certificateChain = developmentCertificateChain;

  /// The PEM-encoded TLS private key for [certificateChain]. **A credential:**
  /// handle it exactly as the marked settings below are handled.
  ///
  /// The default is the private half of the checked-in self-signed pair and is
  /// therefore public. See [certificateChain]: the two are overridden together
  /// or not at all, since a chain without its matching key binds nothing.
  ///
  /// Never log this field, and never log [args], which may carry it. The bytes
  /// are handed to [SecurityContext.usePrivateKeyBytes] unparsed.
  ///
  /// It carries a different wording from the marked settings on purpose. That
  /// marker is a controlled one: `doc/configuration.md` tabulates the four
  /// out-of-band blocks a deployment supplies — JWT signing, server self-login,
  /// outbound mail, outbound SMS — and a test holds the marked fields and that
  /// table to each other, so a field marked without a row there fails. TLS
  /// material has no row: it is documented by the limitation naming the
  /// checked-in pair. The difference is about which document owes a row, not
  /// about how carefully this value is handled.
  String privateKey = developmentPrivateKey;

  /// Whether either half of the TLS material is still the checked-in
  /// development pair.
  ///
  /// **Either half, not both**, because the two halves fail differently and
  /// both are worth hearing about. A default [privateKey] means the server
  /// authenticates itself with a key published in this repository, which is the
  /// danger this getter exists for. A default [certificateChain] beside an
  /// overridden key is a different fault with the same remedy: the pair does
  /// not match, so the socket fails to bind — and saying so before the bind is
  /// cheaper than reading the error afterwards.
  ///
  /// Compared against [developmentCertificateChain] and
  /// [developmentPrivateKey], which are the very constants the fields default
  /// to, so the check cannot drift from what it checks.
  ///
  /// It says nothing about whether TLS is *served* — [noSsl] answers that, and
  /// a plaintext server carrying the default pair is not doing anything wrong.
  /// [TomServer.warnOnDevelopmentTlsMaterial] puts the two questions together.
  /// A method rather than a getter, and on this class that is a distinction
  /// the documentation rests on: the `Properties` table of
  /// `api_summary_configuration.md` is the list of **knobs a deployment sets**,
  /// held to the class's fields by a census, and a computed answer standing
  /// among them would blur the two.
  bool usesDevelopmentTlsMaterial() =>
      certificateChain == developmentCertificateChain ||
      privateKey == developmentPrivateKey;

  /// PEM of the RSA public key that encrypts the payload section of an issued
  /// token; read by [installJwtSigning].
  ///
  /// Null means "not configured", and every one of the three JWT fields means
  /// that by being null rather than by holding a sentinel: a default that
  /// looked like a key could not be told apart from a key, which is how a
  /// server came to sign with a published passphrase and report nothing.
  ///
  /// Environment name: `JWT_RSA_PUB_KEY` (see [getDefaultValues]).
  String? jwtRsaPubKey;

  /// PEM of the RSA private key that decrypts the payload section; the
  /// counterpart of [jwtRsaPubKey] and secret-bearing.
  ///
  /// Environment name: `JWT_RSA_PRIV_KEY`.
  String? jwtRsaPrivKey;

  /// Passphrase of the HMAC key that *signs* an issued token, and the one
  /// setting two servers must agree on to trust each other's tokens.
  ///
  /// The auth server that issues and the application server that verifies share
  /// this value and nothing else; set it in one only and the second rejects the
  /// first's tokens. Secret-bearing: whoever holds it can mint a token this
  /// deployment accepts.
  ///
  /// Environment name: `JWT_SHARED_SECRET_KEY`.
  String? jwtSharedSecretKey;

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
  /// tree / environment, not in a spec
  /// (`tom_core_codespecs/doc/codespecs_mapping.md` §5.16, CE-CF). `null` or
  /// blank disables server self-login.
  String? authServerLoginUri;

  /// The login name of this deployment's service account.
  ///
  /// `null` or blank disables server self-login.
  String? serviceAccountName;

  /// The service account's secret — **secret-bearing** per
  /// `tom_core_codespecs/doc/codespecs_mapping.md` §5.16.
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
  /// (`tom_core_codespecs/doc/codespecs_mapping.md` §5.16, CE-CF).
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
  /// `tom_core_codespecs/doc/codespecs_mapping.md` §5.16.
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
  /// (`tom_core_codespecs/doc/codespecs_mapping.md` §5.16, CE-CF). Must be
  /// `http` or `https`; anything else is rejected when the settings are built,
  /// so a typo surfaces at startup rather than as an unroutable request at
  /// 03:00.
  String? smsEndpoint;

  /// The gateway credential — **secret-bearing** per
  /// `tom_core_codespecs/doc/codespecs_mapping.md` §5.16.
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

  /// How many worker isolates the deployment runs. Defaults to `10`.
  ///
  /// The framework reads it for one decision only: a count above `1` binds the
  /// socket with `shared: true`, so several isolates can accept on the same
  /// port. Actually *starting* the isolates is the application's boot step —
  /// `TomWorkerPool.withSize(configuration.isolateCount, …)` — which is why a
  /// deployment that raises this without also sizing its pool from it gets a
  /// shared socket and one listener.
  ///
  /// `0` is meaningful: a boot that reads it takes it as "no pool, serve from
  /// the main isolate", and the socket is then bound unshared.
  int isolateCount = 10;

  /// Replaces the authentication layer of [TomServer.start]'s pipeline.
  ///
  /// `null` (the default) installs [tomDefaultAuthenticationMiddleware], which
  /// is what reads the bearer token and publishes the principal into the
  /// request zone. A replacement takes over that whole responsibility:
  /// everything downstream — authorization, delegation, audit attribution —
  /// reads the principal this layer established, so a middleware that
  /// publishes none leaves the pipeline running as nobody rather than failing.
  ///
  /// Supply one to authenticate against something this package does not model.
  /// Wrapping rather than replacing is usually what is wanted, and shelf's
  /// `Middleware` composes, so a custom layer can call the default and add to
  /// what it produced.
  Middleware? authenticationMiddleware;

  /// Replaces the server's default error response.
  ///
  /// `null` (the default) leaves [TomServer.errorHandler] in place, which
  /// renders [tomErrorEnvelope] as a 500 with `x-tom-error: true` and a JSON
  /// content type. Installed at **two** pipeline layers — the inner one below
  /// authentication, and the outer one when
  /// [authenticationErrorHandler] is `null` — so a single handler here covers
  /// both unless the two are separated deliberately.
  ///
  /// Returning `null` from the handler rethrows the original error rather than
  /// answering, which is the way to handle some failures and leave the rest to
  /// shelf. The error and its stack trace are already logged before the handler
  /// is called, so a handler that only wants to log has nothing to add.
  ///
  /// **A handler that puts a message in its body must read it through
  /// `TomServerException.clientMessage`,** not from `defaultUserMessage`. The
  /// `clientThrow` flag is the thrower's statement about its own text, and five
  /// types in the package set it `false` because their messages describe server
  /// internals — an unreachable data source, a failed audit write, a
  /// misconfigured identity provider. The default handler is safe by
  /// construction because [tomErrorEnvelope] carries no message at all; a
  /// handler that adds one takes the obligation on.
  Response? Function(Request, Object, StackTrace)? errorHandler;

  /// Replaces the error response for failures raised *at or above* the
  /// authentication layer.
  ///
  /// Falls back to [errorHandler] when `null`, which is the default, so the two
  /// differ only where a deployment wants them to. Separating them is worth it
  /// when an authentication failure should answer differently from an
  /// application one — a `401` with a `WWW-Authenticate` challenge rather than
  /// the `500` envelope, say — since this layer sits outside the authentication
  /// middleware and therefore sees what it throws.
  Response? Function(Request, Object, StackTrace)? authenticationErrorHandler;

  /// A handler offered the request *before* the router, in a shelf [Cascade].
  ///
  /// `null` (the default) leaves the router alone. A cascade tries each handler
  /// in turn and takes the first response that is not a 404, so this one
  /// **answers or steps aside**: return a response to serve it, or a 404 to let
  /// the router handle the request as usual. It is not middleware — it cannot
  /// see or alter what the router returns, and it runs inside the pipeline, so
  /// the principal and the request context are already established.
  ///
  /// Serving a fixed asset or a redirect that must not reach the router is the
  /// case for it.
  Handler? preExecutionHandler;

  /// A handler offered the request *after* the router, in the same [Cascade].
  ///
  /// Reached only when the router answers 404, which is what "after" means
  /// here: it is a fallback, not a post-processing step, and it never sees the
  /// router's response. Use it for a catch-all — a single-page-application
  /// index, a custom not-found body — and use [loggingMiddleware] or a
  /// [Middleware] of your own when the response itself has to be inspected or
  /// changed.
  Handler? postExecutionHandler;

  /// The middleware that emits the per-request access-log line.
  ///
  /// Installed as the innermost layer of [TomServer.start]'s pipeline, so it
  /// sees the response the router produced. The default,
  /// [tomLoggingMiddleware], emits one line per request but only when the
  /// request's [TomRequestLogInfo.shouldBeLogged] is set and it has not already
  /// been logged.
  ///
  /// Shelf's own `logRequests()` is the obvious alternative and drops in
  /// unchanged — it is a `Middleware` of the same shape and adds request
  /// timing, which the default does not report:
  ///
  /// ```dart
  /// loggingMiddleware = logRequests(
  ///   logger: (String s, bool error) =>
  ///       error ? tomLog.error(s) : tomLog.info(s),
  /// );
  /// ```
  ///
  /// It is **not** the default because it reads nothing from the request
  /// context, so it can honour neither guard. The consequential one is
  /// `shouldBeLogged`: the endpoint pipeline copies each endpoint's
  /// `logRequests` flag onto it, which is how `TomHealthService` keeps a
  /// `/health` probe arriving every few seconds out of the log. Substituting
  /// shelf's middleware silently re-enables the line for every endpoint that
  /// opted out. `hasBeenLogged` likewise stops being honoured, so a retried or
  /// re-entered request logs once per pass.
  ///
  /// It also logs the *error* path, which this layer deliberately does not: it
  /// sits inside `_handleError`, which already logs the error and its stack
  /// trace, so shelf's middleware reports every failed request twice.
  ///
  /// Choose it when timing matters more than the opt-out — a load test, or a
  /// deployment with no suppressed endpoints — and expect health-probe noise
  /// and doubled error reports.
  Middleware loggingMiddleware = tomLoggingMiddleware();

  /// Whether the deployment moves logging into an isolate of its own.
  ///
  /// Read by the application's boot, not by the framework: the step it gates is
  /// `TomIsolateLogging.startIsolatedLogging`, which a `main` calls once in the
  /// main isolate. Declared here so it arrives through the same merge as every
  /// other setting rather than being read from the environment by hand.
  ///
  /// `true` by default. Isolated logging keeps formatting and writing off the
  /// request path, which matters most for a worker pool, where every isolate
  /// would otherwise write to the same sink; the cost is that a log line is
  /// posted to another isolate, so a process that dies abruptly can lose the
  /// last of them.
  bool isolateLogging = true;

  /// Per-logger log-level overrides, as `name1=level1,name2=level2`.
  ///
  /// **Not a level for exceptions.** It is the pattern
  /// `TomLogger.setLogLevelExceptions` parses, where each entry raises or lowers
  /// the level for one logger *name* against the global [logLevel] — the
  /// "exception" is to the global setting, not an error. `MyClass=DEBUG` turns
  /// one class up while the rest of the deployment stays at `INFO`.
  ///
  /// Empty (the default) sets no override. An unparseable pattern is logged and
  /// otherwise ignored, so a typo here loses the overrides silently rather than
  /// stopping the boot. Applied by the application's boot alongside [logLevel];
  /// the framework only carries the value.
  String logLevelExceptions = "";

  /// The global log level, by name: `TRACE`, `DEBUG`, `TRAFFIC`, `INFO`,
  /// `WARN`, `STATUS`, `ERROR`, `SEVERE`, `FATAL`, or one of the aggregate
  /// names (`ALL`, `DEVELOPMENT`, `EXTENDED`, `ERRORS`, `PRODUCTION`, `STILL`,
  /// `SILENT`, `OFF`).
  ///
  /// Empty (the default) leaves the logger at whatever it already had, so a
  /// deployment that says nothing does not get silence. An unrecognised name is
  /// reported as an error and the level is left alone.
  ///
  /// Applied by the application's boot — `tomLog.setLogLevelByName(...)` — and
  /// not by the framework, which is why it takes effect at the point that call
  /// is reached: everything logged earlier in the boot, this class's own merge
  /// included, is emitted at the previous level.
  ///
  /// Environment name: `LOG_LEVEL` (see [getDefaultValues]).
  String logLevel = "";

  /// The directory `TomDbMigrations.migrateDatabases` reads, relative to the
  /// working directory unless absolute.
  ///
  /// Defaults to `./database_migrations`, which is where every sample keeps
  /// them — and since the path is relative, a server started from anywhere but
  /// its package root finds no migrations rather than failing to find the
  /// directory. Migration is the application's boot step, so nothing in the
  /// framework reads this; it is declared here so the path is configurable per
  /// deployment through the same merge as the rest.
  ///
  /// The directory holds one subdirectory per datasource name, which is what
  /// ties a migration set to the datasource key it belongs to.
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
  ///
  /// ## Environment names
  ///
  /// Both environment sources pass through [TomArgs.resolveEnvironmentNames],
  /// so a variable written `SCREAMING_SNAKE_CASE` also arrives under the
  /// `lowerCamelCase` field name it spells: `JWT_SHARED_SECRET_KEY` sets
  /// [jwtSharedSecretKey], `LOG_LEVEL` sets [logLevel], `PORT` sets [port].
  /// The verbatim key is kept as well, and a variable already spelled as the
  /// field wins over its screaming twin.
  ///
  /// Resolution happens **per source**, not on the merged result, so a resolved
  /// name inherits the precedence of the source it came from — a `PORT` in the
  /// OS environment still loses to a `port=` argument.
  ///
  /// The command line is deliberately left out of it. An argument names its
  /// field directly — `port=9081`, or `--port=9081`, since `TomArgs` strips a
  /// key's leading dashes (see `doc/cmdline.md`) — so there is no naming
  /// convention to reconcile, and accepting a `SCREAMING_SNAKE_CASE` argument
  /// as well would widen the surface without gaining a source.
  static Map<String, Object?> getDefaultValues(List<String> args) {
    Map<String, Object?> values = deepCopyJsonTree(
      TomServerConfigResourceProvider.getServerConfig().resources,
    );
    mergeMapsOneSided(
      values,
      TomArgs.resolveEnvironmentNames(
        TomArgs.convertToObjectMap(Platform.environment),
      ),
    );
    mergeMapsOneSided(
      values,
      TomArgs.resolveEnvironmentNames(TomEnvFile.read()),
    );
    mergeMapsOneSided(values, TomArgs.parseArgsToMap(args));
    return values;
  }

  /// Assigns the merged configuration [values] onto this instance.
  ///
  /// Implemented by the generated reflection for the concrete subclass; each
  /// known field is set from the matching key in [values].
  ///
  /// **Implement it with the shared `tomReflectionInfo`, not with a
  /// `TomReflectionInfo(strictUnknownFields: true)`.** Strictness turns a key
  /// naming no field into `reflection.set.unknown_field`, which is the right
  /// setting for a map whose two ends are both yours — and [values] is not
  /// that map. [getDefaultValues] merges the entire process environment into
  /// it, in both the `SCREAMING_SNAKE_CASE` spelling and the field spelling
  /// [TomArgs.resolveEnvironmentNames] derives from it, so a configuration
  /// resolved on an ordinary developer machine arrives here carrying `PATH`,
  /// `path`, `HOME`, `home` and eighty or so of their neighbours. A strict
  /// converter would refuse the first of them and no server would start.
  ///
  /// So strictness is asked of the configuration layer alone, before the
  /// environment is merged over it: [settingWarnings] names every key in the
  /// configuration resources that matches no field, which is where a
  /// misspelled setting lives.
  void setValues(Map<String, Object?> values);

  /// Throws when a field marked [TomRequiredField] was supplied by no source.
  ///
  /// Called by the constructor with the map [getDefaultValues] merged, which is
  /// the only place the question can be asked: the answer is "did *any* source
  /// name this setting", and no single source knows. Binding cannot report it —
  /// an unsupplied setting leaves the field at its initialiser, which reads
  /// exactly like a setting nobody required, so the failure would otherwise
  /// surface much later as a connection to `localhost:0` or an empty
  /// application id.
  ///
  /// Nothing on this class carries the annotation, and nothing should: every
  /// field here has a documented default, and a field a constructor falls back
  /// for is not required. An application marks its own:
  ///
  /// ```dart
  /// @tomReflector
  /// class BillingConfiguration extends TomBaseServerConfiguration {
  ///   @TomRequiredField()
  ///   String dbUrl = '';
  ///
  ///   BillingConfiguration(super.args);
  /// }
  /// ```
  ///
  /// Every missing setting is named at once, in declaration order, so a
  /// deployment fixes them in one pass rather than one restart at a time. A key
  /// present with a **null** value counts as missing — a `.env` line `DB_URL=`
  /// names the setting without giving it one — while an explicitly empty
  /// command-line value (`dbUrl=`) counts as supplied. That is the distinction
  /// the conversion table draws deliberately; see
  /// [TomReflectionInfo.missingRequiredFields].
  ///
  /// Public and separate from the constructor so a configuration composed some
  /// other way — a test, a tool that merges its own sources — can ask the same
  /// question of the same map.
  ///
  /// **A configuration with no mirrors is not checked.** The annotation is read
  /// through reflection, so a subclass that implements [setValues] by hand
  /// instead of through the generator has none to read, and this method has
  /// nothing to report rather than a failure to report. That is a supported
  /// shape — a test or a tool composing a configuration without codegen — and
  /// it is the same class of object for which `setValues` was already the
  /// subclass's own affair. A server whose `setValues` is generated is
  /// reflected by construction, so the check is in force wherever the framework
  /// binds the fields.
  void assertRequiredSettings(Map<String, Object?> values) {
    if (!tomReflectionInfo.canReflect(this)) return;
    final missing = tomReflectionInfo.missingRequiredFields(this, values);
    if (missing.isEmpty) return;
    throw TomConfigurationException(
      "configuration.base_configuration.required_settings_missing",
      "No source supplied the required ${missing.length == 1 ? 'setting' : 'settings'} "
          "${missing.join(', ')} for $runtimeType. A resource file, the "
          "environment, a .env file or a command-line argument must name "
          "${missing.length == 1 ? 'it' : 'them'}.",
      parameters: {'missing': missing, 'configuration': '$runtimeType'},
    );
  }

  /// The warnings this configuration owes its operator at startup, given the
  /// merged [values] and the [configurationFile] layer they were merged from
  /// (the configuration resources, before the environment, a `.env` file and
  /// the command line were laid over them).
  ///
  /// At most two, each naming everything it is about at once:
  ///
  /// - **Surplus keys.** Every top-level key of [configurationFile] that names
  ///   no field of this class. Only that layer is checked: the file is the
  ///   deployment's own, while the process environment brings `PATH`, `HOME`
  ///   and dozens more that no configuration declares. A surplus key is not an
  ///   error — the resources are also read by code other than this class
  ///   (`app.title`, say) — but a misspelled setting is one too, and it would
  ///   otherwise be dropped in silence with the field left at its default.
  /// - **Recommended settings no source supplied** — the fields marked
  ///   [TomRecommendedField] that [values] carries no value for. A field
  ///   marked [TomRequiredField] refuses the start instead; see
  ///   [assertRequiredSettings].
  ///
  /// Empty for a configuration with no mirrors, for the reason
  /// [assertRequiredSettings] gives.
  List<String> settingWarnings(
    Map<String, Object?> values,
    Map<String, dynamic> configurationFile,
  ) {
    if (!tomReflectionInfo.canReflect(this)) return const [];
    final warnings = <String>[];
    final surplus = tomReflectionInfo.unknownFields(this, configurationFile);
    if (surplus.isNotEmpty) {
      warnings.add(
        "The configuration resources name ${surplus.length == 1 ? 'a key' : '${surplus.length} keys'} "
        "no field of $runtimeType declares: ${surplus.join(', ')}. "
        "${surplus.length == 1 ? 'It is' : 'They are'} not bound to the "
        "configuration; check the spelling of any that was meant as a setting.",
      );
    }
    final missing = tomReflectionInfo.missingRecommendedFields(this, values);
    if (missing.isNotEmpty) {
      warnings.add(
        "No source supplied the recommended "
        "${missing.length == 1 ? 'setting' : 'settings'} ${missing.join(', ')} "
        "for $runtimeType; ${missing.length == 1 ? 'its default is' : 'their defaults are'} in use.",
      );
    }
    return warnings;
  }

  /// Creates the configuration, resolving and applying values from all sources
  /// (see [getDefaultValues]) for the given [args].
  ///
  /// [args] is assigned to the field of the same name **after** [setValues], so
  /// the record of the invocation survives a merged key that happens to be
  /// spelled `args`. Both are last for a reason: [setValues] runs first because
  /// a subclass's constructor body must see the resolved fields, and the `args`
  /// assignment runs after it because the invocation is the meaning this field
  /// promises.
  ///
  /// The instance also registers itself as the isolate's active configuration,
  /// which is what [tomAppId] resolves through. Registering the object rather
  /// than reading [appId] out of it here is the point: the subclass constructor
  /// body has not run yet, so there is no value to read — only an object that
  /// will have one.
  ///
  /// For the same reason it installs a *resolver* over [tomAppId] as the
  /// kernel's remote-log sender rather than a copy of it. A remote log
  /// collector names its per-client files after the sender, so without this
  /// every application reports the kernel's default — and several servers of
  /// one deployment, which is exactly when a collector is worth running, write
  /// into one file set distinguished only by isolate name. The closure is
  /// installed here because this is the one place that already says "this
  /// isolate's application is me", and it is idempotent: a second
  /// configuration in the same isolate installs an equivalent closure over the
  /// same getter.
  ///
  /// A field an application marked [TomRequiredField] is checked here too, by
  /// [assertRequiredSettings], with the merged map and before the instance
  /// registers itself: a configuration that refuses to start must not become
  /// the isolate's active one on its way out. The softer findings —
  /// configuration-file keys no field declares, and [TomRecommendedField]
  /// settings no source supplied — are logged as warnings by
  /// [settingWarnings], and the start goes on.
  ///
  /// It applies the kernel's protection settings from [args] too
  /// ([TomResourceKeyProtection.applyArguments]), so `tom.protection=false` or
  /// `tom.protection.json=false` on a server's command line switches the
  /// authorization system or one tier of it off. A misspelt setting throws
  /// before anything else is configured: a server that believed a tier off
  /// while it was on — or the reverse — is worse than one that does not start.
  TomBaseServerConfiguration(List<String> args) {
    // First, so a misspelt `tom.protection` argument stops the server before
    // anything else has been configured.
    TomResourceKeyProtection.applyArguments(args);
    final values = getDefaultValues(args);
    setValues(values);
    // Before the instance registers itself below: a configuration that refuses
    // to start must not become the isolate's active one on its way out.
    assertRequiredSettings(values);
    for (final warning in settingWarnings(
      values,
      TomServerConfigResourceProvider.getServerConfig().resources,
    )) {
      tomLog.warn(warning);
    }
    this.args = args;
    _activeConfiguration = this;
    TomRemoteLogMessage.globalSettingSenderIdResolver = () => tomAppId;
  }
}
