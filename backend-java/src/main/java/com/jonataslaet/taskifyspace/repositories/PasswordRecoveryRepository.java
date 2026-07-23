package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface PasswordRecoveryRepository extends JpaRepository<@NonNull PasswordRecovery, @NonNull Long> {

    @Query("""
        SELECT passRecovery FROM PasswordRecovery passRecovery
        WHERE passRecovery.tokenHash = :tokenHash
            AND passRecovery.expiration > :now
        """)
    List<PasswordRecovery> findValidPasswordRecoveries(
        @Param("tokenHash") String tokenHash,
        @Param("now") Instant now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        UPDATE PasswordRecovery passRecovery
        SET passRecovery.expiration = :expiration
        WHERE passRecovery.email = :email
            AND passRecovery.expiration > :expiration
        """)
    int expireValidPasswordRecoveriesByEmail(
        @Param("email") String email,
        @Param("expiration") Instant expiration);
}
