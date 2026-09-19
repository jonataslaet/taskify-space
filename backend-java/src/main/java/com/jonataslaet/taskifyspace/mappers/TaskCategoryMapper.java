package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskCategoryRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskScheduleRecordDTO;
import com.jonataslaet.taskifyspace.entities.*;

import java.time.LocalDate;
import java.util.Objects;
import java.util.Set;

public class TaskCategoryMapper {

    public static Task toEntity(TaskRecordDTO taskRecordDTO, Space space, User creator) {
        Task task = new Task();
        task.setCreator(creator);
        task.setSpace(space);
        task.setDescription(taskRecordDTO.description());
        task.setScore(taskRecordDTO.score());
        task.setCategory(taskRecordDTO.category());
        applySchedule(task, taskRecordDTO.schedule());
        return task;
    }

    public static void applySchedule(Task task, TaskScheduleRecordDTO scheduleRecordDTO) {
        if (Objects.isNull(scheduleRecordDTO)) {
            task.setSchedule(null);
            return;
        }

        TaskSchedule schedule = Objects.nonNull(task.getSchedule())
            ? task.getSchedule()
            : new TaskSchedule();

        schedule.setLocalDates(scheduleRecordDTO.localDates());
        schedule.setFrequenceEnum(scheduleRecordDTO.frequence());

        task.setSchedule(schedule);
    }

    public static TaskCategoryRecordDTO toDTO(TaskCategory taskCategory) {
        if (Objects.isNull(taskCategory)) return null;
        return new TaskCategoryRecordDTO(taskCategory.getId(), taskCategory.getName());
    }
}
