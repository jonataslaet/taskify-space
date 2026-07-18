package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.Task;
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

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

@DataJpaTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:task-service-test;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
    "spring.jpa.hibernate.ddl-auto=create-drop"
})
class TaskServiceJpaTests {

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private SpaceRepository spaceRepository;

    @Autowired
    private SpaceMembershipRepository spaceMembershipRepository;

    @Autowired
    private UserRepository userRepository;

    private TaskService taskService;

    @BeforeEach
    void setUp() {
        taskService = new TaskService(
            taskRepository,
            mock(UserService.class),
            mock(SpaceService.class),
            mock(SpaceMembershipService.class),
            mock(TaskExecutionRepository.class),
            mock(FeatureAccessService.class));
    }

    @Test
    void findAllReturnsOnlyTasksFromApprovedUserSpaces() {
        User authenticatedUser = userRepository.save(createUser("user@example.com"));
        User otherUser = userRepository.save(createUser("other@example.com"));

        Space approvedSpace = spaceRepository.save(createSpace("Approved"));
        Space pendingSpace = spaceRepository.save(createSpace("Pending"));
        Space otherUserSpace = spaceRepository.save(createSpace("Other"));

        saveMembership(approvedSpace, authenticatedUser, SpaceMembershipStatusEnum.APPROVED);
        saveMembership(pendingSpace, authenticatedUser, SpaceMembershipStatusEnum.PENDING);
        saveMembership(otherUserSpace, otherUser, SpaceMembershipStatusEnum.APPROVED);

        Task visibleTask = taskRepository.save(createTask(approvedSpace, "Visible task"));
        taskRepository.save(createTask(pendingSpace, "Pending task"));
        taskRepository.save(createTask(otherUserSpace, "Other user task"));

        Page<TaskRecordDTO> tasks = taskService.findAll(null, Pageable.unpaged(), authenticatedUser);

        List<Long> taskIds = tasks.getContent().stream().map(TaskRecordDTO::id).toList();
        assertThat(taskIds).containsExactly(visibleTask.getId());
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

    private Task createTask(Space space, String description) {
        Task task = new Task();
        task.setSpace(space);
        task.setDescription(description);
        task.setScore(BigDecimal.TEN);
        task.setActive(true);
        return task;
    }

    private void saveMembership(Space space, User user, SpaceMembershipStatusEnum status) {
        SpaceMembership spaceMembership =
            new SpaceMembership(user, space, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT);
        spaceMembership.setSpaceMembershipStatusEnum(status);
        spaceMembershipRepository.save(spaceMembership);
    }
}
