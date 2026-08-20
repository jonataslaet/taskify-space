package com.jonataslaet.taskifyspace.validations;

import com.jonataslaet.taskifyspace.entities.TaskSchedule;
import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TaskSchedulerValidatorTests {

    private final TaskSchedulerValidator validator = new TaskSchedulerValidator();

    @Test
    void allowsDailyScheduleWithoutLocalDates() {
        TaskSchedule schedule = new TaskSchedule();
        schedule.setFrequenceEnum(FrequenceEnum.DAILY);

        assertThatCode(() -> validator.validate(schedule)).doesNotThrowAnyException();
    }

    @Test
    void rejectsNonDailyScheduleWithoutLocalDates() {
        TaskSchedule schedule = new TaskSchedule();
        schedule.setFrequenceEnum(FrequenceEnum.WEEKLY);

        assertThatThrownBy(() -> validator.validate(schedule))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("At least one scheduling date must be configured");
    }

    @Test
    void allowsNonDailyScheduleWithLocalDates() {
        TaskSchedule schedule = new TaskSchedule();
        schedule.setFrequenceEnum(FrequenceEnum.WEEKLY);
        schedule.setLocalDates(Set.of(LocalDate.of(2026, 8, 20)));

        assertThatCode(() -> validator.validate(schedule)).doesNotThrowAnyException();
    }
}
