package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.RefreshToken;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.repositories.RefreshTokenRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatNoException;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefreshTokenServiceTests {

    private static final Instant NOW = Instant.parse("2026-07-22T12:00:00Z");
    private static final long TTL_REFRESH_TOKEN = 60_000L;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    private RefreshTokenService refreshTokenService;

    @BeforeEach
    void setUp() {
        refreshTokenService = new RefreshTokenService(
            refreshTokenRepository,
            Clock.fixed(NOW, ZoneOffset.UTC));
        ReflectionTestUtils.setField(refreshTokenService, "ttlRefreshToken", TTL_REFRESH_TOKEN);
    }

    @Test
    void rotateSavesNewTokenOnlyAfterOldTokenIsAtomicallyRotated() {
        User user = createUser();
        String rawOldToken = "old-refresh-token";
        String oldHash = TokenUtils.sha256(rawOldToken);
        RefreshToken oldToken = createActiveRefreshToken(user, oldHash);

        when(refreshTokenRepository.findByTokenHash(oldHash)).thenReturn(Optional.of(oldToken));
        when(refreshTokenRepository.rotateActiveToken(eq(oldHash), anyString(), eq(NOW))).thenReturn(1);

        String rawNewToken = refreshTokenService.rotate(rawOldToken, "device", "agent", "127.0.0.1");
        String newHash = TokenUtils.sha256(rawNewToken);

        ArgumentCaptor<RefreshToken> savedTokenCaptor = ArgumentCaptor.forClass(RefreshToken.class);
        InOrder inOrder = inOrder(refreshTokenRepository);
        inOrder.verify(refreshTokenRepository).findByTokenHash(oldHash);
        inOrder.verify(refreshTokenRepository).rotateActiveToken(oldHash, newHash, NOW);
        inOrder.verify(refreshTokenRepository).save(savedTokenCaptor.capture());

        RefreshToken savedToken = savedTokenCaptor.getValue();
        assertThat(savedToken.getTokenHash()).isEqualTo(newHash);
        assertThat(savedToken.getUser()).isEqualTo(user);
        assertThat(savedToken.getIssuedAt()).isEqualTo(NOW);
        assertThat(savedToken.getExpiresAt()).isEqualTo(NOW.plusMillis(TTL_REFRESH_TOKEN));
        assertThat(savedToken.getDeviceId()).isEqualTo("device");
        assertThat(savedToken.getUserAgent()).isEqualTo("agent");
        assertThat(savedToken.getIpAddress()).isEqualTo("127.0.0.1");
    }

    @Test
    void rotateDoesNotSaveNewTokenWhenOldTokenWasAlreadyRotatedConcurrently() {
        User user = createUser();
        String rawOldToken = "old-refresh-token";
        String oldHash = TokenUtils.sha256(rawOldToken);
        RefreshToken oldToken = createActiveRefreshToken(user, oldHash);

        when(refreshTokenRepository.findByTokenHash(oldHash)).thenReturn(Optional.of(oldToken));
        when(refreshTokenRepository.rotateActiveToken(eq(oldHash), anyString(), eq(NOW))).thenReturn(0);

        assertThatThrownBy(() -> refreshTokenService.rotate(rawOldToken, "device", "agent", "127.0.0.1"))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(refreshTokenRepository).rotateActiveToken(eq(oldHash), anyString(), eq(NOW));
        verify(refreshTokenRepository, never()).save(any(RefreshToken.class));
    }

    @Test
    void revokeUsesAtomicUpdateAndDoesNotExposeUnknownOrInactiveTokens() {
        String rawRefreshToken = "refresh-token";
        String tokenHash = TokenUtils.sha256(rawRefreshToken);

        assertThatNoException().isThrownBy(() -> refreshTokenService.revoke(rawRefreshToken));

        verify(refreshTokenRepository).revokeActiveToken(tokenHash, NOW);
        verify(refreshTokenRepository, never()).findByTokenHash(anyString());
        verify(refreshTokenRepository, never()).save(any(RefreshToken.class));
    }

    private RefreshToken createActiveRefreshToken(User user, String tokenHash) {
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setTokenHash(tokenHash);
        refreshToken.setUser(user);
        refreshToken.setIssuedAt(NOW.minusSeconds(60));
        refreshToken.setExpiresAt(NOW.plusSeconds(60));
        return refreshToken;
    }

    private User createUser() {
        User user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");
        user.setName("User");
        user.setPassword("encoded-password");
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }
}
