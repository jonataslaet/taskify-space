package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.*;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.TaskMapper;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.validations.TaskSchedulerValidator;
import jakarta.persistence.criteria.JoinType;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.APPROVED;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_MANAGER;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT;

@Service
@Transactional(readOnly = true)
public class TaskService {

    private final TaskRepository taskRepository;
    private final SpaceService spaceService;
    private final SpaceMembershipService spaceMembershipService;
    private final TaskExecutionRepository taskExecutionRepository;
    private final FeatureAccessService featureAccessService;
    private final TaskSchedulerValidator taskSchedulerValidator;

    public TaskService(TaskRepository taskRepository,
                       SpaceService spaceService, SpaceMembershipService spaceMembershipService,
                       TaskExecutionRepository taskExecutionRepository, FeatureAccessService featureAccessService,
                       TaskSchedulerValidator taskSchedulerValidator) {
        this.taskRepository = taskRepository;
        this.spaceService = spaceService;
        this.spaceMembershipService = spaceMembershipService;
        this.taskExecutionRepository = taskExecutionRepository;
        this.featureAccessService = featureAccessService;
        this.taskSchedulerValidator = taskSchedulerValidator;
    }

    @Transactional
    public TaskRecordDTO createTask(Long spaceId, User authenticatedUser, TaskRecordDTO taskRecordDTO) {
        Space space = spaceService.getSpaceEntity(spaceId);
        featureAccessService.requireFeatureWithUsageLock(authenticatedUser, FeatureEnum.CREATE_TASK, space);
        spaceService.validActiveSpace(space);
        spaceService.validateActiveParticipation(authenticatedUser, space, Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));

