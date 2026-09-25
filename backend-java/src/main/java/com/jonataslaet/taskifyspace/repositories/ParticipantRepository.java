package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Repository
public class ParticipantRepository {

    private static final Map<String, String> SORT_COLUMNS = Map.of(
        "id", "u.id",
        "name", "u.name",
        "spaceUserRole", "sm.space_user_role",
        "score", "COALESCE(scores.score, 0)"
    );

    private static final String FROM_PARTICIPANTS = """
        FROM space_memberships sm
        JOIN users u ON u.id = sm.user_id
        JOIN (
            SELECT
                teu.user_id AS user_id,
                STRING_AGG(DISTINCT tc.name, ',') AS task_categories,
                SUM(t.score / executor_counts.executor_count) AS score
            FROM task_execution_users teu
            JOIN tasks_executions te ON te.id = teu.task_execution_id
            JOIN tasks t ON t.id = te.task_id
            JOIN task_categories tc ON tc.id = t.category_id
            JOIN (
                SELECT task_execution_id, COUNT(*) AS executor_count
                FROM task_execution_users
                GROUP BY task_execution_id
            ) executor_counts ON executor_counts.task_execution_id = te.id
            WHERE te.space_id = :spaceId
            AND tc.name IN (%s)
            GROUP BY teu.user_id
        ) scores ON scores.user_id = u.id
        WHERE sm.space_id = :spaceId
        AND sm.space_membership_status_enum = 'APPROVED'
    """;

    private final EntityManager entityManager;

    public ParticipantRepository(EntityManager entityManager) {
        this.entityManager = entityManager;
    }

    public Page<@NonNull ParticipantDTO> findParticipantsWithScores(
        Long spaceId, Pageable pageable, String name, SpaceUserRoleEnum spaceUserRole,
        List<String> taskCategories) {
        String fromParticipants = buildFromParticipants(taskCategories);
        String filters = buildFilters(name, spaceUserRole);
        String sql = """
            SELECT u.id, u.name, sm.space_user_role, scores.task_categories, COALESCE(scores.score, 0)
            """ + fromParticipants + filters + buildOrderBy(pageable.getSort());

        Query query = bindFilters(entityManager.createNativeQuery(sql), spaceId, name, spaceUserRole);

        if (pageable.isPaged()) {
            query.setFirstResult(Math.toIntExact(pageable.getOffset()));
            query.setMaxResults(pageable.getPageSize());
        }

        @SuppressWarnings("unchecked")
        List<Object[]> rows = query.getResultList();

        BigDecimal totalScore = rows.stream().map(
            row -> toBigDecimal(row[4])).reduce(BigDecimal.ZERO, BigDecimal::add);

        List<@NonNull ParticipantDTO> participants = rows.stream()
            .map(row -> toParticipantDTO(row, taskCategories, totalScore))
            .toList();

        Long total = ((Number) bindFilters(
            entityManager.createNativeQuery("SELECT COUNT(*) " + fromParticipants + filters),
            spaceId,
            name,
            spaceUserRole)
            .getSingleResult()).longValue();

        return new PageImpl<>(participants, pageable, total);
    }

    private String buildFromParticipants(List<String> taskCategories) {
        return FROM_PARTICIPANTS.formatted(buildTaskCategoryFilterValues(taskCategories));
    }

    private String buildTaskCategoryFilterValues(List<String> taskCategories) {
        return taskCategories.stream()
            .map(taskCategory -> "'" + taskCategory + "'")
            .collect(Collectors.joining(", "));
    }

    private String buildFilters(String name, SpaceUserRoleEnum spaceUserRole) {
        StringBuilder filters = new StringBuilder();
        if (hasText(name)) {
            filters.append(" AND LOWER(u.name) LIKE :name");
        }
        if (spaceUserRole != null) {
            filters.append(" AND CAST(sm.space_user_role AS varchar) = :spaceUserRole");
        }
        return filters.toString();
    }

    private Query bindFilters(Query query, Long spaceId, String name, SpaceUserRoleEnum spaceUserRole) {
        query.setParameter("spaceId", spaceId);
        if (hasText(name)) {
            query.setParameter("name", "%" + name.toLowerCase() + "%");
        }
        if (spaceUserRole != null) {
            query.setParameter("spaceUserRole", spaceUserRole.name());
        }
        return query;
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private String buildOrderBy(Sort sort) {
        if (sort.isUnsorted()) {
            return " ORDER BY u.name ASC, u.id ASC";
        }

        String orderBy = sort.stream()
            .map(this::toOrderBy)
            .reduce((left, right) -> left + ", " + right)
            .orElse("u.name ASC, u.id ASC");

        if (sort.stream().noneMatch(order -> "id".equals(order.getProperty()))) {
            orderBy += ", u.id ASC";
        }

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

    private ParticipantDTO toParticipantDTO(Object[] row, List<String> taskCategories, BigDecimal totalScore) {
        BigDecimal participantScore = toBigDecimal(row[4]);
        return new ParticipantDTO(((Number) row[0]).longValue(), (String) row[1],
            SpaceUserRoleEnum.valueOf(row[2].toString()), taskCategories,
            participantScore, totalScore.compareTo(BigDecimal.ZERO) == 0 ?
            BigDecimal.ZERO : participantScore.divide(totalScore, RoundingMode.FLOOR));
    }

    private BigDecimal toBigDecimal(Object value) {
        if (value instanceof BigDecimal bigDecimal) {
            return bigDecimal;
        }

        return BigDecimal.valueOf(((Number) value).doubleValue());
    }
}
