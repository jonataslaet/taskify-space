package com.jonataslaet.taskifyspace.controllers.dtos;

import jakarta.validation.constraints.NotBlank;

public record CredentialsRecordDTO(
    @NotBlank(message = "Username is required")
    String username,

    @NotBlank(message = "Password is required")
    String password
) {
}
