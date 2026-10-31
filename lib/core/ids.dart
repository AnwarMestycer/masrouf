import 'package:uuid/uuid.dart';

/// Identifier generation.
///
/// Ids are minted on the client, never by Postgres: an offline insert needs a
/// stable identity the moment it is written so that edits, the sync queue and any
/// foreign keys all agree before the row has ever reached the server.
abstract final class Ids {
  static const Uuid _uuid = Uuid();

  /// UUIDv7 — time-ordered, so newly inserted rows land at the end of the B-tree
  /// instead of scattering random pages the way v4 does. Matters on the
  /// `transactions` primary key, which grows forever.
  static String newId() => _uuid.v7();

  /// The id of [userId]'s savings period for the month `yyyyMM`.
  ///
  /// Derived rather than minted: a month's period is opened and closed by
  /// whichever device notices first, often both. A fresh id on each would be
  /// two Octobers, each claiming the same income and each reserving against
  /// the same balance. A name-based UUIDv5 means both devices write the same
  /// row, and last-write-wins settles the rest.
  static String savingsMonthId(String userId, int yyyymm) =>
      _uuid.v5(Namespace.url.value, 'masrouf:savings-month:$userId:$yyyymm');
}
