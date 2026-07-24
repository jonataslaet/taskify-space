package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SendingEmailDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PasswordRecoveryRequestServiceTests {

    @Mock
    private PasswordRecoveryTokenService passwordRecoveryTokenService;

    @Mock
    private EmailService emailService;

    private PasswordRecoveryRequestService passwordRecoveryRequestService;

    @BeforeEach
    void setUp() {
        passwordRecoveryRequestService = new PasswordRecoveryRequestService(
            passwordRecoveryTokenService,
            emailService);
        ReflectionTestUtils.setField(
            passwordRecoveryRequestService,
            "passwordRecoveryUri",
            "http://localhost/new-password/");
    }

    @Test
    void requestRecoveryTokenDoesNotSendEmailWhenAddressDoesNotExist() {
        String email = "missing@example.com";
        when(passwordRecoveryTokenService.createRecoveryToken(email)).thenReturn(Optional.empty());

        passwordRecoveryRequestService.requestRecoveryToken(email);

        verify(emailService, never()).sendEmail(any());
    }

    @Test
    void requestRecoveryTokenSendsEmailAfterTokenIsCreated() {
        String email = "user@example.com";
        String token = "raw-token";
        when(passwordRecoveryTokenService.createRecoveryToken(email))
            .thenReturn(Optional.of(new PasswordRecoveryEmail(email, token)));

        passwordRecoveryRequestService.requestRecoveryToken(email);

        ArgumentCaptor<SendingEmailDTO> emailCaptor = ArgumentCaptor.forClass(SendingEmailDTO.class);
        verify(emailService).sendEmail(emailCaptor.capture());
        SendingEmailDTO sendingEmailDTO = emailCaptor.getValue();

        assertThat(sendingEmailDTO.to()).isEqualTo(email);
        assertThat(sendingEmailDTO.subject()).isEqualTo("Resetamento de senha");
        assertThat(sendingEmailDTO.body()).contains("http://localhost/new-password/" + token);
    }
}
