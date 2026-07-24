package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.TaskExecution;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskExecutionServiceTests {

    private static final Set<SpaceUserRoleEnum> TASK_EXECUTION_SELF_REMOVAL_ROLES = Set.of(
        SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT,
        SpaceUserRoleEnum.ROLE_SPACE_MANAGER,
        SpaceUserRoleEnum.ROLE_SPACE_ADMIN
    );

    @Mock
    private SpaceService spaceService;

    @Mock
    private TaskExecutionRepository taskExecutionRepository;

    private TaskExecutionService taskExecutionService;

    @BeforeEach
    void setUp() {
        taskExecutionService = new TaskExecutionService(
            spaceService,
            taskExecutionRepository);
    }

    @Test
    void removeCurrentUserFromTaskExecutionRemovesExecutorWhenExecutionBelongsToSpace() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        TaskExecution taskExecution = createTaskExecution(100L, space, authenticatedUser);

        when(taskExecutionRepository.findById(taskExecution.getId())).thenReturn(Optional.of(taskExecution));

        taskExecutionService.removeCurrentUserFromTaskExecution(space.getId(), taskExecution.getId(), authenticatedUser);

        verify(spaceService).validateActiveParticipation(
            authenticatedUser, space, TASK_EXECUTION_SELF_REMOVAL_ROLES);
        verify(taskExecutionRepository).removeExecutorsFromTaskExecution(
            taskExecution, Set.of(authenticatedUser.getId()));
    }

    @Test
    void removeCurrentUserFromTaskExecutionPreventsExecutionFromAnotherSpace() {
        User authenticatedUser = createUser(1L);
        Space taskExecutionSpace = createSpace(11L);
        TaskExecution taskExecution = createTaskExecution(100L, taskExecutionSpace, authenticatedUser);

        when(taskExecutionRepository.findById(taskExecution.getId())).thenReturn(Optional.of(taskExecution));

        assertThatThrownBy(() -> taskExecutionService.removeCurrentUserFromTaskExecution(
            10L, taskExecution.getId(), authenticatedUser))
            .isInstanceOf(ResourceNotFoundException.class)
            .hasMessage("TaskExecution nao encontrada nesse espaco");

        verify(spaceService, never()).validateActiveParticipation(
            authenticatedUser, taskExecutionSpace, TASK_EXECUTION_SELF_REMOVAL_ROLES);
        verify(taskExecutionRepository, never()).removeExecutorsFromTaskExecution(
            taskExecution, Set.of(authenticatedUser.getId()));
    }

    private TaskExecution createTaskExecution(Long id, Space space, User executor) {
        TaskExecution taskExecution = new TaskExecution(null, space, Set.of(executor));
        taskExecution.setId(id);
        return taskExecution;
    }

    private Space createSpace(Long id) {
        Space space = new Space("Space " + id);
        space.setId(id);
        space.setActive(true);
        return space;
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
