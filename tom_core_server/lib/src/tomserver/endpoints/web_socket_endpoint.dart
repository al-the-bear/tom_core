/// WebSocket transport as a *kind of endpoint*: the annotation that declares
/// one and the connection object a handler talks through.
///
/// ## Why a second endpoint kind rather than a second server
///
/// A socket handler needs everything an HTTP handler needs — the same route
/// table, the same access check, the same authenticated [TomPrincipal], the
/// same denial audit — and differs only in what happens *after* those pass: a
/// request answers once and ends, a socket stays open and both sides speak.
/// Standing up a separate socket server would duplicate the first list to gain
/// the second, and the duplicate would drift.
///
/// So [TomWebSocketEndpoint] implements the same [TomEndpointBase] the HTTP
/// annotations implement, which is what the pipeline's scan already keys on
/// (`tag is TomEndpointBase`). A socket endpoint is therefore *discovered*,
/// *authorized* and *audited* by exactly the code that does so for every other
/// endpoint, and only its mounting and its lifecycle are its own.
///
/// ## The zone is the subtle part
///
/// The upgrade completes, the HTTP response is finished, and only *then* does
/// the socket callback fire. By that point the request zone — the one carrying
/// the [TomPrincipal], the execution context and the request id — is long gone,
/// so a handler that asked "who is this?" inside the callback would find
/// nobody. The pipeline therefore captures the zone at upgrade time and runs
/// the handler inside it (`Zone.run`), the same fix the streamed file download
/// needed for the same reason (bug D22).
///
/// ## Example
///
/// The access annotation names a **concrete** [TomAccessControl] subclass —
/// [TomResourceKeyAccess] here, and equally [TomPublicAccess],
/// [TomAuthenticatedAccess], [TomRoleAccess] and their siblings.
/// [TomAccessControl] itself is abstract: it is the type the scan matches
/// (`tag is TomAccessControl`), not one you write.
///
/// ```dart
/// @tomService
/// abstract class TickerService {
///   @TomWebSocketEndpoint(uri: '/ws/ticker')
///   @TomResourceKeyAccess('ticker')
///   Future<void> ticker(TomWebSocketConnection socket, TomPrincipal who);
/// }
///
/// @tomComponent
/// class TickerServer implements TickerService {
///   @override
///   Future<void> ticker(
///     TomWebSocketConnection socket,
///     TomPrincipal who,
///   ) async {
///     socket.sendText('hello ${who.username}');
///     await for (final message in socket.messages) {
///       socket.sendText('echo: $message');
///     }
///   }
/// }
/// ```
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../little_things/server_exception.dart';
import 'endpoint_annotation.dart';

/// Thrown when a WebSocket endpoint is declared or used in a way the pipeline
/// cannot serve.
class TomWebSocketException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomWebSocketException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Method-level annotation declaring a WebSocket endpoint at [uri].
///
/// The annotated method is invoked **once per accepted connection**, not once
/// per message, and its returned future marks the end of the conversation: the
/// pipeline closes the socket when it completes. Parameters are bound by the
/// ordinary endpoint rules — principal, token, execution context, path and
/// query values — plus one addition, a [TomWebSocketConnection] parameter that
/// receives the live socket.
///
/// A socket endpoint answers `GET` and nothing else, because that is what a
/// WebSocket handshake is; [methods] is not offered for the same reason.
class TomWebSocketEndpoint<
  requestType extends Object,
  resultType extends Object
>
    implements TomEndpointBase<requestType, resultType> {
  /// The route path the socket is mounted at.
  final String uri;

  /// The subprotocols the endpoint is willing to speak, in preference order.
  ///
  /// Empty means "no subprotocol", which is the common case: a Tom socket
  /// usually carries JSON with no negotiated name for it.
  final List<String> protocols;

  /// The browser origins allowed to open this socket, or empty for "any".
  ///
  /// The `Origin` header is set by browsers and only by browsers, so this is
  /// the handshake-time counterpart of CORS: it is what stops a page on another
  /// site from opening an authenticated socket in a visitor's session. Leave it
  /// empty only for a socket that is not reachable from a browser.
  final List<String> allowedOrigins;

  /// How often to ping an idle connection, or `null` to never ping.
  ///
  /// A socket that neither side writes to can stay "open" long after the peer
  /// has vanished, because nothing on the wire says otherwise. A ping interval
  /// makes that silence detectable: an unanswered ping closes the channel.
  final Duration? pingInterval;

  /// Binds URL parameters to typed request-DTO fields, as
  /// [TomEndpoint.urlParameterMapping] does for an HTTP endpoint — forwarded
  /// verbatim by [convertToTomEndpoint] and read with the same asymmetry: a
  /// path capture binds with or without an entry, a query-string parameter
  /// **only** with one.
  ///
  /// That opt-in matters more here than it does over HTTP. A handshake is a
  /// `GET` with no body, so the URL is the *only* place a socket endpoint's
  /// request DTO can be built from. An endpoint that leaves this empty while
  /// expecting `?token=…` does not get told so: if the route captures anything
  /// at all the DTO is built without the token, and if it captures nothing the
  /// DTO is not built and the call fails on argument count, naming neither the
  /// parameter nor the query string.
  final Map<String, String> urlParameterMapping;

  /// Whether handshake requests to this endpoint are logged (`null` = default).
  final bool? logRequests;

  /// Declares a WebSocket endpoint at [uri].
  const TomWebSocketEndpoint({
    required this.uri,
    this.protocols = const [],
    this.allowedOrigins = const [],
    this.pingInterval,
    this.urlParameterMapping = const {},
    this.logRequests,
  });

  /// Produces the [TomEndpoint] the pipeline routes with.
  ///
  /// A handshake is a `GET` with no body, so the produced endpoint says exactly
  /// that. Sharing the type is what lets the scan, the access resolution and
  /// the routing table stay single-implementation.
  @override
  TomEndpoint<requestType, resultType> convertToTomEndpoint([
    TomApiImplementation? apiImplementation,
  ]) {
    return TomEndpoint<requestType, resultType>(
      methods: const [TomHttpMethod.get],
      uri: uri,
      urlParameterMapping: urlParameterMapping,
      logRequests: logRequests ?? apiImplementation?.logRequestsDefault,
    );
  }

  @override
  String toString() => 'TomWebSocketEndpoint($uri)';
}

