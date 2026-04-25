package com.jonataslaet.taskifyspace.specifications;

import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import jakarta.persistence.criteria.Predicate;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.domain.Specification;

public class SpaceMembershipSpecification {

    public static Specification<@NonNull SpaceMembership> spaceId(Long spaceId) {
        return (root, query, cb) ->
            cb.equal(root.get("space").get("id"), spaceId);
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
