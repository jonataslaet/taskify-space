package com.jonataslaet.taskifyspace.controllers.dtos;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record PasswordRecoveryCodeDTO(
    @NotBlank(message = "Recovery code is mandatory")
    @Pattern(regexp = "\\d{6}", message = "Recovery code must have 6 digits")
    String code
) {
}
