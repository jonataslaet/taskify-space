package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
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
            null);

        Set<String> fields = violatedFields(
            validator.validate(task, TaskRecordDTO.TaskView.CreateTask.class));

        assertThat(fields).contains("spaceId", "description", "score", "category");
    }

    @Test
    void taskUpdateAllowsPartialPayloadButRejectsInvalidProvidedFields() {
        TaskRecordDTO partialTask = new TaskRecordDTO(null, null, null, null, null, null, null);
        TaskRecordDTO invalidTask = new TaskRecordDTO(
            -1L,
            -1L,
            "",
            new BigDecimal("1.001"),
            TaskCategoryEnum.OPERATIONAL,
            null,
            null);

        assertThat(validator.validate(partialTask, TaskRecordDTO.TaskView.UpdateTask.class)).isEmpty();

        Set<String> fields = violatedFields(
            validator.validate(invalidTask, TaskRecordDTO.TaskView.UpdateTask.class));
        assertThat(fields).contains("id", "spaceId", "description", "score");
    }

    @Test
    void spaceCreateRejectsMissingAndInvalidFields() {
        SpaceRecordDTO space = new SpaceRecordDTO(null, " ", null, null, null, null, null);

        Set<String> fields = violatedFields(
            validator.validate(space, SpaceRecordDTO.SpaceView.CreateSpace.class));

        assertThat(fields).contains("name");
    }

    @Test
    void spaceUpdateAllowsPartialPayloadButRejectsInvalidProvidedFields() {
        SpaceRecordDTO partialSpace = new SpaceRecordDTO(null, null, null, null, null, null, null);
        SpaceRecordDTO invalidSpace = new SpaceRecordDTO(-1L, "", null, null, null, null, null);

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
