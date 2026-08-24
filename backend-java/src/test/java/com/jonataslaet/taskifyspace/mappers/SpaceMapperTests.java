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

    @Test
    void toDTOIncludesAvailableFlag() {
        Space space = new Space("Public space");
        space.setAvailable(true);

        SpaceRecordDTO spaceRecordDTO = SpaceMapper.toDTO(space);

        assertThat(spaceRecordDTO.available()).isTrue();
    }

    @Test
    void toEntityCopiesAvailableWhenProvided() {
        SpaceRecordDTO spaceRecordDTO = new SpaceRecordDTO(
            null,
            "Public space",
            null,
            null,
            true,
            null,
            null,
            null);

        Space space = SpaceMapper.toEntity(spaceRecordDTO);

        assertThat(space.getName()).isEqualTo("Public space");
        assertThat(space.getAvailable()).isTrue();
    }

    @Test
    void toEntityDefaultsAvailableToFalseWhenMissing() {
        SpaceRecordDTO spaceRecordDTO = new SpaceRecordDTO(
            null,
            "Private space",
            null,
            null,
            null,
            null,
            null,
            null);

        Space space = SpaceMapper.toEntity(spaceRecordDTO);

        assertThat(space.getAvailable()).isFalse();
    }

    private User createUser(Long id, String name) {
        User user = new User();
        user.setId(id);
        user.setName(name);
        user.setEmail("user" + id + "@example.com");
        return user;
    }
}
