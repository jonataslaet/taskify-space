package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.*;
import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:taskify-test;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
    "spring.flyway.enabled=false",
    "spring.jpa.hibernate.ddl-auto=create-drop"
})
@Import(ParticipantRepository.class)
class TaskExecutionRepositoryTests {

    @Autowired
    private TaskExecutionRepository taskExecutionRepository;

    @Autowired
    private ParticipantRepository participantRepository;

    @Autowired
    private SpaceMembershipRepository spaceMembershipRepository;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private SpaceRepository spaceRepository;

    @Autowired
    private UserRepository userRepository;

    @Test
    void findsApprovedUsersByIdsForAnySpaceRole() {
        Space space = saveSpace("Casa");

        User admin = userRepository.save(createUser("Admin", "admin@email.com"));
        User participant = userRepository.save(createUser("Participant", "participant@email.com"));
        User pending = userRepository.save(createUser("Pending", "pending@email.com"));

        saveMembership(space, admin, SpaceUserRoleEnum.ROLE_SPACE_ADMIN, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(space, participant, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(space, pending, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, SpaceMembershipStatusEnum.PENDING);

        Set<Long> userIds = spaceMembershipRepository
            .findApprovedUsersByIds(
                space.getId(),
                Set.of(admin.getId(), participant.getId(), pending.getId()),
                SpaceMembershipStatusEnum.APPROVED)
            .stream()
            .map(User::getId)
            .collect(Collectors.toSet());

        assertThat(userIds).containsExactlyInAnyOrder(admin.getId(), participant.getId());
    }

    @Test
    void allowsSameUserToHaveMembershipsInDifferentSpaces() {
        Space firstSpace = saveSpace("Casa");

        Space secondSpace = saveSpace("Trabalho");

        User user = userRepository.save(createUser("Participant", "multi-space@email.com"));

        saveMembership(firstSpace, user, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(secondSpace, user, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, SpaceMembershipStatusEnum.APPROVED);
        spaceMembershipRepository.flush();

        assertThat(spaceMembershipRepository.existsBySpaceIdAndUserId(firstSpace.getId(), user.getId())).isTrue();
        assertThat(spaceMembershipRepository.existsBySpaceIdAndUserId(secondSpace.getId(), user.getId())).isTrue();
    }

    @Test
    void preventsSameUserFromHavingDuplicateMembershipInSameSpace() {
        Space space = saveSpace("Casa");

        User user = userRepository.save(createUser("Participant", "same-space@email.com"));

        saveMembership(space, user, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, SpaceMembershipStatusEnum.APPROVED);
        spaceMembershipRepository.flush();

        SpaceMembership duplicateMembership = new SpaceMembership(user, space, SpaceUserRoleEnum.ROLE_SPACE_MANAGER);
        duplicateMembership.setSpaceMembershipStatusEnum(SpaceMembershipStatusEnum.PENDING);

        assertThatThrownBy(() -> spaceMembershipRepository.saveAndFlush(duplicateMembership))
            .isInstanceOf(DataIntegrityViolationException.class);
    }

    private User createUser(String name, String email) {
        User user = new User(name, email, "password", LocalDate.of(2000, 1, 1));
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }

    private Space saveSpace(String name) {
        User creator = userRepository.save(
            createUser(name + " Creator", "creator-" + normalizedName(name) + "@email.com"));
        Space space = new Space(name);
        space.setActive(true);
        space.setCreator(creator);
        return spaceRepository.save(space);
    }

    private String normalizedName(String name) {
        return name.toLowerCase().replaceAll("[^a-z0-9]+", "-");
    }

    private Task createTask(Space space, String description, String score) {
        return createTask(space, description, score, "OPERATIONAL");
    }

    private Task createTask(
        Space space, String description, String score, String taskCategory) {
        Task task = new Task();
        task.setSpace(space);
        task.setDescription(description);
        task.setScore(new BigDecimal(score));
        task.setCategory(new TaskCategory());
        task.setActive(true);
        return task;
    }

    private void saveApprovedParticipant(Space space, User user) {
        saveMembership(
            space,
            user,
            SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT,
            SpaceMembershipStatusEnum.APPROVED);
    }

    private void saveMembership(
        Space space,
        User user,
        SpaceUserRoleEnum role,
        SpaceMembershipStatusEnum status) {
        SpaceMembership spaceMembership = new SpaceMembership(user, space, role);
        spaceMembership.setSpaceMembershipStatusEnum(status);
        spaceMembershipRepository.save(spaceMembership);
    }
}
