package com.jonataslaet.taskifyspace.services;

public record PasswordRecoveryEmail(String address, String token) {
}
