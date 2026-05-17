package com.jonataslaet.taskifyspace.controllers;

import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.controllers.dtos.StandardErrorRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.TaskRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskService;
import com.jonataslaet.taskifyspace.specifications.SpecificationTemplate;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Set;

@RestController
@RequestMapping("/tasks")
public class TaskController {

    private final TaskService taskService;

    public TaskController(TaskService taskService) {
        this.taskService = taskService;
    }

    @Operation(
        summary = "List tasks",
        description = "Returns a paginated list of tasks with optional filters"
    )
    @Parameters({
        @Parameter(name = "description", description = "Filter by description (case insensitive)"),
        @Parameter(name = "score", description = "Filter by score"),
        @Parameter(name = "active", description = "Filter by active (true or false)"),
        @Parameter(name = "category", description = "Filter by category (OPERATIONAL or FINANCIAL)"),
        @Parameter(name = "minScore", description = "Minimum score"),
        @Parameter(name = "maxScore", description = "Maximum score"),
        @Parameter(name = "minScore", description = "Minimum score"),
        @Parameter(name = "maxScore", description = "Maximum score"),

        @Parameter(name = "page", description = "Page number (0-based)", example = "0"),
        @Parameter(name = "size", description = "Page size", example = "10"),
        @Parameter(name = "sort", description = "Sort criteria (e.g. description,asc)")
    })
    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull TaskRecordDTO>> readAllTasks(
        @Parameter(hidden = true) SpecificationTemplate.TaskSpecification taskSpecification,
        @Parameter(hidden = true) Pageable pageable) {
        Page<@NonNull TaskRecordDTO> taskModelPage = taskService.findAll(taskSpecification, pageable);
        return ResponseEntity.status(HttpStatus.OK).body(taskModelPage);
    }

    @Operation(
        summary = "Create a Task",
        description = "Creates a new Task in the system"
    )
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Task created successfully"),
        @ApiResponse(
            responseCode = "409",
            description = "Essa tarefa já existe",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = StandardErrorRecordDTO.class),
                examples = @ExampleObject(
                    name = "DuplicateDescription",
                    summary = "Task description already exists",
                    value = """
                        {
                          "timestamp": "2026-02-11T17:20:33.880278900Z",
                          "status": 409,
                          "error": "Conflict",
                          "message": "Task description already exists",
                          "path": "/tasks"
                        }
                    """
                )
            )
        ),
        @ApiResponse(responseCode = "422", description = "Invalid request payload"),
        @ApiResponse(responseCode = "400", description = "Bad request")
    })
    @JsonView(TaskRecordDTO.TaskView.ReadTask.class)
    @PostMapping
    public ResponseEntity<@NonNull TaskRecordDTO> createTask(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @JsonView(TaskRecordDTO.TaskView.CreateTask.class) TaskRecordDTO taskRecordDTO){
        return ResponseEntity.status(HttpStatus.CREATED).body(taskService.createTask(authenticatedUser, taskRecordDTO));
    }

    @PostMapping("/{taskId}/spaces/{spaceId}")
    public ResponseEntity<@NonNull Void> finishTask(@PathVariable Long taskId,
        @PathVariable Long spaceId, @AuthenticationPrincipal User authenticatedUser,
        @RequestParam(value = "usersIds", required = false) Set<Long> usersIds){
        taskService.finishTask(taskId, spaceId, authenticatedUser, usersIds);
        return ResponseEntity.noContent().build();
    }

    @Operation(
        summary = "Get Task by ID",
        description = "Returns a Task by its identifier"
    )
    @JsonView(TaskRecordDTO.TaskView.ReadTask.class)
    @GetMapping("/{taskId}")
    public ResponseEntity<@NonNull TaskRecordDTO> getTaskById(@PathVariable("taskId") Long taskId) {
        TaskRecordDTO foundTask = taskService.getTaskById(taskId);
        return ResponseEntity.ok(foundTask);
    }

    @PutMapping("/{taskId}")
    public ResponseEntity<@NonNull TaskRecordDTO> updateTask(
        @PathVariable("taskId") Long taskId, @RequestBody
        @JsonView(TaskRecordDTO.TaskView.UpdateTask.class) TaskRecordDTO taskRecordDTO) {

        TaskRecordDTO updatedTask = taskService.updateTask(taskId, taskRecordDTO);
        return ResponseEntity.ok(updatedTask);
    }

    @DeleteMapping("/{taskId}")
    public ResponseEntity<@NonNull Void> deleteTask(
        @PathVariable("taskId") Long taskId) {

        taskService.deleteTask(taskId);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{taskId}")
    public ResponseEntity<@NonNull Void> toggleActiveTask(
        @PathVariable("taskId") Long taskId) {

        taskService.toggleActiveTask(taskId);
        return ResponseEntity.noContent().build();
    }
}
