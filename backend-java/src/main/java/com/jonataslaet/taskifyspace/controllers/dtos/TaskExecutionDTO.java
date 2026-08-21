package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record TaskExecutionDTO(
    Long id,
    String executionDate,
    BigDecimal score,
    List<String> executorNames
) {
}
