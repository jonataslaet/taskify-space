package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Subscription;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SubscriptionRepository extends JpaRepository<@NonNull Subscription, @NonNull Long> {

    List<Subscription> findByUserId(Long userId);

    List<Subscription> findByUserIdAndPlanId(Long userId, Long planId);
}
