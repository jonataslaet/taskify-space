package com.jonataslaet.taskifyspace.controllers;

import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskService;
import com.jonataslaet.taskifyspace.specifications.SpecificationTemplate;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.Set;

@RestController
@RequestMapping("/tasks")
public class TaskController {

    private final TaskService taskService;

    public TaskController(TaskService taskService) {
        this.taskService = taskService;
    }

    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull TaskRecordDTO>> readAllTasks(
        SpecificationTemplate.TaskSpecification taskSpecification,
        Pageable pageable,
        @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull TaskRecordDTO> taskModelPage = taskService.findAll(
            taskSpecification, pageable, authenticatedUser);
        return ResponseEntity.status(HttpStatus.OK).body(taskModelPage);
    }

    @JsonView(TaskRecordDTO.TaskView.ReadTask.class)
    @PostMapping
    public ResponseEntity<@NonNull TaskRecordDTO> createTask(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Validated(TaskRecordDTO.TaskView.CreateTask.class)
        @JsonView(TaskRecordDTO.TaskView.CreateTask.class) TaskRecordDTO taskRecordDTO){
        return ResponseEntity.status(HttpStatus.CREATED).body(taskService.createTask(authenticatedUser, taskRecordDTO));
    }

    @PostMapping("/{taskId}/spaces/{spaceId}")
    public ResponseEntity<@NonNull Void> finishTask(@PathVariable Long taskId,
        @PathVariable Long spaceId, @AuthenticationPrincipal User authenticatedUser,
        @RequestParam(value = "usersIds", required = false) Set<Long> usersIds,
        @RequestParam(value = "executionDate", required = false)
        @DateTimeFormat(pattern = "yyyy-MM-dd-HH-mm") LocalDateTime executionDate){
        taskService.finishTask(taskId, spaceId, authenticatedUser, usersIds, executionDate);
        return ResponseEntity.noContent().build();
    }

    @JsonView(TaskRecordDTO.TaskView.ReadTask.class)
    @GetMapping("/{taskId}")
    public ResponseEntity<@NonNull TaskRecordDTO> getTaskById(
        @PathVariable("taskId") Long taskId,
        @AuthenticationPrincipal User authenticatedUser) {
        TaskRecordDTO foundTask = taskService.getTaskById(authenticatedUser, taskId);
        return ResponseEntity.ok(foundTask);
    }

    @PutMapping("/{taskId}")
    public ResponseEntity<@NonNull TaskRecordDTO> updateTask(
        @PathVariable("taskId") Long taskId,
        @AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Validated(TaskRecordDTO.TaskView.UpdateTask.class)
        @JsonView(TaskRecordDTO.TaskView.UpdateTask.class) TaskRecordDTO taskRecordDTO) {

        TaskRecordDTO updatedTask = taskService.updateTask(authenticatedUser, taskId, taskRecordDTO);
        return ResponseEntity.ok(updatedTask);
    }

    @DeleteMapping("/{taskId}")
    public ResponseEntity<@NonNull Void> deleteTask(
        @PathVariable("taskId") Long taskId,
        @AuthenticationPrincipal User authenticatedUser) {

        taskService.deleteTask(authenticatedUser, taskId);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{taskId}")
    public ResponseEntity<@NonNull Void> toggleActiveTask(
        @PathVariable("taskId") Long taskId,
        @AuthenticationPrincipal User authenticatedUser) {

        taskService.toggleActiveTask(authenticatedUser, taskId);
        return ResponseEntity.noContent().build();
    }
}
