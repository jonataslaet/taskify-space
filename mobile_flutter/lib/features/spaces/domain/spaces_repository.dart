import 'package:mobile_flutter/features/spaces/domain/created_space.dart';
import 'package:mobile_flutter/features/spaces/domain/space_filters.dart';
import 'package:mobile_flutter/features/spaces/domain/space_page_result.dart';
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

  Future<List<SpaceParticipantSummary>> searchSpaceParticipants({
    required String accessToken,
    required int spaceId,
    required String name,
  });
}
