/// Second factors that are **delivered**: a one-time code sent to an address or
/// a number the user already controls.
///
/// ## The part of the contract TOTP never reached
///
/// [TomTotp2FAService] proved that the adaptor contract works, but it proved
/// only half of it. TOTP re-derives its answer from a shared secret, so it
/// stores nothing in [Tom2FAChallengeSpec.verificationData] — and that map is
/// the contract's central design decision. It is the reason a challenge is split
/// in two: [Tom2FAChallengeSpec.clientData] travels in the interim token's
/// *public* claims, [Tom2FAChallengeSpec.verificationData] in its *encrypted*
/// section, so an adaptor can remember something across the two passes that the
/// holder of the token must not learn.
///
/// A delivered code is precisely that shape, and the first mechanism here to
/// need it. The server generates the code, sends it away, and must recognise it
/// again on pass 2 — while the client, which carries the interim token from one
/// pass to the other, must not be able to read the answer out of what it is
/// carrying. So [verificationData] holds a **salted hash** of the code and never
/// the code itself, and pass 2 re-hashes the submission and compares.
///
/// ## What the two channels share, and what they do not
///
/// Everything except the channel. Code generation, hashing, the constant-time
/// compare, masking, the enrolment begin/confirm shape and the delivery-failure
/// rule are identical for a mailed code and a texted one, and live once in
/// [TomDeliveredCode2FAService]. A subclass supplies four things: its mechanism
/// key, where the destination is on the user record, how to mask a destination
/// for display, and how to hand a rendered message to its channel.
///
/// ## Why delivery is synchronous, and why that is not a violation
///
/// Every other message in the framework goes through [TomMessageOutbox], for
/// good reasons: durable retry, backoff, one-delivery-per-message. A one-time
/// code is the case those reasons do not apply to. Its value expires with the
/// challenge — ten minutes — while the outbox's retry budget is measured in
/// tens of minutes, so a code delivered on the third attempt is a code that
/// arrives after the prompt it answers has gone. Retry does not rescue this
/// message; it only hides that the first attempt failed.
///
/// And the failure must not be hidden. A user staring at a code prompt for a
/// code that was never sent has no way to tell that from a slow relay, and the
/// login has already told them a code is on its way. So delivery goes through
/// [TomTemplatedMessageService.deliverNow], which surfaces the transport's own
/// failure, and an undelivered code fails the challenge with
/// `login.error.2fa.delivery-failed` — the adaptor contract permits a throw
/// exactly when verification "could not be performed", and a challenge nobody
/// received is that.
///
/// The retry a delivered code actually wants is the user pressing *resend*,
/// which issues a fresh challenge with a fresh code — not a redelivery of a
/// stale one.
///
/// ## Enrolment is the proof of control
///
/// For TOTP, enrolment hands the user a secret. Here there is no secret to hand
/// over: the address is already on the user record. What enrolment establishes
/// is that the person logging in can *read* what is sent there — so
/// [TomDeliveredCode2FAService.beginEnrolment] sends a code to the claimed
/// destination and [TomDeliveredCode2FAService.confirmEnrolment] refuses to
/// yield an enrolment until it comes back. The confirmed destination is then
/// stored as the enrolment's [Tom2FAEnrolment.secretData], and challenges prefer
/// it over the record — a proven address outranks an asserted one.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../messaging/email_service.dart';
import '../messaging/message.dart';
import '../messaging/sms_service.dart';
import '../resources/localized_text_resources.dart';
import 'two_factor.dart';
import 'two_factor_enrolment.dart';

// =============================================================================
// SHARED BASE
// =============================================================================

