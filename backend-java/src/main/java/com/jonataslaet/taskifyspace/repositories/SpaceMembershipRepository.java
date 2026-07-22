package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
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

    Set<SpaceMembership> findBySpaceIdAndUserId(Long spaceId, Long userId);

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

    long countBySpaceIdAndSpaceMembershipStatusEnumAndSpaceUserRole(
        Long spaceId,
        SpaceMembershipStatusEnum status,
        SpaceUserRoleEnum spaceUserRole);
}
