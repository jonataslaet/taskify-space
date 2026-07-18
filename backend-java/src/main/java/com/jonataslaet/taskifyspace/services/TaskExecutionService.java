package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.*;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;

@Service
@Transactional(readOnly = true)
public class TaskExecutionService {

    private final TaskRepository taskRepository;
    private final UserService userService;
    private final SpaceService spaceService;
    private final SpaceMembershipService spaceMembershipService;
    private final TaskExecutionRepository taskExecutionRepository;

    public TaskExecutionService(TaskRepository taskRepository, UserService userService,
                                SpaceService spaceService, SpaceMembershipService spaceMembershipService,
                                TaskExecutionRepository taskExecutionRepository) {
        this.taskRepository = taskRepository;
        this.userService = userService;
        this.spaceService = spaceService;
        this.spaceMembershipService = spaceMembershipService;
        this.taskExecutionRepository = taskExecutionRepository;
    }

    @Transactional
    public void removeCurrentUserFromTaskExecution(Long taskExecutionId, User authenticatedUser) {

        TaskExecution taskExecution = getTaskExecutionEntity(taskExecutionId);

        Space space = taskExecution.getSpace();
        spaceService.validateActiveParticipation(
            authenticatedUser, space, Set.of(SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT));

        taskExecutionRepository.removeExecutorsFromTaskExecution(taskExecution, Set.of(authenticatedUser.getId()));
    }

    private TaskExecution getTaskExecutionEntity(Long taskExecutionId) {
        return taskExecutionRepository.findById(taskExecutionId).orElseThrow(
            () -> new ResourceNotFoundException("TaskExecution with id " + taskExecutionId + " not found"));
    }

}
