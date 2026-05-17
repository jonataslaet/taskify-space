package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskExecutionService;
import org.jspecify.annotations.NonNull;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/spaces/{spaceId}/executions")
public class TaskExecutionController {

    private final TaskExecutionService taskExecutionService;

    public TaskExecutionController(TaskExecutionService taskExecutionService) {
        this.taskExecutionService = taskExecutionService;
    }

    @DeleteMapping("/{taskExecutionId}")
    public ResponseEntity<@NonNull Void> removeCurrentUserFromTaskExecution(@PathVariable Long taskExecutionId,
        @AuthenticationPrincipal User authenticatedUser){
        taskExecutionService.removeCurrentUserFromTaskExecution(taskExecutionId, authenticatedUser);
        return ResponseEntity.noContent().build();
    }
}
