/// Retention stand-ins shared by the suites that need a retention service but
/// are not testing the sweep.
///
/// [OpsRetentionStore] is the seam a retention pass reaches the database
/// through, so every suite that builds an [OpsRetentionService] has to supply
/// one — including the suites whose subject is something else entirely (which
/// capability the deployment holds, which beans the runtime publishes). Those
/// suites want the same thing: a store that yields nothing and objects if it is
/// asked to delete. One definition of it rather than one per suite, so that
/// adding a method to the interface breaks a single file instead of as many
/// files as happen to have a copy.
///
/// The recording store in `ops_retention_test.dart` deliberately stays where it
/// is. It answers a different question — *which* calls a pass made, with what
/// arguments — and belongs beside the assertions that read its lists. Two
/// classes implementing one interface are not duplicates when only one of them
/// is a stand-in.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';

/// A retention store holding nothing, which refuses to destroy anything.
///
/// The refusal is the useful half. Because [expiredItems] yields no candidates,
/// a [destroy] call cannot be for a row this store handed out, so the throw
/// catches a pass acting on an item it was never given rather than merely
/// recording that it happened.
class NullRetentionStore implements OpsRetentionStore {
  /// Creates a store with no candidates in it.
  const NullRetentionStore();

  @override
  Future<List<ItemRecord>> expiredItems(
    DateTime cutoff, {
    required int limit,
  }) async => const [];

  @override
  Future<void> destroy(ItemRecord item) async => throw StateError(
    'destroy(${item.id}) on a store with no candidates — the pass acted on an '
    'item expiredItems never returned',
  );
}
