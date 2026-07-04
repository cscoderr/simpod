class AXNode {
  const AXNode({
    required this.role,
    this.subrole,
    this.label,
    this.value,
    this.identifier,
    this.title,
    this.help,
    required this.frameX,
    required this.frameY,
    required this.frameWidth,
    required this.frameHeight,
    this.enabled = true,
    this.focused = false,
    this.hidden = false,
    this.children = const [],
    this.depth = 0,
  });

  factory AXNode.fromJson(Map<String, dynamic> json, {int depth = 0}) {
    final frame = json['frame'] as Map<String, dynamic>? ?? {};
    final childrenJson = json['children'] as List<dynamic>? ?? [];
    return AXNode(
      role: json['role'] as String? ?? 'AXUnknown',
      subrole: json['subrole'] as String?,
      label: json['label'] as String?,
      value: json['value']?.toString(),
      identifier: json['identifier'] as String?,
      title: json['title'] as String?,
      help: json['help'] as String?,
      frameX: (frame['x'] as num?)?.toDouble() ?? 0,
      frameY: (frame['y'] as num?)?.toDouble() ?? 0,
      frameWidth: (frame['width'] as num?)?.toDouble() ?? 0,
      frameHeight: (frame['height'] as num?)?.toDouble() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      focused: json['focused'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
      children: childrenJson
          .whereType<Map<String, dynamic>>()
          .map((c) => AXNode.fromJson(c, depth: depth + 1))
          .toList(),
      depth: depth,
    );
  }

  static AXNode? fromApiResponse(List<dynamic> json) {
    if (json.isEmpty) return null;
    return AXNode.fromJson(json[0] as Map<String, dynamic>);
  }

  final String role;
  final String? subrole;
  final String? label;
  final String? value;
  final String? identifier;
  final String? title;
  final String? help;
  final double frameX;
  final double frameY;
  final double frameWidth;
  final double frameHeight;
  final bool enabled;
  final bool focused;
  final bool hidden;
  final List<AXNode> children;

  /// Depth in the tree (0 = root). Set during parsing to simplify
  /// indent calculations in the tree view.
  final int depth;

  String get displayName {
    return title ?? label ?? value ?? identifier ?? '';
  }

  String get shortRole {
    if (role.startsWith('AX')) return role.substring(2);
    return role;
  }

  bool get hasFrame => frameWidth > 0 && frameHeight > 0;

  int get totalCount => 1 + children.fold(0, (sum, c) => sum + c.totalCount);

  List<AXNode> flatten() {
    final result = <AXNode>[this];
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }

  AXNode? hitTest(double x, double y) {
    if (!_contains(x, y)) return null;
    for (final child in children) {
      final hit = child.hitTest(x, y);
      if (hit != null) return hit;
    }
    return this;
  }

  bool _contains(double x, double y) {
    return x >= frameX &&
        x < frameX + frameWidth &&
        y >= frameY &&
        y < frameY + frameHeight;
  }

  @override
  String toString() =>
      'ViewNode($shortRole ${displayName.isNotEmpty ? '"$displayName"' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AXNode &&
          other.role == role &&
          other.subrole == subrole &&
          other.label == label &&
          other.value == value &&
          other.identifier == identifier &&
          other.title == title &&
          other.help == help &&
          other.frameX == frameX &&
          other.frameY == frameY &&
          other.frameWidth == frameWidth &&
          other.frameHeight == frameHeight &&
          other.enabled == enabled &&
          other.focused == focused &&
          other.hidden == hidden &&
          other.children == children &&
          other.depth == depth;

  @override
  int get hashCode =>
      role.hashCode ^
      subrole.hashCode ^
      label.hashCode ^
      value.hashCode ^
      identifier.hashCode ^
      title.hashCode ^
      help.hashCode ^
      frameX.hashCode ^
      frameY.hashCode ^
      frameWidth.hashCode ^
      frameHeight.hashCode ^
      enabled.hashCode ^
      focused.hashCode ^
      hidden.hashCode ^
      children.hashCode ^
      depth.hashCode;
}
