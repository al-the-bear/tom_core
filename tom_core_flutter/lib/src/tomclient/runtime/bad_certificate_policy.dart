import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The hosts whose **unverified** TLS certificate the native HTTP client
/// accepts.
///
/// A client that is handed a certificate it cannot verify normally refuses the
/// connection, and that refusal is the whole of TLS's value. Development
/// against a local server with a self-signed certificate is the one case where
/// refusing is not useful, so the native variant's
/// `HttpClient.badCertificateCallback` consults this policy and accepts the
/// handshake for the hosts it names — a **loopback address is not reachable
/// from another machine**, so a certificate presented on one came from this
/// machine whatever it claims.
///
/// Every host in [hosts] is a host whose certificate this client will not
/// check. The shipped list is [defaultHosts] and nothing else; it is `const`,
/// so the policy an application ships with is auditable by reading one
/// declaration.
///
/// ## Which spelling actually arrives
///
/// The callback is handed `Uri.host`, and `Uri` strips the brackets an IPv6
/// literal carries in a URL: `https://[::1]:8443` arrives as `::1`. Both
/// spellings are in [defaultHosts] anyway — `[::1]` costs nothing and covers a
/// caller that passes an authority where a host was wanted — but `::1` is the
/// one that matters.
///
/// The IPv4 and IPv6 loopbacks are both listed for the reason a developer would
/// assume they are: which of them `localhost` resolves to is the resolver's
/// choice and differs between machines, so listing one and not the other makes
/// the same code, certificate and URL succeed on one desktop and fail on the
/// next, with the failure reported as a TLS error that points at the
/// certificate.
///
/// ## Changing it
///
/// [allowOnly] **replaces** the list, so an application can widen it — a named
/// development host, a container's address — or narrow it to nothing:
///
/// ```dart
/// // Trust no unverified certificate at all, not even on loopback.
/// TomBadCertificatePolicy.allowOnly(const []);
///
/// // A development container reached by name.
/// TomBadCertificatePolicy.allowOnly([
///   ...TomBadCertificatePolicy.defaultHosts,
///   'dev.internal',
/// ]);
/// ```
///
/// A replacement is **logged at warn level**, naming the hosts. This is a
/// security boundary moving at run time, and the one thing a constant gave that
/// a setter cannot is that the policy in force is the policy in the source; the
/// log line is what replaces it, so a widened policy leaves a record where an
/// operator looks.
///
/// Match is exact and case-sensitive on the host string — there is no pattern
/// syntax and no wildcard, so an entry can only ever admit the one host it
/// spells.
///
/// The policy is process-wide and takes effect for every client built
/// afterwards, because the callback reads it per handshake rather than
/// capturing it. It is consulted **only on native targets**: the browser
/// performs its own certificate validation and no application code can override
/// it, and the neutral variant creates no client at all.
final class TomBadCertificatePolicy {
  /// Not instantiable: the policy is process-wide, and a second instance would
  /// suggest two policies could be in force.
  const TomBadCertificatePolicy._();

  /// The shipped policy: the loopback spellings, and nothing else.
  ///
  /// `0.0.0.0` is the unspecified address rather than a loopback one, and is
  /// here because it is what a server binding every interface is often
  /// addressed as during development. The remaining four are the two loopback
  /// addresses and the two names that reach them.
  static const List<String> defaultHosts = <String>[
    '0.0.0.0',
    'localhost',
    '127.0.0.1',
    '::1',
    '[::1]',
  ];

  static List<String> _hosts = defaultHosts;

  /// The hosts currently accepted.
  ///
  /// Unmodifiable: the list is the policy, and a caller that could add to what
  /// it read would widen a security boundary without passing through
  /// [allowOnly] — which is the only place the change is validated and logged.
  static List<String> get hosts => List.unmodifiable(_hosts);

  /// Whether an unverified certificate is accepted for [host].
  ///
  /// The predicate the native `badCertificateCallback` delegates to. Exact
  /// match, so it answers `false` for every host no entry spells.
  static bool allows(String host) => _hosts.contains(host);

  /// Replaces the accepted hosts with [allowed].
  ///
  /// An empty [allowed] is legitimate and means "accept no unverified
  /// certificate", which is the hardened production setting. A blank entry is
  /// refused with an [ArgumentError]: no host string is empty, so an entry that
  /// is names nothing — it is what a split over a mis-typed setting leaves
  /// behind, and a policy list quietly carrying one reads as though it had been
  /// configured.
  static void allowOnly(Iterable<String> allowed) {
    final hosts = List<String>.unmodifiable(allowed);
    for (final host in hosts) {
      if (host.trim().isEmpty) {
        throw ArgumentError.value(
          allowed,
          'allowed',
          'a bad-certificate host must not be blank',
        );
      }
    }
    _hosts = hosts;
    tomLog.warn(
      'TomBadCertificatePolicy: unverified TLS certificates are now accepted '
      'for ${hosts.isEmpty ? "no host" : hosts.join(", ")}',
    );
  }

  /// Restores [defaultHosts].
  ///
  /// The shipped policy, put back — for a test that widened it, and for an
  /// application that narrowed it for one phase of start-up.
  static void reset() {
    _hosts = defaultHosts;
  }
}
