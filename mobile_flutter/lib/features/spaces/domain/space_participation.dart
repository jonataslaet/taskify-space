import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';

final class SpaceParticipation {
  const SpaceParticipation({
    required this.id,
    required this.name,
    required this.spaceUserRole,
    required this.spaceMembershipStatus,
  });

  factory SpaceParticipation.fromJson(Map<String, dynamic> json) {
    return SpaceParticipation(
      id: _requiredPositiveInt(json, 'id'),
      name: _requiredString(json, 'name'),
      spaceUserRole: SpaceUserRole.fromApiValue(json['spaceUserRole']),
      spaceMembershipStatus: SpaceMembershipStatus.fromApiValue(
        json['spaceMembershipStatus'],
      ),
    );
  }

  final int id;
  final String name;
  final SpaceUserRole spaceUserRole;
  final SpaceMembershipStatus spaceMembershipStatus;

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
