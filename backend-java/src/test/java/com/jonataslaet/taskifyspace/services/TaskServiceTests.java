package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskScheduleRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.TaskExecution;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.validations.TaskSchedulerValidator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.Set;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.APPROVED;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskServiceTests {

    @Mock
    private TaskRepository taskRepository;

    @Mock
    private SpaceService spaceService;

    @Mock
    private SpaceMembershipService spaceMembershipService;

    @Mock
    private TaskExecutionRepository taskExecutionRepository;

    @Mock
    private FeatureAccessService featureAccessService;

    @Mock
    private TaskSchedulerValidator taskSchedulerValidator;

    private TaskService taskService;

    @BeforeEach
    void setUp() {
        taskService = new TaskService(
            taskRepository,
            spaceService,
            spaceMembershipService,
            taskExecutionRepository,
            featureAccessService,
            taskSchedulerValidator);
    }

    @Test
    void getTaskByIdValidatesApprovedParticipationInTaskSpace() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        Task task = createTask(20L, space);

        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));

        TaskRecordDTO foundTask = taskService.getTaskById(authenticatedUser, task.getId());

        assertThat(foundTask.id()).isEqualTo(task.getId());
        verify(spaceService).validateApprovedParticipation(authenticatedUser, space);
    }

    @Test
    void finishTaskWithNullExecutorIdsIncludesAuthenticatedUser() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        Task task = createTask(20L, space);
        addApprovedParticipant(space, authenticatedUser);

        when(spaceService.getSpaceEntity(space.getId())).thenReturn(space);
        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));
        when(spaceMembershipService.getApprovedMembersBySpaceAndUsersIds(
            eq(space), eq(Set.of(authenticatedUser.getId())))).thenReturn(Set.of(authenticatedUser));

        taskService.finishTask(task.getId(), space.getId(), authenticatedUser, null);

        ArgumentCaptor<TaskExecution> taskExecutionCaptor = ArgumentCaptor.forClass(TaskExecution.class);
        verify(taskExecutionRepository).save(taskExecutionCaptor.capture());
        TaskExecution savedTaskExecution = taskExecutionCaptor.getValue();

        assertThat(savedTaskExecution.getTask()).isSameAs(task);
        assertThat(savedTaskExecution.getSpace()).isSameAs(space);
        assertThat(savedTaskExecution.getExecutors()).containsExactly(authenticatedUser);
    }

    @Test
    void finishTaskWithExecutionDateSetsTaskExecutionCreatedAt() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        Task task = createTask(20L, space);
        LocalDateTime executionDate = LocalDateTime.of(2026, 7, 25, 14, 30);
        addApprovedParticipant(space, authenticatedUser);

        when(spaceService.getSpaceEntity(space.getId())).thenReturn(space);
        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));
        when(spaceMembershipService.getApprovedMembersBySpaceAndUsersIds(
            eq(space), eq(Set.of(authenticatedUser.getId())))).thenReturn(Set.of(authenticatedUser));

        taskService.finishTask(task.getId(), space.getId(), authenticatedUser, null, executionDate);

        ArgumentCaptor<TaskExecution> taskExecutionCaptor = ArgumentCaptor.forClass(TaskExecution.class);
        verify(taskExecutionRepository).save(taskExecutionCaptor.capture());

        assertThat(taskExecutionCaptor.getValue().getCreatedAt())
            .isEqualTo(executionDate.toInstant(ZoneOffset.UTC));
    }

    @Test
    void finishTaskIncludesApprovedAdminExecutor() {
        User authenticatedUser = createUser(1L);
        User adminExecutor = createUser(2L);
        User participantExecutor = createUser(3L);
        Space space = createSpace(10L);
        Task task = createTask(20L, space);
        addApprovedMembership(space, authenticatedUser, ROLE_SPACE_PARTICIPANT);
        addApprovedMembership(space, adminExecutor, ROLE_SPACE_ADMIN);
        addApprovedMembership(space, participantExecutor, ROLE_SPACE_PARTICIPANT);
        Set<Long> executorIds = Set.of(adminExecutor.getId(), participantExecutor.getId());
        Set<Long> expectedExecutorIds = Set.of(
            authenticatedUser.getId(), adminExecutor.getId(), participantExecutor.getId());

        when(spaceService.getSpaceEntity(space.getId())).thenReturn(space);
        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));
        when(spaceMembershipService.getApprovedMembersBySpaceAndUsersIds(eq(space), eq(expectedExecutorIds)))
            .thenReturn(Set.of(authenticatedUser, adminExecutor, participantExecutor));

        taskService.finishTask(task.getId(), space.getId(), authenticatedUser, executorIds);

        ArgumentCaptor<TaskExecution> taskExecutionCaptor = ArgumentCaptor.forClass(TaskExecution.class);
        verify(taskExecutionRepository).save(taskExecutionCaptor.capture());

        assertThat(taskExecutionCaptor.getValue().getExecutors())
            .containsExactlyInAnyOrder(authenticatedUser, adminExecutor, participantExecutor);
    }

    @Test
    void finishTaskPreventsTaskFromAnotherSpace() {
        User authenticatedUser = createUser(1L);
        Space requestedSpace = createSpace(10L);
        Space taskSpace = createSpace(11L);
        Task task = createTask(20L, taskSpace);

        when(spaceService.getSpaceEntity(requestedSpace.getId())).thenReturn(requestedSpace);
        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));

        assertThatThrownBy(() -> taskService.finishTask(
            task.getId(), requestedSpace.getId(), authenticatedUser, Set.of()))
            .isInstanceOf(ResourceNotFoundException.class)
            .hasMessage("Tarefa nao encontrada nesse espaco");

        verify(taskExecutionRepository, never()).save(any(TaskExecution.class));
    }

    @Test
    void updateTaskWithPartialPayloadPreservesMissingFields() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        Task task = createTask(20L, space);
        task.setDescription("Original task");
        task.setScore(new BigDecimal("10.0"));
        task.setCategory(TaskCategoryEnum.OPERATIONAL);
        task.setActive(true);
        TaskRecordDTO partialUpdate = new TaskRecordDTO(
            null,
            null,
            null,
            new BigDecimal("20.0"),
            null,
            null,
            null,
            null);

        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));
        when(taskRepository.save(task)).thenReturn(task);

        TaskRecordDTO updatedTask = taskService.updateTask(authenticatedUser, task.getId(), partialUpdate);

        assertThat(updatedTask.description()).isEqualTo("Original task");
        assertThat(updatedTask.score()).isEqualByComparingTo("20.0");
        assertThat(updatedTask.category()).isEqualTo(TaskCategoryEnum.OPERATIONAL);
        assertThat(updatedTask.active()).isTrue();
    }

    @Test
    void createTaskPersistsScheduleFromPayload() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        LocalDate scheduledDate = LocalDate.of(2026, 8, 4);
        TaskRecordDTO taskRecordDTO = new TaskRecordDTO(
            null,
            space.getId(),
            "Scheduled task",
            BigDecimal.TEN,
            TaskCategoryEnum.OPERATIONAL,
            new TaskScheduleRecordDTO(Set.of(scheduledDate), FrequenceEnum.WEEKLY),
            null,
            null);

        when(spaceService.getSpaceEntity(space.getId())).thenReturn(space);
        when(taskRepository.save(any(Task.class))).thenAnswer(invocation -> invocation.getArgument(0));

        TaskRecordDTO createdTask = taskService.createTask(authenticatedUser, taskRecordDTO);

        ArgumentCaptor<Task> taskCaptor = ArgumentCaptor.forClass(Task.class);
        verify(taskRepository).save(taskCaptor.capture());
        Task savedTask = taskCaptor.getValue();

        assertThat(savedTask.getSchedule()).isNotNull();
        assertThat(savedTask.getSchedule().getTask()).isSameAs(savedTask);
        assertThat(savedTask.getSchedule().getLocalDates()).containsExactly(scheduledDate);
        assertThat(savedTask.getSchedule().getFrequenceEnum()).isEqualTo(FrequenceEnum.WEEKLY);
        assertThat(createdTask.schedule().localDates()).containsExactly(scheduledDate);
        assertThat(createdTask.schedule().frequence()).isEqualTo(FrequenceEnum.WEEKLY);
    }

    @Test
    void deleteTaskRemovesExecutionsBeforeDeletingTask() {
        User authenticatedUser = createUser(1L);
        Space space = createSpace(10L);
        Task task = createTask(20L, space);

        when(taskRepository.findById(task.getId())).thenReturn(Optional.of(task));

        taskService.deleteTask(authenticatedUser, task.getId());

        verify(spaceService).validateActiveParticipation(authenticatedUser, space, Set.of(ROLE_SPACE_ADMIN));
        var inOrder = inOrder(taskExecutionRepository, taskRepository);
        inOrder.verify(taskExecutionRepository).deleteByTaskId(task.getId());
        inOrder.verify(taskRepository).deleteById(task.getId());
    }

    private Space createSpace(Long id) {
        Space space = new Space("Space " + id);
        space.setId(id);
        space.setActive(true);
        return space;
    }

    private Task createTask(Long id, Space space) {
        Task task = new Task();
        task.setId(id);
        task.setSpace(space);
        task.setDescription("Task " + id);
        task.setScore(BigDecimal.TEN);
        task.setActive(true);
        return task;
    }

    private void addApprovedParticipant(Space space, User user) {
        addApprovedMembership(space, user, ROLE_SPACE_PARTICIPANT);
    }

    private void addApprovedMembership(Space space, User user, SpaceUserRoleEnum role) {
        SpaceMembership spaceMembership = new SpaceMembership(user, space, role);
        spaceMembership.setSpaceMembershipStatusEnum(APPROVED);
        space.getSpaceMemberships().add(spaceMembership);
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
