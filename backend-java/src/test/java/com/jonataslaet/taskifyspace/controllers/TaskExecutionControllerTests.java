package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskExecutionDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskExecutionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskExecutionControllerTests {

    @Mock
    private TaskExecutionService taskExecutionService;

    private TaskExecutionController taskExecutionController;

    @BeforeEach
    void setUp() {
        taskExecutionController = new TaskExecutionController(taskExecutionService);
    }

    @Test
    void readAllExecutionsByTaskReturnsPagedExecutions() {
        User authenticatedUser = new User();
        Pageable pageable = PageRequest.of(0, 10);
        var taskExecutionDTO = new TaskExecutionDTO(
            100L,
            "21/08/2026 14:30",
            new BigDecimal("15.50"),
            List.of("Ana", "Maria"));
        var taskExecutions = new PageImpl<>(List.of(taskExecutionDTO), pageable, 1);

        when(taskExecutionService.findAllByTask(10L, 20L, pageable, authenticatedUser))
            .thenReturn(taskExecutions);

        var response = taskExecutionController.readAllExecutionsByTask(
            10L, 20L, pageable, authenticatedUser);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isSameAs(taskExecutions);
        verify(taskExecutionService).findAllByTask(10L, 20L, pageable, authenticatedUser);
    }
}
