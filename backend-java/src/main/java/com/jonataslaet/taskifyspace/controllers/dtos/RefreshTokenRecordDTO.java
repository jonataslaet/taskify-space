package com.jonataslaet.taskifyspace.controllers.dtos;

import jakarta.validation.constraints.NotBlank;

public record RefreshTokenRecordDTO(
    @NotBlank(message = "Refresh token is required")
    String refreshToken
) {}
