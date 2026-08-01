package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import jakarta.persistence.LockModeType;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface UserRegistrationConfirmationRepository
    extends JpaRepository<@NonNull UserRegistrationConfirmation, @NonNull Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT confirmation
        FROM UserRegistrationConfirmation confirmation
        JOIN FETCH confirmation.user user
        WHERE confirmation.tokenHash = :tokenHash
            AND confirmation.usedAt IS NULL
            AND confirmation.expiration > :now
        """)
    List<UserRegistrationConfirmation> findValidConfirmationsForUpdate(
        @Param("tokenHash") String tokenHash,
        @Param("now") Instant now);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT confirmation
        FROM UserRegistrationConfirmation confirmation
        JOIN FETCH confirmation.user user
        WHERE confirmation.tokenHash = :tokenHash
            AND confirmation.usedAt IS NULL
        """)
    List<UserRegistrationConfirmation> findUnusedConfirmationsForUpdate(@Param("tokenHash") String tokenHash);

    @Query("""
        SELECT DISTINCT confirmation.user.id
        FROM UserRegistrationConfirmation confirmation
        WHERE confirmation.usedAt IS NULL
            AND confirmation.expiration <= :now
            AND confirmation.user.status = :userStatus
            AND NOT EXISTS (
                SELECT validConfirmation.id
                FROM UserRegistrationConfirmation validConfirmation
                WHERE validConfirmation.user = confirmation.user
                    AND validConfirmation.usedAt IS NULL
                    AND validConfirmation.expiration > :now
            )
        ORDER BY confirmation.user.id ASC
        """)
    List<Long> findPendingUserIdsWithExpiredConfirmationAndNoValidConfirmation(
        @Param("now") Instant now,
        @Param("userStatus") UserStatusEnum userStatus);

    boolean existsByUserIdAndUsedAtIsNullAndExpirationAfter(Long userId, Instant now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        UPDATE UserRegistrationConfirmation confirmation
        SET confirmation.expiration = :expiration
        WHERE confirmation.user.id = :userId
            AND confirmation.usedAt IS NULL
            AND confirmation.expiration > :expiration
        """)
    int expireValidConfirmationsByUserId(
        @Param("userId") Long userId,
        @Param("expiration") Instant expiration);
}
