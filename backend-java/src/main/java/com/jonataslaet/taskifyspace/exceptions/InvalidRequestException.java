package com.jonataslaet.taskifyspace.exceptions;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

import java.io.Serial;

@ResponseStatus(HttpStatus.BAD_REQUEST)
public class InvalidRequestException extends RuntimeException {
    @Serial
    private static final long serialVersionUID = 1L;

    public InvalidRequestException(String ex) {
        super(ex);
    }
}
