package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.TaskExecution;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:taskify-test;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
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
    void sumsParticipantScoreDividingTaskScoreByExecutionExecutorCount() {
        Space space = new Space("Casa");
        space.setActive(true);
        space = spaceRepository.save(space);

        User user1 = userRepository.save(createUser("User 1", "user1@email.com"));
        User user2 = userRepository.save(createUser("User 2", "user2@email.com"));

        Task sharedTask = taskRepository.save(createTask(space, "Shared task", "90.0"));
        Task singleTask = taskRepository.save(createTask(space, "Single task", "30.0"));

        taskExecutionRepository.save(new TaskExecution(sharedTask, space, Set.of(user1, user2)));
        taskExecutionRepository.save(new TaskExecution(singleTask, space, Set.of(user1)));

        Map<Long, BigDecimal> scoresByUserId = taskExecutionRepository
            .sumParticipantScoresBySpaceIdAndUserIds(space.getId(), Set.of(user1.getId(), user2.getId()))
            .stream()
            .collect(Collectors.toMap(
                TaskExecutionRepository.ParticipantScoreProjection::getUserId,
                TaskExecutionRepository.ParticipantScoreProjection::getScore));

        assertThat(scoresByUserId.get(user1.getId())).isEqualByComparingTo("75.0");
        assertThat(scoresByUserId.get(user2.getId())).isEqualByComparingTo("45.0");
    }

    @Test
    void sortsParticipantsByScoreDescending() {
        Space space = new Space("Casa");
        space.setActive(true);
        space = spaceRepository.save(space);

        User user1 = userRepository.save(createUser("User 1", "score1@email.com"));
        User user2 = userRepository.save(createUser("User 2", "score2@email.com"));
        User user3 = userRepository.save(createUser("User 3", "score3@email.com"));

        saveApprovedParticipant(space, user1);
        saveApprovedParticipant(space, user2);
        saveApprovedParticipant(space, user3);

        Task sharedTask = taskRepository.save(createTask(space, "Shared task", "90.0"));
        Task singleTask = taskRepository.save(createTask(space, "Single task", "30.0"));

        taskExecutionRepository.save(new TaskExecution(sharedTask, space, Set.of(user1, user2)));
        taskExecutionRepository.save(new TaskExecution(singleTask, space, Set.of(user1)));

        List<Long> participantIds = participantRepository
            .findParticipantsWithScores(
                space.getId(),
                PageRequest.of(0, 10, Sort.by(Sort.Direction.DESC, "score")))
            .getContent()
            .stream()
            .map(participant -> participant.id())
            .toList();

        assertThat(participantIds).containsExactly(user1.getId(), user2.getId(), user3.getId());
    }

    @Test
    void filtersParticipantsByNameAndSpaceUserRole() {
        Space space = new Space("Casa");
        space.setActive(true);
        space = spaceRepository.save(space);

        User admin = userRepository.save(createUser("Jon Admin", "filter-admin@email.com"));
        User participant = userRepository.save(createUser("Jon Participant", "filter-participant@email.com"));
        User otherParticipant = userRepository.save(createUser("Mary Participant", "filter-other@email.com"));

        saveMembership(space, admin, SpaceUserRoleEnum.ROLE_SPACE_ADMIN, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(space, participant, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(space, otherParticipant, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT, SpaceMembershipStatusEnum.APPROVED);

        List<ParticipantDTO> participants = participantRepository
            .findParticipantsWithScores(
                space.getId(),
                PageRequest.of(0, 10, Sort.by(Sort.Direction.ASC, "id")),
                "jon",
                SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT)
            .getContent();

        assertThat(participants).singleElement().satisfies(foundParticipant -> {
            assertThat(foundParticipant.id()).isEqualTo(participant.getId());
            assertThat(foundParticipant.name()).isEqualTo("Jon Participant");
            assertThat(foundParticipant.spaceUserRole()).isEqualTo(SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT);
            assertThat(foundParticipant.score()).isEqualByComparingTo("0");
        });
    }

    @Test
    void filtersParticipantScoresByTaskCategory() {
        Space space = new Space("Casa");
        space.setActive(true);
        space = spaceRepository.save(space);

        User user1 = userRepository.save(createUser("User 1", "category-score1@email.com"));
        User user2 = userRepository.save(createUser("User 2", "category-score2@email.com"));

        saveApprovedParticipant(space, user1);
        saveApprovedParticipant(space, user2);

        Task operationalTask = taskRepository.save(
            createTask(space, "Operational task", "90.0", TaskCategoryEnum.OPERATIONAL));
        Task financialTask = taskRepository.save(
            createTask(space, "Financial task", "30.0", TaskCategoryEnum.FINANCIAL));

        taskExecutionRepository.save(new TaskExecution(operationalTask, space, Set.of(user1)));
        taskExecutionRepository.save(new TaskExecution(financialTask, space, Set.of(user1, user2)));

        Map<Long, BigDecimal> scoresByUserId = participantRepository
            .findParticipantsWithScores(
                space.getId(),
                PageRequest.of(0, 10, Sort.by(Sort.Direction.ASC, "id")),
                null,
                null,
                TaskCategoryEnum.FINANCIAL)
            .getContent()
            .stream()
            .collect(Collectors.toMap(ParticipantDTO::id, ParticipantDTO::score));

        assertThat(scoresByUserId.get(user1.getId())).isEqualByComparingTo("15.0");
        assertThat(scoresByUserId.get(user2.getId())).isEqualByComparingTo("15.0");
    }

    @Test
    void findsApprovedUsersByIdsForAnySpaceRole() {
        Space space = new Space("Casa");
        space.setActive(true);
        space = spaceRepository.save(space);

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

    private User createUser(String name, String email) {
        User user = new User(name, email, "password", LocalDate.of(2000, 1, 1));
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }

    private Task createTask(Space space, String description, String score) {
        return createTask(space, description, score, TaskCategoryEnum.OPERATIONAL);
    }

    private Task createTask(
        Space space, String description, String score, TaskCategoryEnum taskCategory) {
        Task task = new Task();
        task.setSpace(space);
        task.setDescription(description);
        task.setScore(new BigDecimal(score));
        task.setCategory(taskCategory);
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
