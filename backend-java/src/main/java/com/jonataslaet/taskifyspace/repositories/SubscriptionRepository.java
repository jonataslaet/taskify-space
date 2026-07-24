package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Subscription;
import com.jonataslaet.taskifyspace.entities.enums.SubscriptionStatusEnum;
import jakarta.persistence.LockModeType;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Set;

@Repository
public interface SubscriptionRepository extends JpaRepository<@NonNull Subscription, @NonNull Long> {

    List<Subscription> findByUserId(Long userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT subscription
        FROM Subscription subscription
        WHERE subscription.user.id = :userId
            AND subscription.status IN :statuses
        ORDER BY subscription.id ASC
        """)
    List<Subscription> findByUserIdAndStatusInForUpdate(
        @Param("userId") Long userId,
        @Param("statuses") Set<SubscriptionStatusEnum> statuses);
}
