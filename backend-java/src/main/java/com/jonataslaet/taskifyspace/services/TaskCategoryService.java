package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskCategoryRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.TaskCategory;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.TaskCategoryMapper;
import com.jonataslaet.taskifyspace.repositories.TaskCategoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;
import java.util.Set;

import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
import static com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_MANAGER;

@Service
@Transactional(readOnly = true)
public class TaskCategoryService {

    private final TaskCategoryRepository taskCategoryRepository;
    private final SpaceService spaceService;
    private final FeatureAccessService featureAccessService;

    public TaskCategoryService(TaskCategoryRepository taskCategoryRepository, SpaceService spaceService,
        FeatureAccessService featureAccessService) {
        this.taskCategoryRepository = taskCategoryRepository;
        this.spaceService = spaceService;
        this.featureAccessService = featureAccessService;
    }

    @Transactional
    public TaskCategoryRecordDTO createTaskCategory(Long spaceId,
        User authenticatedUser, TaskCategoryRecordDTO taskCategoryRecordDTO) {
        Space space = spaceService.getSpaceEntity(spaceId);
        featureAccessService.requireFeatureWithUsageLock(authenticatedUser, FeatureEnum.CREATE_TASK_CATEGORY, space);
        spaceService.validActiveSpace(space);
        spaceService.validateActiveParticipation(authenticatedUser, space, Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        validateNotDuplicated(spaceId, null, taskCategoryRecordDTO.name());

        TaskCategory taskCategory = new TaskCategory(taskCategoryRecordDTO.name(), space, authenticatedUser);
        return TaskCategoryMapper.toDTO(taskCategoryRepository.save(taskCategory));
    }

    public List<TaskCategoryRecordDTO> searchTaskCategoriesByName(Long spaceId, User authenticatedUser, String name) {
        Space space = spaceService.getSpaceEntity(spaceId);
        spaceService.validateApprovedParticipation(authenticatedUser, space);
        return taskCategoryRepository.searchTaskCategoriesByName(spaceId, Objects.requireNonNullElse(name, ""));
    }

    @Transactional
    public TaskCategoryRecordDTO updateTaskCategory(Long spaceId, User authenticatedUser, Long taskCategoryId,
        TaskCategoryRecordDTO taskCategoryRecordDTO) {
        TaskCategory taskCategory = getTaskCategoryEntity(spaceId, taskCategoryId);
        Space space = taskCategory.getSpace();
        spaceService.validateActiveParticipation(authenticatedUser, space, Set.of(ROLE_SPACE_ADMIN, ROLE_SPACE_MANAGER));
        validateNotDuplicated(spaceId, taskCategoryId, taskCategoryRecordDTO.name());

        taskCategory.setName(taskCategoryRecordDTO.name());
        return TaskCategoryMapper.toDTO(taskCategoryRepository.save(taskCategory));
    }

    @Transactional
    public void deleteTaskCategory(Long spaceId, User authenticatedUser, Long taskCategoryId) {
        TaskCategory taskCategory = getTaskCategoryEntity(spaceId, taskCategoryId);
        spaceService.validateActiveParticipation(authenticatedUser, taskCategory.getSpace(), Set.of(ROLE_SPACE_ADMIN));
        taskCategoryRepository.delete(taskCategory);
    }

    private TaskCategory getTaskCategoryEntity(Long spaceId, Long taskCategoryId) {
        return taskCategoryRepository.findByIdAndSpaceId(taskCategoryId, spaceId)
            .orElseThrow(() -> new ResourceNotFoundException("Categoria de tarefa nao encontrada nesse espaco"));
    }

    private void validateNotDuplicated(Long spaceId, Long taskCategoryId, String name) {
        boolean duplicated = Objects.isNull(taskCategoryId)
            ? taskCategoryRepository.existsBySpaceIdAndNameIgnoreCase(spaceId, name)
            : taskCategoryRepository.existsBySpaceIdAndNameIgnoreCaseAndIdNot(spaceId, name, taskCategoryId);
        if (duplicated) {
            throw new DuplicationException("Essa categoria de tarefa ja existe neste espaco");
        }
    }
}
