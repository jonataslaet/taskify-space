package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class SpaceMapperTests {

    @Test
    void toDTOUsesSpaceCreatorNameAsOwnerNameEvenWhenAnotherAdminIsPending() {
        User creator = createUser(1L, "Creator");
        User pendingAdmin = createUser(2L, "Pending Admin");
        Space space = new Space("Family space");
        space.setId(10L);
        space.setCreator(creator);

        SpaceMembership pendingAdminMembership =
            new SpaceMembership(pendingAdmin, space, SpaceUserRoleEnum.ROLE_SPACE_ADMIN);
        pendingAdminMembership.setSpaceMembershipStatusEnum(SpaceMembershipStatusEnum.PENDING);
        space.getSpaceMemberships().add(pendingAdminMembership);

        SpaceRecordDTO spaceRecordDTO = SpaceMapper.toDTO(space);

        assertThat(spaceRecordDTO.spaceAdminName()).isEqualTo(creator.getName());
    }

    private User createUser(Long id, String name) {
        User user = new User();
        user.setId(id);
        user.setName(name);
        user.setEmail("user" + id + "@example.com");
        return user;
    }
}
