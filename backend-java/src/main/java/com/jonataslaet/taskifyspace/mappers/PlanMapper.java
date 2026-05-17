package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.PlanRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PlanFeatureLimitRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.PlanFeatureLimit;

import java.util.HashSet;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

public class PlanMapper {

    public static Plan toEntity(PlanRecordDTO dto) {
        Plan plan = new Plan();
        plan.setCode(dto.code());
        plan.setName(dto.name());
        plan.setDescription(dto.description());
        plan.setActive(Objects.isNull(dto.active()) || dto.active());
        plan.setFeatures(Objects.isNull(dto.features()) ? new HashSet<>() : new HashSet<>(dto.features()));
        plan.setFeatureLimits(toFeatureLimits(dto.featureLimits()));
        return plan;
    }

    public static PlanRecordDTO toDTO(Plan plan) {
        if (Objects.isNull(plan)) return null;
        return new PlanRecordDTO(
            plan.getId(),
            plan.getCode(),
            plan.getName(),
            plan.getDescription(),
            plan.getActive(),
            plan.getFeatures(),
            toFeatureLimitDTOs(plan.getFeatureLimits())
        );
    }

    private static Set<PlanFeatureLimit> toFeatureLimits(Set<PlanFeatureLimitRecordDTO> dtos) {
        if (Objects.isNull(dtos)) return new HashSet<>();
        return dtos.stream()
            .map(dto -> new PlanFeatureLimit(dto.feature(), dto.spaceUserRole(), dto.usageLimit()))
            .collect(Collectors.toSet());
    }

    private static Set<PlanFeatureLimitRecordDTO> toFeatureLimitDTOs(Set<PlanFeatureLimit> limits) {
        if (Objects.isNull(limits)) return Set.of();
        return limits.stream()
            .map(limit -> new PlanFeatureLimitRecordDTO(
                limit.getFeature(),
                limit.getSpaceUserRole(),
                limit.getUsageLimit()
            ))
            .collect(Collectors.toSet());
    }
}
