package com.jonataslaet.taskifyspace.exceptions;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

import java.io.Serial;

@ResponseStatus(HttpStatus.CONFLICT)
public class DuplicationException extends RuntimeException {
    @Serial
    private static final long serialVersionUID = 1L;

    public DuplicationException(String ex) {
        super(ex);
    }
}
