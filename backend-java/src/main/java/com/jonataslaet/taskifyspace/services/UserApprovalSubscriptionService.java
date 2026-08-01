package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.repositories.PlanRepository;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Objects;

@Service
@Transactional(readOnly = true)
public class UserApprovalSubscriptionService {

    private static final String BASIC_PLAN_CODE = "BASIC";
    private static final long BASIC_PLAN_DAYS = 30L;

    private final PlanRepository planRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final Clock clock;

    public UserApprovalSubscriptionService(
        PlanRepository planRepository,
        SubscriptionRepository subscriptionRepository,
        Clock clock) {
        this.planRepository = planRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.clock = clock;
    }

    @Transactional
    public void grantBasicPlanForApprovedUserWithoutPlan(User user) {
        validateUser(user);
        Instant now = Instant.now(clock);
        List<Subscription> accessSubscriptions = subscriptionRepository.findByUserIdAndStatusInForUpdate(
            user.getId(), Subscription.accessStatuses());

        expireEndedSubscriptions(accessSubscriptions, now);
        if (accessSubscriptions.stream().anyMatch(Subscription::hasAccessStatus)) {
            return;
        }

        Plan basicPlan = getActiveBasicPlan();
        Subscription subscription = new Subscription();
        subscription.setUser(user);
        subscription.setPlan(basicPlan);
        subscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        subscription.setProvider(SubscriptionProviderEnum.INTERNAL);
        subscription.setCurrentPeriodStart(now);
        subscription.setCurrentPeriodEnd(now.plus(BASIC_PLAN_DAYS, ChronoUnit.DAYS));
        subscriptionRepository.save(subscription);
    }

    private void validateUser(User user) {
        if (Objects.isNull(user) || Objects.isNull(user.getId())) {
            throw new InvalidRequestException("Usuario e obrigatorio para conceder plano BASIC");
        }
    }

    private void expireEndedSubscriptions(List<Subscription> subscriptions, Instant now) {
        List<Subscription> expiredSubscriptions = subscriptions.stream()
            .filter(subscription -> hasEndedAtOrBefore(subscription, now))
            .toList();
        if (expiredSubscriptions.isEmpty()) return;

        expiredSubscriptions.forEach(subscription -> subscription.setStatus(SubscriptionStatusEnum.EXPIRED));
        subscriptionRepository.saveAll(expiredSubscriptions);
        subscriptionRepository.flush();
    }

    private boolean hasEndedAtOrBefore(Subscription subscription, Instant now) {
        return Objects.nonNull(subscription.getCurrentPeriodEnd())
            && !subscription.getCurrentPeriodEnd().isAfter(now);
    }

    private Plan getActiveBasicPlan() {
        Plan basicPlan = planRepository.findByCodeIgnoreCase(BASIC_PLAN_CODE)
            .orElseThrow(() -> new ResourceNotFoundException("Plano BASIC nao encontrado"));
        if (!Boolean.TRUE.equals(basicPlan.getActive())) {
            throw new InvalidRequestException("Plano BASIC inativo nao pode ser concedido");
        }
        return basicPlan;
    }
}
