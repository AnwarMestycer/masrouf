import 'package:masrouf/data/remote/dto/remote_mappers.dart';

/// Decides whether a pulled row should overwrite what is on the device.
///
/// The rule is last-write-wins on `updated_at`, with one refinement: a local row
/// that is still sitting in the sync queue is never overwritten, regardless of
/// timestamps. Without that guard a pull scheduled between a local edit and its
/// push would discard the user's change and, because the queue entry still
/// exists, then push the *server's* version back — losing an edit the user
/// watched land.
abstract final class ConflictResolver {
  static ConflictOutcome resolve({
    required DateTime serverUpdatedAt,
    required DateTime? localUpdatedAt,
    required bool localHasPendingChange,
  }) {
    if (localUpdatedAt == null) return ConflictOutcome.applyServer;
    if (localHasPendingChange) return ConflictOutcome.keepLocal;

    // Equal timestamps mean the device already has this exact version — usually
    // its own push echoing back on the next pull. Skipping avoids a pointless
    // write and the aggregate rebuild it would trigger.
    if (!serverUpdatedAt.isAfter(localUpdatedAt)) {
      return ConflictOutcome.keepLocal;
    }
    return ConflictOutcome.applyServer;
  }

  /// Convenience for the common shape at the call site.
  static bool shouldApply({
    required Json serverRow,
    required DateTime? localUpdatedAt,
    required bool localHasPendingChange,
  }) =>
      resolve(
        serverUpdatedAt: rowUpdatedAt(serverRow),
        localUpdatedAt: localUpdatedAt,
        localHasPendingChange: localHasPendingChange,
      ) ==
      ConflictOutcome.applyServer;
}

enum ConflictOutcome { applyServer, keepLocal }
