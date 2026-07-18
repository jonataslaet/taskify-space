package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.GrantSubscriptionRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SubscriptionRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
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
import java.util.Objects;
import java.util.Optional;

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
    public SubscriptionRecordDTO grantSubscription(Long userId, Long planId, GrantSubscriptionRequestDTO request) {
        if (Objects.isNull(request)) {
            throw new InvalidRequestException("Dados da assinatura sao obrigatorios");
        }
        User user = userService.findUserById(userId);
        Plan plan = planService.getPlanEntity(planId);
        if (!Boolean.TRUE.equals(plan.getActive())) {
            throw new InvalidRequestException("Plano inativo nao pode ser concedido");
        }

        Instant now = Instant.now(clock);
        Optional<Subscription> activeSubscription = findActiveSubscription(userId, planId, now);
        if (activeSubscription.isPresent()) {
            return SubscriptionMapper.toDTO(activeSubscription.get());
        }

        Instant periodStart = Objects.isNull(request.currentPeriodStart()) ? now : request.currentPeriodStart();
        if (Objects.nonNull(request.currentPeriodEnd()) && !request.currentPeriodEnd().isAfter(periodStart)) {
            throw new InvalidRequestException("Fim do periodo da assinatura deve ser posterior ao inicio");
        }

        Subscription subscription = new Subscription();
        subscription.setUser(user);
        subscription.setPlan(plan);
        subscription.setStatus(request.status() == null ? SubscriptionStatusEnum.ACTIVE : request.status());
        subscription.setProvider(request.provider() == null ? SubscriptionProviderEnum.INTERNAL : request.provider());
        subscription.setCurrentPeriodStart(periodStart);
        subscription.setCurrentPeriodEnd(request.currentPeriodEnd());
        subscription.setExternalCustomerId(request.externalCustomerId());
        subscription.setExternalSubscriptionId(request.externalSubscriptionId());
        subscription.setExternalPriceId(request.externalPriceId());
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

    private Optional<Subscription> findActiveSubscription(Long userId, Long planId, Instant now) {
        return subscriptionRepository.findByUserIdAndPlanId(userId, planId).stream()
            .filter(subscription -> subscription.grantsAccessAt(now))
            .findFirst();
    }
}
