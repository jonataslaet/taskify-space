package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;

public record SpaceMembershipRecordDTO(
    Long id,
    String name,
    SpaceUserRoleEnum spaceUserRole,
    SpaceMembershipStatusEnum spaceMembershipStatus
) {
}
