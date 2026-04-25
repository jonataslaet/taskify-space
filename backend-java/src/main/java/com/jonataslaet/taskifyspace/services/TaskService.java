package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.*;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.TaskMapper;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class TaskService {

    private final TaskRepository taskRepository;
    private final UserService userService;
    private final SpaceService spaceService;
    private final SpaceMembershipService spaceMembershipService;
    private final TaskExecutionRepository taskExecutionRepository;

    public TaskService(TaskRepository taskRepository, UserService userService,
                       SpaceService spaceService, SpaceMembershipService spaceMembershipService,
                       TaskExecutionRepository taskExecutionRepository) {
        this.taskRepository = taskRepository;
        this.userService = userService;
        this.spaceService = spaceService;
        this.spaceMembershipService = spaceMembershipService;
        this.taskExecutionRepository = taskExecutionRepository;
    }

    @Transactional
    public TaskRecordDTO createTask(User authenticatedUser, TaskRecordDTO taskRecordDTO) {
        Space space = spaceService.getSpaceEntity(taskRecordDTO.spaceId());
        validActiveSpace(space);
        if (!hasPermissionToCreateTask(authenticatedUser, space)) {
            throw new ForbiddenException("Esse usuário não tem permissão para criar tarefa nesse espaço");
        }

        if (taskRepository.existsBySpaceIdAndDescriptionIgnoreCase(
            taskRecordDTO.spaceId(), taskRecordDTO.description())) {
            throw new DuplicationException("Essa tarefa já existe");
        }
        Task task = TaskMapper.toEntity(taskRecordDTO, space, authenticatedUser);
        task.setActive(false);
        return TaskMapper.toDTO(taskRepository.save(task));
    }

    @Transactional
    public void finishTask(Long taskId, Long spaceId, User authenticatedUser, Set<Long> executorsIds) {

        Space space = spaceService.getSpaceEntity(spaceId);
        validActiveSpace(space);

        validateParticipation(authenticatedUser, space);

        Task task = getTaskEntity(taskId);
        validActiveTask(task);

        includeAuthenticatedUser(authenticatedUser, executorsIds);

        TaskExecution taskExecution = getTaskExecution(task, space, executorsIds);
        taskExecutionRepository.save(taskExecution);
    }

    private void includeAuthenticatedUser(User authenticatedUser, Set<Long> executorsIds) {
        if (Objects.isNull(executorsIds)) executorsIds = new HashSet<>();
        executorsIds.add(authenticatedUser.getId());
    }

    private TaskExecution getTaskExecution(Task task, Space space, Set<Long> usersIds) {
        Set<User> users = spaceMembershipService.getParticipantsBySpaceAndUsersIds(space, usersIds);;
        return new TaskExecution(task, space, users);
    }

    private void validActiveTask(Task task) {
        if (!task.isActive()) {
            throw new ForbiddenException("Essa tarefa está inativa no momento");
        }
    }

    private void validActiveSpace(Space task) {
        if (!task.getActive()) {
            throw new ForbiddenException("Esse espaço está inativo no momento");
        }
    }

    private void validateParticipation(User authenticatedUser, Space space) {
        space.getSpaceMemberships().stream().filter(f ->
            f.getSpaceUserRole().equals(SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT) &&
            f.getUser().getId().equals(authenticatedUser.getId())).findFirst().orElseThrow(() ->
            new ForbiddenException("Esse usuário não participa desse espaço"));

    }

    private boolean hasPermissionToCreateTask(User authenticatedUser, Space space) {
        Set<SpaceMembership> spaceMemberships = spaceMembershipService.getSpaceMemberships(authenticatedUser, space);
        for (SpaceMembership spaceMembership: spaceMemberships) {
            if (List.of(SpaceUserRoleEnum.ROLE_SPACE_ADMIN, SpaceUserRoleEnum.ROLE_SPACE_MANAGER)
                .contains(spaceMembership.getSpaceUserRole())) {
                return true;
            }
        }
        return false;
    }

    public TaskRecordDTO getTaskById(Long TaskId) {
        Task task = getTaskEntity(TaskId);
        return TaskMapper.toDTO(task);
    }

    public Task getTaskEntity(Long TaskId) {
        return taskRepository.findById(TaskId).orElseThrow(() ->
            new ResourceNotFoundException("Tarefa não encontrada"));
    }

    @Transactional
    public TaskRecordDTO updateTask(Long TaskId, TaskRecordDTO taskRecordDTO) {
        Task taskEntity = getTaskEntity(TaskId);
        if (!taskEntity.getDescription().equalsIgnoreCase(taskRecordDTO.description())) {
            if (taskRepository.existsBySpaceIdAndDescriptionIgnoreCase(taskRecordDTO.spaceId(), taskRecordDTO.description())) {
                throw new DuplicationException("Essa tarefa já existe");
            }
        }
        BeanUtils.copyProperties(taskRecordDTO, taskEntity, "id");
        return TaskMapper.toDTO(taskRepository.save(taskEntity));
    }

    @Transactional
    public void deleteTask(Long TaskId) {
        if (!taskRepository.existsById(TaskId)) {
            throw new ResourceNotFoundException("Tarefa não encontrada");
        }
        taskRepository.deleteById(TaskId);
    }

    @Transactional
    public void toggleActiveTask(Long taskId) {
        Task task = getTaskEntity(taskId);
        task.setActive(!task.isActive());
        taskRepository.save(task);
    }

    public Page<@NonNull TaskRecordDTO> findAll(Specification<@NonNull Task> TaskSpecification, Pageable pageable) {
        return taskRepository.findAll(TaskSpecification, pageable).map(TaskMapper::toDTO);
    }
}
