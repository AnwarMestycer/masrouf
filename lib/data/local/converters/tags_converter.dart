import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores `tags` as a JSON array in a TEXT column.
///
/// SQLite has no array type. JSON keeps the round trip lossless (a tag may
/// contain a comma) and stays queryable with `LIKE '%"gym"%'` for the history
/// search, which is enough at personal-ledger scale.
class TagsConverter extends TypeConverter<List<String>, String>
    with JsonTypeConverter<List<String>, String> {
  const TagsConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty || fromDb == '[]') return const <String>[];
    final decoded = jsonDecode(fromDb);
    if (decoded is! List) return const <String>[];
    return decoded.map((e) => e.toString()).toList(growable: false);
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
