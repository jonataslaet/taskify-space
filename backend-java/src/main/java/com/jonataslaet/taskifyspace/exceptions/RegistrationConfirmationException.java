package com.jonataslaet.taskifyspace.exceptions;

import org.springframework.http.HttpStatus;

public class RegistrationConfirmationException extends RuntimeException {

    private final HttpStatus status;
    private final String code;

    private RegistrationConfirmationException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }

    public static RegistrationConfirmationException invalidToken() {
        return new RegistrationConfirmationException(
            HttpStatus.BAD_REQUEST,
            "REGISTRATION_CONFIRMATION_TOKEN_INVALID",
            "Token de confirmacao de cadastro invalido");
    }

    public static RegistrationConfirmationException expiredToken() {
        return new RegistrationConfirmationException(
            HttpStatus.GONE,
            "REGISTRATION_CONFIRMATION_TOKEN_EXPIRED",
            "Token de confirmacao de cadastro expirado. Solicite um novo token.");
    }

    public static RegistrationConfirmationException expiredRegistrationDeleted() {
        return new RegistrationConfirmationException(
            HttpStatus.GONE,
            "REGISTRATION_CONFIRMATION_EXPIRED_USER_DELETED",
            "Cadastro expirado e removido. Faca um novo cadastro.");
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getCode() {
        return code;
    }
}
