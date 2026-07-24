package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
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
import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.PENDING;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.SUSPENDED;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
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
        User creator = createUser(1L);
        User authenticatedAdmin = createUser(2L);
        User participant = createUser(3L);
        Space space = new Space("Space");
        space.setId(10L);
        space.setCreator(creator);
        SpaceMembership spaceMembership = new SpaceMembership(participant, space, ROLE_SPACE_PARTICIPANT);
        spaceMembership.setSpaceMembershipStatusEnum(APPROVED);

        when(spaceMembershipRepository.findByIdAndSpaceId(20L, space.getId()))
            .thenReturn(Optional.of(spaceMembership));
        when(spaceMembershipRepository.existsBySpaceIdAndUserIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
            space.getId(), authenticatedAdmin.getId(), APPROVED, ROLE_SPACE_ADMIN))
            .thenReturn(true);
        when(spaceMembershipRepository.save(spaceMembership)).thenReturn(spaceMembership);

        SpaceMembershipRecordDTO updatedMembership = spaceMembershipService.updateParticipation(
            space.getId(), 20L, null, ROLE_SPACE_MANAGER, authenticatedAdmin);

        ArgumentCaptor<SpaceMembership> spaceMembershipCaptor = ArgumentCaptor.forClass(SpaceMembership.class);
        verify(spaceMembershipRepository).save(spaceMembershipCaptor.capture());
        verify(featureAccessService).requireFeatureWithUsageLock(
            creator, FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER, space);
        SpaceMembership savedMembership = spaceMembershipCaptor.getValue();

        assertThat(savedMembership.getSpaceMembershipStatusEnum()).isEqualTo(APPROVED);
        assertThat(savedMembership.getSpaceUserRole()).isEqualTo(ROLE_SPACE_MANAGER);
        assertThat(updatedMembership.spaceMembershipStatus()).isEqualTo(APPROVED);
        assertThat(updatedMembership.spaceUserRole()).isEqualTo(ROLE_SPACE_MANAGER);
    }

    @Test
    void updateParticipationPreventsManagerFromChangingAdminStatus() {
        User manager = createUser(1L);
        User admin = createUser(2L);
        Space space = createSpace();
        SpaceMembership adminMembership = createMembership(admin, space, ROLE_SPACE_ADMIN, APPROVED);

        when(spaceMembershipRepository.findByIdAndSpaceId(20L, space.getId()))
            .thenReturn(Optional.of(adminMembership));

        assertThatThrownBy(() -> spaceMembershipService.updateParticipation(
            space.getId(), 20L, SUSPENDED, null, manager))
            .isInstanceOf(ForbiddenException.class);

        verify(spaceMembershipRepository, never()).save(org.mockito.ArgumentMatchers.any(SpaceMembership.class));
    }

    @Test
    void updateParticipationPreventsRemovingLastApprovedAdmin() {
        User admin = createUser(1L);
        Space space = createSpace();
        SpaceMembership adminMembership = createMembership(admin, space, ROLE_SPACE_ADMIN, APPROVED);

        when(spaceMembershipRepository.findByIdAndSpaceId(20L, space.getId()))
            .thenReturn(Optional.of(adminMembership));
        when(spaceMembershipRepository.existsBySpaceIdAndUserIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
            space.getId(), admin.getId(), APPROVED, ROLE_SPACE_ADMIN))
            .thenReturn(true);
        when(spaceMembershipRepository.findBySpaceIdAndStatusAndSpaceUserRoleForUpdate(
            space.getId(), APPROVED, ROLE_SPACE_ADMIN))
            .thenReturn(Set.of(adminMembership));

        assertThatThrownBy(() -> spaceMembershipService.updateParticipation(
            space.getId(), 20L, SUSPENDED, null, admin))
            .isInstanceOf(ForbiddenException.class);

        verify(spaceMembershipRepository, never()).save(org.mockito.ArgumentMatchers.any(SpaceMembership.class));
    }

    @Test
    void updateParticipationAllowsAdminToSuspendAdminWhenAnotherApprovedAdminRemains() {
        User authenticatedAdmin = createUser(1L);
        User targetAdmin = createUser(2L);
        User otherAdmin = createUser(3L);
        Space space = createSpace();
        SpaceMembership targetAdminMembership = createMembership(targetAdmin, space, ROLE_SPACE_ADMIN, APPROVED);
        SpaceMembership otherAdminMembership = createMembership(otherAdmin, space, ROLE_SPACE_ADMIN, APPROVED);

        when(spaceMembershipRepository.findByIdAndSpaceId(20L, space.getId()))
            .thenReturn(Optional.of(targetAdminMembership));
        when(spaceMembershipRepository.existsBySpaceIdAndUserIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
            space.getId(), authenticatedAdmin.getId(), APPROVED, ROLE_SPACE_ADMIN))
            .thenReturn(true);
        when(spaceMembershipRepository.findBySpaceIdAndStatusAndSpaceUserRoleForUpdate(
            space.getId(), APPROVED, ROLE_SPACE_ADMIN))
            .thenReturn(Set.of(targetAdminMembership, otherAdminMembership));
        when(spaceMembershipRepository.save(targetAdminMembership)).thenReturn(targetAdminMembership);

        SpaceMembershipRecordDTO updatedMembership = spaceMembershipService.updateParticipation(
            space.getId(), 20L, SUSPENDED, null, authenticatedAdmin);

        assertThat(updatedMembership.spaceMembershipStatus()).isEqualTo(SUSPENDED);
        assertThat(updatedMembership.spaceUserRole()).isEqualTo(ROLE_SPACE_ADMIN);
    }

    @Test
    void setSpaceMembershipAllowsUserWithMembershipInAnotherSpace() {
        User user = createUser(2L);
        Space space = new Space("Space");
        space.setId(10L);

        when(spaceMembershipRepository.existsBySpaceIdAndUserId(space.getId(), user.getId()))
            .thenReturn(false);

        spaceMembershipService.setSpaceMembership(space, user, ROLE_SPACE_PARTICIPANT);

        ArgumentCaptor<SpaceMembership> spaceMembershipCaptor = ArgumentCaptor.forClass(SpaceMembership.class);
        verify(spaceMembershipRepository).save(spaceMembershipCaptor.capture());
        SpaceMembership savedMembership = spaceMembershipCaptor.getValue();

        assertThat(savedMembership.getUser()).isEqualTo(user);
        assertThat(savedMembership.getSpace()).isEqualTo(space);
        assertThat(savedMembership.getSpaceUserRole()).isEqualTo(ROLE_SPACE_PARTICIPANT);
        assertThat(savedMembership.getSpaceMembershipStatusEnum()).isEqualTo(PENDING);
        assertThat(space.getSpaceMemberships()).contains(savedMembership);
    }

    @Test
    void setSpaceMembershipDoesNotCreateDuplicateParticipationInSameSpace() {
        User user = createUser(2L);
        Space space = new Space("Space");
        space.setId(10L);

        when(spaceMembershipRepository.existsBySpaceIdAndUserId(space.getId(), user.getId()))
            .thenReturn(true);

        spaceMembershipService.setSpaceMembership(space, user, ROLE_SPACE_PARTICIPANT);

        verify(spaceMembershipRepository, never()).save(org.mockito.ArgumentMatchers.any(SpaceMembership.class));
        assertThat(space.getSpaceMemberships()).isEmpty();
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

    private Space createSpace() {
        Space space = new Space("Space");
        space.setId(10L);
        space.setCreator(createUser(100L));
        return space;
    }

    private SpaceMembership createMembership(
        User user,
        Space space,
        SpaceUserRoleEnum role,
        SpaceMembershipStatusEnum status) {
        SpaceMembership spaceMembership = new SpaceMembership(user, space, role);
        spaceMembership.setSpaceMembershipStatusEnum(status);
        space.getSpaceMemberships().add(spaceMembership);
        return spaceMembership;
    }
}
