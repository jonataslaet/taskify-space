package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.repositories.PasswordRecoveryRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PasswordRecoveryServiceTests {

    @Mock
    private PasswordRecoveryRepository passwordRecoveryRepository;

    private PasswordRecoveryService passwordRecoveryService;

    @BeforeEach
    void setUp() {
        passwordRecoveryService = new PasswordRecoveryService(passwordRecoveryRepository);
    }

    @Test
    void getValidPasswordRecoveriesLooksUpHashedToken() {
        String rawToken = "raw-token";
        Instant now = Instant.parse("2026-07-22T12:00:00Z");
        String tokenHash = TokenUtils.sha256(rawToken);

        when(passwordRecoveryRepository.findValidPasswordRecoveries(tokenHash, now))
            .thenReturn(List.of(new com.jonataslaet.taskifyspace.entities.PasswordRecovery(
                tokenHash,
                "user@example.com",
                now.plusSeconds(60))));

        passwordRecoveryService.getValidPasswordRecoveries(rawToken, now);

        verify(passwordRecoveryRepository).findValidPasswordRecoveries(tokenHash, now);
    }
}
