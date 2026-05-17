package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PlanFeatureLimit;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class FeatureAccessService {

    private static final Set<SubscriptionStatusEnum> ACTIVE_STATUSES =
        Set.of(SubscriptionStatusEnum.ACTIVE, SubscriptionStatusEnum.TRIALING);

    private final SubscriptionRepository subscriptionRepository;
    private final SpaceRepository spaceRepository;
    private final TaskRepository taskRepository;
    private final TaskExecutionRepository taskExecutionRepository;
    private final Clock clock;

    public FeatureAccessService(
        SubscriptionRepository subscriptionRepository,
        SpaceRepository spaceRepository,
        TaskRepository taskRepository,
        TaskExecutionRepository taskExecutionRepository,
        Clock clock) {
        this.subscriptionRepository = subscriptionRepository;
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
        if (user.getRole().equals(UserRoleEnum.ROLE_ADMIN)) {
            return true;
        }
        Set<SpaceUserRoleEnum> spaceUserRoles = resolveSpaceUserRoles(user, space);
        UsageGrant usageGrant = resolveUsageGrant(user, feature, spaceUserRoles);
        if (!usageGrant.granted()) {
            return false;
        }
        if (usageGrant.unlimited()) {
            return true;
        }
        long currentUsage = countUsage(user, feature, usageGrant.periodStart(), usageGrant.periodEnd());
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

    private UsageGrant resolveUsageGrant(User user, FeatureEnum feature, Set<SpaceUserRoleEnum> spaceUserRoles) {
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
                if (!matches(limit, feature, spaceUserRoles)) {
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

    private boolean matches(PlanFeatureLimit limit, FeatureEnum feature, Set<SpaceUserRoleEnum> spaceUserRoles) {
        if (!limit.getFeature().equals(feature)) {
            return false;
        }
        return Objects.isNull(limit.getSpaceUserRole()) || spaceUserRoles.contains(limit.getSpaceUserRole());
    }

    private Set<SpaceUserRoleEnum> resolveSpaceUserRoles(User user, Space space) {
        if (Objects.isNull(space)) {
            return Set.of();
        }
        return space.getSpaceMemberships().stream()
            .filter(item -> item.getUser().getId().equals(user.getId()))
            .filter(item -> SpaceMembershipStatusEnum.APPROVED.equals(item.getSpaceMembershipStatusEnum()))
            .map(SpaceMembership::getSpaceUserRole)
            .collect(Collectors.toSet());
    }

    private long countUsage(User user, FeatureEnum feature, Instant periodStart, Instant periodEnd) {
        return switch (feature) {
            case CREATE_SPACE -> spaceRepository.countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                user.getId(), periodStart, periodEnd);
            case CREATE_TASK -> taskRepository.countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                user.getId(), periodStart, periodEnd);
            case FINISH_TASK -> taskExecutionRepository.countExecutionsByExecutorInPeriod(
                user.getId(), periodStart, periodEnd);
            case READ_SPACE, UPDATE_SPACE, DELETE_SPACE,
                 ACTIVE_OR_INACTIVE_SPACE,
                 READ_TASK, UPDATE_TASK, DELETE_TASK,
                 MANAGE_PARTICIPANTS -> 0;
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
