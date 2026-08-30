package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PlanFeatureLimit;
import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.SubscriptionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

@Service
public class FeatureAccessService {

    private final SubscriptionRepository subscriptionRepository;
    private final SpaceMembershipRepository spaceMembershipRepository;
    private final SpaceRepository spaceRepository;
    private final TaskRepository taskRepository;
    private final UserRepository userRepository;
    private final Clock clock;

    public FeatureAccessService(SubscriptionRepository subscriptionRepository,
        SpaceMembershipRepository spaceMembershipRepository, SpaceRepository spaceRepository,
        TaskRepository taskRepository, UserRepository userRepository, Clock clock) {
        this.subscriptionRepository = subscriptionRepository;
        this.spaceMembershipRepository = spaceMembershipRepository;
        this.spaceRepository = spaceRepository;
        this.taskRepository = taskRepository;
        this.userRepository = userRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public boolean hasFeature(User user, FeatureEnum feature) {
        return hasFeature(user, feature, null);
    }

    @Transactional(readOnly = true)
    public boolean hasFeature(User user, FeatureEnum feature, Space space) {
        User featureOwner = resolveFeatureOwner(user, feature, space);
        if (Objects.isNull(featureOwner)) return false;

        UsageGrant usageGrant = resolveUsageGrant(featureOwner, feature);
        if (!usageGrant.granted()) return false;
        if (usageGrant.unlimited()) return true;
        long currentUsage = countUsage(featureOwner, feature, space, usageGrant.periodStart(), usageGrant.periodEnd());
        return currentUsage < usageGrant.usageLimit();
    }

    public void requireFeature(User user, FeatureEnum feature, Space space) {
        if (!hasFeature(user, feature, space)) {
            throw new ForbiddenException("O plano atual ultrapassou o limite de " + feature.getDescription());
        }
    }

    @Transactional
    public void requireFeatureWithUsageLock(User user, FeatureEnum feature) {
        requireFeatureWithUsageLock(user, feature, null);
    }

    @Transactional
    public void requireFeatureWithUsageLock(User user, FeatureEnum feature, Space space) {
        lockUsageScope(user, feature, space);
        requireFeature(user, feature, space);
    }

    private void lockUsageScope(User user, FeatureEnum feature, Space space) {
        switch (feature) {
            case CREATE_SPACE, CREATE_TASK ->
                userRepository.findByIdForUpdate(user.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("User not found"));
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT -> {
                if (Objects.isNull(space)) {
                    throw new ForbiddenException("Espaco obrigatorio para validar limite de aprovacao");
                }
                spaceRepository.findByIdForUpdate(space.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("Espaco nao encontrado"));
            }
        }
    }

    private UsageGrant resolveUsageGrant(User user, FeatureEnum feature) {
        Instant now = Instant.now(clock);
        return resolveActiveSubscription(user, now)
            .map(subscription -> resolveUsageGrant(subscription, feature))
            .orElseGet(this::emptyUsageGrant);
    }

    private Optional<Subscription> resolveActiveSubscription(User user, Instant now) {
        List<Subscription> activeSubscriptions = subscriptionRepository.findByUserId(user.getId()).stream()
            .filter(subscription -> subscription.grantsAccessAt(now)).toList();

        if (activeSubscriptions.size() > 1) {
            throw new IllegalStateException("Usuario possui mais de uma assinatura ativa");
        }

        return activeSubscriptions.stream().findFirst();
    }

    private UsageGrant resolveUsageGrant(Subscription subscription, FeatureEnum feature) {
        for (PlanFeatureLimit limit : subscription.getPlan().getFeatureLimits()) {
            if (limit.getFeature().equals(feature)) {
                return new UsageGrant(true, Objects.isNull(limit.getUsageLimit()),
                    Objects.isNull(limit.getUsageLimit()) ? 0L : limit.getUsageLimit(),
                    nullableStart(subscription.getCurrentPeriodStart()),
                    nullableEnd(subscription.getCurrentPeriodEnd())
                );
            }
        }

        return emptyUsageGrant();
    }

    private UsageGrant emptyUsageGrant() {
        return new UsageGrant(false, false, 0L, Instant.EPOCH, Instant.EPOCH);
    }

    private User resolveFeatureOwner(User user, FeatureEnum feature, Space space) {
        if (!isSpaceOwnedFeature(feature)) return user;
        return Objects.isNull(space) ? null : space.getCreator();
    }

    private boolean isSpaceOwnedFeature(FeatureEnum feature) {
        return switch (feature) {
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT -> true;
            case CREATE_SPACE, CREATE_TASK -> false;
        };
    }

    private long countUsage(User user, FeatureEnum feature, Space space, Instant periodStart, Instant periodEnd) {
        return switch (feature) {
            case CREATE_SPACE ->
                spaceRepository.countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                    user.getId(), periodStart, periodEnd);

            case CREATE_TASK ->
                taskRepository.countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                    user.getId(), periodStart, periodEnd);

            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT ->
                Objects.isNull(space) ? Long.MAX_VALUE : spaceMembershipRepository
                .countBySpaceIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
                  space.getId(), SpaceMembershipStatusEnum.APPROVED, feature.approvalSpaceUserRole());
        };
    }

    private Instant nullableStart(Instant value) {
        return Objects.isNull(value) ? Instant.EPOCH : value;
    }

    private Instant nullableEnd(Instant value) {
        return Objects.isNull(value) ? Instant.parse("9999-12-31T23:59:59Z") : value;
    }

    private record UsageGrant(boolean granted, boolean unlimited,
        long usageLimit, Instant periodStart, Instant periodEnd) {}
}