/// A live WebSocket connection, as a handler sees it.
///
/// Handed to the endpoint method as a parameter. It wraps the underlying
/// [WebSocketChannel] rather than exposing it, so that a handler talks in terms
/// of messages ([sendText], [sendBytes], [messages]) and the transport stays
/// replaceable — and so that "the socket is not attached yet" is a named error
/// rather than a null dereference.
///
/// ### Lifetime
///
/// The instance is created *before* the upgrade, so that a parameter-binding
/// failure is still an ordinary HTTP error rather than a socket that opens and
/// immediately dies. It is attached to the channel at the moment the connection
/// is accepted, which is also the moment the handler is invoked — so from
/// inside a handler the connection is always live.
class TomWebSocketConnection {
  WebSocketChannel? _channel;
  String? _subprotocol;
  bool _closed = false;
  Stream<dynamic>? _messages;
  int _messagesReceived = 0;
  int _messagesSent = 0;

  /// Creates a not-yet-attached connection; the pipeline attaches it on upgrade.
  TomWebSocketConnection();

  /// Attaches the accepted [channel] (and the negotiated [subprotocol]).
  ///
  /// Called by the endpoint pipeline at upgrade time — not from application
  /// code, which always receives an already-attached connection.
  void attachChannel(WebSocketChannel channel, [String? subprotocol]) {
    if (_channel != null) {
      throw TomWebSocketException(
        'web_socket_endpoint.already_attached',
        'This connection is already serving a socket.',
      );
    }
    _channel = channel;
    _subprotocol = subprotocol;
  }

  WebSocketChannel get _live {
    final channel = _channel;
    if (channel == null) {
      throw TomWebSocketException(
        'web_socket_endpoint.not_attached',
        'This connection is not serving a socket yet.',
      );
    }
    return channel;
  }

  /// The subprotocol agreed during the handshake, or `null` when none was.
  String? get subprotocol => _subprotocol;

  /// Whether the socket has been attached and not yet closed from this side.
  bool get isOpen => _channel != null && !_closed;

  /// The messages arriving from the peer.
  ///
  /// Each event is a `String` for a text frame and a `List<int>` for a binary
  /// one — the channel's own distinction, passed through rather than
  /// normalised, because which of the two a peer sent is information the
  /// handler may need. The stream is single-subscription and closing it (or
  /// letting it end) ends the conversation.
  ///
  /// Counted as it passes, for [messagesReceived]. The count is a side effect
  /// of the pass-through rather than a second traversal, and it is cached so
  /// that reading this getter twice yields the one stream the channel has —
  /// a second subscription is the error it always was.
  Stream<dynamic> get messages => _messages ??= _live.stream.map((message) {
    _messagesReceived++;
    return message;
  });

  /// Reads every message from the peer in turn, running [onMessage] for each
  /// as work of its own, and completes when the peer ends the conversation.
  ///
  /// Each call runs in a new span of the connection's trace with the request
  /// id `<trace id>-<span id>` ([TomRequestId.runChild]), so the log lines,
  /// exceptions and audit entries of one message name that message, and still
  /// name the upgrade request's trace. A handler reading [messages] itself
  /// writes everything under the upgrade request's id. The two read the same
  /// single-subscription stream: use one or the other.
  ///
  /// The next message is read only once [onMessage] has completed, so the
  /// messages are handled in the order the peer sent them; an error from
  /// [onMessage] ends the loop and reaches the caller.
  Future<void> serve(FutureOr<void> Function(dynamic message) onMessage) async {
    await for (final message in messages) {
      await TomRequestId.runChild(() async => onMessage(message));
    }
  }

  /// How many frames the peer has sent, counted as the handler reads them.
  ///
  /// A frame the handler never reads is not counted: the stream is
  /// single-subscription and the count rides on it, so this is "what this
  /// conversation consumed", which is what the audit entry is about. A handler
  /// that never listens reports zero, and that is the true answer about it.
  int get messagesReceived => _messagesReceived;

  /// How many frames this side has sent.
  int get messagesSent => _messagesSent;

  /// Sends a text frame.
  void sendText(String message) {
    _live.sink.add(message);
    _messagesSent++;
  }

  /// Sends a binary frame.
  void sendBytes(List<int> bytes) {
    _live.sink.add(bytes);
    _messagesSent++;
  }

  /// Closes the socket, optionally with a WebSocket close [code] and [reason].
  ///
  /// Idempotent: closing an already-closed connection is a no-op rather than an
  /// error, because the pipeline closes the socket when a handler returns and a
  /// handler that closed it itself is the normal case, not a mistake.
  Future<void> close([int? code, String? reason]) async {
    if (_closed || _channel == null) return;
    _closed = true;
    await _channel!.sink.close(code, reason);
  }

  @override
  String toString() =>
      'TomWebSocketConnection(open: $isOpen, subprotocol: $subprotocol, '
      'received: $_messagesReceived, sent: $_messagesSent)';
}
