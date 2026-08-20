package com.jonataslaet.taskifyspace.validations;

import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
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

        if (requiresSchedulingDates(schedule)
            && (Objects.isNull(schedule.getLocalDates()) || schedule.getLocalDates().isEmpty())) {
            throw new IllegalArgumentException(
                "At least one scheduling date must be configured"
            );
        }

        if (Objects.nonNull(schedule.getLocalDates())
            && schedule.getLocalDates().stream().anyMatch(Objects::isNull)) {
            throw new IllegalArgumentException(
                "Scheduling dates cannot contain null values"
            );
        }
    }

    private boolean requiresSchedulingDates(TaskSchedule schedule) {
        return !FrequenceEnum.DAILY.equals(schedule.getFrequenceEnum());
    }
}