/// The mechanism shape shared by every second factor that **sends a code
/// somewhere**.
///
/// Subclasses supply the channel; everything else — generating the code,
/// sealing it into [Tom2FAChallengeSpec.verificationData], recognising it again,
/// and the enrolment round trip that proves the destination — is here, once.
///
/// Instances are constructed by [Tom2FARegistry] through reflection, so a
/// subclass needs a no-argument constructor and must resolve its collaborators
/// (the messaging service, the enrolment store) at call time rather than in its
/// constructor.
///
/// [S] is the delivery service the channel sends through, named as a type
/// parameter so [requireDeliveryService] hands the subclass its own service
/// back without a cast. It is also what makes this mechanism shape a
/// [Tom2FAPrerequisite]: a code mechanism with nothing to send through cannot
/// be offered, and that has to be answerable at registration rather than
/// discovered at the challenge.
abstract class TomDeliveredCode2FAService<S extends Object>
    implements Tom2FAService, Tom2FAEnrolmentSupport, Tom2FAPrerequisite {
  /// The key the destination is filed under in [Tom2FAEnrolment.secretData] and
  /// in [Tom2FAEnrolmentOffer.enrolmentData].
  static const String destinationKey = 'destination';

  /// The key the code's random salt is filed under.
  static const String saltKey = 'salt';

  /// The key the salted hash of the code is filed under.
  ///
  /// Named `codeHash` rather than `code` on purpose: the one mistake this design
  /// exists to prevent is a maintainer filing the code itself here, and a key
  /// that says *hash* makes the mistake visible at the assignment.
  static const String hashKey = 'codeHash';

  /// The key the masked destination is filed under in
  /// [Tom2FAChallengeSpec.clientData] and [Tom2FAEnrolmentOffer.clientData].
  static const String maskedDestinationKey = 'destination';

  /// The key the code's length is filed under in the client payload, so a UI can
  /// size its input without hard-coding this mechanism's policy.
  static const String digitsKey = 'digits';

  /// How many bytes of salt a sealed code carries.
  ///
  /// Sixteen: enough that two challenges never share a salt, so a table of
  /// hashes of every six-digit code cannot be precomputed once and reused. The
  /// value being protected is small — a million possibilities — which is exactly
  /// why the salt matters more here than it would for a password.
  static const int saltBytes = 16;

  /// The mechanism key this adaptor answers to, and the scope its resource keys
  /// live under (`two_factor.<type>.*`).
  String get type;

  /// How many digits a generated code carries.
  int get codeDigits;

  /// How many submissions one challenge tolerates.
  int get attemptsAllowed;

  /// How long a challenge stays answerable.
  Duration get challengeValidity;

  /// The resource key prefix of the message that carries a login code.
  String get challengeTemplateKey;

  /// The resource key prefix of the message that carries an enrolment code.
  String get enrolmentTemplateKey;

  /// How many confirmation attempts one enrolment offer tolerates.
  int get enrolmentAttemptsAllowed;

  /// How long an enrolment offer stays confirmable.
  Duration get enrolmentValidity;

  /// The destination this channel would reach [context]'s user at according to
  /// the **user record** — the mail address, the mobile number — or `null` when
  /// the record names none.
  ///
  /// Distinct from [resolveDestination], which prefers a *confirmed* enrolment.
  /// This is the asserted address; enrolment is what turns it into a proven one.
  String? destinationOnRecord(Tom2FAContext context);

  /// [destination] reduced to what is safe to show a caller who has not yet
  /// proved anything.
  ///
  /// Shown on the code prompt so a user with two mail addresses knows which
  /// inbox to open — and shown to whoever holds the interim token, which is why
  /// it is a mask and not the address.
  String maskDestination(String destination);

  /// The service this adaptor sends through, or `null` when the deployment
  /// installed none.
  ///
  /// Resolved per call rather than held, for the reason the class dartdoc gives:
  /// the adaptor is constructed by the registry before a deployment has
  /// necessarily finished installing its beans, so a service captured in a
  /// field would be captured as `null` and stay that way.
  S? resolveDeliveryService();

  /// The bean type [resolveDeliveryService] looks for.
  ///
  /// A [Type] rather than a string so the diagnostics survive a rename: every
  /// message that has to tell an operator what to install interpolates this.
  Type get deliveryServiceType;

  /// Nothing, unless this deployment installed no [deliveryServiceType] — in
  /// which case this adaptor could accept a challenge and send no code.
  @override
  String? get unmetPrerequisite => resolveDeliveryService() == null
      ? 'no $deliveryServiceType is installed, so no "$type" code could be sent'
      : null;

  /// The delivery service, or a [Tom2FAException] naming what is missing.
  ///
  /// Reached only when the prerequisite was bypassed — an adaptor registered by
  /// hand, or a service uninstalled after the scan. A wiring fault either way,
  /// which is why it is a [Tom2FAException]: not client-throwable, so the
  /// caller learns only that the login failed while the operator gets a logged,
  /// named cause.
  S requireDeliveryService() {
    final service = resolveDeliveryService();
    if (service == null) {
      throw Tom2FAException(
        'authentication.2fa.$type.no_service',
        'Mechanism "$type" is registered but no $deliveryServiceType is '
            'installed, so no code can be sent.',
        autoLog: true,
      );
    }
    return service;
  }

  /// Sends [code] to [destination] through this adaptor's channel.
  ///
  /// Must complete only when the message has actually been handed to a
  /// transport that accepted it, and must throw otherwise — the whole
  /// delivery-failure rule rests on this being synchronous. [templateKey] names
  /// the resource template to render; the code and the challenge's lifetime are
  /// supplied as parameters, never as literal text.
  Future<void> deliver(
    Tom2FAContext context, {
    required String destination,
    required String code,
    required String templateKey,
    required Duration validity,
  });

  /// Resource keys under `two_factor.<type>.*`; no literal text
  /// (G-RES-1).
  ///
  /// Cached per instance rather than rebuilt per call, and per instance rather
  /// than in a static, because the descriptor depends on [type] — which
  /// a subclass supplies and a static in this base could not see.
  late final Tom2FAMethodDescriptor _descriptor = Tom2FAMethodDescriptor.scoped(
    type,
  );

  @override
  Tom2FAMethodDescriptor get descriptor => _descriptor;

  // ---------------------------------------------------------------------------
  // CHALLENGE
  // ---------------------------------------------------------------------------

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    final destination = await resolveDestination(context);
    if (destination == null) {
      throw TomLoginException(
        'login.error.2fa.not-enrolled',
        'There is no address on record to send a one-time code to',
        parameters: {'mechanism': type},
      );
    }

    final code = generateNumericCode(codeDigits);
    // Before the spec is built, not after: a spec returned for a code that was
    // never sent is a prompt the user cannot answer, and the login flow has no
    // way to tell that apart from a user who simply has not typed yet.
    await deliverOrFail(
      context,
      destination: destination,
      code: code,
      templateKey: challengeTemplateKey,
      validity: challengeValidity,
    );

    final masked = maskDestination(destination);
    return Tom2FAChallengeSpec(
      hint: masked,
      clientData: {maskedDestinationKey: masked, digitsKey: codeDigits},
      // The one thing the client must not be able to read, in the one place it
      // cannot: the encrypted section of the interim token.
      verificationData: sealCode(code),
      attemptsAllowed: attemptsAllowed,
      validity: challengeValidity,
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async =>
      matchesSealedCode(submission.verificationData, submission.submitted);

  /// The destination a challenge should be sent to: the **confirmed** one from
  /// the enrolment store, else the one on the user record.
  ///
  /// The ordering matters and is the same as [TomTotp2FAService]'s. A user who
  /// has proved control of an address must be challenged at *that* address even
  /// if the record has since been edited — an attacker who can change a profile
  /// field must not thereby redirect the second factor. And a deployment that
  /// has installed a store but not yet run an enrolment campaign keeps working,
  /// because the record still answers.
  ///
  /// Falling back to the record is deliberate rather than lax: it is the address
  /// the deployment already trusts for account recovery, and refusing to use it
  /// would lock out every user of a system that has not enrolled anybody yet.
  /// What enrolment adds is proof, and where proof exists it wins.
  Future<String?> resolveDestination(Tom2FAContext context) async {
    final store = Tom2FAEnrolmentStore.resolve();
    if (store != null) {
      final enrolments = await store.enrolmentsFor(context);
      for (final enrolment in enrolments) {
        if (enrolment.type != type) continue;
        final destination = enrolment.secretData[destinationKey];
        // A malformed row is skipped rather than treated as an answer, so one
        // bad record cannot lock out a user who also holds a good one.
        if (destination is String && destination.trim().isNotEmpty) {
          return destination.trim();
        }
      }
    }
    final onRecord = destinationOnRecord(context);
    if (onRecord == null || onRecord.trim().isEmpty) return null;
    return onRecord.trim();
  }

  // ---------------------------------------------------------------------------
  // ENROLMENT
  // ---------------------------------------------------------------------------

  @override
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context) async {
    // The *record*, not [resolveDestination]: enrolling is how a destination
    // becomes confirmed, so starting from the already-confirmed one would make
    // the step a tautology that can never move a user to a new address.
    final destination = destinationOnRecord(context)?.trim();
    if (destination == null || destination.isEmpty) {
      throw TomLoginException(
        'login.error.2fa.no-destination',
        'There is no address on record to confirm',
        parameters: {'mechanism': type},
      );
    }

    final code = generateNumericCode(codeDigits);
    await deliverOrFail(
      context,
      destination: destination,
      code: code,
      templateKey: enrolmentTemplateKey,
      validity: enrolmentValidity,
    );

    final masked = maskDestination(destination);
    return Tom2FAEnrolmentOffer(
      type: type,
      hint: masked,
      clientData: {maskedDestinationKey: masked, digitsKey: codeDigits},
      // The destination travels in the encrypted section beside the sealed code.
      // Confirmation stores *this* copy, so a client cannot answer an offer for
      // one address and have a different address recorded as proven.
      enrolmentData: {...sealCode(code), destinationKey: destination},
      attemptsAllowed: enrolmentAttemptsAllowed,
      validity: enrolmentValidity,
    );
  }

  @override
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  ) async {
    final destination = offer.enrolmentData[destinationKey];
    if (destination is! String || destination.trim().isEmpty) {
      throw TomLoginException(
        'login.error.2fa.enrolment-offer-invalid',
        'This enrolment can no longer be completed; please start again',
        parameters: {'mechanism': type},
      );
    }

    if (!matchesSealedCode(offer.enrolmentData, submitted)) {
      // Throwing rather than returning a nullable enrolment: the only value this
      // method can return is a confirmed one, so a caller cannot store an
      // unproven destination by forgetting a null check.
      throw TomLoginException(
        'login.error.2fa.enrolment-code-invalid',
        'That code does not match the one that was just sent',
        parameters: {'mechanism': type},
      );
    }

    return Tom2FAEnrolment(
      type: type,
      // One destination per channel per user, for the reason TOTP keeps one
      // authenticator: [resolveDestination] answers with the first matching
      // enrolment, so a second row would make which address is challenged depend
      // on storage order. A stable id makes re-confirmation an upsert — which is
      // what changing your phone number should do.
      enrolmentId: type,
      hint: maskDestination(destination.trim()),
      secretData: {destinationKey: destination.trim()},
    );
  }

  // ---------------------------------------------------------------------------
  // DELIVERY
  // ---------------------------------------------------------------------------

  /// Calls [deliver] and turns any failure into a login the user can understand.
  ///
  /// Two kinds of failure pass through unchanged, because both are already
  /// classified and re-labelling them would lose the classification:
  ///
  /// - [TomLoginException] — a subclass that already decided how this login
  ///   fails knows more than this wrapper does;
  /// - [Tom2FAException] — a **wiring** fault (no messaging service installed,
  ///   no gateway configured), which has a different owner and a different fix
  ///   from a relay that is down. Reported as a delivery failure it would send
  ///   whoever is on call to the mail logs of a relay that was never asked.
  ///
  /// Everything else becomes `login.error.2fa.delivery-failed`, logged, with the
  /// original cause attached: the operator needs the relay's own words, and the
  /// user needs to be told the code is not coming rather than to wait for it.
  /// Either way the challenge is not issued, which is the part that matters.
  Future<void> deliverOrFail(
    Tom2FAContext context, {
    required String destination,
    required String code,
    required String templateKey,
    required Duration validity,
  }) async {
    try {
      await deliver(
        context,
        destination: destination,
        code: code,
        templateKey: templateKey,
        validity: validity,
      );
    } on TomLoginException {
      rethrow;
    } on Tom2FAException {
      rethrow;
    } catch (error, stack) {
      throw TomLoginException(
        'login.error.2fa.delivery-failed',
        'The one-time code could not be sent',
        parameters: {'mechanism': type, 'templateKey': templateKey},
        rootException: error,
        stack: stack,
        autoLog: true,
      );
    }
  }

  /// The locale a delivered message should be rendered in.
  ///
  /// The principal's own preference first ([TomTextLocale.fromPrincipal] already
  /// prefers the stored language over the device's), then the login attempt's
  /// client locale, then `null` — which lets the bundle set apply its default in
  /// one place instead of every adaptor inventing `'en'`.
  TomTextLocale? localeFor(Tom2FAContext context) {
    final fromPrincipal = TomTextLocale.fromPrincipal(context.principal);
    if (fromPrincipal != null) return fromPrincipal;
    if (context.language.trim().isEmpty) return null;
    return TomTextLocale(context.language, context.country);
  }

  /// The template parameters every delivered code message may use.
  ///
  /// Supplied whether or not a given template mentions them: an unreferenced
  /// parameter costs nothing, whereas a template that wants the user's first
  /// name and finds no parameter renders a visible `{firstname}`.
  Map<String, Object?> templateParameters(
    Tom2FAContext context, {
    required String code,
    required Duration validity,
  }) {
    final user = context.principal.user;
    return {
      'code': code,
      'minutes': validity.inMinutes,
      'username': context.principal.username,
      'firstname': user.firstname ?? '',
      'lastname': user.lastname ?? '',
      'application': context.application,
    };
  }

  // ---------------------------------------------------------------------------
  // CODES
  // ---------------------------------------------------------------------------

  /// A fresh decimal code of [digits] digits, drawn from the framework's CSPRNG.
  ///
  /// [RsaKeyHelper.getSecureRandom] rather than `dart:math`'s `Random()`, whose
  /// output is predictable from a handful of observations — and a predictable
  /// one-time code is worse than no second factor, because it is trusted.
  ///
  /// Rejection-sampled rather than reduced modulo ten: `byte % 10` would make
  /// the digits `0`–`5` slightly likelier than `6`–`9`, and while that bias is
  /// small it is free to remove.
  static String generateNumericCode(int digits) {
    final random = RsaKeyHelper.getSecureRandom();
    final buffer = StringBuffer();
    while (buffer.length < digits) {
      final byte = random.nextUint8();
      if (byte >= 250) continue;
      buffer.write(byte % 10);
    }
    return buffer.toString();
  }

  /// [code] reduced to a salt and a hash — the only form of it that may travel.
  ///
  /// The map is what goes into [Tom2FAChallengeSpec.verificationData] and
  /// [Tom2FAEnrolmentOffer.enrolmentData]. Both are carried in an *encrypted*
  /// token section, so the hash is defence in depth rather than the only
  /// defence; it is here because a six-digit code is brute-forceable in
  /// microseconds by anyone who does obtain the plaintext, and the encryption is
  /// one key compromise away from being no defence at all.
  static Map<String, Object?> sealCode(String code) {
    final salt = RsaKeyHelper.getSecureRandom().nextBytes(saltBytes);
    return {
      saltKey: base64.encode(salt),
      hashKey: base64.encode(_digest(salt, code)),
    };
  }

  /// Whether [submitted] is the code [sealed] was built from.
  ///
  /// `false` — never a throw — for a malformed or absent seal: a token that lost
  /// its verification blob is an ordinary thing to meet, and the login's answer
  /// to it is the same as its answer to a wrong code.
  static bool matchesSealedCode(Map<String, Object?> sealed, String submitted) {
    final saltValue = sealed[saltKey];
    final hashValue = sealed[hashKey];
    if (saltValue is! String || hashValue is! String) return false;

    final Uint8List salt;
    try {
      salt = base64.decode(saltValue);
    } on FormatException {
      return false;
    }

    final expected = base64.encode(_digest(salt, submitted.trim()));
    return constantTimeEquals(expected, hashValue);
  }

  /// SHA-256 over the salt followed by the code.
  ///
  /// Salt first so that the code's bytes cannot be shifted into the salt's
  /// position by a code of a different length — the length-extension shape that
  /// makes `hash(code + salt)` and `hash(salt + code)` different propositions.
  static List<int> _digest(List<int> salt, String code) =>
      sha256.convert([...salt, ...utf8.encode(code)]).bytes;

  /// Compares two strings without leaking, through timing, how much of the
  /// submission was right.
  ///
  /// The same shape as [TomTotp2FAService]'s private one. Public here because
  /// two adaptors and their tests use it, and a second private copy is exactly
  /// the duplication that lets one of them quietly become a `==`.
  static bool constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }
}

