package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.TaskExecution;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

@Repository
public interface TaskExecutionRepository extends JpaRepository<@NonNull TaskExecution, @NonNull Long>,
    JpaSpecificationExecutor<@NonNull TaskExecution> {
}
