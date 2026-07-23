package com.jonataslaet.taskifyspace.controllers.dtos;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record EmailDTO(
    @NotBlank(message = "Email is required")
    @Email(message = "Email must be in the expected format")
    String address
) {
}
