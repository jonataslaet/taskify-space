package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.entities.TaskExecution;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Set;

@Repository
public interface TaskExecutionRepository extends JpaRepository<@NonNull TaskExecution, @NonNull Long>,
    JpaSpecificationExecutor<@NonNull TaskExecution> {

    @Query(value = """
        SELECT
            teu.user_id AS userId,
            COALESCE(SUM(t.score / executor_counts.executor_count), 0) AS score
        FROM task_execution_users teu
        JOIN tasks_executions te ON te.id = teu.task_execution_id
        JOIN tasks t ON t.id = te.task_id
        JOIN (
            SELECT task_execution_id, COUNT(*) AS executor_count
            FROM task_execution_users
            GROUP BY task_execution_id
        ) executor_counts ON executor_counts.task_execution_id = te.id
        WHERE te.space_id = :spaceId
        AND teu.user_id IN (:userIds)
        GROUP BY teu.user_id
        """, nativeQuery = true)
    List<ParticipantScoreProjection> sumParticipantScoresBySpaceIdAndUserIds(
        @Param("spaceId") Long spaceId,
        @Param("userIds") Set<Long> userIds);

    @Query("""
        SELECT COUNT(te)
        FROM TaskExecution te
        JOIN te.executors executor
        WHERE executor.id = :userId
          AND te.createdAt >= :periodStart
          AND te.createdAt < :periodEnd
        """)
    long countExecutionsByExecutorInPeriod(
        @Param("userId") Long userId,
        @Param("periodStart") Instant periodStart,
        @Param("periodEnd") Instant periodEnd);

    TaskExecution findBySpaceIdAndTaskId(Long spaceId, Long taskId);

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

    interface ParticipantScoreProjection {
        Long getUserId();

        BigDecimal getScore();
    }
}
