package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.time.Instant;

@Repository
public interface SpaceRepository extends JpaRepository<@NonNull Space, @NonNull Long>, JpaSpecificationExecutor<@NonNull Space> {

    long countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
        Long creatorId,
        Instant periodStart,
        Instant periodEnd);
}
