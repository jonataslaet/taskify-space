package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface PasswordRecoveryRepository extends JpaRepository<@NonNull PasswordRecovery, @NonNull Long> {

    @Query("SELECT passRecovery FROM PasswordRecovery passRecovery WHERE passRecovery.token = :token AND passRecovery.expiration > :now")
    List<PasswordRecovery> findValidPasswordRecoveries(String token, Instant now);
}
