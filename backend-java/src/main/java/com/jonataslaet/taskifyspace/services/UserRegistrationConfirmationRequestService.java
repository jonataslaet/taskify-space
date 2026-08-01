package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.SendingEmailDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UserRegistrationConfirmationEmail;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class UserRegistrationConfirmationRequestService {

    private static final Logger LOGGER = LoggerFactory.getLogger(UserRegistrationConfirmationRequestService.class);

    @Value("${security.email.registration-confirmation.uri}")
    private String registrationConfirmationUri;

    @Value("${security.email.registration-confirmation.token.minutes:5}")
    private Long tokenMinutes = 5L;

    private final UserRegistrationConfirmationTokenService tokenService;
    private final EmailService emailService;

    public UserRegistrationConfirmationRequestService(
        UserRegistrationConfirmationTokenService tokenService,
        EmailService emailService) {
        this.tokenService = tokenService;
        this.emailService = emailService;
    }

    public void requestConfirmationToken(Long userId) {
        try {
            tokenService.createConfirmationToken(userId).ifPresent(this::sendConfirmationEmail);
        } catch (Exception exception) {
            LOGGER.warn("Unable to process user registration confirmation request", exception);
        }
    }

    private void sendConfirmationEmail(UserRegistrationConfirmationEmail confirmationEmail) {
        String emailBody = "Clique no seguinte link para confirmar seu cadastro: \n"
            + registrationConfirmationUri + confirmationEmail.token()
            + "\n\n Esse link expirara daqui a " + tokenMinutes + " minutos. "
            + "Se esse cadastro nao foi feito por voce, apenas ignore este email.";

        emailService.sendEmail(new SendingEmailDTO(
            confirmationEmail.address(),
            null,
            "Confirmacao de cadastro",
            emailBody));
    }
}
