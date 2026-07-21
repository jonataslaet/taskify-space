package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;

import java.math.BigDecimal;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ParticipantDTO(

    Long id,

    String name,

    SpaceUserRoleEnum spaceUserRole,

    List<TaskCategoryEnum> taskCategories,

    BigDecimal score
) {
}
