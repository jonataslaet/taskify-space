final class SpaceParticipantSummary {
  const SpaceParticipantSummary({required this.id, required this.name});

  factory SpaceParticipantSummary.fromJson(Map<String, dynamic> json) {
    return SpaceParticipantSummary(
      id: _requiredPositiveInt(json, 'id'),
      name: _requiredString(json, 'name'),
    );
  }

  final int id;
  final String name;

  static int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value <= 0) {
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
}
