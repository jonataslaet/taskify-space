package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PlanFeatureLimit;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;

@Service
public class FeatureAccessService {

    private final SubscriptionRepository subscriptionRepository;
    private final SpaceMembershipRepository spaceMembershipRepository;
    private final SpaceRepository spaceRepository;
    private final TaskRepository taskRepository;
    private final TaskExecutionRepository taskExecutionRepository;
    private final Clock clock;

    public FeatureAccessService(
        SubscriptionRepository subscriptionRepository,
        SpaceMembershipRepository spaceMembershipRepository,
        SpaceRepository spaceRepository,
        TaskRepository taskRepository,
        TaskExecutionRepository taskExecutionRepository,
        Clock clock) {
        this.subscriptionRepository = subscriptionRepository;
        this.spaceMembershipRepository = spaceMembershipRepository;
        this.spaceRepository = spaceRepository;
        this.taskRepository = taskRepository;
        this.taskExecutionRepository = taskExecutionRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public boolean hasFeature(User user, FeatureEnum feature) {
        return hasFeature(user, feature, null);
    }

    @Transactional(readOnly = true)
    public boolean hasFeature(User user, FeatureEnum feature, Space space) {
        UsageGrant usageGrant = resolveUsageGrant(user, feature);
        if (!usageGrant.granted()) {
            return false;
        }
        if (usageGrant.unlimited()) {
            return true;
        }
        long currentUsage = countUsage(user, feature, space, usageGrant.periodStart(), usageGrant.periodEnd());
        return currentUsage < usageGrant.usageLimit();
    }

    public void requireFeature(User user, FeatureEnum feature) {
        requireFeature(user, feature, null);
    }

    public void requireFeature(User user, FeatureEnum feature, Space space) {
        if (!hasFeature(user, feature, space)) {
            throw new ForbiddenException("Plano atual nao libera a funcionalidade " + feature);
        }
    }

    private UsageGrant resolveUsageGrant(User user, FeatureEnum feature) {
        Instant now = Instant.now(clock);
        long usageLimit = 0;
        boolean granted = false;
        boolean unlimited = false;
        Instant periodStart = Instant.parse("9999-12-31T23:59:59Z");
        Instant periodEnd = Instant.EPOCH;

        for (Subscription subscription : subscriptionRepository.findByUserId(user.getId())) {
            if (!subscription.grantsAccessAt(now)) {
                continue;
            }

            for (PlanFeatureLimit limit : subscription.getPlan().getFeatureLimits()) {
                if (!limit.getFeature().equals(feature)) {
                    continue;
                }
                granted = true;
                periodStart = min(periodStart, nullableStart(subscription.getCurrentPeriodStart()));
                periodEnd = max(periodEnd, nullableEnd(subscription.getCurrentPeriodEnd()));
                if (Objects.isNull(limit.getUsageLimit())) {
                    unlimited = true;
                } else {
                    usageLimit += limit.getUsageLimit();
                }
            }
        }

        return new UsageGrant(granted, unlimited, usageLimit, nullableGrantStart(granted, periodStart),
            nullableGrantEnd(granted, periodEnd));
    }

    private long countUsage(
        User user,
        FeatureEnum feature,
        Space space,
        Instant periodStart,
        Instant periodEnd
    ) {
        return switch (feature) {
            case CREATE_SPACE ->
                spaceRepository.countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                    user.getId(),
                    periodStart,
                    periodEnd
                );

            case CREATE_TASK ->
                taskRepository.countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                    user.getId(),
                    periodStart,
                    periodEnd
                );

            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT ->
                Objects.isNull(space)
                    ? Long.MAX_VALUE
                    : spaceMembershipRepository
                      .countBySpaceIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
                          space.getId(),
                          SpaceMembershipStatusEnum.APPROVED,
                          feature.approvalSpaceUserRole()
                      );
        };
    }

    private Instant nullableStart(Instant value) {
        return Objects.isNull(value) ? Instant.EPOCH : value;
    }

    private Instant nullableEnd(Instant value) {
        return Objects.isNull(value) ? Instant.parse("9999-12-31T23:59:59Z") : value;
    }

    private Instant nullableGrantStart(boolean granted, Instant value) {
        return granted ? value : Instant.EPOCH;
    }

    private Instant nullableGrantEnd(boolean granted, Instant value) {
        return granted ? value : Instant.EPOCH;
    }

    private Instant max(Instant current, Instant candidate) {
        return candidate.isAfter(current) ? candidate : current;
    }

    private Instant min(Instant current, Instant candidate) {
        return candidate.isBefore(current) ? candidate : current;
    }

    private record UsageGrant(
        boolean granted,
        boolean unlimited,
        long usageLimit,
        Instant periodStart,
        Instant periodEnd
    ) {}
}
