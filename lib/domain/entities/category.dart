import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:meta/meta.dart';

@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.isDefault,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final CategoryKind kind;

  /// A key into the app's curated icon map, not a raw code point.
  ///
  /// Storing code points would break tree shaking of icon fonts — Flutter can only
  /// shake `IconData` it can see statically — and would leave the database holding
  /// values that mean nothing if the icon set is ever swapped.
  final String icon;

  /// Packed ARGB. Stored as an int so it round-trips through Postgres `bigint` and
  /// drift `INTEGER` without a hex-parsing step on every list item build.
  final int color;

  final int sortOrder;

  /// True for the seeded starter set. Purely informational: defaults are fully
  /// editable and deletable, this just lets the UI explain where they came from.
  final bool isDefault;

  final DateTime updatedAt;

  Category copyWith({
    String? name,
    CategoryKind? kind,
    String? icon,
    int? color,
    int? sortOrder,
    DateTime? updatedAt,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        isDefault: isDefault,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == id &&
          other.name == name &&
          other.kind == kind &&
          other.icon == icon &&
          other.color == color &&
          other.sortOrder == sortOrder);

  @override
  int get hashCode => Object.hash(id, name, kind, icon, color, sortOrder);
}
