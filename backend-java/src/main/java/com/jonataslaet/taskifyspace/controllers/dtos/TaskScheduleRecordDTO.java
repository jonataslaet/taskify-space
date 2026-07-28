package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.time.DayOfWeek;
import java.util.Set;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record TaskScheduleRecordDTO(

    @JsonView({
        TaskRecordDTO.TaskView.CreateTask.class,
        TaskRecordDTO.TaskView.ReadTask.class,
        TaskRecordDTO.TaskView.UpdateTask.class
    })
    Set<@NotNull(groups = {
        TaskRecordDTO.TaskView.CreateTask.class,
        TaskRecordDTO.TaskView.UpdateTask.class
    }, message = "Dia da semana da agenda da tarefa nao pode ser nulo") DayOfWeek> daysOfWeek,

    @Min(groups = {
        TaskRecordDTO.TaskView.CreateTask.class,
        TaskRecordDTO.TaskView.UpdateTask.class
    }, value = 1, message = "Dia do mes da agenda da tarefa deve ser maior ou igual a 1")
    @Max(groups = {
        TaskRecordDTO.TaskView.CreateTask.class,
        TaskRecordDTO.TaskView.UpdateTask.class
    }, value = 31, message = "Dia do mes da agenda da tarefa deve ser menor ou igual a 31")
    @JsonView({
        TaskRecordDTO.TaskView.CreateTask.class,
        TaskRecordDTO.TaskView.ReadTask.class,
        TaskRecordDTO.TaskView.UpdateTask.class
    })
    Integer dayOfMonth
) {

}
