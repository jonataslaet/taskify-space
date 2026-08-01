package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
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
import java.util.Optional;

@Repository
public interface UserRegistrationConfirmationRepository
    extends JpaRepository<@NonNull UserRegistrationConfirmation, @NonNull Long> {

    @Query("""
        SELECT confirmation.id AS id, confirmation.user.id AS userId
        FROM UserRegistrationConfirmation confirmation
        WHERE confirmation.tokenHash = :tokenHash
            AND confirmation.usedAt IS NULL
        """)
    List<ConfirmationReference> findUnusedConfirmationReferencesByTokenHash(@Param("tokenHash") String tokenHash);

    interface ConfirmationReference {
        Long getId();
        Long getUserId();
    }

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT confirmation
        FROM UserRegistrationConfirmation confirmation
        JOIN FETCH confirmation.user user
        WHERE confirmation.id = :confirmationId
        """)
    Optional<UserRegistrationConfirmation> findByIdForUpdate(@Param("confirmationId") Long confirmationId);

    @Modifying(flushAutomatically = true)
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
