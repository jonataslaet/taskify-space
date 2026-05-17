package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.PlanRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
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

@Service
@Transactional(readOnly = true)
public class PlanService {

    private final PlanRepository planRepository;

    public PlanService(PlanRepository planRepository) {
        this.planRepository = planRepository;
    }

    @Transactional
    public PlanRecordDTO createPlan(PlanRecordDTO dto) {
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
        Plan plan = getPlanEntity(planId);
        if (!plan.getCode().equalsIgnoreCase(dto.code()) && planRepository.existsByCodeIgnoreCase(dto.code())) {
            throw new DuplicationException("Plano ja existe");
        }
        BeanUtils.copyProperties(PlanMapper.toEntity(dto), plan, "id");
        if (Objects.isNull(dto.features())) {
            plan.setFeatures(new HashSet<>());
        }
        return PlanMapper.toDTO(planRepository.save(plan));
    }

    @Transactional
    public void toggleActive(Long planId) {
        Plan plan = getPlanEntity(planId);
        plan.setActive(!plan.getActive());
        planRepository.save(plan);
    }
}
