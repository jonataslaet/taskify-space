package com.jonataslaet.taskifyspace.controllers.dtos;

import java.math.BigDecimal;
import java.util.List;

public record RequestParamsTasksDTO(
    String description,
    BigDecimal score,
    Boolean active,
    List<String> categories,
    BigDecimal minScore,
    BigDecimal maxScore
) {}