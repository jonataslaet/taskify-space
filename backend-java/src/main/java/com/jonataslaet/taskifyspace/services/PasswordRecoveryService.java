package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.exceptions.ResourceStorageException;
import com.jonataslaet.taskifyspace.exceptions.TokenExpirationException;
import com.jonataslaet.taskifyspace.repositories.PasswordRecoveryRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

@Service
public class PasswordRecoveryService {

    private static final String RECOVERY_TOKEN_PATTERN = "\\d{6}";
    private static final int MAX_FAILED_ATTEMPTS = 5;

    private final PasswordRecoveryRepository passwordRecoveryRepository;
    private final Clock clock;

    @org.springframework.beans.factory.annotation.Value("${security.email.password-recover.reset-session.minutes:10}")
    private Long resetSessionMinutes = 10L;

    public PasswordRecoveryService(PasswordRecoveryRepository passwordRecoveryRepository, Clock clock) {
        this.passwordRecoveryRepository = passwordRecoveryRepository;
        this.clock = clock;
    }

    public List<PasswordRecovery> getValidPasswordRecoveries(String rawToken, Instant now) {
        validateRecoveryTokenFormat(rawToken);
        String tokenHash = TokenUtils.sha256(rawToken);
        List<PasswordRecovery> passwordRecoveries =
            passwordRecoveryRepository.findValidPasswordRecoveries(tokenHash, now);
        validPasswordRecoveries(passwordRecoveries);
        return passwordRecoveries;
    }

    public boolean hasValidPasswordRecovery(String rawToken, Instant now) {
        validateRecoveryTokenFormat(rawToken);
        return passwordRecoveryRepository.existsValidPasswordRecoveryByTokenHash(TokenUtils.sha256(rawToken), now);
    }

    @Transactional
    public String createResetSession(String requestToken, String rawCode) {
        validateRequiredToken(requestToken);
        validateRecoveryTokenFormat(rawCode);

        Instant now = Instant.now(clock);
        PasswordRecovery passwordRecovery = passwordRecoveryRepository
            .findPendingByRequestTokenHashForUpdate(TokenUtils.sha256(requestToken), now)
            .orElseThrow(() -> invalidRecoveryTokenException());

        if (!Objects.equals(passwordRecovery.getTokenHash(), TokenUtils.sha256(rawCode))) {
            passwordRecovery.recordFailedAttempt(now, MAX_FAILED_ATTEMPTS);
            savePasswordRecovery(passwordRecovery);
            throw invalidRecoveryTokenException();
        }

        return startResetSession(passwordRecovery, now);
    }

    @Transactional
    public PasswordRecovery consumeResetSession(String resetSessionToken) {
        validateRequiredToken(resetSessionToken);

        Instant now = Instant.now(clock);
        PasswordRecovery passwordRecovery = passwordRecoveryRepository
            .findValidResetSessionForUpdate(TokenUtils.sha256(resetSessionToken), now)
            .orElseThrow(() -> invalidRecoveryTokenException());

        passwordRecovery.consumeResetSession(now);
        return savePasswordRecovery(passwordRecovery);
    }

    private String startResetSession(PasswordRecovery passwordRecovery, Instant now) {
        String rawResetSessionToken = TokenUtils.generateRandomToken();
        passwordRecovery.startResetSession(
            TokenUtils.sha256(rawResetSessionToken),
            now.plus(resetSessionTtl()),
            now);
        savePasswordRecovery(passwordRecovery);
        return rawResetSessionToken;
    }

    private Duration resetSessionTtl() {
        return Duration.ofMinutes(resetSessionMinutes);
    }

    private void validateRecoveryTokenFormat(String rawToken) {
        if (Objects.isNull(rawToken) || !rawToken.matches(RECOVERY_TOKEN_PATTERN)) {
            throw invalidRecoveryTokenException();
        }
    }

    private void validateRequiredToken(String token) {
        if (Objects.isNull(token) || token.isBlank()) {
            throw invalidRecoveryTokenException();
        }
    }

    private void validPasswordRecoveries(List<PasswordRecovery> passwordRecoveries) {
        if (Objects.isNull(passwordRecoveries) || passwordRecoveries.isEmpty()) {
            throw invalidRecoveryTokenException();
        }
    }

    private TokenExpirationException invalidRecoveryTokenException() {
        return new TokenExpirationException("O token de recuperacao e invalido. Por favor, tente novamente.");
    }

    @Transactional
    public PasswordRecovery savePasswordRecovery(PasswordRecovery passwordRecovery) {
        try {
            return passwordRecoveryRepository.save(passwordRecovery);
        } catch (Exception e) {
            throw new ResourceStorageException("Problema desconhecido ao salvar recuperacao de senha");
        }
    }

    @Transactional
    public void expireValidPasswordRecoveriesByEmail(String email, Instant expiration) {
        passwordRecoveryRepository.expireValidPasswordRecoveriesByEmail(email, expiration);
    }
}
