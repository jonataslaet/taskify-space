package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.TaskExecution;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = "DELETE FROM task_execution_users WHERE user_id = :userId", nativeQuery = true)
    int deleteExecutorLinksByUserId(@Param("userId") Long userId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = """
        DELETE FROM tasks_executions task_execution
        WHERE NOT EXISTS (
            SELECT 1
            FROM task_execution_users task_execution_user
            WHERE task_execution_user.task_execution_id = task_execution.id
        )
        """, nativeQuery = true)
    int deleteExecutionsWithoutExecutors();
}
