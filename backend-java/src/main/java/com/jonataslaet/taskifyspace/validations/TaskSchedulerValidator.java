package com.jonataslaet.taskifyspace.validations;

import com.jonataslaet.taskifyspace.entities.TaskSchedule;
import org.springframework.stereotype.Component;

import java.util.Objects;

@Component
public class TaskSchedulerValidator {

    public void validate(TaskSchedule schedule) {
        if (Objects.isNull(schedule)) {
            return;
        }

        if (Objects.isNull(schedule.getFrequenceEnum())) {
            throw new IllegalArgumentException(
                "Task schedule frequency must be informed"
            );
        }

        if (Objects.isNull(schedule.getLocalDates()) || schedule.getLocalDates().isEmpty()) {
            throw new IllegalArgumentException(
                "At least one scheduling date must be configured"
            );
        }

        if (schedule.getLocalDates().stream().anyMatch(Objects::isNull)) {
            throw new IllegalArgumentException(
                "Scheduling dates cannot contain null values"
            );
        }
    }
}