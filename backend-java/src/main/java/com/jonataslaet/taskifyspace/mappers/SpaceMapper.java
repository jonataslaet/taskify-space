package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import org.springframework.beans.BeanUtils;

import java.util.Objects;

public class SpaceMapper {

    public static Space toEntity(SpaceRecordDTO spaceRecordDTO) {
        Space Space = new Space();
        BeanUtils.copyProperties(spaceRecordDTO, Space);
        return Space;
    }

    public static SpaceRecordDTO toDTO(Space space) {
        return new SpaceRecordDTO(space.getId(), space.getName(), getSpaceAdminName(space), space.getActive());
    }

    private static String getSpaceAdminName(Space space) {
        for (SpaceMembership spaceMembership: space.getSpaceMemberships()) {
            if (Objects.nonNull(spaceMembership) && Objects.nonNull(spaceMembership.getSpaceUserRole()) &&
                spaceMembership.getSpaceUserRole().equals(SpaceUserRoleEnum.ROLE_SPACE_ADMIN)) {
                return spaceMembership.getUser().getName();
            }
        }
        return null;
    }
}
