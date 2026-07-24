package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.GrantSubscriptionRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SubscriptionRecordDTO;
import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionProviderEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anySet;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SubscriptionServiceTests {

    private static final Instant NOW = Instant.parse("2026-07-17T12:00:00Z");

    @Mock
    private SubscriptionRepository subscriptionRepository;

    @Mock
    private PlanService planService;

    @Mock
    private UserService userService;

    private SubscriptionService subscriptionService;

    @BeforeEach
    void setUp() {
        subscriptionService = new SubscriptionService(
            subscriptionRepository,
            planService,
            userService,
            Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void grantSubscriptionCancelsCurrentPlanBeforeCreatingDifferentActivePlan() {
        User user = createUser(1L);
        Plan basicPlan = createPlan(10L, "BASIC");
        Plan proPlan = createPlan(20L, "PRO");
        Subscription currentSubscription = activeSubscription(100L, user, basicPlan);

        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(planService.getPlanEntity(proPlan.getId())).thenReturn(proPlan);
        when(subscriptionRepository.findByUserIdAndStatusInForUpdate(eq(user.getId()), anySet()))
            .thenReturn(List.of(currentSubscription));
        when(subscriptionRepository.save(any(Subscription.class))).thenAnswer(invocation -> {
            Subscription subscription = invocation.getArgument(0);
            subscription.setId(200L);
            return subscription;
        });

        SubscriptionRecordDTO grantedSubscription = subscriptionService.grantSubscription(
            user.getId(),
            proPlan.getId(),
            new GrantSubscriptionRequestDTO(null, null, null, null, null, null, null));

        assertThat(currentSubscription.getStatus()).isEqualTo(SubscriptionStatusEnum.CANCELED);
        assertThat(currentSubscription.getCurrentPeriodEnd()).isEqualTo(NOW);
        assertThat(grantedSubscription.planId()).isEqualTo(proPlan.getId());
        assertThat(grantedSubscription.status()).isEqualTo(SubscriptionStatusEnum.ACTIVE);

        ArgumentCaptor<Subscription> subscriptionCaptor = ArgumentCaptor.forClass(Subscription.class);
        verify(subscriptionRepository).save(subscriptionCaptor.capture());
        Subscription savedSubscription = subscriptionCaptor.getValue();
        assertThat(savedSubscription.getUser()).isSameAs(user);
        assertThat(savedSubscription.getPlan()).isSameAs(proPlan);
        assertThat(savedSubscription.getCurrentPeriodStart()).isEqualTo(NOW);

        InOrder inOrder = inOrder(subscriptionRepository);
        inOrder.verify(subscriptionRepository).saveAll(List.of(currentSubscription));
        inOrder.verify(subscriptionRepository).flush();
        inOrder.verify(subscriptionRepository).save(savedSubscription);
    }

    @Test
    void grantSubscriptionReturnsCurrentSubscriptionWhenSamePlanAlreadyHasAccessStatus() {
        User user = createUser(1L);
        Plan proPlan = createPlan(20L, "PRO");
        Subscription currentSubscription = activeSubscription(100L, user, proPlan);

        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(planService.getPlanEntity(proPlan.getId())).thenReturn(proPlan);
        when(subscriptionRepository.findByUserIdAndStatusInForUpdate(eq(user.getId()), anySet()))
            .thenReturn(List.of(currentSubscription));

        SubscriptionRecordDTO grantedSubscription = subscriptionService.grantSubscription(
            user.getId(),
            proPlan.getId(),
            new GrantSubscriptionRequestDTO(null, null, null, null, null, null, null));

        assertThat(grantedSubscription.id()).isEqualTo(currentSubscription.getId());
        assertThat(grantedSubscription.planId()).isEqualTo(proPlan.getId());
        verify(subscriptionRepository, never()).save(any(Subscription.class));
        verify(subscriptionRepository, never()).saveAll(any());
        verify(subscriptionRepository, never()).flush();
    }

    @Test
    void grantSubscriptionDoesNotCancelCurrentPlanWhenRequestedStatusDoesNotGrantAccess() {
        User user = createUser(1L);
        Plan proPlan = createPlan(20L, "PRO");

        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(planService.getPlanEntity(proPlan.getId())).thenReturn(proPlan);
        when(subscriptionRepository.save(any(Subscription.class))).thenAnswer(invocation -> {
            Subscription subscription = invocation.getArgument(0);
            subscription.setId(200L);
            return subscription;
        });

        SubscriptionRecordDTO grantedSubscription = subscriptionService.grantSubscription(
            user.getId(),
            proPlan.getId(),
            new GrantSubscriptionRequestDTO(
                SubscriptionStatusEnum.PAST_DUE,
                SubscriptionProviderEnum.INTERNAL,
                null,
                null,
                null,
                null,
                null));

        assertThat(grantedSubscription.status()).isEqualTo(SubscriptionStatusEnum.PAST_DUE);
        verify(subscriptionRepository, never()).findByUserIdAndStatusInForUpdate(any(), anySet());
    }

    private User createUser(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        return user;
    }

    private Plan createPlan(Long id, String code) {
        Plan plan = new Plan();
        plan.setId(id);
        plan.setCode(code);
        plan.setName(code + " Plan");
        plan.setActive(true);
        return plan;
    }

    private Subscription activeSubscription(Long id, User user, Plan plan) {
        Subscription subscription = new Subscription();
        subscription.setId(id);
        subscription.setUser(user);
        subscription.setPlan(plan);
        subscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        subscription.setProvider(SubscriptionProviderEnum.INTERNAL);
        subscription.setCurrentPeriodStart(NOW.minusSeconds(60));
        return subscription;
    }
}
