package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Repository
public class ParticipantRepository {

    private static final Map<String, String> SORT_COLUMNS = Map.of(
        "id", "u.id",
        "name", "u.name",
        "score", "COALESCE(scores.score, 0)"
    );

    private static final String FROM_PARTICIPANTS = """
        FROM space_memberships sm
        JOIN users u ON u.id = sm.user_id
        LEFT JOIN (
            SELECT
                teu.user_id AS user_id,
                SUM(t.score / executor_counts.executor_count) AS score
            FROM task_execution_users teu
            JOIN tasks_executions te ON te.id = teu.task_execution_id
            JOIN tasks t ON t.id = te.task_id
            JOIN (
                SELECT task_execution_id, COUNT(*) AS executor_count
                FROM task_execution_users
                GROUP BY task_execution_id
            ) executor_counts ON executor_counts.task_execution_id = te.id
            WHERE te.space_id = :spaceId
            GROUP BY teu.user_id
        ) scores ON scores.user_id = u.id
        WHERE sm.space_id = :spaceId
        AND sm.space_membership_status_enum = 'APPROVED'
        """;

    private final EntityManager entityManager;

    public ParticipantRepository(EntityManager entityManager) {
        this.entityManager = entityManager;
    }

    public Page<@NonNull ParticipantDTO> findParticipantsWithScores(Long spaceId, Pageable pageable) {
        String sql = """
            SELECT u.id, u.name, COALESCE(scores.score, 0)
            """ + FROM_PARTICIPANTS + buildOrderBy(pageable.getSort());

        Query query = entityManager.createNativeQuery(sql)
            .setParameter("spaceId", spaceId);

        if (pageable.isPaged()) {
            query.setFirstResult(Math.toIntExact(pageable.getOffset()));
            query.setMaxResults(pageable.getPageSize());
        }

        @SuppressWarnings("unchecked")
        List<Object[]> rows = query.getResultList();

        List<@NonNull ParticipantDTO> participants = rows.stream()
            .map(this::toParticipantDTO)
            .toList();

        Long total = ((Number) entityManager.createNativeQuery("SELECT COUNT(*) " + FROM_PARTICIPANTS)
            .setParameter("spaceId", spaceId)
            .getSingleResult()).longValue();

        return new PageImpl<>(participants, pageable, total);
    }

    private String buildOrderBy(Sort sort) {
        if (sort.isUnsorted()) {
            return " ORDER BY u.name ASC, u.id ASC";
        }

        String orderBy = sort.stream()
            .map(this::toOrderBy)
            .reduce((left, right) -> left + ", " + right)
            .orElse("u.name ASC, u.id ASC");

        return " ORDER BY " + orderBy;
    }

    private String toOrderBy(Sort.Order order) {
        String column = SORT_COLUMNS.get(order.getProperty());
        if (column == null) {
            throw new IllegalArgumentException(
                "Ordenação inválida para participantes: " + order.getProperty());
        }

        return column + " " + order.getDirection().name();
    }

    private ParticipantDTO toParticipantDTO(Object[] row) {
        return new ParticipantDTO(
            ((Number) row[0]).longValue(),
            (String) row[1],
            toBigDecimal(row[2]));
    }

    private BigDecimal toBigDecimal(Object value) {
        if (value instanceof BigDecimal bigDecimal) {
            return bigDecimal;
        }

        return BigDecimal.valueOf(((Number) value).doubleValue());
    }
}
