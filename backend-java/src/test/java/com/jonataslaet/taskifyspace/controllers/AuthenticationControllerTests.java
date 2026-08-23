package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.AuthenticationResponseRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.CredentialsRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.EmailDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PasswordRecoveryCodeDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PasswordResetSessionDTO;
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
    void loginDelegatesFirstForwardedIpToService() {
        CredentialsRecordDTO credentials = new CredentialsRecordDTO("user@example.com", "Strong1!");
        AuthenticationResponseRecordDTO dto = new AuthenticationResponseRecordDTO(
            1L,
            "user@example.com",
            "User",
            "access-token",
            "refresh-token",
            UserRoleEnum.ROLE_USER);
        when(authenticationService.login(credentials, "device", "agent", "203.0.113.10")).thenReturn(dto);

        var response = authenticationController.login(
            credentials,
            "device",
            "agent",
            "203.0.113.10, 10.0.0.1");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(authenticationService).login(credentials, "device", "agent", "203.0.113.10");
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
    void recoveryTokenDelegatesFirstForwardedIpAndDeviceToService() {
        EmailDTO emailDTO = new EmailDTO("user@example.com");

        var response = authenticationController.recoveryToken(
            emailDTO,
            "device",
            "203.0.113.10, 10.0.0.1");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(authenticationService).recoveryToken(emailDTO, "203.0.113.10", "device");
    }

    @Test
    void recoverySessionDelegatesRequestTokenAndCodeToService() {
        PasswordRecoveryCodeDTO codeDTO = new PasswordRecoveryCodeDTO("123456");
        PasswordResetSessionDTO sessionDTO = new PasswordResetSessionDTO("reset-session");
        when(authenticationService.createPasswordResetSession("request-token", codeDTO)).thenReturn(sessionDTO);

        var response = authenticationController.recoverySession("request-token", codeDTO);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(sessionDTO);
        verify(authenticationService).createPasswordResetSession("request-token", codeDTO);
    }

    @Test
    void logoutDelegatesNullBodyToServiceWithoutDereferencingRequest() {
        var response = authenticationController.logout(null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(authenticationService).logout(null);
    }
}
