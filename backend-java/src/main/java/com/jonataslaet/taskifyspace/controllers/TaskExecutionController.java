package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskExecutionDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskExecutionService;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/spaces/{spaceId}/tasks/{taskId}/executions")
public class TaskExecutionController {

    private final TaskExecutionService taskExecutionService;

    public TaskExecutionController(TaskExecutionService taskExecutionService) {
        this.taskExecutionService = taskExecutionService;
    }

    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull TaskExecutionDTO>> readAllExecutionsByTask(
        @PathVariable Long spaceId, @PathVariable Long taskId, Pageable pageable,
        @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull TaskExecutionDTO> taskExecutions =
            taskExecutionService.findAllByTask(spaceId, taskId, pageable, authenticatedUser);
        return ResponseEntity.status(HttpStatus.OK).body(taskExecutions);
    }

    @DeleteMapping("/{taskExecutionId}")
    public ResponseEntity<@NonNull Void> removeCurrentUserFromTaskExecution(@PathVariable Long spaceId,
        @PathVariable Long taskExecutionId, @AuthenticationPrincipal User authenticatedUser){
        taskExecutionService.removeCurrentUserFromTaskExecution(spaceId, taskExecutionId, authenticatedUser);
        return ResponseEntity.noContent().build();
    }
}
