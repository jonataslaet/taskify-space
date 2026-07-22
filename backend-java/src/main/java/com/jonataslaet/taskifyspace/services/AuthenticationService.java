package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import com.jonataslaet.taskifyspace.controllers.dtos.*;
import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;

@Service
public class AuthenticationService {

    @Value("${security.email.password-recover.token.minutes}")
    private Long tokenMinutes;

    @Value("${security.email.password-recover.uri}")
    private String passwordRecoveryUri;

    private final RefreshTokenService refreshTokenService;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenConfiguration tokenConfiguration;
    private final PasswordRecoveryService passwordRecoveryService;
    private final EmailService emailService;
    private final Validator validator;

    public AuthenticationService(RefreshTokenService refreshTokenService, UserRepository userRepository,
        PasswordEncoder passwordEncoder, TokenConfiguration tokenConfiguration,
        PasswordRecoveryService passwordRecoveryService, EmailService emailService, Validator validator) {
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenConfiguration = tokenConfiguration;
        this.passwordRecoveryService = passwordRecoveryService;
        this.emailService = emailService;
        this.validator = validator;
    }

    @Transactional
    public AuthenticationResponseRecordDTO login(
        CredentialsRecordDTO credentialsRecordDTO, String deviceId, String userAgent, String ipAddress) {

        User user = userRepository.findByEmail(credentialsRecordDTO.username()).orElse(null);
        if (Objects.nonNull(user) && isMatchedPassword(credentialsRecordDTO, user.getPassword()) && user.isEnabled()) {
            String accessToken = tokenConfiguration.createAccessToken(user);
            String refreshToken = refreshTokenService.issue(user, deviceId, userAgent, ipAddress);

            return new AuthenticationResponseRecordDTO(user.getId(), user.getEmail(), user.getName(),
                accessToken, refreshToken, user.getRole());
        }
        throw new InvalidAuthenticationException(
            "Email ou senha estão inválidos ou este usuário está pendente de avaliação");
    }

    @Transactional
    public AuthenticationResponseRecordDTO refresh(
        String refreshToken, String deviceId, String userAgent, String ipAddress) {

        var current = refreshTokenService.validate(refreshToken);
        User user = userRepository.findByEmail(current.getUser().getUsername())
            .orElseThrow(() -> new InvalidAuthenticationException("Usuário não encontrado"));

        validateEnabledUser(user);

        String newToken = tokenConfiguration.createAccessToken(user);
        String newRefreshToken = refreshTokenService.rotate(refreshToken, deviceId, userAgent, ipAddress);

        return new AuthenticationResponseRecordDTO(
            user.getId(),
            user.getEmail(),
            user.getName(),
            newToken,
            newRefreshToken,
            user.getRole()
        );
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokenService.revoke(rawRefreshToken);
    }

    @Transactional
    private void saveUserAndPasswordRecovery(PasswordRecovery passwordRecovery, User user) {
        userRepository.save(user);
        passwordRecoveryService.savePasswordRecovery(passwordRecovery);
    }

    @Transactional
    public void recoveryToken(EmailDTO emailDTO) {
        if (userRepository.findByEmail(emailDTO.address()).isEmpty()) {
            return;
        }

        String uuidToken = UUID.randomUUID().toString();
        PasswordRecovery passwordRecovery = new PasswordRecovery(
            uuidToken,
            emailDTO.address(),
            Instant.now().plusSeconds(60 * tokenMinutes)
        );
        passwordRecoveryService.savePasswordRecovery(passwordRecovery);
        String emailBody = "Clique no seguinte link para resetar sua senha: \n" + passwordRecoveryUri + uuidToken
            + "\n\n Esse link expirará daqui a 30 minutos. " +
            "Portanto, se esse email não foi solicitado por você, apenas o ignore.";
        emailService.sendEmail(new SendingEmailDTO(
            emailDTO.address(),
            null,
            "Resetamento de senha",
            emailBody
        ));
    }

    private boolean isMatchedPassword(CredentialsRecordDTO credentialsRecordDTO, String encodedPassword) {
        return passwordEncoder.matches(credentialsRecordDTO.password(), encodedPassword);
    }

    private void validateEnabledUser(User user) {
        if (!user.isEnabled()) {
            throw new InvalidAuthenticationException("Usuario nao esta ativo");
        }
    }

    @Transactional
    public void resetPassword(String uuidToken, PasswordResetDTO passwordRenovationDTO) {
        validPasswordRenovation(passwordRenovationDTO);
        List<PasswordRecovery> passwordRecoveries =
            passwordRecoveryService.getValidPasswordRecoveries(uuidToken, Instant.now());
        PasswordRecovery validPasswordRecovery = passwordRecoveries.getFirst();
        User user = userRepository.findByEmail(validPasswordRecovery.getEmail()).orElseThrow(() ->
            new ResourceNotFoundException("Usuário não encontrado"));
        validPasswordRecovery.setExpiration(Instant.now());
        user.setPassword(passwordEncoder.encode(passwordRenovationDTO.newPassword()));
        saveUserAndPasswordRecovery(validPasswordRecovery, user);
    }

    private void validPasswordRenovation(PasswordResetDTO passwordRenovationDTO) {
        if (Objects.isNull(passwordRenovationDTO)
            || Objects.isNull(passwordRenovationDTO.newPassword())
            || Objects.isNull(passwordRenovationDTO.newPasswordConfirmation())) {
            throw new InvalidAuthenticationException("Nova senha e confirmacao sao obrigatorias");
        }

        Set<ConstraintViolation<PasswordResetDTO>> violations = validator.validate(passwordRenovationDTO);
        if (!violations.isEmpty()) {
            throw new InvalidAuthenticationException("Nova senha invalida");
        }

        if (!Objects.equals(passwordRenovationDTO.newPassword(), passwordRenovationDTO.newPasswordConfirmation())) {
            throw new InvalidAuthenticationException("A senha e a confirmação dela devem ser exatamente iguais");
        }
    }
}
