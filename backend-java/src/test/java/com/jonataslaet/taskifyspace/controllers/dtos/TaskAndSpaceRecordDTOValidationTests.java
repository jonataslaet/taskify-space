package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

class TaskAndSpaceRecordDTOValidationTests {

    private static ValidatorFactory validatorFactory;
    private static Validator validator;

    @BeforeAll
    static void setUpValidator() {
        validatorFactory = Validation.buildDefaultValidatorFactory();
        validator = validatorFactory.getValidator();
    }

    @AfterAll
    static void closeValidatorFactory() {
        validatorFactory.close();
    }

    @Test
    void taskCreateRejectsMissingAndInvalidFields() {
        TaskRecordDTO task = new TaskRecordDTO(
            null,
            null,
            " ",
            BigDecimal.ZERO,
            null,
            null,
            null,
            null);

        Set<String> fields = violatedFields(
            validator.validate(task, TaskRecordDTO.TaskView.CreateTask.class));

        assertThat(fields).contains("spaceId", "description", "score", "category");
    }

    @Test
    void taskUpdateAllowsPartialPayloadButRejectsInvalidProvidedFields() {
        TaskRecordDTO partialTask = new TaskRecordDTO(null, null, null, null, null, null, null, null);
        TaskRecordDTO invalidTask = new TaskRecordDTO(
            -1L,
            -1L,
            "",
            new BigDecimal("1.001"),
            TaskCategoryEnum.OPERATIONAL,
            null,
            null,
            null);

        assertThat(validator.validate(partialTask, TaskRecordDTO.TaskView.UpdateTask.class)).isEmpty();

        Set<String> fields = violatedFields(
            validator.validate(invalidTask, TaskRecordDTO.TaskView.UpdateTask.class));
        assertThat(fields).contains("id", "spaceId", "description", "score");
    }

    @Test
    void taskScheduleRejectsEmptyScheduleAndMissingFrequency() {
        TaskRecordDTO emptyScheduleTask = new TaskRecordDTO(
            null,
            1L,
            "Task",
            BigDecimal.ONE,
            TaskCategoryEnum.OPERATIONAL,
            new TaskScheduleRecordDTO(Set.of(), null),
            null,
            null);
        TaskRecordDTO missingFrequencyTask = new TaskRecordDTO(
            null,
            1L,
            "Task",
            BigDecimal.ONE,
            TaskCategoryEnum.OPERATIONAL,
            new TaskScheduleRecordDTO(Set.of(LocalDate.of(2026, 8, 4)), null),
            null,
            null);

        Set<String> emptyScheduleFields = violatedFields(
            validator.validate(emptyScheduleTask, TaskRecordDTO.TaskView.CreateTask.class));
        Set<String> missingFrequencyFields = violatedFields(
            validator.validate(missingFrequencyTask, TaskRecordDTO.TaskView.CreateTask.class));

        assertThat(emptyScheduleFields).contains("schedule.frequence");
        assertThat(emptyScheduleFields).doesNotContain("schedule.localDates");
        assertThat(missingFrequencyFields).contains("schedule.frequence");
    }

    @Test
    void taskScheduleAllowsDailyFrequencyWithoutLocalDatesOnCreateAndUpdate() {
        TaskRecordDTO dailyTask = new TaskRecordDTO(
            null,
            1L,
            "Task",
            BigDecimal.ONE,
            TaskCategoryEnum.OPERATIONAL,
            new TaskScheduleRecordDTO(null, FrequenceEnum.DAILY),
            null,
            null);

        assertThat(validator.validate(dailyTask, TaskRecordDTO.TaskView.CreateTask.class)).isEmpty();
        assertThat(validator.validate(dailyTask, TaskRecordDTO.TaskView.UpdateTask.class)).isEmpty();
    }

    @Test
    void taskScheduleRequiresLocalDatesForNonDailyFrequencyOnCreateAndUpdate() {
        TaskRecordDTO weeklyTask = new TaskRecordDTO(
            null,
            1L,
            "Task",
            BigDecimal.ONE,
            TaskCategoryEnum.OPERATIONAL,
            new TaskScheduleRecordDTO(Set.of(), FrequenceEnum.WEEKLY),
            null,
            null);

        Set<String> createFields = violatedFields(
            validator.validate(weeklyTask, TaskRecordDTO.TaskView.CreateTask.class));
        Set<String> updateFields = violatedFields(
            validator.validate(weeklyTask, TaskRecordDTO.TaskView.UpdateTask.class));

        assertThat(createFields).contains("schedule.localDates");
        assertThat(updateFields).contains("schedule.localDates");
    }

    @Test
    void spaceCreateRejectsMissingAndInvalidFields() {
        SpaceRecordDTO space = new SpaceRecordDTO(null, " ", null, null, null, null, null, null);

        Set<String> fields = violatedFields(
            validator.validate(space, SpaceRecordDTO.SpaceView.CreateSpace.class));

        assertThat(fields).contains("name");
    }

    @Test
    void spaceUpdateAllowsPartialPayloadButRejectsInvalidProvidedFields() {
        SpaceRecordDTO partialSpace = new SpaceRecordDTO(null, null, null, null, null, null, null, null);
        SpaceRecordDTO invalidSpace = new SpaceRecordDTO(-1L, "", null, null, null, null, null, null);

        assertThat(validator.validate(partialSpace, SpaceRecordDTO.SpaceView.UpdateSpace.class)).isEmpty();

        Set<String> fields = violatedFields(
            validator.validate(invalidSpace, SpaceRecordDTO.SpaceView.UpdateSpace.class));
        assertThat(fields).contains("id", "name");
    }

    private Set<String> violatedFields(Set<? extends ConstraintViolation<?>> violations) {
        return violations.stream()
            .map(violation -> violation.getPropertyPath().toString())
            .collect(Collectors.toSet());
    }
}
