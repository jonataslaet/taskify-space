import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';

final class SpaceSummary {
  const SpaceSummary({
    required this.id,
    required this.name,
    required this.spaceAdminName,
    required this.active,
    required this.spaceUserRole,
    required this.spaceMembershipStatus,
    required this.activeParticipationsCount,
  });

  factory SpaceSummary.fromJson(Map<String, dynamic> json) {
    return SpaceSummary(
      id: _requiredPositiveInt(json, 'id'),
      name: _requiredString(json, 'name'),
      spaceAdminName: _optionalString(json, 'spaceAdminName'),
      active: _requiredBool(json, 'active'),
      spaceUserRole: _optionalString(json, 'spaceUserRole'),
      spaceMembershipStatus: _optionalString(json, 'spaceMembershipStatus'),
      activeParticipationsCount: _requiredNonNegativeInt(
        json,
        'activeParticipationsCount',
      ),
    );
  }

  final int id;
  final String name;
  final String? spaceAdminName;
  final bool active;
  final String? spaceUserRole;
  final String? spaceMembershipStatus;
  final int activeParticipationsCount;

  bool get canEditTasks => canEditParticipations;

  bool get canEditParticipations {
    return spaceMembershipStatus == SpaceMembershipStatus.approved.apiValue &&
        (spaceUserRole == SpaceUserRole.admin.apiValue ||
            spaceUserRole == SpaceUserRole.manager.apiValue);
  }

  bool get canEditParticipationRoles {
    return spaceMembershipStatus == SpaceMembershipStatus.approved.apiValue &&
        spaceUserRole == SpaceUserRole.admin.apiValue;
  }

  static int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value <= 0) {
      throw FormatException('Campo $key ausente ou inválido.');
    }
    return value;
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value < 0) {
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
