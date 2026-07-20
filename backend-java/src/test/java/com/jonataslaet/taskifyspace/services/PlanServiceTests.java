package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.PlanFeatureLimitRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PlanRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.PlanFeatureLimit;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.repositories.PlanRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlanServiceTests {

    @Mock
    private PlanRepository planRepository;

    private PlanService planService;

    @BeforeEach
    void setUp() {
        planService = new PlanService(planRepository);
    }

    @Test
    void createPlanAllowsNumericUsageLimit() {
        PlanRecordDTO dto = createPlanDTO(1L);
        when(planRepository.existsByCodeIgnoreCase(dto.code())).thenReturn(false);
        when(planRepository.save(any(Plan.class))).thenAnswer(invocation -> invocation.getArgument(0));

        PlanRecordDTO created = planService.createPlan(dto);

        assertThat(created.featureLimits())
            .contains(new PlanFeatureLimitRecordDTO(FeatureEnum.CREATE_SPACE, 1L));
    }

    @Test
    void updatePlanAllowsNumericUsageLimit() {
        Plan existingPlan = createPlan();
        PlanRecordDTO dto = createPlanDTO(10L);
        when(planRepository.findById(existingPlan.getId())).thenReturn(Optional.of(existingPlan));
        when(planRepository.save(any(Plan.class))).thenAnswer(invocation -> invocation.getArgument(0));

        PlanRecordDTO updated = planService.updatePlan(existingPlan.getId(), dto);

        assertThat(updated.featureLimits())
            .contains(new PlanFeatureLimitRecordDTO(FeatureEnum.CREATE_SPACE, 10L));
    }

    @Test
    void createPlanRejectsNonPositiveUsageLimit() {
        PlanRecordDTO dto = createPlanDTO(0L);

        assertThatThrownBy(() -> planService.createPlan(dto))
            .isInstanceOf(InvalidRequestException.class);
    }

    private PlanRecordDTO createPlanDTO(Long usageLimit) {
        Set<PlanFeatureLimitRecordDTO> featureLimits = Set.of(
            new PlanFeatureLimitRecordDTO(FeatureEnum.CREATE_SPACE, usageLimit));

        return new PlanRecordDTO(
            null,
            "basic",
            "Basic",
            "Basic plan",
            true,
            Set.of(FeatureEnum.CREATE_SPACE),
            featureLimits);
    }

    private Plan createPlan() {
        Plan plan = new Plan();
        plan.setId(1L);
        plan.setCode("basic");
        plan.setName("Basic");
        plan.setDescription("Basic plan");
        plan.setActive(true);
        plan.setFeatureLimits(Set.of(new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, 1L)));
        return plan;
    }
}
