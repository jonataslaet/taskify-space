package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SendingEmailDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UserRegistrationConfirmationEmail;
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
class UserRegistrationConfirmationRequestServiceTests {

    @Mock
    private UserRegistrationConfirmationTokenService tokenService;

    @Mock
    private EmailService emailService;

    private UserRegistrationConfirmationRequestService requestService;

    @BeforeEach
    void setUp() {
        requestService = new UserRegistrationConfirmationRequestService(tokenService, emailService);
        ReflectionTestUtils.setField(
            requestService,
            "registrationConfirmationUri",
            "http://localhost:8080/users/confirm-registration/");
    }

    @Test
    void requestConfirmationTokenDoesNotSendEmailWhenTokenIsNotCreated() {
        when(tokenService.createConfirmationToken(1L)).thenReturn(Optional.empty());

        requestService.requestConfirmationToken(1L);

        verify(emailService, never()).sendEmail(any());
    }

    @Test
    void requestConfirmationTokenSendsEmailAfterTokenIsCreated() {
        when(tokenService.createConfirmationToken(1L))
            .thenReturn(Optional.of(new UserRegistrationConfirmationEmail("user@example.com", "raw-token")));

        requestService.requestConfirmationToken(1L);

        ArgumentCaptor<SendingEmailDTO> emailCaptor = ArgumentCaptor.forClass(SendingEmailDTO.class);
        verify(emailService).sendEmail(emailCaptor.capture());
        SendingEmailDTO sendingEmailDTO = emailCaptor.getValue();

        assertThat(sendingEmailDTO.to()).isEqualTo("user@example.com");
        assertThat(sendingEmailDTO.subject()).isEqualTo("Confirmacao de cadastro");
        assertThat(sendingEmailDTO.body())
            .contains("http://localhost:8080/users/confirm-registration/raw-token")
            .contains("5 minutos");
    }
}
