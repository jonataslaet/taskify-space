package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.TaskMapper;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class TaskService {

    private final TaskRepository taskRepository;
    private final SpaceService spaceService;

    public TaskService(TaskRepository taskRepository, SpaceService spaceService) {
        this.taskRepository = taskRepository;
        this.spaceService = spaceService;
    }

    @Transactional
    public TaskRecordDTO createTask(TaskRecordDTO taskRecordDTO) {
        Space space = spaceService.getSpaceEntity(taskRecordDTO.spaceId());
//        TODO: If space is not where I am admin, then return forbidden operation
        if (taskRepository.existsBySpaceIdAndDescriptionIgnoreCase(
            taskRecordDTO.spaceId(), taskRecordDTO.description())) {
            throw new DuplicationException("Essa tarefa já existe");
        }
        Task task = TaskMapper.toEntity(taskRecordDTO, space);
        task.setActive(false);
        return TaskMapper.toDTO(taskRepository.save(task));
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

    public Page<@NonNull TaskRecordDTO> findAll(Specification<@NonNull Task> TaskSpecification, Pageable pageable) {
        return taskRepository.findAll(TaskSpecification, pageable).map(TaskMapper::toDTO);
    }
}
