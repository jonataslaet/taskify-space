package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ParticipantDTO(

    @Schema(example = "1")
    Long id,

    @Schema(example = "Jonatas Laet")
    String name,

    @Schema(example = "7.988")
    BigDecimal score
) {
}
