enum SpaceUserRole {
  admin('ROLE_SPACE_ADMIN'),
  manager('ROLE_SPACE_MANAGER'),
  participant('ROLE_SPACE_PARTICIPANT');

  const SpaceUserRole(this.apiValue);

  final String apiValue;

  static SpaceUserRole fromApiValue(Object? value) {
    if (value is! String) {
      throw const FormatException('Campo spaceUserRole ausente ou inválido.');
    }

    final normalizedValue = value.trim();
    for (final role in values) {
      if (role.apiValue == normalizedValue) {
        return role;
      }
    }
    throw const FormatException('Campo spaceUserRole inválido.');
  }
}

enum SpaceMembershipStatus {
  pending('PENDING'),
  approved('APPROVED'),
  blocked('BLOCKED'),
  cancelled('CANCELLED'),
  denied('DENIED'),
  suspended('SUSPENDED');

  const SpaceMembershipStatus(this.apiValue);

  final String apiValue;

  static SpaceMembershipStatus fromApiValue(Object? value) {
    if (value is! String) {
      throw const FormatException(
        'Campo spaceMembershipStatus ausente ou inválido.',
      );
    }

    final normalizedValue = value.trim();
    for (final status in values) {
      if (status.apiValue == normalizedValue) {
        return status;
      }
    }
    throw const FormatException('Campo spaceMembershipStatus inválido.');
  }
}

final class SpaceFilters {
  const SpaceFilters({this.name, this.role, this.status});

  final String? name;
  final SpaceUserRole? role;
  final SpaceMembershipStatus? status;
}
