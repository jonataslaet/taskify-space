package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import com.jonataslaet.taskifyspace.controllers.dtos.*;
import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import com.jonataslaet.taskifyspace.services.ratelimit.AuthRateLimiter;
import com.jonataslaet.taskifyspace.utils.EmailUtils;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;

@Service
public class AuthenticationService {

    private static final String INVALID_LOGIN_MESSAGE =
        "Email ou senha invalidos ou usuario pendente de avaliacao";

    private final RefreshTokenService refreshTokenService;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenConfiguration tokenConfiguration;
    private final PasswordRecoveryService passwordRecoveryService;
    private final PasswordRecoveryRequestService passwordRecoveryRequestService;
    private final Validator validator;
    private final AuthRateLimiter authRateLimiter;

    public AuthenticationService(RefreshTokenService refreshTokenService, UserRepository userRepository,
        PasswordEncoder passwordEncoder, TokenConfiguration tokenConfiguration,
        PasswordRecoveryService passwordRecoveryService,
        PasswordRecoveryRequestService passwordRecoveryRequestService,
        Validator validator,
        AuthRateLimiter authRateLimiter) {
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenConfiguration = tokenConfiguration;
        this.passwordRecoveryService = passwordRecoveryService;
        this.passwordRecoveryRequestService = passwordRecoveryRequestService;
        this.validator = validator;
        this.authRateLimiter = authRateLimiter;
    }

    @Transactional
    public AuthenticationResponseRecordDTO login(
        CredentialsRecordDTO credentialsRecordDTO, String deviceId, String userAgent, String ipAddress) {
        if (hasMissingCredentials(credentialsRecordDTO)) {
            throw new InvalidAuthenticationException(INVALID_LOGIN_MESSAGE);
        }

        String normalizedEmail = EmailUtils.normalize(credentialsRecordDTO.username());
        authRateLimiter.checkLogin(ipAddress, normalizedEmail, deviceId);

        User user = userRepository.findByEmail(normalizedEmail).orElse(null);
        if (Objects.nonNull(user) && isMatchedPassword(credentialsRecordDTO, user.getPassword()) && user.isEnabled()) {
            String accessToken = tokenConfiguration.createAccessToken(user);
            String refreshToken = refreshTokenService.issue(user, deviceId, userAgent, ipAddress);
            authRateLimiter.recordLoginSuccess(ipAddress, normalizedEmail, deviceId);

            return new AuthenticationResponseRecordDTO(user.getId(), user.getEmail(), user.getName(),
                accessToken, refreshToken, user.getRole());
        }
        authRateLimiter.recordLoginFailure(ipAddress, normalizedEmail, deviceId);
        throw new InvalidAuthenticationException(
            "Email ou senha estão inválidos ou este usuário está pendente de avaliação");
    }

    @Transactional
    public AuthenticationResponseRecordDTO refresh(
        String refreshToken, String deviceId, String userAgent, String ipAddress) {
        validateRequiredRefreshToken(refreshToken);

        var current = refreshTokenService.validate(refreshToken);
        User user = userRepository.findByEmail(current.getUser().getUsername())
            .orElseThrow(() -> new InvalidAuthenticationException("Usuário não encontrado"));

        validateEnabledUser(user);

        String newToken = tokenConfiguration.createAccessToken(user);
        String newRefreshToken = refreshTokenService.rotate(refreshToken, deviceId, userAgent, ipAddress);

        return new AuthenticationResponseRecordDTO(user.getId(),user.getEmail(), user.getName(), newToken,
            newRefreshToken, user.getRole()
        );
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        validateRequiredRefreshToken(rawRefreshToken);
        refreshTokenService.revoke(rawRefreshToken);
    }

    private boolean hasMissingCredentials(CredentialsRecordDTO credentialsRecordDTO) {
        return Objects.isNull(credentialsRecordDTO) || isBlank(credentialsRecordDTO.username())
            || isBlank(credentialsRecordDTO.password());
    }

    private void validateRequiredRefreshToken(String refreshToken) {
        if (isBlank(refreshToken)) throw new InvalidAuthenticationException("Refresh token obrigatorio");
    }

    private boolean isBlank(String value) {
        return Objects.isNull(value) || value.isBlank();
    }

    @Transactional
    private void saveUserAndPasswordRecovery(PasswordRecovery passwordRecovery, User user) {
        userRepository.save(user);
        passwordRecoveryService.savePasswordRecovery(passwordRecovery);
    }

    public void recoveryToken(EmailDTO emailDTO) {
        recoveryToken(emailDTO, null, null);
    }

    public void recoveryToken(EmailDTO emailDTO, String ipAddress, String deviceId) {
        if (Objects.isNull(emailDTO) || isBlank(emailDTO.address())) {
            throw new InvalidRequestException("Email is required");
        }

        String normalizedEmail = EmailUtils.normalize(emailDTO.address());
        authRateLimiter.checkPasswordRecovery(ipAddress, normalizedEmail, deviceId);
        passwordRecoveryRequestService.requestRecoveryToken(normalizedEmail);
    }

    private boolean isMatchedPassword(CredentialsRecordDTO credentialsRecordDTO, String encodedPassword) {
        return passwordEncoder.matches(credentialsRecordDTO.password(), encodedPassword);
    }

    private void validateEnabledUser(User user) {
        if (!user.isEnabled()) throw new InvalidAuthenticationException("Usuario nao esta ativo");
    }

    @Transactional
    public void resetPassword(String uuidToken, PasswordResetDTO passwordRenovationDTO) {
        validPasswordRenovation(passwordRenovationDTO);
        List<PasswordRecovery> passwordRecoveries =
            passwordRecoveryService.getValidPasswordRecoveries(uuidToken, Instant.now());
        PasswordRecovery validPasswordRecovery = passwordRecoveries.getFirst();
        User user = userRepository.findByEmail(EmailUtils.normalize(validPasswordRecovery.getEmail())).orElseThrow(() ->
            new ResourceNotFoundException("Usuário não encontrado"));
        validPasswordRecovery.setExpiration(Instant.now());
        user.setPassword(passwordEncoder.encode(passwordRenovationDTO.newPassword()));
        saveUserAndPasswordRecovery(validPasswordRecovery, user);
        refreshTokenService.revokeAllByUserId(user.getId());
    }

    private void validPasswordRenovation(PasswordResetDTO passwordRenovationDTO) {
        if (Objects.isNull(passwordRenovationDTO) || Objects.isNull(passwordRenovationDTO.newPassword())
            || Objects.isNull(passwordRenovationDTO.newPasswordConfirmation())) {
            throw new InvalidAuthenticationException("Nova senha e confirmacao sao obrigatorias");
        }

        Set<ConstraintViolation<PasswordResetDTO>> violations = validator.validate(passwordRenovationDTO);
        if (!violations.isEmpty()) throw new InvalidAuthenticationException("Nova senha invalida");

        if (!Objects.equals(passwordRenovationDTO.newPassword(), passwordRenovationDTO.newPasswordConfirmation())) {
            throw new InvalidAuthenticationException("A senha e a confirmação dela devem ser exatamente iguais");
        }
    }
}
