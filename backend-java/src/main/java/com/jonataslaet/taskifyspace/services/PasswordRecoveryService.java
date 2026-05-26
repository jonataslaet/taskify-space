package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.exceptions.ResourceStorageException;
import com.jonataslaet.taskifyspace.exceptions.TokenExpirationException;
import com.jonataslaet.taskifyspace.repositories.PasswordRecoveryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

@Service
public class PasswordRecoveryService {

    private final PasswordRecoveryRepository passwordRecoveryRepository;

    public PasswordRecoveryService(PasswordRecoveryRepository passwordRecoveryRepository) {
        this.passwordRecoveryRepository = passwordRecoveryRepository;
    }


    public List<PasswordRecovery> getValidPasswordRecoveries(String uuidToken, Instant now) {
        List<PasswordRecovery> passwordRecoveries =
                passwordRecoveryRepository.findValidPasswordRecoveries(uuidToken, now);
        validPasswordRecoveries(passwordRecoveries);
        return passwordRecoveries;
    }

    private void validPasswordRecoveries(List<PasswordRecovery> passwordRecoveries) {
        if (Objects.isNull(passwordRecoveries) || passwordRecoveries.isEmpty()) {
            throw new TokenExpirationException("O token de recuperação é inválido. Por favor, tente novamente.");
        }
    }

    @Transactional
    public PasswordRecovery savePasswordRecovery(PasswordRecovery passwordRecovery) {
        try {
            return passwordRecoveryRepository.save(passwordRecovery);
        } catch (Exception e) {
            throw new ResourceStorageException("Problema desconhecido ao salvar recuperação de senha");
        }
    }
}
