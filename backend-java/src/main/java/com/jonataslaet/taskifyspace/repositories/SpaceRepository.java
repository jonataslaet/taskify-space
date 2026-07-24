package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Space;
import jakarta.persistence.LockModeType;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;

@Repository
public interface SpaceRepository extends JpaRepository<@NonNull Space, @NonNull Long>, JpaSpecificationExecutor<@NonNull Space> {

    long countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
        Long creatorId,
        Instant periodStart,
        Instant periodEnd);

    boolean existsByCreatorId(Long creatorId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT space FROM Space space WHERE space.id = :spaceId")
    Optional<Space> findByIdForUpdate(@Param("spaceId") Long spaceId);

}
