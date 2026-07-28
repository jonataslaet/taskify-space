package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.Set;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record TaskScheduleRecordDTO(

    @NotEmpty(
        groups = {
            TaskRecordDTO.TaskView.CreateTask.class,
            TaskRecordDTO.TaskView.UpdateTask.class
        },
        message = "Ao menos uma data da agenda da tarefa deve ser informada"
    )
    @JsonView({
        TaskRecordDTO.TaskView.CreateTask.class,
        TaskRecordDTO.TaskView.ReadTask.class,
        TaskRecordDTO.TaskView.UpdateTask.class
    })
    Set<
        @NotNull(
            groups = {
                TaskRecordDTO.TaskView.CreateTask.class,
                TaskRecordDTO.TaskView.UpdateTask.class
            },
            message = "Data da agenda da tarefa nao pode ser nula"
        )
            LocalDate
        > localDates,

    @NotNull(
        groups = {
            TaskRecordDTO.TaskView.CreateTask.class,
            TaskRecordDTO.TaskView.UpdateTask.class
        },
        message = "Frequencia da agenda da tarefa deve ser informada"
    )
    @JsonView({
        TaskRecordDTO.TaskView.CreateTask.class,
        TaskRecordDTO.TaskView.ReadTask.class,
        TaskRecordDTO.TaskView.UpdateTask.class
    })
    FrequenceEnum frequence

) {
}