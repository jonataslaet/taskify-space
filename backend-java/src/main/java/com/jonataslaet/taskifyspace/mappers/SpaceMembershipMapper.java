package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import org.springframework.beans.BeanUtils;

public class SpaceMembershipMapper {

    public static SpaceMembership toEntity(SpaceMembershipRecordDTO spaceMembershipRecordDTO) {
        SpaceMembership spaceMembership = new SpaceMembership();
        BeanUtils.copyProperties(spaceMembershipRecordDTO, spaceMembership);
        return spaceMembership;
    }

    public static SpaceMembershipRecordDTO toDTO(SpaceMembership spaceMembership) {
        return new SpaceMembershipRecordDTO(spaceMembership.getId(), spaceMembership.getUser().getName(),
            spaceMembership.getSpaceUserRole(), spaceMembership.getSpaceMembershipStatusEnum());
    }
}
