package com.jonataslaet.taskifyspace.specifications;

import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.Task;
import com.jonataslaet.taskifyspace.entities.User;
import net.kaczmarzyk.spring.data.jpa.domain.*;
import net.kaczmarzyk.spring.data.jpa.web.annotation.And;
import net.kaczmarzyk.spring.data.jpa.web.annotation.Conjunction;
import net.kaczmarzyk.spring.data.jpa.web.annotation.Or;
import net.kaczmarzyk.spring.data.jpa.web.annotation.Spec;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.domain.Specification;

public class SpecificationTemplate {

    @And({
        @Spec(path = "name", params = "name", spec = LikeIgnoreCase.class),
        @Spec(path = "email", spec = LikeIgnoreCase.class),
        @Spec(path = "status", params = "statuses", paramSeparator = ',', spec = In.class),
        @Spec(path = "role", params = "authorities", paramSeparator = ',', spec = In.class)

    })
    public interface UserSpecification extends Specification<@NonNull User> {}

    @And({
        @Spec(path = "description", spec = LikeIgnoreCase.class),
        @Spec(path = "score", params = "score", spec = Equal.class),
        @Spec(path = "active", params = "active", spec = Equal.class),
        @Spec(path = "category", params = "categories", paramSeparator = ',', spec = In.class),
        @Spec(path = "score", params = "minScore", spec = GreaterThanOrEqual.class),
        @Spec(path = "score", params = "maxScore", spec = LessThanOrEqual.class),
        @Spec(path = "score", params = "minScore", spec = GreaterThanOrEqual.class),
        @Spec(path = "score", params = "maxScore", spec = LessThanOrEqual.class)
    })
    public interface TaskSpecification extends Specification<@NonNull Task> {}

    @And({
        @Spec(path = "name", spec = LikeIgnoreCase.class),
        @Spec(path = "active", params = "active", spec = Equal.class),
        @Spec(path = "spaceMemberships.spaceUserRole", params = "spaceUserRole", spec = Equal.class),
        @Spec(path = "spaceMemberships.spaceMembershipStatusEnum", params = "spaceMembershipStatus", spec = Equal.class)
    })
    public interface SpaceSpecification extends Specification<@NonNull Space> {}

    @And({
        @Spec(path = "space.name", params = "name", spec = LikeIgnoreCase.class),
        @Spec(path = "user.name", params = "username", spec = LikeIgnoreCase.class),
        @Spec(path = "spaceMembershipStatusEnum", params = "statuses", paramSeparator = ',', spec = In.class),
    })
    public interface SpaceMembershipSpecification extends Specification<@NonNull SpaceMembership> {}

}
