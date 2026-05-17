package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;

import java.util.Set;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record PlanRecordDTO(
    Long id,
    String code,
    String name,
    String description,
    Boolean active,
    Set<FeatureEnum> features,
    Set<PlanFeatureLimitRecordDTO> featureLimits
) {}
