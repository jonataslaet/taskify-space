package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import org.springframework.beans.BeanUtils;

public class TaskMapper {

    public static Task toEntity(TaskRecordDTO taskRecordDTO, Space space) {
        Task task = new Task();
        task.setSpace(space);
        BeanUtils.copyProperties(taskRecordDTO, task);
        return task;
    }

    public static TaskRecordDTO toDTO(Task task) {
        return new TaskRecordDTO(task.getId(), task.getSpace().getId(), task.getDescription(),
            task.getScore(), task.getCategory(), task.isActive());
    }
}
