package com.jonataslaet.taskifyspace.controllers.dtos;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

class UserRequestDTOValidationTests {

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
    void createUserRequestRejectsMissingAndInvalidFields() {
        CreateUserRequestDTO request = new CreateUserRequestDTO(" ", "A", "weak", null);

        Set<String> fields = violatedFields(validator.validate(request));

        assertThat(fields).contains("email", "name", "password", "passwordConfirmation");
    }

    @Test
    void updateUserRequestRejectsInvalidEditableFields() {
        UpdateUserRequestDTO request = new UpdateUserRequestDTO("not-an-email", "A");

        Set<String> fields = violatedFields(validator.validate(request));

        assertThat(fields).contains("email", "name");
    }

    @Test
    void updateUserPasswordRequestRejectsInvalidPasswordFields() {
        UpdateUserPasswordRequestDTO request = new UpdateUserPasswordRequestDTO(" ", null);

        Set<String> fields = violatedFields(validator.validate(request));

        assertThat(fields).contains("password", "oldPassword");
    }

    private Set<String> violatedFields(Set<? extends ConstraintViolation<?>> violations) {
        return violations.stream()
            .map(violation -> violation.getPropertyPath().toString())
            .collect(Collectors.toSet());
    }
}
