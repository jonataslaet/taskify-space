import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';

final class SpaceParticipationFilters {
  const SpaceParticipationFilters({
    this.username,
    this.statuses = const <SpaceMembershipStatus>{},
  });

  final String? username;
  final Set<SpaceMembershipStatus> statuses;
}
