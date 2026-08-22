import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participation_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_page_result.dart';
import 'package:mobile_flutter/features/spaces/domain/space_participant_summary.dart';

abstract interface class SpacesRepository {
  Future<CreatedSpace> createSpace({
    required String accessToken,
    required String name,
  });

  Future<SpacePageResult> fetchSpaces({
    required String accessToken,
    SpaceFilters filters = const SpaceFilters(),
    int page = 0,
    int size = 10,
  });

  Future<SpaceParticipantPageResult> fetchSpaceParticipants({
    required String accessToken,
    required int spaceId,
    SpaceParticipantFilters filters = const SpaceParticipantFilters(),
    int page = 0,
    int size = 10,
  });

  Future<SpaceParticipationPageResult> fetchSpaceParticipations({
    required String accessToken,
    required int spaceId,
    SpaceParticipationFilters filters = const SpaceParticipationFilters(),
    int page = 0,
    int size = 10,
  });

  Future<SpaceParticipation> updateSpaceParticipation({
    required String accessToken,
    required int spaceId,
    required int membershipId,
    SpaceMembershipStatus? status,
    SpaceUserRole? spaceUserRole,
  });

  Future<void> requestSpaceParticipation({
    required String accessToken,
    required int spaceId,
  });

  Future<List<SpaceParticipantSummary>> searchSpaceParticipants({
    required String accessToken,
    required int spaceId,
    required String name,
  });
}
