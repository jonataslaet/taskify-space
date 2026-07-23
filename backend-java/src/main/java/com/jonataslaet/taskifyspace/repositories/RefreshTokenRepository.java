package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.RefreshToken;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<@NonNull RefreshToken, @NonNull Long> {
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    void deleteByUserId(Long userId);

    @Modifying(flushAutomatically = true)
    @Query("""
        UPDATE RefreshToken refreshToken
        SET refreshToken.revokedAt = :revokedAt,
            refreshToken.replacedByHash = :replacedByHash
        WHERE refreshToken.tokenHash = :tokenHash
            AND refreshToken.revokedAt IS NULL
            AND refreshToken.replacedByHash IS NULL
            AND refreshToken.expiresAt >= :revokedAt
        """)
    int rotateActiveToken(
        @Param("tokenHash") String tokenHash,
        @Param("replacedByHash") String replacedByHash,
        @Param("revokedAt") Instant revokedAt);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        UPDATE RefreshToken refreshToken
        SET refreshToken.revokedAt = :revokedAt
        WHERE refreshToken.user.id = :userId
            AND refreshToken.revokedAt IS NULL
        """)
    int revokeActiveByUserId(@Param("userId") Long userId, @Param("revokedAt") Instant revokedAt);
}
