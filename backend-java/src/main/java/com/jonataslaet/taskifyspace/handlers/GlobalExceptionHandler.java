package com.jonataslaet.taskifyspace.handlers;

import com.jonataslaet.taskifyspace.controllers.dtos.StandardError;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import org.jspecify.annotations.NonNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.time.Instant;

@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<@NonNull StandardError> handleHttpMessageNotReadableException(
        HttpMessageNotReadableException ex, HttpServletRequest request) {
        StandardError error = new StandardError();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.BAD_REQUEST.value());
        error.setError("Erro de requisição");
        error.setMessage(ex.getMessage());
        error.setPath(request.getRequestURI());

        return ResponseEntity.badRequest().body(error);
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<@NonNull StandardError> handleResourceNotFoundException(ResourceNotFoundException ex,
        HttpServletRequest httpServletRequest) {
        StandardError standardError = new StandardError();
        standardError.setTimestamp(Instant.now());
        standardError.setStatus(HttpStatus.NOT_FOUND.value());
        standardError.setError("Recurso não encontrado");
        standardError.setMessage(ex.getMessage());
        standardError.setPath(httpServletRequest.getRequestURI());

        return ResponseEntity.status(HttpStatus.NOT_FOUND.value()).body(standardError);
    }

    @ExceptionHandler(DuplicationException.class)
    public ResponseEntity<@NonNull StandardError> handleDuplicationException(
        DuplicationException ex, HttpServletRequest httpServletRequest) {
        StandardError standardError = new StandardError();
        standardError.setTimestamp(Instant.now());
        standardError.setStatus(HttpStatus.CONFLICT.value());
        standardError.setError("Erro de requisição");
        standardError.setMessage(ex.getMessage());
        standardError.setPath(httpServletRequest.getRequestURI());

        return ResponseEntity.status(HttpStatus.CONFLICT.value()).body(standardError);
    }
}
