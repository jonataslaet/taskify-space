package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SubscriptionRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.SubscriptionMapper;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class SubscriptionService {

    private final SubscriptionRepository subscriptionRepository;
    private final PlanService planService;
    private final UserService userService;
    private final Clock clock;

    public SubscriptionService(
        SubscriptionRepository subscriptionRepository, PlanService planService, UserService userService, Clock clock) {
        this.subscriptionRepository = subscriptionRepository;
        this.planService = planService;
        this.userService = userService;
        this.clock = clock;
    }

    @Transactional
    public SubscriptionRecordDTO grantSubscription(Long userId, Long planId, SubscriptionRecordDTO dto) {
        User user = userService.findUserById(userId);
        Plan plan = planService.getPlanEntity(planId);
        Subscription subscription = new Subscription();
        subscription.setUser(user);
        subscription.setPlan(plan);
        subscription.setStatus(dto.status() == null ? SubscriptionStatusEnum.ACTIVE : dto.status());
        subscription.setProvider(dto.provider() == null ? SubscriptionProviderEnum.INTERNAL : dto.provider());
        subscription.setCurrentPeriodStart(dto.currentPeriodStart() == null ? Instant.now(clock) : dto.currentPeriodStart());
        subscription.setCurrentPeriodEnd(dto.currentPeriodEnd());
        subscription.setExternalCustomerId(dto.externalCustomerId());
        subscription.setExternalSubscriptionId(dto.externalSubscriptionId());
        subscription.setExternalPriceId(dto.externalPriceId());
        return SubscriptionMapper.toDTO(subscriptionRepository.save(subscription));
    }

    public Page<@NonNull SubscriptionRecordDTO> findAll(Pageable pageable) {
        return subscriptionRepository.findAll(pageable).map(SubscriptionMapper::toDTO);
    }

    public List<SubscriptionRecordDTO> findByUser(Long userId) {
        return subscriptionRepository.findByUserId(userId).stream().map(SubscriptionMapper::toDTO).toList();
    }

    public SubscriptionRecordDTO findById(Long subscriptionId) {
        return SubscriptionMapper.toDTO(getSubscriptionEntity(subscriptionId));
    }

    @Transactional
    public void cancelSubscription(Long subscriptionId) {
        Subscription subscription = getSubscriptionEntity(subscriptionId);
        subscription.setStatus(SubscriptionStatusEnum.CANCELED);
        subscription.setCurrentPeriodEnd(Instant.now(clock));
        subscriptionRepository.save(subscription);
    }

    public Subscription getSubscriptionEntity(Long subscriptionId) {
        return subscriptionRepository.findById(subscriptionId)
            .orElseThrow(() -> new ResourceNotFoundException("Assinatura nao encontrada"));
    }
}
