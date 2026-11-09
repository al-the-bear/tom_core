/// The suppression list: addresses a carrier reported as permanently
/// undeliverable, and that no message is sent to again until released.
///
/// ## The gap this closes
///
/// A delivery report saying a number does not exist or a mailbox bounced was
/// recorded and nothing acted on it, so the next message went to the same dead
/// address — paid for, refused again, and for email counted against the
/// sender's reputation by every receiving server. The list is what a report
/// changes: `TomDeliveryReportEndpoint` adds the address of a
/// [TomDeliveryState.failed] report, and [TomMessageRouter] leaves suppressed
/// addresses out before a transport is called.
///
/// ## What suppresses, and what does not
///
/// Only [TomDeliveryState.failed], which a protocol reserves for an address to
/// stop using. An expiry (a handset switched off for a day) is worth another
/// attempt and suppresses nothing; nor does an unknown state. A failure is
/// attributed to the address the report names, or — when the report names none
/// — to the message's single address. A message to several addresses whose
/// report names none suppresses nothing: which of them failed is not known, and
/// suppressing all of them would stop mail to the ones that work.
///
/// ## The key
///
/// One entry per channel and normalised address ([normalize]): an email address
/// is compared without case, a phone number by its digits — `+44 7700 900000`
/// and Vonage's `447700900000` are one number. The list is the deployment's,
/// not a tenant's: an address a carrier refuses is refused for every tenant
/// sending to it. The tenant whose message failed is recorded with the entry.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'delivery_report.dart';
import 'message.dart';
import 'message_transport.dart';

/// One suppressed address and why.
class TomSuppressedAddress {
  /// The channel the address is suppressed on.
  final TomMessageChannel channel;

  /// The address, normalised ([TomSuppressionList.normalize]).
  final String address;

  /// When it was suppressed.
  final DateTime suppressedAt;

  /// The message whose failure suppressed it, when a report did.
  final String? messageId;

  /// The carrier's id of that message.
  final String? remoteId;

  /// The carrier's error code from the report.
  final String? providerCode;

  /// The carrier's words, or the reason an operator gave.
  final String? detail;

  /// The tenant the failed message was sent for, or `null`.
  final String? tenant;

  /// Creates an entry; [address] is normalised for [channel].
  TomSuppressedAddress({
    required this.channel,
    required String address,
    DateTime? suppressedAt,
    this.messageId,
    this.remoteId,
    this.providerCode,
    this.detail,
    this.tenant,
  }) : address = TomSuppressionList.normalize(channel, address),
       suppressedAt = (suppressedAt ?? DateTime.now()).toUtc();

  /// The entry a failure report on [correlation] adds for [address].
  factory TomSuppressedAddress.fromReport(
    TomDeliveryCorrelation correlation,
    String address,
  ) => TomSuppressedAddress(
    channel: correlation.channel,
    address: address,
    suppressedAt: correlation.reportedAt,
    messageId: correlation.messageId,
    remoteId: correlation.remoteId,
    providerCode: correlation.providerCode,
    detail: correlation.detail,
    tenant: correlation.tenant,
  );

  @override
  String toString() =>
      'TomSuppressedAddress(${channel.name} $address'
      '${providerCode == null ? '' : ', code $providerCode'})';
}

/// The addresses no message is sent to.
abstract class TomSuppressionList {
  /// Creates a list.
  const TomSuppressionList();

  /// [address] as the list compares it on [channel]: an email address trimmed
  /// and lower-cased, a phone number reduced to its digits, any other address
  /// trimmed.
  static String normalize(TomMessageChannel channel, String address) {
    final trimmed = address.trim();
    if (channel.name == TomMessageChannel.email.name) {
      return trimmed.toLowerCase();
    }
    if (channel.name == TomMessageChannel.sms.name) {
      return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    }
    return trimmed;
  }

  /// Suppresses [entry]'s address, replacing an entry for the same address.
  Future<void> suppress(TomSuppressedAddress entry);

