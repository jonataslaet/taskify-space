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
        SELECT p.user FROM SpaceMembership p WHERE p.user.id in (:usersIds) 
        AND p.space.id = :spaceId AND p.spaceUserRole = :spaceUserRole
        """)
    Set<User> findParticipantsByIds(@Param("spaceId") Long spaceId,
        @Param("usersIds") Set<Long> ids, @Param("spaceUserRole") SpaceUserRoleEnum participant);

    @Query(value = """
        SELECT sm FROM SpaceMembership sm WHERE (:usersIds IS NULL or sm.user.id in (:usersIds)) AND sm.space.id = :spaceId
        """)
    Set<SpaceMembership> findBySpaceIdUsersIds(@Param("spaceId") Long spaceId, @Param("usersIds") Set<Long> usersIds);

    Optional<SpaceMembership> findByIdAndSpaceId(Long id, Long spaceId);

    Set<SpaceMembership> findBySpaceIdAndUserId(Long spaceId, Long userId);

    boolean existsBySpaceIdAndUserIdAndSpaceUserRole(Long spaceId, Long userId, SpaceUserRoleEnum spaceUserRoleEnum);

    boolean existsBySpaceIdAndUserIdAndSpaceUserRoleIn(Long spaceId, Long userId, Set<SpaceUserRoleEnum> roles);

    boolean existsBySpaceIdAndUserIdAndSpaceUserRoleInAndIdNot(
        Long spaceId,
        Long userId,
        Set<SpaceUserRoleEnum> roles,
        Long id);

    boolean existsBySpaceIdAndUserIdAndSpaceUserRoleInAndSpaceMembershipStatusEnum(
        Long spaceId,
        Long userId,
        Set<SpaceUserRoleEnum> roles,
        SpaceMembershipStatusEnum status);
}
