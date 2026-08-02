package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

@DataJpaTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:space-service-test;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
    "spring.flyway.enabled=false",
    "spring.jpa.hibernate.ddl-auto=create-drop"
})
class SpaceServiceJpaTests {

    @Autowired
    private SpaceRepository spaceRepository;

    @Autowired
    private SpaceMembershipRepository spaceMembershipRepository;

    @Autowired
    private UserRepository userRepository;

    private SpaceService spaceService;

    @BeforeEach
    void setUp() {
        spaceService = new SpaceService(
            spaceRepository,
            mock(SpaceMembershipService.class),
            mock(FeatureAccessService.class),
            mock(TaskRepository.class),
            mock(TaskExecutionRepository.class));
    }

    @Test
    void findAllReturnsOnlyActiveSpacesWhereUserHasNoMembershipOrPendingOrApprovedMembership() {
        User authenticatedUser = userRepository.save(createUser("user@example.com"));
        User otherUser = userRepository.save(createUser("other@example.com"));

        Space noMembershipSpace = spaceRepository.save(createSpace("No membership"));
        Space deniedSpace = spaceRepository.save(createSpace("Denied"));
        Space cancelledSpace = spaceRepository.save(createSpace("Cancelled"));
        Space approvedSpace = spaceRepository.save(createSpace("Approved"));
        Space pendingSpace = spaceRepository.save(createSpace("Pending"));
        Space otherUserSpace = spaceRepository.save(createSpace("Other user"));
        Space inactiveSpace = spaceRepository.save(createSpace("Inactive"));
        inactiveSpace.setActive(false);
        spaceRepository.save(inactiveSpace);

        saveMembership(deniedSpace, authenticatedUser, SpaceMembershipStatusEnum.DENIED);
        saveMembership(cancelledSpace, authenticatedUser, SpaceMembershipStatusEnum.CANCELLED);
        saveMembership(approvedSpace, authenticatedUser, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(pendingSpace, authenticatedUser, SpaceMembershipStatusEnum.PENDING);
        saveMembership(otherUserSpace, otherUser, SpaceMembershipStatusEnum.APPROVED);

        Page<SpaceRecordDTO> spaces = spaceService.findAll(null, Pageable.unpaged(), authenticatedUser);

        List<Long> spaceIds = spaces.getContent().stream().map(SpaceRecordDTO::id).toList();
        assertThat(spaceIds).containsExactlyInAnyOrder(
            noMembershipSpace.getId(),
            approvedSpace.getId(),
            pendingSpace.getId(),
            otherUserSpace.getId());
    }

    @Test
    void findAllFiltersRoleOnAuthenticatedUsersPendingOrApprovedMembershipOnly() {
        User authenticatedUser = userRepository.save(createUser("user@example.com"));

        Space pendingParticipantSpace = spaceRepository.save(createSpace("Pending participant"));
        Space pendingAdminSpace = spaceRepository.save(createSpace("Pending admin"));
        Space approvedAdminSpace = spaceRepository.save(createSpace("Approved admin"));
        Space deniedAdminSpace = spaceRepository.save(createSpace("Denied admin"));

        saveMembership(
            pendingParticipantSpace,
            authenticatedUser,
            SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT,
            SpaceMembershipStatusEnum.PENDING);
        saveMembership(
            pendingAdminSpace,
            authenticatedUser,
            SpaceUserRoleEnum.ROLE_SPACE_ADMIN,
            SpaceMembershipStatusEnum.PENDING);
        saveMembership(
            approvedAdminSpace,
            authenticatedUser,
            SpaceUserRoleEnum.ROLE_SPACE_ADMIN,
            SpaceMembershipStatusEnum.APPROVED);
        saveMembership(
            deniedAdminSpace,
            authenticatedUser,
            SpaceUserRoleEnum.ROLE_SPACE_ADMIN,
            SpaceMembershipStatusEnum.DENIED);

        Page<SpaceRecordDTO> spaces = spaceService.findAll(
            null, Pageable.unpaged(), authenticatedUser, SpaceUserRoleEnum.ROLE_SPACE_ADMIN, null);

        List<Long> spaceIds = spaces.getContent().stream().map(SpaceRecordDTO::id).toList();
        assertThat(spaceIds).containsExactlyInAnyOrder(
            pendingAdminSpace.getId(),
            approvedAdminSpace.getId());
    }

    @Test
    void findAllFiltersStatusOnAuthenticatedUsersPendingOrApprovedMembershipOnly() {
        User authenticatedUser = userRepository.save(createUser("user@example.com"));
        User otherUser = userRepository.save(createUser("other@example.com"));

        Space deniedSpace = spaceRepository.save(createSpace("Denied"));
        Space pendingSpace = spaceRepository.save(createSpace("Pending"));
        Space otherUserPendingSpace = spaceRepository.save(createSpace("Other user pending"));

        saveMembership(
            deniedSpace,
            authenticatedUser,
            SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT,
            SpaceMembershipStatusEnum.DENIED);
        saveMembership(
            pendingSpace,
            authenticatedUser,
            SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT,
            SpaceMembershipStatusEnum.PENDING);
        saveMembership(
            otherUserPendingSpace,
            otherUser,
            SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT,
            SpaceMembershipStatusEnum.PENDING);

        Page<SpaceRecordDTO> spaces = spaceService.findAll(
            null, Pageable.unpaged(), authenticatedUser, null, SpaceMembershipStatusEnum.PENDING);

        List<Long> spaceIds = spaces.getContent().stream().map(SpaceRecordDTO::id).toList();
        assertThat(spaceIds).containsExactly(pendingSpace.getId());
    }

    private User createUser(String email) {
        User user = new User();
        user.setName(email);
        user.setEmail(email);
        user.setPassword("encoded-password");
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }

    private Space createSpace(String name) {
        User creator = userRepository.save(createUser("creator-" + normalizedName(name) + "@example.com"));
        Space space = new Space(name);
        space.setActive(true);
        space.setCreator(creator);
        return space;
    }

    private String normalizedName(String name) {
        return name.toLowerCase().replaceAll("[^a-z0-9]+", "-");
    }

    private void saveMembership(Space space, User user, SpaceMembershipStatusEnum status) {
        saveMembership(space, user, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, status);
    }

    private void saveMembership(
        Space space, User user, SpaceUserRoleEnum role, SpaceMembershipStatusEnum status) {
        SpaceMembership spaceMembership =
            new SpaceMembership(user, space, role);
        spaceMembership.setSpaceMembershipStatusEnum(status);
        spaceMembershipRepository.save(spaceMembership);
    }
}
