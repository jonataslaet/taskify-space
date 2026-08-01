package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.repositories.PlanRepository;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anySet;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserApprovalSubscriptionServiceTests {

    private static final Instant NOW = Instant.parse("2026-08-01T12:00:00Z");

    @Mock
    private PlanRepository planRepository;

    @Mock
    private SubscriptionRepository subscriptionRepository;

    private UserApprovalSubscriptionService userApprovalSubscriptionService;

    @BeforeEach
    void setUp() {
        userApprovalSubscriptionService = new UserApprovalSubscriptionService(
            planRepository,
            subscriptionRepository,
            Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void grantBasicPlanForApprovedUserWithoutPlanCreatesThirtyDaySubscription() {
        User user = createUser(1L);
        Plan basicPlan = createPlan(10L);
        when(subscriptionRepository.findByUserIdAndStatusInForUpdate(eq(user.getId()), anySet()))
            .thenReturn(List.of());
        when(planRepository.findByCodeIgnoreCase("BASIC")).thenReturn(Optional.of(basicPlan));

        userApprovalSubscriptionService.grantBasicPlanForApprovedUserWithoutPlan(user);

        ArgumentCaptor<Subscription> subscriptionCaptor = ArgumentCaptor.forClass(Subscription.class);
        verify(subscriptionRepository).save(subscriptionCaptor.capture());
        Subscription subscription = subscriptionCaptor.getValue();
        assertThat(subscription.getUser()).isSameAs(user);
        assertThat(subscription.getPlan()).isSameAs(basicPlan);
        assertThat(subscription.getStatus()).isEqualTo(SubscriptionStatusEnum.ACTIVE);
        assertThat(subscription.getProvider()).isEqualTo(SubscriptionProviderEnum.INTERNAL);
        assertThat(subscription.getCurrentPeriodStart()).isEqualTo(NOW);
        assertThat(subscription.getCurrentPeriodEnd()).isEqualTo(NOW.plusSeconds(30L * 24L * 60L * 60L));
    }

    @Test
    void grantBasicPlanForApprovedUserWithoutPlanDoesNothingWhenUserAlreadyHasPlan() {
        User user = createUser(1L);
        Subscription currentSubscription = new Subscription();
        currentSubscription.setUser(user);
        currentSubscription.setPlan(createPlan(10L));
        currentSubscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        currentSubscription.setCurrentPeriodStart(NOW.minusSeconds(60));
        when(subscriptionRepository.findByUserIdAndStatusInForUpdate(eq(user.getId()), anySet()))
            .thenReturn(List.of(currentSubscription));

        userApprovalSubscriptionService.grantBasicPlanForApprovedUserWithoutPlan(user);

        verify(planRepository, never()).findByCodeIgnoreCase(any());
        verify(subscriptionRepository, never()).save(any(Subscription.class));
    }

    @Test
    void grantBasicPlanForApprovedUserWithoutPlanExpiresEndedSubscriptionBeforeCreatingNewOne() {
        User user = createUser(1L);
        Subscription endedSubscription = new Subscription();
        endedSubscription.setUser(user);
        endedSubscription.setPlan(createPlan(10L));
        endedSubscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        endedSubscription.setCurrentPeriodStart(NOW.minusSeconds(120));
        endedSubscription.setCurrentPeriodEnd(NOW);
        when(subscriptionRepository.findByUserIdAndStatusInForUpdate(eq(user.getId()), anySet()))
            .thenReturn(List.of(endedSubscription));
        when(planRepository.findByCodeIgnoreCase("BASIC")).thenReturn(Optional.of(createPlan(10L)));

        userApprovalSubscriptionService.grantBasicPlanForApprovedUserWithoutPlan(user);

        assertThat(endedSubscription.getStatus()).isEqualTo(SubscriptionStatusEnum.EXPIRED);
        verify(subscriptionRepository).saveAll(List.of(endedSubscription));
        verify(subscriptionRepository).flush();
        verify(subscriptionRepository).save(any(Subscription.class));
    }

    private User createUser(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        return user;
    }

    private Plan createPlan(Long id) {
        Plan plan = new Plan();
        plan.setId(id);
        plan.setCode("BASIC");
        plan.setName("Basic");
        plan.setActive(true);
        return plan;
    }
}
