package com.jonataslaet.taskifyspace.controllers.dtos;

public record PasswordRecoveryEmail(String address, String token) {
}
