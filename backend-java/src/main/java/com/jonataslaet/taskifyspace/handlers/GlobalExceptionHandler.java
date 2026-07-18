package com.jonataslaet.taskifyspace.handlers;

import com.jonataslaet.taskifyspace.controllers.dtos.StandardErrorRecordDTO;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import org.jspecify.annotations.NonNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.time.Instant;
import java.util.stream.Collectors;

@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ForbiddenException.class)
    public ResponseEntity<StandardErrorRecordDTO> handleForbiddenException(
        ForbiddenException ex,
        HttpServletRequest request) {

        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.FORBIDDEN.value());
        error.setError("Acesso negado");
        error.setMessage(ex.getMessage());
        error.setPath(request.getRequestURI());

        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }

    @ExceptionHandler(InvalidAuthenticationException.class)
    public ResponseEntity<StandardErrorRecordDTO> handleInvalidAuthenticationException(
        InvalidAuthenticationException ex,
        HttpServletRequest request) {

        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.UNAUTHORIZED.value());
        error.setError("Erro de autenticação");
        error.setMessage(ex.getMessage());
        error.setPath(request.getRequestURI());

        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(error);
    }


    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleHttpMessageNotReadableException(
        HttpMessageNotReadableException ex, HttpServletRequest request) {
        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.BAD_REQUEST.value());
        error.setError("Erro de requisição");
        error.setMessage(ex.getMessage());
        error.setPath(request.getRequestURI());

        return ResponseEntity.badRequest().body(error);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleMethodArgumentNotValidException(
        MethodArgumentNotValidException ex, HttpServletRequest request) {
        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.BAD_REQUEST.value());
        error.setError("Requisicao invalida");
        error.setMessage(ex.getBindingResult().getFieldErrors().stream()
            .map(fieldError -> fieldError.getField() + ": " + fieldError.getDefaultMessage())
            .collect(Collectors.joining("; ")));
        error.setPath(request.getRequestURI());

        return ResponseEntity.badRequest().body(error);
    }

    @ExceptionHandler(InvalidRequestException.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleInvalidRequestException(
        InvalidRequestException ex, HttpServletRequest request) {
        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.BAD_REQUEST.value());
        error.setError("Requisicao invalida");
        error.setMessage(ex.getMessage());
        error.setPath(request.getRequestURI());

        return ResponseEntity.badRequest().body(error);
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleResourceNotFoundException(ResourceNotFoundException ex,
                                                                                           HttpServletRequest httpServletRequest) {
        StandardErrorRecordDTO standardErrorRecordDTO = new StandardErrorRecordDTO();
        standardErrorRecordDTO.setTimestamp(Instant.now());
        standardErrorRecordDTO.setStatus(HttpStatus.NOT_FOUND.value());
        standardErrorRecordDTO.setError("Recurso não encontrado");
        standardErrorRecordDTO.setMessage(ex.getMessage());
        standardErrorRecordDTO.setPath(httpServletRequest.getRequestURI());

        return ResponseEntity.status(HttpStatus.NOT_FOUND.value()).body(standardErrorRecordDTO);
    }

    @ExceptionHandler(DuplicationException.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleDuplicationException(
        DuplicationException ex, HttpServletRequest httpServletRequest) {
        StandardErrorRecordDTO standardErrorRecordDTO = new StandardErrorRecordDTO();
        standardErrorRecordDTO.setTimestamp(Instant.now());
        standardErrorRecordDTO.setStatus(HttpStatus.CONFLICT.value());
        standardErrorRecordDTO.setError("Erro de requisição");
        standardErrorRecordDTO.setMessage(ex.getMessage());
        standardErrorRecordDTO.setPath(httpServletRequest.getRequestURI());

        return ResponseEntity.status(HttpStatus.CONFLICT.value()).body(standardErrorRecordDTO);
    }
}
