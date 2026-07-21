package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.repositories.ParticipantRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.Set;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.APPROVED;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_MANAGER;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SpaceMembershipServiceTests {

    @Mock
    private SpaceMembershipRepository spaceMembershipRepository;

    @Mock
    private ParticipantRepository participantRepository;

    @Mock
    private FeatureAccessService featureAccessService;

    private SpaceMembershipService spaceMembershipService;

    @BeforeEach
    void setUp() {
        spaceMembershipService = new SpaceMembershipService(
            spaceMembershipRepository,
            participantRepository,
            featureAccessService);
    }

    @Test
    void updateParticipationPreservesStatusWhenOnlyRoleChanges() {
        User authenticatedUser = createUser(1L);
        User participant = createUser(2L);
        Space space = new Space("Space");
        space.setId(10L);
        SpaceMembership spaceMembership = new SpaceMembership(participant, space, ROLE_SPACE_PARTICIPANT);
        spaceMembership.setSpaceMembershipStatusEnum(APPROVED);

        when(spaceMembershipRepository.findByIdAndSpaceId(20L, space.getId()))
            .thenReturn(Optional.of(spaceMembership));
        when(spaceMembershipRepository.save(spaceMembership)).thenReturn(spaceMembership);

        SpaceMembershipRecordDTO updatedMembership = spaceMembershipService.updateParticipation(
            space.getId(), 20L, null, ROLE_SPACE_MANAGER, authenticatedUser);

        ArgumentCaptor<SpaceMembership> spaceMembershipCaptor = ArgumentCaptor.forClass(SpaceMembership.class);
        verify(spaceMembershipRepository).save(spaceMembershipCaptor.capture());
        SpaceMembership savedMembership = spaceMembershipCaptor.getValue();

        assertThat(savedMembership.getSpaceMembershipStatusEnum()).isEqualTo(APPROVED);
        assertThat(savedMembership.getSpaceUserRole()).isEqualTo(ROLE_SPACE_MANAGER);
        assertThat(updatedMembership.spaceMembershipStatus()).isEqualTo(APPROVED);
        assertThat(updatedMembership.spaceUserRole()).isEqualTo(ROLE_SPACE_MANAGER);
    }

    @Test
    void setSpaceMembershipPreventsUserWithExistingMembership() {
        User user = createUser(2L);
        Space space = new Space("Space");
        space.setId(10L);

        when(spaceMembershipRepository.existsBySpaceIdAndUserIdAndSpaceUserRoleIn(
            space.getId(), user.getId(), Set.of(ROLE_SPACE_PARTICIPANT)))
            .thenReturn(false);
        when(spaceMembershipRepository.existsByUserId(user.getId())).thenReturn(true);

        assertThatThrownBy(() -> spaceMembershipService.setSpaceMembership(space, user, ROLE_SPACE_PARTICIPANT))
            .isInstanceOf(DuplicationException.class);

        verify(spaceMembershipRepository, never()).save(org.mockito.ArgumentMatchers.any(SpaceMembership.class));
    }

    private User createUser(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        user.setName("User " + id);
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }
}