// =============================================================================
// EMAIL
// =============================================================================

/// A one-time code delivered by email.
///
/// Registered as mechanism `'email'`, so a principal whose
/// [TomPrincipal.twoFactorType] is `'email'` — or a [Tom2FAPolicy] that permits
/// it — is challenged with a code sent to their address.
///
/// ```dart
/// TomBean.withType(TomEmailService, TomEmailService(outbox: outbox, texts: texts));
/// // The template the code arrives in:
/// //   email.two_factor_code.subject: "Your {application} sign-in code"
/// //   email.two_factor_code.text:    "Your code is {code}. It expires in {minutes} minutes."
/// ```
///
/// The address comes from the user's confirmed `'email'` enrolment, falling back
/// to [TomUser.email].
@tomReflector
@Tom2FAAdaptor(TomEmailCode2FAService.mechanismType)
class TomEmailCode2FAService
    extends TomDeliveredCode2FAService<TomEmailService> {
  /// The mechanism key this adaptor answers to.
  static const String mechanismType = 'email';

  /// How many digits a mailed code carries.
  ///
  /// Six, matching TOTP, because the user is typing into the same field and a
  /// mechanism-dependent code length is a UI that has to know which mechanism
  /// issued the challenge.
  static int globalSettingCodeDigits = 6;

  /// How many submissions one challenge tolerates.
  static int globalSettingAttemptsAllowed = 3;

  /// How long a mailed code stays answerable.
  ///
  /// Longer than TOTP's five minutes: a code that must travel through a mail
  /// relay, possibly through greylisting, and then be found in an inbox is not
  /// answerable in the time a code already on the user's phone is.
  static Duration globalSettingChallengeValidity = const Duration(minutes: 10);

  /// The resource key prefix of the login-code mail.
  static String globalSettingChallengeTemplateKey = 'email.two_factor_code';

  /// The resource key prefix of the enrolment-confirmation mail.
  ///
  /// A separate template rather than the login one reused: the two mails say
  /// genuinely different things ("here is your sign-in code" versus "confirm
  /// this address"), and a deployment that had to serve both from one wording
  /// would end up with a literal in a Dart file to tell them apart.
  static String globalSettingEnrolmentTemplateKey =
      'email.two_factor_enrolment';

  /// How many confirmation attempts one enrolment offer tolerates.
  static int globalSettingEnrolmentAttemptsAllowed = 3;

  /// How long an enrolment offer stays confirmable.
  static Duration globalSettingEnrolmentValidity = const Duration(minutes: 15);

  /// Creates the adaptor. No-argument so the registry can reflect it into life.
  TomEmailCode2FAService();

  @override
  String get type => mechanismType;

  @override
  int get codeDigits => globalSettingCodeDigits;

  @override
  int get attemptsAllowed => globalSettingAttemptsAllowed;

  @override
  Duration get challengeValidity => globalSettingChallengeValidity;

  @override
  String get challengeTemplateKey => globalSettingChallengeTemplateKey;

  @override
  String get enrolmentTemplateKey => globalSettingEnrolmentTemplateKey;

  @override
  int get enrolmentAttemptsAllowed => globalSettingEnrolmentAttemptsAllowed;

  @override
  Duration get enrolmentValidity => globalSettingEnrolmentValidity;

  @override
  String? destinationOnRecord(Tom2FAContext context) =>
      context.principal.user.email;

  @override
  String maskDestination(String destination) => maskEmailAddress(destination);

  @override
  TomEmailService? resolveDeliveryService() => TomEmailService.resolve();

  @override
  Type get deliveryServiceType => TomEmailService;

  @override
  Future<void> deliver(
    Tom2FAContext context, {
    required String destination,
    required String code,
    required String templateKey,
    required Duration validity,
  }) async {
    final service = requireDeliveryService();
    final user = context.principal.user;
    final name = [
      user.firstname,
      user.lastname,
    ].whereType<String>().join(' ').trim();
    await service.deliverNow(
      TomEmailRequest(
        templateKey: templateKey,
        to: [
          TomRecipient(destination, displayName: name.isEmpty ? null : name),
        ],
        locale: localeFor(context),
        parameters: templateParameters(context, code: code, validity: validity),
      ),
    );
  }

  /// `alice@example.com` as `a***e@example.com`.
  ///
  /// The domain is kept whole and the local part is reduced to its ends. That is
  /// the convention every large provider uses, and it is the right trade: the
  /// domain is what tells a user *which* of their inboxes to open, while the
  /// local part is the half that identifies them.
  ///
  /// A value with no `@` is masked as an opaque string rather than rejected —
  /// this runs on data the deployment supplied, and a challenge prompt is not
  /// the place to discover that a directory holds a malformed address.
  static String maskEmailAddress(String address) {
    final trimmed = address.trim();
    final at = trimmed.lastIndexOf('@');
    if (at <= 0 || at == trimmed.length - 1) return _maskWhole(trimmed);
    final local = trimmed.substring(0, at);
    final domain = trimmed.substring(at);
    return '${_maskLocalPart(local)}$domain';
  }

  static String _maskLocalPart(String local) {
    if (local.length <= 2) return '***';
    return '${local[0]}***${local[local.length - 1]}';
  }

  static String _maskWhole(String value) =>
      value.length <= 2 ? '***' : '${value[0]}***';
}

