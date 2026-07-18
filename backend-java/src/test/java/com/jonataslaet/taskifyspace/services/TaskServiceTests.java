package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskServiceTests {

    @Mock
    private TaskRepository taskRepository;

    @Mock
    private UserService userService;

    @Mock
    private SpaceService spaceService;

    @Mock
    private SpaceMembershipService spaceMembershipService;

    @Mock
    private TaskExecutionRepository taskExecutionRepository;

    @Mock
    private FeatureAccessService featureAccessService;

    private TaskService taskService;

    @BeforeEach
    void setUp() {
        taskService = new TaskService(
            taskRepository,
            userService,
            spaceService,
            spaceMembershipService,
            taskExecutionRepository,
            featureAccessService);
    }

    @Test
    void getTaskByIdValidatesApprovedParticipationInTaskSpace() {
        User authenticatedUser = createUser(1L);
        Space space = new Space("Space");
        space.setId(10L);

        Task task = new Task();
        task.setId(20L);
        task.setSpace(space);
        task.setDescription("Task");
        task.setScore(BigDecimal.TEN);
        task.setActive(true);

        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));

        TaskRecordDTO foundTask = taskService.getTaskById(authenticatedUser, task.getId());

        assertThat(foundTask.id()).isEqualTo(task.getId());
        verify(spaceService).validateApprovedParticipation(authenticatedUser, space);
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
