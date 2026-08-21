package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskExecutionDTO;
import com.jonataslaet.taskifyspace.entities.TaskExecution;
import com.jonataslaet.taskifyspace.entities.User;

import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Objects;

public class TaskExecutionMapper {

    private static final DateTimeFormatter EXECUTION_DATE_FORMATTER =
        DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm").withZone(ZoneOffset.UTC);

    public static TaskExecutionDTO toDTO(TaskExecution taskExecution) {
        if (Objects.isNull(taskExecution)) return null;

        List<String> executorNames = Objects.isNull(taskExecution.getExecutors())
            ? List.of()
            : taskExecution.getExecutors().stream()
                .map(User::getName)
                .filter(Objects::nonNull)
                .sorted()
                .toList();

        return new TaskExecutionDTO(
            taskExecution.getId(),
            Objects.isNull(taskExecution.getCreatedAt())
                ? null
                : EXECUTION_DATE_FORMATTER.format(taskExecution.getCreatedAt()),
            Objects.isNull(taskExecution.getTask()) ? null : taskExecution.getTask().getScore(),
            executorNames
        );
    }
}
