package com.jonataslaet.taskifyspace.controllers.dtos;

public record PasswordResetDTO(
    String newPassword,
    String newPasswordConfirmation
) {
}