// =============================================================================
// SMS
// =============================================================================

/// A one-time code delivered by SMS.
///
/// Registered as mechanism `'sms'`. The number comes from the user's confirmed
/// `'sms'` enrolment, falling back to [TomUser.mobile] and then [TomUser.phone]
/// — the same order [TomSmsRequest.toPrincipal] uses, so a code and a
/// notification reach the same handset.
///
/// ```dart
/// TomBean.withType(TomSmsService, TomSmsService(outbox: outbox, texts: texts));
/// //   sms.two_factor_code.text: "{code} is your {application} code."
/// ```
///
/// The default validity is shorter than the mailed code's: an SMS arrives in
/// seconds, and a one-time code should live no longer than it needs to.
@tomReflector
@Tom2FAAdaptor(TomSmsCode2FAService.mechanismType)
class TomSmsCode2FAService extends TomDeliveredCode2FAService<TomSmsService> {
  /// The mechanism key this adaptor answers to.
  static const String mechanismType = 'sms';

  /// How many digits a texted code carries.
  static int globalSettingCodeDigits = 6;

  /// How many submissions one challenge tolerates.
  static int globalSettingAttemptsAllowed = 3;

  /// How long a texted code stays answerable.
  static Duration globalSettingChallengeValidity = const Duration(minutes: 5);

