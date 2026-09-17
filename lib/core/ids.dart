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
}
