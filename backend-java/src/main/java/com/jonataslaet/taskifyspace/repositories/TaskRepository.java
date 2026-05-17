package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Task;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.time.Instant;

@Repository
public interface TaskRepository extends JpaRepository<@NonNull Task, @NonNull Long>, JpaSpecificationExecutor<@NonNull Task> {
    boolean existsBySpaceIdAndDescriptionIgnoreCase(Long spaceId, String description);

    long countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
        Long creatorId,
        Instant periodStart,
        Instant periodEnd);

    void deleteBySpaceId(Long spaceId);
}
