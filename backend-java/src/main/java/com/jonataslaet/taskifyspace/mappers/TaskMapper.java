package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskScheduleRecordDTO;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.TaskSchedule;
import com.jonataslaet.taskifyspace.entities.User;

import java.time.DayOfWeek;
import java.util.Objects;
import java.util.Set;

public class TaskMapper {

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
        if (Objects.isNull(scheduleRecordDTO)) return;

        TaskSchedule schedule = Objects.nonNull(task.getSchedule()) ? task.getSchedule() : new TaskSchedule();
        if (Objects.nonNull(scheduleRecordDTO.daysOfWeek())) {
            schedule.setDaysOfWeek(scheduleRecordDTO.daysOfWeek());
        }
        if (Objects.nonNull(scheduleRecordDTO.dayOfMonth())) {
            schedule.setDayOfMonth(scheduleRecordDTO.dayOfMonth());
        }
        task.setSchedule(schedule);
    }

    public static TaskRecordDTO toDTO(Task task) {
        if (Objects.isNull(task)) return null;
        return new TaskRecordDTO(task.getId(), Objects.isNull(task.getSpace()) ? null : task.getSpace().getId(), task.getDescription(),
            task.getScore(), task.getCategory(), toScheduleDTO(task.getSchedule()), task.isActive(), Objects.nonNull(task.getCreator()) ?
            task.getCreator().getName() : null);
    }

    private static TaskScheduleRecordDTO toScheduleDTO(TaskSchedule schedule) {
        if (Objects.isNull(schedule)) return null;
        Set<DayOfWeek> daysOfWeek = Objects.isNull(schedule.getDaysOfWeek())
            ? null
            : Set.copyOf(schedule.getDaysOfWeek());
        return new TaskScheduleRecordDTO(daysOfWeek, schedule.getDayOfMonth());
    }
}
