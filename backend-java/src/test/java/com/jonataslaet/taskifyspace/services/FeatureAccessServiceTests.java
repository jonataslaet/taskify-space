package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.Plan;
import com.jonataslaet.taskifyspace.entities.PlanFeatureLimit;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FeatureAccessServiceTests {

    private static final Instant NOW = Instant.parse("2026-07-17T12:00:00Z");

    @Mock
    private SubscriptionRepository subscriptionRepository;

    @Mock
    private SpaceMembershipRepository spaceMembershipRepository;

    @Mock
    private SpaceRepository spaceRepository;

    @Mock
    private TaskRepository taskRepository;

    @Mock
    private UserRepository userRepository;

    private FeatureAccessService featureAccessService;

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        featureAccessService = new FeatureAccessService(
            subscriptionRepository,
            spaceMembershipRepository,
            spaceRepository,
            taskRepository,
            userRepository,
            clock);
    }

    @Test
    void adminWithoutSubscriptionDoesNotHavePlanFeature() {
        User admin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        when(subscriptionRepository.findByUserId(admin.getId())).thenReturn(List.of());

        boolean hasFeature = featureAccessService.hasFeature(admin, FeatureEnum.CREATE_SPACE);

        assertThat(hasFeature).isFalse();
    }

    @Test
    void requireFeatureWithUsageLockLocksUserBeforeCheckingUserScopedUsage() {
        User user = createUser(5L, UserRoleEnum.ROLE_USER);
        Plan plan = new Plan();
        plan.setActive(true);
        plan.setFeatureLimits(Set.of(new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, 1L)));
        Subscription subscription = new Subscription();
        subscription.setUser(user);
        subscription.setPlan(plan);
        subscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        subscription.setCurrentPeriodStart(NOW.minusSeconds(60));

        when(userRepository.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));
        when(subscriptionRepository.findByUserId(user.getId())).thenReturn(List.of(subscription));

        featureAccessService.requireFeatureWithUsageLock(user, FeatureEnum.CREATE_SPACE);

        verify(userRepository).findByIdForUpdate(user.getId());
    }

    @Test
    void userWithActiveSubscriptionHasPlanFeature() {
        User user = createUser(2L, UserRoleEnum.ROLE_USER);
        Plan plan = new Plan();
        plan.setActive(true);
        plan.setFeatureLimits(Set.of(new PlanFeatureLimit(FeatureEnum.CREATE_SPACE, 1L)));

        Subscription subscription = new Subscription();
        subscription.setUser(user);
        subscription.setPlan(plan);
        subscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        subscription.setCurrentPeriodStart(NOW.minusSeconds(60));

        when(subscriptionRepository.findByUserId(user.getId())).thenReturn(List.of(subscription));
        when(spaceRepository.countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            user.getId(), subscription.getCurrentPeriodStart(), Instant.parse("9999-12-31T23:59:59Z")))
            .thenReturn(0L);

        boolean hasFeature = featureAccessService.hasFeature(user, FeatureEnum.CREATE_SPACE);

        assertThat(hasFeature).isTrue();
    }

    @Test
    void userCanApproveSpaceMembershipWhenSpaceIsBelowPlanLimit() {
        User user = createUser(3L, UserRoleEnum.ROLE_USER);
        Space space = new Space();
        space.setId(10L);
        Subscription subscription = activeSubscription(
            user,
            new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, 3L));

        when(subscriptionRepository.findByUserId(user.getId())).thenReturn(List.of(subscription));
        when(spaceMembershipRepository.countBySpaceIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
            space.getId(), SpaceMembershipStatusEnum.APPROVED, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT))
            .thenReturn(2L);

        boolean hasFeature = featureAccessService.hasFeature(
            user, FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, space);

        assertThat(hasFeature).isTrue();
    }

    @Test
    void userCannotApproveSpaceMembershipWhenSpaceReachedPlanLimit() {
        User user = createUser(4L, UserRoleEnum.ROLE_USER);
        Space space = new Space();
        space.setId(11L);
        Subscription subscription = activeSubscription(
            user,
            new PlanFeatureLimit(FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, 3L));

        when(subscriptionRepository.findByUserId(user.getId())).thenReturn(List.of(subscription));
        when(spaceMembershipRepository.countBySpaceIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
            space.getId(), SpaceMembershipStatusEnum.APPROVED, SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT))
            .thenReturn(3L);

        boolean hasFeature = featureAccessService.hasFeature(
            user, FeatureEnum.APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT, space);

        assertThat(hasFeature).isFalse();
    }

    private User createUser(Long id, UserRoleEnum role) {
        User user = new User();
        user.setId(id);
        user.setRole(role);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }

    private Subscription activeSubscription(User user, PlanFeatureLimit featureLimit) {
        Plan plan = new Plan();
        plan.setActive(true);
        plan.setFeatureLimits(Set.of(featureLimit));

        Subscription subscription = new Subscription();
        subscription.setUser(user);
        subscription.setPlan(plan);
        subscription.setStatus(SubscriptionStatusEnum.ACTIVE);
        subscription.setCurrentPeriodStart(NOW.minusSeconds(60));
        return subscription;
    }
}
