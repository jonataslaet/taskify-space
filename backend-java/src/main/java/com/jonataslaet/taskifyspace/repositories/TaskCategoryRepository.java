package com.jonataslaet.taskifyspace.repositories;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskCategoryRecordDTO;
import com.jonataslaet.taskifyspace.entities.TaskCategory;
import org.jspecify.annotations.NonNull;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface TaskCategoryRepository extends JpaRepository<@NonNull TaskCategory, @NonNull Long> {

    boolean existsBySpaceIdAndNameIgnoreCase(Long spaceId, String name);

    boolean existsBySpaceIdAndNameIgnoreCaseAndIdNot(Long spaceId, String name, Long id);

    Optional<TaskCategory> findByIdAndSpaceId(Long id, Long spaceId);

    long countByCreatorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
        Long creatorId, Instant periodStart, Instant periodEnd);

    void deleteBySpaceId(Long spaceId);

    @Query("""
        SELECT new com.jonataslaet.taskifyspace.controllers.dtos.TaskCategoryRecordDTO(
            taskCategory.id,
            taskCategory.name
        )
        FROM TaskCategory taskCategory
        WHERE taskCategory.space.id = :spaceId
            AND LOWER(taskCategory.name) LIKE LOWER(CONCAT('%', :name, '%'))
        ORDER BY taskCategory.name ASC, taskCategory.id ASC
        """)
    List<TaskCategoryRecordDTO> searchTaskCategoriesByName(
        @Param("spaceId") Long spaceId, @Param("name") String name);

    @Query("""
        SELECT taskCategory FROM TaskCategory taskCategory
        WHERE taskCategory.space.id = :spaceId
            AND LOWER(taskCategory.name) LIKE LOWER(CONCAT('%', :name, '%'))
        """)
    Optional<TaskCategory> findTaskCategoryByName(@Param("spaceId") Long spaceId, @Param("name") String name);
}
