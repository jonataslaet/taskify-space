package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.validations.PasswordConstraint;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PasswordResetDTO(
    @NotBlank(message = "Password is mandatory")
    @Size(min = 8, max = 32, message = "Size must be between 8 and 32")
    @PasswordConstraint
    String newPassword,

    @NotBlank(message = "Password confirmation is mandatory")
    @Size(min = 8, max = 32, message = "Size must be between 8 and 32")
    @PasswordConstraint
    String newPasswordConfirmation
) {
}
