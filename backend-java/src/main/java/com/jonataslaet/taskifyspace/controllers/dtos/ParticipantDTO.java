package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;

import java.math.BigDecimal;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ParticipantDTO(

    Long id,

    String name,

    SpaceUserRoleEnum spaceUserRole,

    BigDecimal score
) {
}
