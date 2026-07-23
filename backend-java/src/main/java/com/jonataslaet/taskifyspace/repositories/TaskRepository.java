package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Task;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE Task task SET task.creator = null WHERE task.creator.id = :userId")
    int clearCreatorByUserId(@Param("userId") Long userId);
}
