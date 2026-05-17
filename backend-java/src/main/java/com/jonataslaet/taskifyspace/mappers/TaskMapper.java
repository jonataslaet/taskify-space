package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.User;
import org.springframework.beans.BeanUtils;

import java.util.Objects;

public class TaskMapper {

    public static Task toEntity(TaskRecordDTO taskRecordDTO, Space space, User creator) {
        Task task = new Task();
        task.setCreator(creator);
        task.setSpace(space);
        BeanUtils.copyProperties(taskRecordDTO, task);
        return task;
    }

    public static TaskRecordDTO toDTO(Task task) {
        if (Objects.isNull(task)) return null;
        return new TaskRecordDTO(task.getId(), Objects.isNull(task.getSpace()) ? null : task.getSpace().getId(), task.getDescription(),
            task.getScore(), task.getCategory(), task.isActive(), Objects.nonNull(task.getCreator()) ?
            task.getCreator().getName() : null);
    }
}
