package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.PasswordRecoveryEmail;
import com.jonataslaet.taskifyspace.controllers.dtos.SendingEmailDTO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
public class PasswordRecoveryRequestService {

    private static final Logger LOGGER = LoggerFactory.getLogger(PasswordRecoveryRequestService.class);

    @Value("${security.email.password-recover.uri}")
    private String passwordRecoveryUri;

    @Value("${security.email.password-recover.token.minutes:10}")
    private Long tokenMinutes;

    private final PasswordRecoveryTokenService passwordRecoveryTokenService;
    private final EmailService emailService;

    public PasswordRecoveryRequestService(
        PasswordRecoveryTokenService passwordRecoveryTokenService,
        EmailService emailService) {
        this.passwordRecoveryTokenService = passwordRecoveryTokenService;
        this.emailService = emailService;
    }

    @Async("passwordRecoveryTaskExecutor")
    public void requestRecoveryToken(String email) {
        try {
            passwordRecoveryTokenService.createRecoveryToken(email).ifPresent(this::sendRecoveryEmail);
        } catch (Exception exception) {
            LOGGER.warn("Unable to process password recovery request", exception);
        }
    }

    private void sendRecoveryEmail(PasswordRecoveryEmail recoveryEmail) {
        String emailBody = "Use o seguinte codigo para resetar sua senha: " + recoveryEmail.code() + "\n"
            + "Acesse o link: " + passwordRecoveryUri + recoveryEmail.requestToken() + "\n"
            + "Esse codigo expirara daqui a " + tokenMinutes + " minutos. "
            + "Portanto, se esse email nao foi solicitado por voce, apenas o ignore.";

        emailService.sendEmail(new SendingEmailDTO( recoveryEmail.address(),
            null, "Resetamento de senha", emailBody));
    }
}
