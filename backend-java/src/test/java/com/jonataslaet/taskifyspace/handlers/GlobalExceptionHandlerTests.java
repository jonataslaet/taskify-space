package com.jonataslaet.taskifyspace.handlers;

import com.jonataslaet.taskifyspace.controllers.dtos.StandardErrorRecordDTO;
import org.junit.jupiter.api.Test;
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
}
