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

class AuthenticationAndUserStatusDTOValidationTests {

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
    void credentialsRejectMissingAndBlankFields() {
        CredentialsRecordDTO credentials = new CredentialsRecordDTO(" ", null);

        Set<String> fields = violatedFields(validator.validate(credentials));

        assertThat(fields).contains("username", "password");
    }

    @Test
    void refreshTokenRejectsMissingToken() {
        RefreshTokenRecordDTO refreshToken = new RefreshTokenRecordDTO(" ");

        Set<String> fields = violatedFields(validator.validate(refreshToken));

        assertThat(fields).contains("refreshToken");
    }

    @Test
    void userStatusRejectsMissingStatus() {
        UpdateUserStatusRequestDTO statusRequest = new UpdateUserStatusRequestDTO(null);

        Set<String> fields = violatedFields(validator.validate(statusRequest));

        assertThat(fields).contains("status");
    }

    private Set<String> violatedFields(Set<? extends ConstraintViolation<?>> violations) {
        return violations.stream()
            .map(violation -> violation.getPropertyPath().toString())
            .collect(Collectors.toSet());
    }
}
