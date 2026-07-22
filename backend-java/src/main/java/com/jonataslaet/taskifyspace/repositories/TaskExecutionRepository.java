package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.TaskExecution;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.Set;

@Repository
public interface TaskExecutionRepository extends JpaRepository<@NonNull TaskExecution, @NonNull Long>,
    JpaSpecificationExecutor<@NonNull TaskExecution> {

    default void removeExecutorsFromTaskExecution(TaskExecution taskExecution, Set<Long> userIds) {
        if (taskExecution == null || taskExecution.getExecutors() == null || userIds == null || userIds.isEmpty()) {
            return;
        }

        taskExecution.getExecutors().removeIf(executor -> userIds.contains(executor.getId()));

        if (taskExecution.getExecutors().isEmpty()) {
            delete(taskExecution);
            return;
        }

        save(taskExecution);
    }

    void deleteBySpaceId(Long spaceId);

    void deleteByTaskId(Long taskId);
}
