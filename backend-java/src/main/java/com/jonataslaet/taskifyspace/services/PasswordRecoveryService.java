package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.exceptions.ResourceStorageException;
import com.jonataslaet.taskifyspace.exceptions.TokenExpirationException;
import com.jonataslaet.taskifyspace.repositories.PasswordRecoveryRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

@Service
public class PasswordRecoveryService {

    private static final String RECOVERY_TOKEN_PATTERN = "\\d{6}";

    private final PasswordRecoveryRepository passwordRecoveryRepository;

    public PasswordRecoveryService(PasswordRecoveryRepository passwordRecoveryRepository) {
        this.passwordRecoveryRepository = passwordRecoveryRepository;
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
        return passwordRecoveryRepository.existsByTokenHashAndExpirationAfter(TokenUtils.sha256(rawToken), now);
    }

    private void validateRecoveryTokenFormat(String rawToken) {
        if (Objects.isNull(rawToken) || !rawToken.matches(RECOVERY_TOKEN_PATTERN)) {
            throw new TokenExpirationException("O token de recuperacao e invalido. Por favor, tente novamente.");
        }
    }

    private void validPasswordRecoveries(List<PasswordRecovery> passwordRecoveries) {
        if (Objects.isNull(passwordRecoveries) || passwordRecoveries.isEmpty()) {
            throw new TokenExpirationException("O token de recuperacao e invalido. Por favor, tente novamente.");
        }
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
