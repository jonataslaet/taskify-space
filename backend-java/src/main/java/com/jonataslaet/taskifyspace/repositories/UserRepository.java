package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import jakarta.persistence.LockModeType;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<@NonNull User, @NonNull Long>, JpaSpecificationExecutor<@NonNull User> {

    boolean existsByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.email = :username")
    Optional<User> findByEmail(@Param("username") String username);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.id = :userId")
    Optional<User> findByIdForUpdate(@Param("userId") Long userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.email = :email")
    Optional<User> findByEmailForUpdate(@Param("email") String email);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.role = :role AND u.status = :status")
    List<User> findByRoleAndStatusForUpdate(
        @Param("role") UserRoleEnum role,
        @Param("status") UserStatusEnum status);

    @Query(
        value = """
            SELECT u.id
            FROM users u
            WHERE u.status = :status
                AND u.email_confirmed_at IS NULL
                AND u.registration_confirmation_expires_at IS NOT NULL
                AND u.registration_confirmation_expires_at <= :now
            ORDER BY u.id ASC
            LIMIT :limit
            FOR UPDATE SKIP LOCKED
            """,
        nativeQuery = true)
    List<Long> findExpiredUnconfirmedRegistrationUserIdsForUpdate(
        @Param("now") Instant now,
        @Param("status") String status,
        @Param("limit") int limit);

}