  /// Lifts the suppression of [address] on [channel], answering whether it
  /// was suppressed.
  Future<bool> release(TomMessageChannel channel, String address);

  /// The entry for [address] on [channel], or `null`.
  Future<TomSuppressedAddress?> find(TomMessageChannel channel, String address);

  /// Those of [addresses] that are suppressed on [channel], as given.
  Future<Set<String>> suppressedAmong(
    TomMessageChannel channel,
    Iterable<String> addresses,
  );

  /// Every entry, or those of [channel], most recent first.
  Future<List<TomSuppressedAddress>> all({TomMessageChannel? channel});

  /// The addresses a [TomDeliveryState.failed] report on [correlation]
  /// suppresses: the one [report] names, else the message's single address,
  /// else none — see the library documentation.
  static List<String> addressesToSuppress(
    TomDeliveryCorrelation correlation, {
    TomDeliveryReport? report,
  }) {
    if (correlation.state != TomDeliveryState.failed) return const [];
    final named = report?.recipient;
    if (named != null && named.trim().isNotEmpty) return [named];
    if (correlation.addresses.length == 1) return correlation.addresses;
    return const [];
  }

  /// Applies a recorded [report] to this list: suppresses what
  /// [addressesToSuppress] names, answering the entries added.
  Future<List<TomSuppressedAddress>> applyReport(
    TomDeliveryCorrelation correlation, {
    TomDeliveryReport? report,
  }) async {
    final added = <TomSuppressedAddress>[];
    for (final address in addressesToSuppress(correlation, report: report)) {
      final entry = TomSuppressedAddress.fromReport(correlation, address);
      if (entry.address.isEmpty) continue;
      await suppress(entry);
      added.add(entry);
    }
    if (added.isEmpty &&
        correlation.state == TomDeliveryState.failed &&
        correlation.addresses.length > 1) {
      tomLog.info(
        'TomSuppressionList: message ${correlation.messageId} failed for one '
        'of ${correlation.addresses.length} addresses and the report names '
        'none; nothing suppressed',
      );
    }
    return added;
  }
}

/// A [TomSuppressionList] in memory: for tests, and for a single process that
/// accepts losing the list on restart.
class TomMemorySuppressionList extends TomSuppressionList {
  final Map<(String, String), TomSuppressedAddress> _entries = {};

  /// Creates an empty list.
  TomMemorySuppressionList();

  @override
  Future<void> suppress(TomSuppressedAddress entry) async =>
      _entries[(entry.channel.name, entry.address)] = entry;

  @override
  Future<bool> release(TomMessageChannel channel, String address) async =>
      _entries.remove((
        channel.name,
        TomSuppressionList.normalize(channel, address),
      )) !=
      null;

  @override
  Future<TomSuppressedAddress?> find(
    TomMessageChannel channel,
    String address,
  ) async =>
      _entries[(channel.name, TomSuppressionList.normalize(channel, address))];

  @override
  Future<Set<String>> suppressedAmong(
    TomMessageChannel channel,
    Iterable<String> addresses,
  ) async => {
    for (final address in addresses)
      if (_entries.containsKey((
        channel.name,
        TomSuppressionList.normalize(channel, address),
      )))
        address,
  };

  @override
  Future<List<TomSuppressedAddress>> all({TomMessageChannel? channel}) async =>
      _entries.values
          .where(
            (entry) => channel == null || entry.channel.name == channel.name,
          )
          .toList()
        ..sort((a, b) => b.suppressedAt.compareTo(a.suppressedAt));
}

/// Why a [TomMessageRouter] sent nothing: every recipient was suppressed.
///
/// The detail a [TomDeliveryOutcome.suppressed] receipt carries.
String tomSuppressedDetail(int count) => count == 1
    ? 'The recipient is on the suppression list; nothing was sent.'
    : 'All $count recipients are on the suppression list; nothing was '
          'sent.';
