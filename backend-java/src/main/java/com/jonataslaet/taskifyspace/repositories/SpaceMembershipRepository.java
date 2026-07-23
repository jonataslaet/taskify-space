package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import jakarta.persistence.LockModeType;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.Set;

@Repository
public interface SpaceMembershipRepository extends JpaRepository<
    @NonNull SpaceMembership, @NonNull Long>, JpaSpecificationExecutor<@NonNull SpaceMembership> {

    @Query(value = """
        SELECT sm.user FROM SpaceMembership sm WHERE sm.user.id in (:usersIds)
        AND sm.space.id = :spaceId AND sm.spaceMembershipStatusEnum = :status
        """)
    Set<User> findApprovedUsersByIds(
        @Param("spaceId") Long spaceId,
        @Param("usersIds") Set<Long> ids,
        @Param("status") SpaceMembershipStatusEnum status);

    @Query(value = """
        SELECT sm FROM SpaceMembership sm WHERE (:usersIds IS NULL or sm.user.id in (:usersIds)) AND sm.space.id = :spaceId
        """)
    Set<SpaceMembership> findBySpaceIdUsersIds(@Param("spaceId") Long spaceId, @Param("usersIds") Set<Long> usersIds);

    Optional<SpaceMembership> findByIdAndSpaceId(Long id, Long spaceId);

    boolean existsByUserId(Long userId);

    boolean existsBySpaceIdAndUserId(Long spaceId, Long userId);

    boolean existsBySpaceIdAndUserIdAndIdNot(
        Long spaceId,
        Long userId,
        Long id);

    boolean existsBySpaceIdAndUserIdAndSpaceMembershipStatusEnum(
        Long spaceId,
        Long userId,
        SpaceMembershipStatusEnum status);

    boolean existsBySpaceIdAndUserIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
        Long spaceId,
        Long userId,
        SpaceMembershipStatusEnum status,
        SpaceUserRoleEnum spaceUserRole);

    long countBySpaceIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
        Long spaceId,
        SpaceMembershipStatusEnum status,
        SpaceUserRoleEnum spaceUserRole);

    @Query("""
        SELECT COUNT(spaceMembership)
        FROM SpaceMembership spaceMembership
        WHERE spaceMembership.user.id = :userId
            AND spaceMembership.spaceMembershipStatusEnum = :status
            AND spaceMembership.spaceUserRole = :spaceUserRole
            AND (
                SELECT COUNT(adminMembership)
                FROM SpaceMembership adminMembership
                WHERE adminMembership.space.id = spaceMembership.space.id
                    AND adminMembership.spaceMembershipStatusEnum = :status
                    AND adminMembership.spaceUserRole = :spaceUserRole
            ) = 1
        """)
    long countSpacesWhereUserIsOnlyApprovedAdmin(
        @Param("userId") Long userId,
        @Param("status") SpaceMembershipStatusEnum status,
        @Param("spaceUserRole") SpaceUserRoleEnum spaceUserRole);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT sm FROM SpaceMembership sm
        WHERE sm.space.id = :spaceId
            AND sm.spaceMembershipStatusEnum = :status
            AND sm.spaceUserRole = :spaceUserRole
        """)
    Set<SpaceMembership> findBySpaceIdAndStatusAndSpaceUserRoleForUpdate(
        @Param("spaceId") Long spaceId,
        @Param("status") SpaceMembershipStatusEnum status,
        @Param("spaceUserRole") SpaceUserRoleEnum spaceUserRole);
}
