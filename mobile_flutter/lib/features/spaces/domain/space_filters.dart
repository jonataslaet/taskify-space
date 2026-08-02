enum SpaceUserRole {
  admin('ROLE_SPACE_ADMIN'),
  manager('ROLE_SPACE_MANAGER'),
  participant('ROLE_SPACE_PARTICIPANT');

  const SpaceUserRole(this.apiValue);

  final String apiValue;
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
}

final class SpaceFilters {
  const SpaceFilters({this.name, this.role, this.status});

  final String? name;
  final SpaceUserRole? role;
  final SpaceMembershipStatus? status;
}
