package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;

public class SpaceMembershipMapper {

    public static SpaceMembershipRecordDTO toDTO(SpaceMembership spaceMembership) {
        return new SpaceMembershipRecordDTO(spaceMembership.getId(), spaceMembership.getUser().getName(),
            spaceMembership.getSpaceUserRole(), spaceMembership.getSpaceMembershipStatusEnum());
    }
}
