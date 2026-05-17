package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record PlanFeatureLimitRecordDTO(
    FeatureEnum feature,
    SpaceUserRoleEnum spaceUserRole,
    Long usageLimit
) {}
