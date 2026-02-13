package com.jonataslaet.taskifyspace.specifications;

import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.Task;
import net.kaczmarzyk.spring.data.jpa.domain.*;
import net.kaczmarzyk.spring.data.jpa.web.annotation.And;
import net.kaczmarzyk.spring.data.jpa.web.annotation.Spec;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.domain.Specification;

public class SpecificationTemplate {

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
        @Spec(path = "active", params = "active", spec = Equal.class)
    })
    public interface SpaceSpecification extends Specification<@NonNull Space> {}

}
