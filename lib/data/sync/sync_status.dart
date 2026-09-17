import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:meta/meta.dart';

/// What the sync indicator shows.
@immutable
class SyncStatus {
  const SyncStatus({
    required this.state,
    this.pending = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  static const SyncStatus idle = SyncStatus(state: SyncState.idle);

  final SyncState state;

  /// Rows still waiting in the outbox. Surfaced so the user can tell the
  /// difference between "saved on this phone" and "saved everywhere" — important
  /// when the app is deliberately usable offline.
  final int pending;

  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get isBusy => state == SyncState.syncing;
  bool get hasPending => pending > 0;

  SyncStatus copyWith({
    SyncState? state,
    int? pending,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        pending: pending ?? this.pending,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStatus &&
          other.state == state &&
          other.pending == pending &&
          other.lastSyncedAt == lastSyncedAt &&
          other.lastError == lastError);

  @override
  int get hashCode => Object.hash(state, pending, lastSyncedAt, lastError);
}
