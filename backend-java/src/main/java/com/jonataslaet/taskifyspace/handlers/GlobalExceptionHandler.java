package com.jonataslaet.taskifyspace.handlers;

import com.jonataslaet.taskifyspace.controllers.dtos.StandardErrorRecordDTO;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.RateLimitExceededException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import org.jspecify.annotations.NonNull;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;

import java.time.Instant;
import java.util.stream.Collectors;

@ControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

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

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleIllegalArgumentException(
        IllegalArgumentException ex, HttpServletRequest request) {
        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.BAD_REQUEST.value());
        error.setError("Requisicao invalida");
        error.setMessage(messageOrFallback(ex, "Parametro invalido"));
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

    @ExceptionHandler(RateLimitExceededException.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleRateLimitExceededException(
        RateLimitExceededException ex, HttpServletRequest request) {
        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        error.setError("Muitas requisicoes");
        error.setMessage(ex.getMessage());
        error.setPath(request.getRequestURI());

        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
            .header(HttpHeaders.RETRY_AFTER, String.valueOf(ex.getRetryAfterSeconds()))
            .body(error);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<@NonNull StandardErrorRecordDTO> handleGenericException(
        Exception ex, HttpServletRequest request) {
        ResponseStatus responseStatus = AnnotatedElementUtils.findMergedAnnotation(
            ex.getClass(), ResponseStatus.class);
        if (responseStatus != null) {
            return handleResponseStatusException(ex, request, responseStatus);
        }

        logger.error("Erro inesperado na requisicao {}", request.getRequestURI(), ex);

        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(HttpStatus.INTERNAL_SERVER_ERROR.value());
        error.setError("Erro interno");
        error.setMessage("Ocorreu um erro inesperado");
        error.setPath(request.getRequestURI());

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }

    private ResponseEntity<@NonNull StandardErrorRecordDTO> handleResponseStatusException(
        Exception ex,
        HttpServletRequest request,
        ResponseStatus responseStatus) {
        HttpStatus status = responseStatus.code();

        StandardErrorRecordDTO error = new StandardErrorRecordDTO();
        error.setTimestamp(Instant.now());
        error.setStatus(status.value());
        error.setError(errorLabelFor(status));
        error.setMessage(messageOrFallback(ex, status.getReasonPhrase()));
        error.setPath(request.getRequestURI());

        return ResponseEntity.status(status).body(error);
    }

    private String errorLabelFor(HttpStatus status) {
        return switch (status) {
            case BAD_REQUEST -> "Requisicao invalida";
            case UNAUTHORIZED -> "Erro de autenticacao";
            case FORBIDDEN -> "Acesso negado";
            case NOT_FOUND -> "Recurso nao encontrado";
            case CONFLICT -> "Conflito";
            default -> status.is5xxServerError() ? "Erro interno" : "Erro de requisicao";
        };
    }

    private String messageOrFallback(Exception ex, String fallback) {
        return ex.getMessage() == null || ex.getMessage().isBlank()
            ? fallback
            : ex.getMessage();
    }
}
