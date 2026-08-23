package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
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
public interface PasswordRecoveryRepository extends JpaRepository<@NonNull PasswordRecovery, @NonNull Long> {

    @Query("""
        SELECT passRecovery FROM PasswordRecovery passRecovery
        WHERE passRecovery.tokenHash = :tokenHash
            AND passRecovery.expiration > :now
            AND passRecovery.usedAt IS NULL
        """)
    List<PasswordRecovery> findValidPasswordRecoveries(
        @Param("tokenHash") String tokenHash,
        @Param("now") Instant now);

    @Query("""
        SELECT COUNT(passRecovery) > 0 FROM PasswordRecovery passRecovery
        WHERE passRecovery.tokenHash = :tokenHash
            AND passRecovery.expiration > :now
            AND passRecovery.usedAt IS NULL
        """)
    boolean existsValidPasswordRecoveryByTokenHash(
        @Param("tokenHash") String tokenHash,
        @Param("now") Instant now);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT passRecovery FROM PasswordRecovery passRecovery
        WHERE passRecovery.requestTokenHash = :requestTokenHash
            AND passRecovery.expiration > :now
            AND passRecovery.usedAt IS NULL
        """)
    Optional<PasswordRecovery> findPendingByRequestTokenHashForUpdate(
        @Param("requestTokenHash") String requestTokenHash,
        @Param("now") Instant now);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT passRecovery FROM PasswordRecovery passRecovery
        WHERE passRecovery.resetSessionHash = :resetSessionHash
            AND passRecovery.resetSessionExpiration > :now
            AND passRecovery.resetSessionUsedAt IS NULL
        """)
    Optional<PasswordRecovery> findValidResetSessionForUpdate(
        @Param("resetSessionHash") String resetSessionHash,
        @Param("now") Instant now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        UPDATE PasswordRecovery passRecovery
        SET passRecovery.expiration = :expiration
        WHERE passRecovery.email = :email
            AND passRecovery.expiration > :expiration
            AND passRecovery.usedAt IS NULL
        """)
    int expireValidPasswordRecoveriesByEmail(
        @Param("email") String email,
        @Param("expiration") Instant expiration);
}
