final class CreatedSpace {
  const CreatedSpace({
    required this.id,
    required this.name,
    required this.spaceAdminName,
    required this.active,
  });

  factory CreatedSpace.fromJson(Map<String, dynamic> json) {
    return CreatedSpace(
      id: _requiredPositiveInt(json, 'id'),
      name: _requiredString(json, 'name'),
      spaceAdminName: _optionalString(json, 'spaceAdminName'),
      active: _requiredBool(json, 'active'),
    );
  }

  final int id;
  final String name;
  final String? spaceAdminName;
  final bool active;

  static int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value <= 0) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo $key inválido.');
    }
    return value.trim();
  }
}
