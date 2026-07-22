package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.AuthenticationResponseRecordDTO;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.services.AuthenticationService;
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
class AuthenticationControllerTests {

    @Mock
    private AuthenticationService authenticationService;

    private AuthenticationController authenticationController;

    @BeforeEach
    void setUp() {
        authenticationController = new AuthenticationController(authenticationService);
    }

    @Test
    void refreshDelegatesNullBodyToServiceWithoutDereferencingRequest() {
        AuthenticationResponseRecordDTO dto = new AuthenticationResponseRecordDTO(
            1L,
            "user@example.com",
            "User",
            "access-token",
            "refresh-token",
            UserRoleEnum.ROLE_USER);
        when(authenticationService.refresh(null, "device", "agent", "127.0.0.1")).thenReturn(dto);

        var response = authenticationController.refresh(null, "device", "agent", "127.0.0.1");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(dto);
        verify(authenticationService).refresh(null, "device", "agent", "127.0.0.1");
    }

    @Test
    void logoutDelegatesNullBodyToServiceWithoutDereferencingRequest() {
        var response = authenticationController.logout(null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(authenticationService).logout(null);
    }
}
