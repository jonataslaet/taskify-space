package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.PlanRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PlanFeatureLimitRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.PlanMapper;
import com.jonataslaet.taskifyspace.repositories.PlanRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.Objects;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class PlanService {

    private final PlanRepository planRepository;

    public PlanService(PlanRepository planRepository) {
        this.planRepository = planRepository;
    }

    @Transactional
    public PlanRecordDTO createPlan(PlanRecordDTO dto) {
        validatePlan(dto);
        if (planRepository.existsByCodeIgnoreCase(dto.code())) {
            throw new DuplicationException("Plano ja existe");
        }
        Plan plan = PlanMapper.toEntity(dto);
        return PlanMapper.toDTO(planRepository.save(plan));
    }

    public Page<@NonNull PlanRecordDTO> findAll(Pageable pageable) {
        return planRepository.findAll(pageable).map(PlanMapper::toDTO);
    }

    public PlanRecordDTO findById(Long planId) {
        return PlanMapper.toDTO(getPlanEntity(planId));
    }

    public Plan getPlanEntity(Long planId) {
        return planRepository.findById(planId)
            .orElseThrow(() -> new ResourceNotFoundException("Plano nao encontrado"));
    }

    public Plan getPlanByCode(String code) {
        return planRepository.findByCodeIgnoreCase(code)
            .orElseThrow(() -> new ResourceNotFoundException("Plano nao encontrado"));
    }

    @Transactional
    public PlanRecordDTO updatePlan(Long planId, PlanRecordDTO dto) {
        validatePlan(dto);
        Plan plan = getPlanEntity(planId);
        if (!plan.getCode().equalsIgnoreCase(dto.code()) && planRepository.existsByCodeIgnoreCase(dto.code())) {
            throw new DuplicationException("Plano ja existe");
        }
        BeanUtils.copyProperties(PlanMapper.toEntity(dto), plan, "id");
        return PlanMapper.toDTO(planRepository.save(plan));
    }

    @Transactional
    public void toggleActive(Long planId) {
        Plan plan = getPlanEntity(planId);
        plan.setActive(!plan.getActive());
        planRepository.save(plan);
    }

    private void validatePlan(PlanRecordDTO dto) {
        if (Objects.isNull(dto)) {
            throw new InvalidRequestException("Plano e obrigatorio");
        }
        if (Objects.isNull(dto.featureLimits()) || dto.featureLimits().isEmpty()) {
            throw new InvalidRequestException("Limites de funcionalidades do plano sao obrigatorios");
        }

        Set<FeatureEnum> featuresFromLimits = new HashSet<>();
        for (PlanFeatureLimitRecordDTO limit : dto.featureLimits()) {
            FeatureEnum feature = validateFeatureLimit(limit);
            if (!featuresFromLimits.add(feature)) {
                throw new InvalidRequestException("Limite duplicado para funcionalidade " + feature);
            }
        }

        if (Objects.nonNull(dto.features()) && !dto.features().equals(featuresFromLimits)) {
            throw new InvalidRequestException("Campo features deve corresponder as funcionalidades em featureLimits");
        }
    }

    private FeatureEnum validateFeatureLimit(PlanFeatureLimitRecordDTO limit) {
        if (Objects.isNull(limit)) {
            throw new InvalidRequestException("Limite de funcionalidade nao pode ser nulo");
        }
        FeatureEnum feature = limit.feature();
        if (Objects.isNull(feature)) {
            throw new InvalidRequestException("Funcionalidade do limite e obrigatoria");
        }
        if (!feature.isUsageMetered() && Objects.nonNull(limit.usageLimit())) {
            throw new InvalidRequestException("Funcionalidade " + feature + " nao aceita limite numerico de uso");
        }
        return feature;
    }
}
