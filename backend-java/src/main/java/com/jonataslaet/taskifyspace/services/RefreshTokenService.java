package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.RefreshToken;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.repositories.RefreshTokenRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;

import static com.jonataslaet.taskifyspace.utils.TokenUtils.generateRandomToken;

@Service
@Transactional(readOnly = true)
public class RefreshTokenService {

    @Value("${security.jwt.ttl.token.refresh}")
    private Long ttlRefreshToken;

    private final RefreshTokenRepository refreshTokenRepository;
    private final Clock clock;

    public RefreshTokenService(RefreshTokenRepository refreshTokenRepository, Clock clock) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.clock = clock;
    }

    /** Gera um novo refresh token (string) e persiste seu hash associado ao usuário. */
    @Transactional
    public String issue(User user, String deviceId, String userAgent, String ipAddress) {
        String raw = generateRandomToken();
        String hash = TokenUtils.sha256(raw);
        Instant now = Instant.now(clock);

        RefreshToken refreshTokenEntity = new RefreshToken();
        refreshTokenEntity.setTokenHash(hash);
        refreshTokenEntity.setUser(user);
        refreshTokenEntity.setIssuedAt(now);
        refreshTokenEntity.setExpiresAt(now.plusMillis(ttlRefreshToken));
        refreshTokenEntity.setDeviceId(deviceId);
        refreshTokenEntity.setUserAgent(userAgent);
        refreshTokenEntity.setIpAddress(ipAddress);

        refreshTokenRepository.save(refreshTokenEntity);
        return raw;
    }

    /** Valida o refresh token, verifica expiração/revogação e retorna a entidade. */
    @Transactional(readOnly = true)
    public RefreshToken validate(String rawRefreshToken) {
        String hash = TokenUtils.sha256(rawRefreshToken);
        RefreshToken token = refreshTokenRepository.findByTokenHash(hash)
            .orElseThrow(() -> new InvalidAuthenticationException("Refresh token inválido"));

        Instant now = Instant.now(clock);
        if (token.getRevokedAt() != null) {
            throw new InvalidAuthenticationException("Refresh token revogado");
        }
        if (now.isAfter(token.getExpiresAt())) {
            throw new InvalidAuthenticationException("Refresh token expirado");
        }
        if (token.getReplacedByHash() != null) {
            throw new InvalidAuthenticationException("Refresh token já foi rotacionado");
        }
        return token;
    }

    /** Rotaciona: revoga o atual e emite um novo, encadeando replacedByHash. */
    @Transactional
    public String rotate(String rawOldRefreshToken, String deviceId, String userAgent, String ipAddress) {
        RefreshToken old = validate(rawOldRefreshToken); // valida atual

        String rawNew = generateRandomToken();
        String newHash = TokenUtils.sha256(rawNew);
        Instant now = Instant.now(clock);

        // marca encadeamento e revogação lógica do antigo
        int rotatedTokens = refreshTokenRepository.rotateActiveToken(old.getTokenHash(), newHash, now);
        if (rotatedTokens != 1) {
            throw new InvalidAuthenticationException("Refresh token ja foi rotacionado");
        }

        // cria o novo
        RefreshToken newer = new RefreshToken();
        newer.setTokenHash(newHash);
        newer.setUser(old.getUser());
        newer.setIssuedAt(now);
        newer.setExpiresAt(now.plusMillis(ttlRefreshToken));
        newer.setDeviceId(deviceId);
        newer.setUserAgent(userAgent);
        newer.setIpAddress(ipAddress);
        refreshTokenRepository.save(newer);

        return rawNew;
    }

    /** Revoga toda a “cadeia” do token atual (logout). */
    @Transactional
    public void revoke(String rawRefreshToken) {
        String hash = TokenUtils.sha256(rawRefreshToken);
        RefreshToken token = refreshTokenRepository.findByTokenHash(hash)
            .orElseThrow(() -> new InvalidAuthenticationException("Refresh token inválido"));
        token.setRevokedAt(Instant.now(clock));
        refreshTokenRepository.save(token);
    }

    @Transactional
    public void revokeAllByUserId(Long userId) {
        refreshTokenRepository.revokeActiveByUserId(userId, Instant.now(clock));
    }

    @Transactional
    public void deleteAllByUserId(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

}
