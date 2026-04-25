package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.RefreshToken;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<@NonNull RefreshToken, @NonNull Long> {
    Optional<RefreshToken> findByTokenHash(String tokenHash);
}
