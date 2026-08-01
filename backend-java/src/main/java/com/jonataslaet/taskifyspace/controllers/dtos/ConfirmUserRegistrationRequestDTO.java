package com.jonataslaet.taskifyspace.controllers.dtos;

import jakarta.validation.constraints.NotBlank;

public record ConfirmUserRegistrationRequestDTO(
    @NotBlank(message = "Token is required")
    String token
) {
}
