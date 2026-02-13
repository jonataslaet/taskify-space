package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.Space;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

@Repository
public interface SpaceMembershipRepository extends JpaRepository<
    @NonNull SpaceMembership, @NonNull Long>, JpaSpecificationExecutor<@NonNull SpaceMembership> {
}
