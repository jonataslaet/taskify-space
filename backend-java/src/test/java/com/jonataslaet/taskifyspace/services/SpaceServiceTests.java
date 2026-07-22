package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SpaceServiceTests {

    @Mock
    private SpaceRepository spaceRepository;

    @Mock
    private SpaceMembershipService spaceMembershipService;

    @Mock
    private FeatureAccessService featureAccessService;

    @Mock
    private TaskRepository taskRepository;

    @Mock
    private TaskExecutionRepository taskExecutionRepository;

    private SpaceService spaceService;

    @BeforeEach
    void setUp() {
        spaceService = new SpaceService(
            spaceRepository,
            spaceMembershipService,
            featureAccessService,
            taskRepository,
            taskExecutionRepository);
    }

    @Test
    void getSpaceByIdAllowsApprovedParticipant() {
        User user = createUser(1L);
        Space space = createSpace(10L);
        addMembership(space, user, SpaceMembershipStatusEnum.APPROVED);

        when(spaceRepository.findById(space.getId())).thenReturn(Optional.of(space));

        SpaceRecordDTO foundSpace = spaceService.getSpaceById(user, space.getId());

        assertThat(foundSpace.id()).isEqualTo(space.getId());
    }

    @Test
    void getSpaceByIdPreventsUserWithoutApprovedParticipation() {
        User user = createUser(1L);
        Space space = createSpace(10L);
        addMembership(space, user, SpaceMembershipStatusEnum.PENDING);

        when(spaceRepository.findById(space.getId())).thenReturn(Optional.of(space));

        assertThatThrownBy(() -> spaceService.getSpaceById(user, space.getId()))
            .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void updateSpaceWithPartialPayloadPreservesMissingFields() {
        User user = createUser(1L);
        Space space = createSpace(10L);
        space.setName("Original space");
        space.setActive(true);
        addMembership(
            space,
            user,
            SpaceMembershipStatusEnum.APPROVED,
            SpaceUserRoleEnum.ROLE_SPACE_ADMIN);
        SpaceRecordDTO partialUpdate = new SpaceRecordDTO(
            null,
            "Updated space",
            null,
            null,
            null,
            null,
            null);

        when(spaceRepository.findById(space.getId())).thenReturn(Optional.of(space));
        when(spaceRepository.save(space)).thenReturn(space);

        SpaceRecordDTO updatedSpace = spaceService.updateSpace(user, space.getId(), partialUpdate);

        assertThat(updatedSpace.name()).isEqualTo("Updated space");
        assertThat(updatedSpace.active()).isTrue();
    }

    private User createUser(Long id) {
        User user = new User();
        user.setId(id);
        user.setName("User " + id);
        user.setEmail("user" + id + "@example.com");
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }

    private Space createSpace(Long id) {
        Space space = new Space("Space " + id);
        space.setId(id);
        space.setActive(true);
        return space;
    }

    private void addMembership(Space space, User user, SpaceMembershipStatusEnum status) {
        addMembership(space, user, status, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT);
    }

    private void addMembership(
        Space space,
        User user,
        SpaceMembershipStatusEnum status,
        SpaceUserRoleEnum role) {
        SpaceMembership spaceMembership =
            new SpaceMembership(user, space, role);
        spaceMembership.setSpaceMembershipStatusEnum(status);
        space.getSpaceMemberships().add(spaceMembership);
    }
}
