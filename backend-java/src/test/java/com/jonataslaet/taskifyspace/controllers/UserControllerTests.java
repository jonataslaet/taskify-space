package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.services.UserRegistrationConfirmationService;
import com.jonataslaet.taskifyspace.services.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class UserControllerTests {

    @Mock
    private UserService userService;

    @Mock
    private UserRegistrationConfirmationService userRegistrationConfirmationService;

    private UserController userController;

    @BeforeEach
    void setUp() {
        userController = new UserController(userService, userRegistrationConfirmationService);
    }

    @Test
    void confirmRegistrationDelegatesQueryParamTokenToService() {
        var response = userController.confirmRegistration("raw-token");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(userRegistrationConfirmationService).confirmRegistration("raw-token");
    }
}