  /// The resource key prefix of the login-code text.
  static String globalSettingChallengeTemplateKey = 'sms.two_factor_code';

  /// The resource key prefix of the enrolment-confirmation text.
  static String globalSettingEnrolmentTemplateKey = 'sms.two_factor_enrolment';

  /// How many confirmation attempts one enrolment offer tolerates.
  static int globalSettingEnrolmentAttemptsAllowed = 3;

  /// How long an enrolment offer stays confirmable.
  static Duration globalSettingEnrolmentValidity = const Duration(minutes: 10);

  /// Creates the adaptor. No-argument so the registry can reflect it into life.
  TomSmsCode2FAService();

  @override
  String get type => mechanismType;

  @override
  int get codeDigits => globalSettingCodeDigits;

  @override
  int get attemptsAllowed => globalSettingAttemptsAllowed;

  @override
  Duration get challengeValidity => globalSettingChallengeValidity;

  @override
  String get challengeTemplateKey => globalSettingChallengeTemplateKey;

  @override
  String get enrolmentTemplateKey => globalSettingEnrolmentTemplateKey;

  @override
  int get enrolmentAttemptsAllowed => globalSettingEnrolmentAttemptsAllowed;

  @override
  Duration get enrolmentValidity => globalSettingEnrolmentValidity;

