package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import java.util.Set;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record PlanRecordDTO(
    Long id,
    @NotBlank(message = "Codigo do plano e obrigatorio")
    String code,
    @NotBlank(message = "Nome do plano e obrigatorio")
    String name,
    String description,
    Boolean active,
    Set<FeatureEnum> features,
    @NotEmpty(message = "Limites de funcionalidades do plano sao obrigatorios")
    Set<@Valid PlanFeatureLimitRecordDTO> featureLimits
) {}
