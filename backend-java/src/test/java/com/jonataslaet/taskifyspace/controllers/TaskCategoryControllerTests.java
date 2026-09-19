package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.TaskCategoryRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.TaskCategoryService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskCategoryControllerTests {

    @Mock
    private TaskCategoryService taskCategoryService;

    private TaskCategoryController taskCategoryController;

    @BeforeEach
    void setUp() {
        taskCategoryController = new TaskCategoryController(taskCategoryService);
    }

    @Test
    void updateTaskCategoryDelegatesSpaceIdToService() {
        User authenticatedUser = new User();
        TaskCategoryRecordDTO request = new TaskCategoryRecordDTO(null, "Financeiro");
        TaskCategoryRecordDTO responseBody = new TaskCategoryRecordDTO(20L, "Financeiro");

        when(taskCategoryService.updateTaskCategory(10L, authenticatedUser, 20L, request))
            .thenReturn(responseBody);

        var response = taskCategoryController.updateTaskCategory(10L, 20L, authenticatedUser, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(responseBody);
        verify(taskCategoryService).updateTaskCategory(10L, authenticatedUser, 20L, request);
    }

    @Test
    void deleteTaskCategoryDelegatesSpaceIdToService() {
        User authenticatedUser = new User();

        var response = taskCategoryController.deleteTaskCategory(10L, 20L, authenticatedUser);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(taskCategoryService).deleteTaskCategory(10L, authenticatedUser, 20L);
    }
}
