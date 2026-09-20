package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskCategoryRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskScheduleRecordDTO;
import com.jonataslaet.taskifyspace.entities.*;

import java.time.LocalDate;
import java.util.Objects;
import java.util.Set;

public class TaskCategoryMapper {

    public static TaskCategoryRecordDTO toDTO(TaskCategory taskCategory) {
        if (Objects.isNull(taskCategory)) return null;
        return new TaskCategoryRecordDTO(taskCategory.getId(), taskCategory.getName());
    }
}
