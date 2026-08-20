package com.jonataslaet.taskifyspace.validations;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskScheduleRecordDTO;
import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.util.Objects;

public class ValidTaskScheduleValidator implements ConstraintValidator<ValidTaskSchedule, TaskScheduleRecordDTO> {

    @Override
    public boolean isValid(TaskScheduleRecordDTO schedule, ConstraintValidatorContext context) {
        if (Objects.isNull(schedule)
            || Objects.isNull(schedule.frequence())
            || FrequenceEnum.DAILY.equals(schedule.frequence())) {
            return true;
        }

        if (Objects.nonNull(schedule.localDates()) && !schedule.localDates().isEmpty()) {
            return true;
        }

        context.disableDefaultConstraintViolation();
        context.buildConstraintViolationWithTemplate(context.getDefaultConstraintMessageTemplate())
            .addPropertyNode("localDates")
            .addConstraintViolation();
        return false;
    }
}
