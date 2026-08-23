package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.exceptions.TokenExpirationException;
import com.jonataslaet.taskifyspace.repositories.PasswordRecoveryRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PasswordRecoveryServiceTests {

    private static final Instant NOW = Instant.parse("2026-07-22T12:00:00Z");
    private static final String CODE = "123456";
    private static final String REQUEST_TOKEN = "request-token";
    private static final String RESET_SESSION_TOKEN = "reset-session-token";

    @Mock
    private PasswordRecoveryRepository passwordRecoveryRepository;

    private PasswordRecoveryService passwordRecoveryService;

    @BeforeEach
    void setUp() {
        passwordRecoveryService = new PasswordRecoveryService(
            passwordRecoveryRepository,
            Clock.fixed(NOW, ZoneOffset.UTC));
        ReflectionTestUtils.setField(passwordRecoveryService, "resetSessionMinutes", 10L);
    }

    @Test
    void getValidPasswordRecoveriesLooksUpHashedToken() {
        String tokenHash = TokenUtils.sha256(CODE);

        when(passwordRecoveryRepository.findValidPasswordRecoveries(tokenHash, NOW))
            .thenReturn(List.of(recovery(CODE, REQUEST_TOKEN, NOW.plusSeconds(60))));

        passwordRecoveryService.getValidPasswordRecoveries(CODE, NOW);

        verify(passwordRecoveryRepository).findValidPasswordRecoveries(tokenHash, NOW);
    }

    @Test
    void createResetSessionConsumesCodeAndStoresHashedSessionToken() {
        PasswordRecovery passwordRecovery = recovery(CODE, REQUEST_TOKEN, NOW.plusSeconds(60));
        when(passwordRecoveryRepository.findPendingByRequestTokenHashForUpdate(
            TokenUtils.sha256(REQUEST_TOKEN),
            NOW))
            .thenReturn(Optional.of(passwordRecovery));

        String resetSessionToken = passwordRecoveryService.createResetSession(REQUEST_TOKEN, CODE);

        assertThat(resetSessionToken).isNotBlank();
        assertThat(passwordRecovery.getUsedAt()).isEqualTo(NOW);
        assertThat(passwordRecovery.getExpiration()).isEqualTo(NOW);
        assertThat(passwordRecovery.getResetSessionHash()).isEqualTo(TokenUtils.sha256(resetSessionToken));
        assertThat(passwordRecovery.getResetSessionExpiration()).isEqualTo(NOW.plusSeconds(600));
        assertThat(passwordRecovery.getResetSessionUsedAt()).isNull();
        verify(passwordRecoveryRepository).save(passwordRecovery);
    }

    @Test
    void createResetSessionInvalidatesRecoveryOnFifthWrongCode() {
        PasswordRecovery passwordRecovery = recovery(CODE, REQUEST_TOKEN, NOW.plusSeconds(60));
        when(passwordRecoveryRepository.findPendingByRequestTokenHashForUpdate(
            TokenUtils.sha256(REQUEST_TOKEN),
            NOW))
            .thenReturn(Optional.of(passwordRecovery));

        for (int attempt = 0; attempt < 5; attempt++) {
            assertThatThrownBy(() -> passwordRecoveryService.createResetSession(REQUEST_TOKEN, "654321"))
                .isInstanceOf(TokenExpirationException.class);
        }

        assertThat(passwordRecovery.getFailedAttempts()).isEqualTo(5);
        assertThat(passwordRecovery.getExpiration()).isEqualTo(NOW);
        assertThat(passwordRecovery.getUsedAt()).isNull();
        verify(passwordRecoveryRepository, times(5)).save(passwordRecovery);
    }

    @Test
    void consumeResetSessionMarksSessionAsUsed() {
        PasswordRecovery passwordRecovery = recovery(CODE, REQUEST_TOKEN, NOW.minusSeconds(60));
        passwordRecovery.startResetSession(
            TokenUtils.sha256(RESET_SESSION_TOKEN),
            NOW.plusSeconds(600),
            NOW.minusSeconds(30));
        when(passwordRecoveryRepository.findValidResetSessionForUpdate(
            TokenUtils.sha256(RESET_SESSION_TOKEN),
            NOW))
            .thenReturn(Optional.of(passwordRecovery));
        when(passwordRecoveryRepository.save(passwordRecovery)).thenReturn(passwordRecovery);

        PasswordRecovery result = passwordRecoveryService.consumeResetSession(RESET_SESSION_TOKEN);

        assertThat(result).isSameAs(passwordRecovery);
        assertThat(passwordRecovery.getResetSessionUsedAt()).isEqualTo(NOW);
        assertThat(passwordRecovery.getResetSessionExpiration()).isEqualTo(NOW);
        verify(passwordRecoveryRepository).save(passwordRecovery);
    }

    private PasswordRecovery recovery(String code, String requestToken, Instant expiration) {
        return new PasswordRecovery(
            TokenUtils.sha256(code),
            TokenUtils.sha256(requestToken),
            "user@example.com",
            expiration);
    }
}
