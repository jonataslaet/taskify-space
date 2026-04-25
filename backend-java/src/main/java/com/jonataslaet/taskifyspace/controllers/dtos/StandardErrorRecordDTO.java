package com.jonataslaet.taskifyspace.controllers.dtos;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;

@Schema(description = "Standard API error response")
public class StandardErrorRecordDTO {

    @Schema(example = "2026-02-08T12:00:00Z")
    private Instant timestamp;

    @Schema(example = "404")
    private Integer status;

    @Schema(example = "Recurso não encontrado")
    private String error;

    @Schema(example = "Tarefa não encontrada")
    private String message;

    @Schema(example = "/tasks/1")
    private String path;

    public StandardErrorRecordDTO() {
    }

    public Instant getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(Instant timestamp) {
        this.timestamp = timestamp;
    }

    public Integer getStatus() {
        return status;
    }

    public void setStatus(Integer status) {
        this.status = status;
    }

    public String getError() {
        return error;
    }

    public void setError(String error) {
        this.error = error;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getPath() {
        return path;
    }

    public void setPath(String path) {
        this.path = path;
    }
}