  @override
  String? destinationOnRecord(Tom2FAContext context) {
    final user = context.principal.user;
    for (final candidate in [user.mobile, user.phone]) {
      if (candidate != null && candidate.trim().isNotEmpty) return candidate;
    }
    return null;
  }

  @override
  String maskDestination(String destination) => maskPhoneNumber(destination);

  @override
  TomSmsService? resolveDeliveryService() => TomSmsService.resolve();

  @override
  Type get deliveryServiceType => TomSmsService;

  @override
  Future<void> deliver(
    Tom2FAContext context, {
    required String destination,
    required String code,
    required String templateKey,
    required Duration validity,
  }) async {
    final service = requireDeliveryService();
    await service.deliverNow(
      TomSmsRequest(
        templateKey: templateKey,
        to: [TomRecipient(destination)],
        locale: localeFor(context),
        parameters: templateParameters(context, code: code, validity: validity),
      ),
    );
  }

  /// `+41791234567` as `+*******4567`.
  ///
  /// The last four digits are kept — the part a user recognises as their own —
  /// and every earlier digit is replaced. Non-digits are preserved so a number
  /// keeps the shape it was stored in, which is what makes `+41 79 …` and
  /// `0041 79 …` still look like the same handset to the person reading the
  /// prompt.
  static String maskPhoneNumber(String number) {
    final trimmed = number.trim();
    // Counted over digits rather than characters: keeping the last four
    // *characters* of `+41 79 123 45 67` would keep `45 67` from one number and
    // `4567` from another written without spaces.
    var digitsSeen = 0;
    for (final unit in trimmed.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) digitsSeen++;
    }
    final buffer = StringBuffer();
    var digitIndex = 0;
    for (final character in trimmed.split('')) {
      final unit = character.codeUnitAt(0);
      final isDigit = unit >= 0x30 && unit <= 0x39;
      if (!isDigit) {
        buffer.write(character);
        continue;
      }
      buffer.write(digitIndex < digitsSeen - 4 ? '*' : character);
      digitIndex++;
    }
    return buffer.toString();
  }
}