        if (taskRepository.existsBySpaceIdAndDescriptionIgnoreCase(
            taskRecordDTO.spaceId(), taskRecordDTO.description())) {
            throw new DuplicationException("Essa tarefa já existe");
        }
        Task task = TaskMapper.toEntity(taskRecordDTO, space, authenticatedUser);
        taskSchedulerValidator.validate(task.getSchedule());
        task.setActive(false);
        return TaskMapper.toDTO(taskRepository.save(task));
    }

    @Transactional
    public void finishTask(Long taskId, Long spaceId, User authenticatedUser, Set<Long> executorsIds) {
        finishTask(taskId, spaceId, authenticatedUser, executorsIds, null);
    }

    @Transactional
    public void finishTask(Long taskId, Long spaceId, User authenticatedUser, Set<Long> executorsIds,
        LocalDateTime executionDate) {

        Space space = spaceService.getSpaceEntity(spaceId);
        spaceService.validActiveSpace(space);
        spaceService.validateActiveParticipation(
            authenticatedUser, space, Set.of(ROLE_SPACE_PARTICIPANT, ROLE_SPACE_MANAGER, ROLE_SPACE_ADMIN));

        Set<Long> executorIds = includeAuthenticatedUserId(executorsIds, authenticatedUser.getId());
        Set<SpaceMembership> approvedSpaceMemberships = getApprovedSpaceMemberships(space.getSpaceMemberships());

        Task task = getTaskEntity(taskId);
        validateTaskBelongsToSpace(task, space);
        validActiveTask(task);

        TaskExecution taskExecution = getTaskExecution(task, space,
            getApprovedExecutors(executorIds, approvedSpaceMemberships), executionDate);
        taskExecutionRepository.save(taskExecution);
    }

    private Set<Long> getApprovedExecutors(Set<Long> executorsIds, Set<SpaceMembership> approvedSpaceMemberships) {
        return approvedSpaceMemberships
            .stream().filter(s -> executorsIds.contains(s.getUser().getId()))
            .map(s -> s.getUser().getId()).collect(Collectors.toSet());
    }

    private Set<SpaceMembership> getApprovedSpaceMemberships(Set<SpaceMembership> spaceMembershipsExecutors) {
        return spaceMembershipsExecutors.stream().filter(
            s -> s.getSpaceMembershipStatusEnum().equals(APPROVED)).collect(Collectors.toSet());
    }

    private Set<Long> includeAuthenticatedUserId(Set<Long> executorsIds, Long authenticatedUserId) {
        Set<Long> executorIds = Objects.nonNull(executorsIds) ? new HashSet<>(executorsIds) : new HashSet<>();
        executorIds.add(authenticatedUserId);
        return executorIds;
    }

    private void validateTaskBelongsToSpace(Task task, Space space) {
        Long taskSpaceId = Objects.nonNull(task.getSpace()) ? task.getSpace().getId() : null;
        if (!Objects.equals(taskSpaceId, space.getId())) {
            throw new ResourceNotFoundException("Tarefa nao encontrada nesse espaco");
        }
    }

    private TaskExecution getTaskExecution(Task task, Space space, Set<Long> usersIds, LocalDateTime executionDate) {
        Set<User> users = spaceMembershipService.getApprovedMembersBySpaceAndUsersIds(space, usersIds);
        TaskExecution taskExecution = new TaskExecution(task, space, users);
        if (Objects.nonNull(executionDate)) taskExecution.setCreatedAt(executionDate.toInstant(ZoneOffset.UTC));
        else taskExecution.setCreatedAt(LocalDateTime.now().toInstant(ZoneOffset.UTC));
        return taskExecution;
    }

    private void validActiveTask(Task task) {
        if (!task.isActive()) throw new ForbiddenException("Essa tarefa está inativa no momento");
    }

    public TaskRecordDTO getTaskById(User authenticatedUser, Long TaskId) {
        Task task = getTaskEntity(TaskId);
        spaceService.validateApprovedParticipation(authenticatedUser, task.getSpace());
        return TaskMapper.toDTO(task);
    }

    public Task getTaskEntity(Long TaskId) {
        return taskRepository.findById(TaskId).orElseThrow(() -> new ResourceNotFoundException("Tarefa não encontrada"));
    }

    @Transactional
    public TaskRecordDTO updateTask(User authenticatedUser, Long TaskId, TaskRecordDTO taskRecordDTO) {
        Task taskEntity = getTaskEntity(TaskId);
        Space space = taskEntity.getSpace();
        spaceService.validateActiveParticipation(authenticatedUser, space, Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        if (Objects.nonNull(taskRecordDTO.description())
            && !taskEntity.getDescription().equalsIgnoreCase(taskRecordDTO.description())) {
            if (taskRepository.existsBySpaceIdAndDescriptionIgnoreCase(space.getId(), taskRecordDTO.description())) {
                throw new DuplicationException("Essa tarefa já existe");
            }
            taskEntity.setDescription(taskRecordDTO.description());
        }

        if (Objects.nonNull(taskRecordDTO.score())) taskEntity.setScore(taskRecordDTO.score());
        if (Objects.nonNull(taskRecordDTO.category())) taskEntity.setCategory(taskRecordDTO.category());
        TaskMapper.applySchedule(taskEntity, taskRecordDTO.schedule());
        taskSchedulerValidator.validate(taskEntity.getSchedule());
        return TaskMapper.toDTO(taskRepository.save(taskEntity));
    }

    @Transactional
    public void deleteTask(User authenticatedUser, Long TaskId) {
        Task task = getTaskEntity(TaskId);
        spaceService.validateActiveParticipation(authenticatedUser, task.getSpace(), Set.of(ROLE_SPACE_ADMIN));
        taskExecutionRepository.deleteByTaskId(TaskId);
        taskRepository.deleteById(TaskId);
    }

    @Transactional
    public void toggleActiveTask(User authenticatedUser, Long taskId) {
        Task task = getTaskEntity(taskId);
        spaceService.validateActiveParticipation(authenticatedUser, task.getSpace(), Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        task.setActive(!task.isActive());
        taskRepository.save(task);
    }

    public Page<@NonNull TaskRecordDTO> findAll(
        Long spaceId, Specification<@NonNull Task> taskSpecification, Pageable pageable, User authenticatedUser) {

        Specification<@NonNull Task> authenticatedUserTasks = (root, query, criteriaBuilder) -> {
            query.distinct(true);
            var spaceMembershipJoin = root.join("space").join("spaceMemberships");
            return criteriaBuilder.and(
                criteriaBuilder.equal(root.get("space").get("id"), spaceId),
                criteriaBuilder.equal(spaceMembershipJoin.get("user").get("id"), authenticatedUser.getId()),
                criteriaBuilder.equal(spaceMembershipJoin.get("spaceMembershipStatusEnum"), APPROVED)
            );
        };
        Specification<@NonNull Task> finalSpecification = authenticatedUserTasks;
        if (Objects.nonNull(taskSpecification)) finalSpecification = authenticatedUserTasks.and(taskSpecification);

        return taskRepository.findAll(finalSpecification, pageable).map(TaskMapper::toDTO);
    }

    public Page<@NonNull TaskRecordDTO> findAllScheduledTasks(Long spaceId,
        Specification<@NonNull Task> taskSpecification, Pageable pageable, User authenticatedUser) {

        LocalDate currentDate = LocalDate.now();

        Specification<@NonNull Task> scheduledTasksSpecification =
            (root, query, criteriaBuilder) -> {
                query.distinct(true);

                var scheduleJoin = root.join("schedule", JoinType.INNER);

                var localDatesJoin = scheduleJoin.join("localDates", JoinType.LEFT);

                var oncePredicate = criteriaBuilder.and(
                    criteriaBuilder.equal(scheduleJoin.get("frequenceEnum"), FrequenceEnum.ONCE),
                    criteriaBuilder.equal(localDatesJoin, currentDate)
                );

                var dailyPredicate = criteriaBuilder.equal(scheduleJoin.get("frequenceEnum"), FrequenceEnum.DAILY);

                var localDateDayOfMonth = criteriaBuilder.function("date_part", Double.class,
                    criteriaBuilder.literal("day"), localDatesJoin
                );

                var monthlyPredicate = criteriaBuilder.and(
                    criteriaBuilder.equal(scheduleJoin.get("frequenceEnum"), FrequenceEnum.MONTHLY),
                    criteriaBuilder.equal(localDateDayOfMonth, (double) currentDate.getDayOfMonth())
                );

                var localDateDayOfWeek = criteriaBuilder.function("date_part", Double.class,
                    criteriaBuilder.literal("isodow"), localDatesJoin);

                var weeklyPredicate = criteriaBuilder.and(
                    criteriaBuilder.equal(scheduleJoin.get("frequenceEnum"), FrequenceEnum.WEEKLY),
                    criteriaBuilder.equal(localDateDayOfWeek, (double) currentDate.getDayOfWeek().getValue()));

                var localDateMonth = criteriaBuilder.function("date_part", Double.class,
                    criteriaBuilder.literal("month"), localDatesJoin);

                var yearlyPredicate = criteriaBuilder.and(
                    criteriaBuilder.equal(scheduleJoin.get("frequenceEnum"), FrequenceEnum.YEARLY),
                    criteriaBuilder.equal(localDateMonth, (double) currentDate.getMonthValue()),
                    criteriaBuilder.equal(localDateDayOfMonth, (double) currentDate.getDayOfMonth())
                );

                var scheduledForCurrentDatePredicate = criteriaBuilder.or(
                    oncePredicate, dailyPredicate, weeklyPredicate, monthlyPredicate, yearlyPredicate);

                var activePredicate = criteriaBuilder.isTrue(root.get("active"));

                var spacePredicate = criteriaBuilder.equal(root.get("space").get("id"), spaceId);

                var spaceMembershipJoin = root.join("space").join("spaceMemberships");

                var spaceMembershipJoinPredicate = criteriaBuilder.equal(
                    spaceMembershipJoin.get("spaceMembershipStatusEnum"), APPROVED);

                var authenticatedUserMembershipPredicate =
                    criteriaBuilder.equal(spaceMembershipJoin.get("user").get("id"), authenticatedUser.getId());

                return criteriaBuilder.and(activePredicate, spacePredicate, scheduledForCurrentDatePredicate,
                    authenticatedUserMembershipPredicate, spaceMembershipJoinPredicate);
            };

        Specification<@NonNull Task> finalSpecification =  Objects.nonNull(taskSpecification) ?
            scheduledTasksSpecification.and(taskSpecification) : scheduledTasksSpecification;

        return taskRepository.findAll(finalSpecification, pageable).map(TaskMapper::toDTO);
    }
}
