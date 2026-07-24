package com.jonataslaet.taskifyspace.handlers;

import com.jonataslaet.taskifyspace.controllers.dtos.StandardErrorRecordDTO;
import com.jonataslaet.taskifyspace.exceptions.EmailException;
import com.jonataslaet.taskifyspace.exceptions.InvalidCredentialsException;
import com.jonataslaet.taskifyspace.exceptions.RateLimitExceededException;
import com.jonataslaet.taskifyspace.exceptions.TokenExpirationException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTests {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void handlesIllegalArgumentExceptionAsBadRequest() {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/participants");

        var response = handler.handleIllegalArgumentException(
            new IllegalArgumentException("Ordenacao invalida"),
            request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).satisfies(error -> {
            assertThat(error).isNotNull();
            assertThat(error.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST.value());
            assertThat(error.getMessage()).isEqualTo("Ordenacao invalida");
            assertThat(error.getPath()).isEqualTo("/participants");
        });
    }

    @Test
    void handlesGenericExceptionAsInternalServerError() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/tasks");

        var response = handler.handleGenericException(new RuntimeException("database details"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        StandardErrorRecordDTO error = response.getBody();
        assertThat(error).isNotNull();
        assertThat(error.getStatus()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR.value());
        assertThat(error.getMessage()).isEqualTo("Ocorreu um erro inesperado");
        assertThat(error.getPath()).isEqualTo("/tasks");
    }

    @Test
    void preservesTokenExpirationResponseStatus() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/auth/new-password/token");

        var response = handler.handleGenericException(
            new TokenExpirationException("Token expirado"),
            request);

        assertResponseStatusException(response.getBody(), HttpStatus.UNAUTHORIZED, "Token expirado", request);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void preservesEmailExceptionResponseStatus() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/auth/recovery-token");

        var response = handler.handleGenericException(
            new EmailException("Falha ao enviar email"),
            request);

        assertResponseStatusException(response.getBody(), HttpStatus.BAD_REQUEST, "Falha ao enviar email", request);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void preservesInvalidCredentialsResponseStatus() {
        MockHttpServletRequest request = new MockHttpServletRequest("PATCH", "/users/password");

        var response = handler.handleGenericException(
            new InvalidCredentialsException("Old password does not match"),
            request);

        assertResponseStatusException(
            response.getBody(),
            HttpStatus.CONFLICT,
            "Old password does not match",
            request);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void handlesRateLimitExceededAsTooManyRequestsWithRetryAfterHeader() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/auth/login");

        var response = handler.handleRateLimitExceededException(
            new RateLimitExceededException("Muitas tentativas", 60),
            request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(response.getHeaders().getFirst(HttpHeaders.RETRY_AFTER)).isEqualTo("60");
        assertResponseStatusException(response.getBody(), HttpStatus.TOO_MANY_REQUESTS, "Muitas tentativas", request);
    }

    private void assertResponseStatusException(
        StandardErrorRecordDTO error,
        HttpStatus status,
        String message,
        MockHttpServletRequest request) {
        assertThat(error).isNotNull();
        assertThat(error.getStatus()).isEqualTo(status.value());
        assertThat(error.getMessage()).isEqualTo(message);
        assertThat(error.getPath()).isEqualTo(request.getRequestURI());
    }
}
