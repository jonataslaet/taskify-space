package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record PlanFeatureLimitRecordDTO(
    @NotNull(message = "Funcionalidade do limite e obrigatoria")
    FeatureEnum feature,
    SpaceUserRoleEnum spaceUserRole,
    @Positive(message = "Limite de uso deve ser positivo quando informado")
    Long usageLimit
) {}
