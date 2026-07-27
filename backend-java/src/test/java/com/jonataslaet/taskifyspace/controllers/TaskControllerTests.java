package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.time.LocalDateTime;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class TaskControllerTests {

    @Mock
    private TaskService taskService;

    private TaskController taskController;

    @BeforeEach
    void setUp() {
        taskController = new TaskController(taskService);
    }

    @Test
    void finishTaskDelegatesExecutionDateToService() {
        User authenticatedUser = new User();
        Set<Long> usersIds = Set.of(2L, 3L);
        LocalDateTime executionDate = LocalDateTime.of(2026, 7, 25, 14, 30);

        var response = taskController.finishTask(20L, 10L, authenticatedUser, usersIds, executionDate);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(taskService).finishTask(20L, 10L, authenticatedUser, usersIds, executionDate);
    }
}
