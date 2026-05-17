package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.enums.FeatureEnum;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

@Repository
public interface SubscriptionRepository extends JpaRepository<@NonNull Subscription, @NonNull Long> {

    List<Subscription> findByUserId(Long userId);

    @Query("""
        SELECT COUNT(s) > 0
        FROM Subscription s
        JOIN s.plan p
        JOIN p.features f
        WHERE s.user.id = :userId
          AND p.active = true
          AND s.status IN :statuses
          AND f = :feature
          AND (s.currentPeriodStart IS NULL OR s.currentPeriodStart <= :now)
          AND (s.currentPeriodEnd IS NULL OR s.currentPeriodEnd > :now)
        """)
    boolean userHasActiveFeature(
        @Param("userId") Long userId,
        @Param("feature") FeatureEnum feature,
        @Param("statuses") Collection<SubscriptionStatusEnum> statuses,
        @Param("now") Instant now
    );
}
