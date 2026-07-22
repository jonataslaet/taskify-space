package com.jonataslaet.taskifyspace.specifications;

import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.domain.Specification;

public class SpaceMembershipSpecification {

    public static Specification<@NonNull SpaceMembership> spaceId(Long spaceId) {
        return (root, query, cb) ->
            cb.equal(root.get("space").get("id"), spaceId);
    }
}
