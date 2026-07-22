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
    void findAllReturnsOnlySpacesWhereUserHasApprovedMembership() {
        User authenticatedUser = userRepository.save(createUser("user@example.com"));
        User otherUser = userRepository.save(createUser("other@example.com"));

        Space approvedSpace = spaceRepository.save(createSpace("Approved"));
        Space pendingSpace = spaceRepository.save(createSpace("Pending"));
        Space blockedSpace = spaceRepository.save(createSpace("Blocked"));
        Space otherUserSpace = spaceRepository.save(createSpace("Other user"));

        saveMembership(approvedSpace, authenticatedUser, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(pendingSpace, authenticatedUser, SpaceMembershipStatusEnum.PENDING);
        saveMembership(blockedSpace, authenticatedUser, SpaceMembershipStatusEnum.BLOCKED);
        saveMembership(otherUserSpace, otherUser, SpaceMembershipStatusEnum.APPROVED);

        Page<SpaceRecordDTO> spaces = spaceService.findAll(null, Pageable.unpaged(), authenticatedUser);

        List<Long> spaceIds = spaces.getContent().stream().map(SpaceRecordDTO::id).toList();
        assertThat(spaceIds).containsExactly(approvedSpace.getId());
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
        Space space = new Space(name);
        space.setActive(true);
        return space;
    }

    private void saveMembership(Space space, User user, SpaceMembershipStatusEnum status) {
        SpaceMembership spaceMembership =
            new SpaceMembership(user, space, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT);
        spaceMembership.setSpaceMembershipStatusEnum(status);
        spaceMembershipRepository.save(spaceMembership);
    }
}
