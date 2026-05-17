package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Plan;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PlanRepository extends JpaRepository<@NonNull Plan, @NonNull Long> {

    boolean existsByCodeIgnoreCase(String code);

    Optional<Plan> findByCodeIgnoreCase(String code);
}
