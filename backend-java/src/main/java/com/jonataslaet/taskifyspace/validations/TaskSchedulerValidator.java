package com.jonataslaet.taskifyspace.validations;

import com.jonataslaet.taskifyspace.entities.TaskSchedule;
import org.springframework.stereotype.Component;

@Component
public class TaskSchedulerValidator {

    public void validate(TaskSchedule schedule) {
        if (schedule == null) return;

        boolean hasDaysOfWeek = schedule.getDaysOfWeek() != null && !schedule.getDaysOfWeek().isEmpty();

        boolean hasDayOfMonth = schedule.getDayOfMonth() != null;

        if (hasDaysOfWeek && hasDayOfMonth) {
            throw new IllegalArgumentException("Days of week and day of month cannot be configured simultaneously");
        }

        if (hasDayOfMonth && (schedule.getDayOfMonth() < 1 || schedule.getDayOfMonth() > 31)) {
            throw new IllegalArgumentException("Day of month must be between 1 and 31");
        }

        if (!hasDaysOfWeek && !hasDayOfMonth) {
            throw new IllegalArgumentException("At least one scheduling rule must be configured");
        }
    }
}
