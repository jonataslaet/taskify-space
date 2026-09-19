package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskCategoryRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskCategoryService;
import jakarta.validation.Valid;
import org.jspecify.annotations.NonNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/spaces/{spaceId}/taskcategories")
public class TaskCategoryController {

    private final TaskCategoryService taskCategoryService;

    public TaskCategoryController(TaskCategoryService taskCategoryService) {
        this.taskCategoryService = taskCategoryService;
    }

    @GetMapping("/search")
    public ResponseEntity<List<TaskCategoryRecordDTO>> searchTaskCategoriesByName(
        @PathVariable("spaceId") Long spaceId,
        @RequestParam("name") String name,
        @AuthenticationPrincipal User authenticatedUser) {

        List<TaskCategoryRecordDTO> taskCategories =
            taskCategoryService.searchTaskCategoriesByName(spaceId, authenticatedUser, name);

        return ResponseEntity.ok(taskCategories);
    }

    @PostMapping
    public ResponseEntity<@NonNull TaskCategoryRecordDTO> createTaskCategory(
        @PathVariable("spaceId") Long spaceId,
        @AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Valid TaskCategoryRecordDTO taskCategoryRecordDTO) {

        return ResponseEntity.status(HttpStatus.CREATED).body(
            taskCategoryService.createTaskCategory(spaceId, authenticatedUser, taskCategoryRecordDTO));
    }

    @PutMapping("/{taskCategoryId}")
    public ResponseEntity<@NonNull TaskCategoryRecordDTO> updateTaskCategory(
        @PathVariable("spaceId") Long spaceId,
        @PathVariable("taskCategoryId") Long taskCategoryId,
        @AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Valid TaskCategoryRecordDTO taskCategoryRecordDTO) {

        TaskCategoryRecordDTO updatedTaskCategory = taskCategoryService
            .updateTaskCategory(spaceId, authenticatedUser, taskCategoryId, taskCategoryRecordDTO);
        return ResponseEntity.ok(updatedTaskCategory);
    }

    @DeleteMapping("/{taskCategoryId}")
    public ResponseEntity<@NonNull Void> deleteTaskCategory(
        @PathVariable("spaceId") Long spaceId,
        @PathVariable("taskCategoryId") Long taskCategoryId,
        @AuthenticationPrincipal User authenticatedUser) {

        taskCategoryService.deleteTaskCategory(spaceId, authenticatedUser, taskCategoryId);
        return ResponseEntity.noContent().build();
    }
}
