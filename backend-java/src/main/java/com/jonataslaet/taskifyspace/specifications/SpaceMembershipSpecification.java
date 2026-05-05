package com.jonataslaet.taskifyspace.specifications;

import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import jakarta.persistence.criteria.Predicate;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.domain.Specification;

public class SpaceMembershipSpecification {

    public static Specification<@NonNull SpaceMembership> spaceId(Long spaceId) {
        return (root, query, cb) ->
            cb.equal(root.get("space").get("id"), spaceId);
    }

    public static Specification<@NonNull SpaceMembership> role(SpaceUserRoleEnum role) {
        return (root, query, cb) ->
            cb.equal(root.get("spaceUserRole"), role);
    }

    public static Specification<@NonNull SpaceMembership> status(SpaceMembershipStatusEnum status) {
        return (root, query, cb) ->
            cb.equal(root.get("spaceMembershipStatusEnum"), status);
    }

    public static Specification<@NonNull SpaceMembership> filter(
        Long spaceId,
        String username
    ) {
        return (root, query, cb) -> {

            Predicate predicate = cb.equal(root.get("space").get("id"), spaceId);

            if (username != null && !username.isBlank()) {
                Predicate usernamePredicate =
                    cb.like(
                        cb.lower(root.get("user").get("name")),
                        "%" + username.toLowerCase() + "%"
                    );

                predicate = cb.and(predicate, usernamePredicate);
            }

            return predicate;
        };
    }
}
