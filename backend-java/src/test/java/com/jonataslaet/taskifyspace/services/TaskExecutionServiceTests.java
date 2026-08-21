package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskExecutionDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskExecutionServiceTests {

    private static final Set<SpaceUserRoleEnum> TASK_EXECUTION_ACCESS_ROLES = Set.of(
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
    void findAllByTaskReturnsPagedExecutionDtos() {
        User authenticatedUser = createUser(1L);
        User firstExecutor = createUser(2L);
        firstExecutor.setName("Maria");
        User secondExecutor = createUser(3L);
        secondExecutor.setName("Ana");
        Space space = createSpace(10L);
        Task task = createTask(20L, new BigDecimal("15.50"));
        TaskExecution taskExecution = new TaskExecution(task, space, Set.of(firstExecutor, secondExecutor));
        taskExecution.setId(100L);
        taskExecution.setCreatedAt(Instant.parse("2026-08-21T14:30:00Z"));
        Pageable pageable = PageRequest.of(0, 10);

        when(spaceService.getSpaceEntity(space.getId())).thenReturn(space);
        when(taskExecutionRepository.findAllBySpaceIdAndTaskId(space.getId(), task.getId(), pageable))
            .thenReturn(new PageImpl<>(List.of(taskExecution), pageable, 1));

        Page<TaskExecutionDTO> taskExecutions =
            taskExecutionService.findAllByTask(space.getId(), task.getId(), pageable, authenticatedUser);

        verify(spaceService).validateActiveParticipation(authenticatedUser, space, TASK_EXECUTION_ACCESS_ROLES);
        assertThat(taskExecutions.getTotalElements()).isEqualTo(1);
        assertThat(taskExecutions.getContent())
            .singleElement()
            .satisfies(taskExecutionDTO -> {
                assertThat(taskExecutionDTO.id()).isEqualTo(taskExecution.getId());
                assertThat(taskExecutionDTO.executionDate()).isEqualTo("21/08/2026 14:30");
                assertThat(taskExecutionDTO.score()).isEqualByComparingTo("15.50");
                assertThat(taskExecutionDTO.executorNames()).containsExactly("Ana", "Maria");
            });
    }

    @Test
    void removeCurrentUserFromTaskExecutionRemovesExecutorWhenExecutionBelongsToSpace() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        TaskExecution taskExecution = createTaskExecution(100L, space, authenticatedUser);

        when(taskExecutionRepository.findById(taskExecution.getId())).thenReturn(Optional.of(taskExecution));

        taskExecutionService.removeCurrentUserFromTaskExecution(space.getId(), taskExecution.getId(), authenticatedUser);

        verify(spaceService).validateActiveParticipation(
            authenticatedUser, space, TASK_EXECUTION_ACCESS_ROLES);
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
            authenticatedUser, taskExecutionSpace, TASK_EXECUTION_ACCESS_ROLES);
        verify(taskExecutionRepository, never()).removeExecutorsFromTaskExecution(
            taskExecution, Set.of(authenticatedUser.getId()));
    }

    private Task createTask(Long id, BigDecimal score) {
        Task task = new Task();
        task.setId(id);
        task.setScore(score);
        return task;
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
