package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import org.springframework.beans.BeanUtils;

import java.util.List;
import java.util.Objects;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.APPROVED;

public class SpaceMapper {

    public static Space toEntity(SpaceRecordDTO spaceRecordDTO) {
        Space Space = new Space();
        BeanUtils.copyProperties(spaceRecordDTO, Space);
        return Space;
    }

    public static SpaceRecordDTO toDTO(Space space) {
        return new SpaceRecordDTO(space.getId(), space.getName(), getSpaceAdminName(space), space.getActive(), null, null, null);
    }

    public static SpaceRecordDTO toDTO(Space space, User authenticatedUser) {
        SpaceMembership authenticatedUserMembership = getAuthenticatedUserMembership(space, authenticatedUser);
        return new SpaceRecordDTO(
            space.getId(),
            space.getName(),
            getSpaceAdminName(space),
            space.getActive(),
            Objects.nonNull(authenticatedUserMembership) ? authenticatedUserMembership.getSpaceUserRole() : null,
            Objects.nonNull(authenticatedUserMembership) ? authenticatedUserMembership.getSpaceMembershipStatusEnum() : null,
            countActiveParticipations(space)
        );
    }

    private static Long countActiveParticipations(Space space) {
        return space.getSpaceMemberships().stream()
            .filter(spaceMembership -> Objects.nonNull(spaceMembership)
                && APPROVED.equals(spaceMembership.getSpaceMembershipStatusEnum()))
            .count();
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

    private static SpaceMembership getAuthenticatedUserMembership(Space space, User authenticatedUser) {
        if (Objects.isNull(authenticatedUser)) return null;

        return List.of(
                SpaceUserRoleEnum.ROLE_SPACE_ADMIN,
                SpaceUserRoleEnum.ROLE_SPACE_MANAGER,
                SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT
            )
            .stream()
            .map(role -> getMembershipByRole(space, authenticatedUser, role))
            .filter(Objects::nonNull)
            .findFirst()
            .orElse(null);
    }

    private static SpaceMembership getMembershipByRole(Space space, User authenticatedUser, SpaceUserRoleEnum role) {
        return space.getSpaceMemberships().stream().filter(spaceMembership ->
            Objects.nonNull(spaceMembership) &&
            Objects.nonNull(spaceMembership.getUser()) &&
            Objects.nonNull(spaceMembership.getSpaceUserRole()) &&
            spaceMembership.getUser().getId().equals(authenticatedUser.getId()) &&
            spaceMembership.getSpaceUserRole().equals(role))
            .findFirst()
            .orElse(null);
    }
}
