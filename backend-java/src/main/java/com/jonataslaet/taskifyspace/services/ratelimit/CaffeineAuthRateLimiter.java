package com.jonataslaet.taskifyspace.services.ratelimit;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import com.jonataslaet.taskifyspace.exceptions.RateLimitExceededException;
import com.jonataslaet.taskifyspace.utils.EmailUtils;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Objects;

@Service
public class CaffeineAuthRateLimiter implements AuthRateLimiter {

    static final int LOGIN_IP_LIMIT = 30;
    static final Duration LOGIN_IP_WINDOW = Duration.ofMinutes(1);
    static final int LOGIN_EMAIL_LIMIT = 10;
    static final Duration LOGIN_EMAIL_WINDOW = Duration.ofMinutes(15);
    static final int LOGIN_EMAIL_DEVICE_LIMIT = 6;
    static final Duration LOGIN_EMAIL_DEVICE_WINDOW = Duration.ofMinutes(15);
    static final int LOGIN_FAILURES_BEFORE_BACKOFF = 5;
    static final Duration LOGIN_FAILURE_RETENTION = Duration.ofHours(1);
    static final Duration INITIAL_LOGIN_BACKOFF = Duration.ofSeconds(30);
    static final Duration MAX_LOGIN_BACKOFF = Duration.ofMinutes(15);

    static final int RECOVERY_IP_LIMIT = 10;
    static final Duration RECOVERY_IP_WINDOW = Duration.ofHours(1);
    static final int RECOVERY_EMAIL_LIMIT = 3;
    static final Duration RECOVERY_EMAIL_WINDOW = Duration.ofHours(1);
    static final int RECOVERY_EMAIL_SEND_LIMIT = 1;
    static final Duration RECOVERY_EMAIL_SEND_WINDOW = Duration.ofMinutes(5);
    static final int RECOVERY_IP_EMAIL_LIMIT = 3;
    static final Duration RECOVERY_IP_EMAIL_WINDOW = Duration.ofHours(1);
    static final int RECOVERY_DEVICE_LIMIT = 10;
    static final Duration RECOVERY_DEVICE_WINDOW = Duration.ofHours(1);

    private static final int MAX_CACHE_SIZE = 100_000;
    private static final Duration CACHE_RETENTION = Duration.ofHours(24);
    private static final String KEY_PREFIX = "taskify:auth";
    private static final String UNKNOWN = "unknown";

    private final Cache<String, WindowCounter> counters = Caffeine.newBuilder()
        .maximumSize(MAX_CACHE_SIZE)
        .expireAfterWrite(CACHE_RETENTION)
        .build();
    private final Cache<String, LoginFailureState> loginFailures = Caffeine.newBuilder()
        .maximumSize(MAX_CACHE_SIZE)
        .expireAfterWrite(CACHE_RETENTION)
        .build();
    private final Clock clock;

    public CaffeineAuthRateLimiter(Clock clock) {
        this.clock = clock;
    }

    @Override
    public void checkLogin(String ipAddress, String email, String deviceId) {
        Instant now = Instant.now(clock);
        String ipKey = identity(ipAddress);
        String emailKey = emailIdentity(email);
        String deviceKey = identity(deviceId);

        enforceLoginBackoff(loginFailureEmailKey(emailKey), now);
        enforceLoginBackoff(loginFailureEmailDeviceKey(emailKey, deviceKey), now);

        consumeCounter(loginIpKey(ipKey), LOGIN_IP_LIMIT, LOGIN_IP_WINDOW, now);
        consumeCounter(loginEmailKey(emailKey), LOGIN_EMAIL_LIMIT, LOGIN_EMAIL_WINDOW, now);
        consumeCounter(loginEmailDeviceKey(emailKey, deviceKey), LOGIN_EMAIL_DEVICE_LIMIT,
            LOGIN_EMAIL_DEVICE_WINDOW, now);
    }

    @Override
    public void recordLoginFailure(String ipAddress, String email, String deviceId) {
        Instant now = Instant.now(clock);
        String emailKey = emailIdentity(email);
        String deviceKey = identity(deviceId);

        recordLoginFailure(loginFailureEmailKey(emailKey), now);
        recordLoginFailure(loginFailureEmailDeviceKey(emailKey, deviceKey), now);
    }

    @Override
    public void recordLoginSuccess(String ipAddress, String email, String deviceId) {
        String emailKey = emailIdentity(email);
        String deviceKey = identity(deviceId);
        loginFailures.invalidateAll(List.of(
            loginFailureEmailKey(emailKey),
            loginFailureEmailDeviceKey(emailKey, deviceKey)
        ));
    }

    @Override
    public void checkPasswordRecovery(String ipAddress, String email, String deviceId) {
        Instant now = Instant.now(clock);
        String ipKey = identity(ipAddress);
        String emailKey = emailIdentity(email);

        consumeCounter(recoveryIpKey(ipKey), RECOVERY_IP_LIMIT, RECOVERY_IP_WINDOW, now);
        consumeCounter(recoveryEmailSendKey(emailKey), RECOVERY_EMAIL_SEND_LIMIT,
            RECOVERY_EMAIL_SEND_WINDOW, now);
        consumeCounter(recoveryEmailKey(emailKey), RECOVERY_EMAIL_LIMIT, RECOVERY_EMAIL_WINDOW, now);
        consumeCounter(recoveryIpEmailKey(ipKey, emailKey), RECOVERY_IP_EMAIL_LIMIT,
            RECOVERY_IP_EMAIL_WINDOW, now);

        if (hasText(deviceId)) {
            consumeCounter(recoveryDeviceKey(identity(deviceId)), RECOVERY_DEVICE_LIMIT,
                RECOVERY_DEVICE_WINDOW, now);
        }
    }

    private void consumeCounter(String key, int limit, Duration window, Instant now) {
        WindowCounter counter = counters.asMap().compute(key, (ignored, current) -> {
            if (Objects.isNull(current) || !current.resetAt().isAfter(now)) {
                return new WindowCounter(1, now.plus(window));
            }
            return new WindowCounter(current.count() + 1, current.resetAt());
        });

        if (counter.count() > limit) {
            throw new RateLimitExceededException(
                "Muitas requisicoes. Tente novamente mais tarde.",
                secondsUntil(counter.resetAt(), now));
        }
    }

    private void enforceLoginBackoff(String key, Instant now) {
        LoginFailureState state = loginFailures.getIfPresent(key);
        if (Objects.isNull(state) || !state.expiresAt().isAfter(now)) {
            loginFailures.invalidate(key);
            return;
        }

        if (Objects.nonNull(state.blockedUntil()) && state.blockedUntil().isAfter(now)) {
            throw new RateLimitExceededException(
                "Muitas tentativas de login. Tente novamente mais tarde.",
                secondsUntil(state.blockedUntil(), now));
        }
    }

    private void recordLoginFailure(String key, Instant now) {
        loginFailures.asMap().compute(key, (ignored, current) -> {
            int previousFailures = Objects.isNull(current) || !current.expiresAt().isAfter(now)
                ? 0
                : current.failureCount();
            int failures = previousFailures + 1;
            Instant blockedUntil = failures < LOGIN_FAILURES_BEFORE_BACKOFF
                ? null
                : now.plus(loginBackoffFor(failures));

            return new LoginFailureState(
                failures,
                blockedUntil,
                now.plus(LOGIN_FAILURE_RETENTION));
        });
    }

    private Duration loginBackoffFor(int failures) {
        int backoffStep = Math.max(0, failures - LOGIN_FAILURES_BEFORE_BACKOFF);
        long multiplier = 1L << Math.min(backoffStep, 5);
        return Duration.ofSeconds(Math.min(
            INITIAL_LOGIN_BACKOFF.toSeconds() * multiplier,
            MAX_LOGIN_BACKOFF.toSeconds()));
    }

    private long secondsUntil(Instant instant, Instant now) {
        return Math.max(1L, Duration.between(now, instant).toSeconds());
    }

    private String loginIpKey(String ipKey) {
        return KEY_PREFIX + ":login:ip:" + ipKey + ":1m";
    }

    private String loginEmailKey(String emailKey) {
        return KEY_PREFIX + ":login:email:" + emailKey + ":15m";
    }

    private String loginEmailDeviceKey(String emailKey, String deviceKey) {
        return KEY_PREFIX + ":login:email-device:" + emailKey + ":" + deviceKey + ":15m";
    }

    private String loginFailureEmailKey(String emailKey) {
        return KEY_PREFIX + ":login:failure:email:" + emailKey + ":1h";
    }

    private String loginFailureEmailDeviceKey(String emailKey, String deviceKey) {
        return KEY_PREFIX + ":login:failure:email-device:" + emailKey + ":" + deviceKey + ":1h";
    }

    private String recoveryIpKey(String ipKey) {
        return KEY_PREFIX + ":recovery:ip:" + ipKey + ":1h";
    }

    private String recoveryEmailKey(String emailKey) {
        return KEY_PREFIX + ":recovery:email:" + emailKey + ":1h";
    }

    private String recoveryEmailSendKey(String emailKey) {
        return KEY_PREFIX + ":recovery:email-send:" + emailKey + ":5m";
    }

    private String recoveryIpEmailKey(String ipKey, String emailKey) {
        return KEY_PREFIX + ":recovery:ip-email:" + ipKey + ":" + emailKey + ":1h";
    }

    private String recoveryDeviceKey(String deviceKey) {
        return KEY_PREFIX + ":recovery:device:" + deviceKey + ":1h";
    }

    private String emailIdentity(String email) {
        return identity(EmailUtils.normalize(email));
    }

    private String identity(String value) {
        if (!hasText(value)) {
            return UNKNOWN;
        }
        return "sha256:" + TokenUtils.sha256(value.trim().toLowerCase(Locale.ROOT));
    }

    private boolean hasText(String value) {
        return Objects.nonNull(value) && !value.isBlank();
    }

    private record WindowCounter(int count, Instant resetAt) {}

    private record LoginFailureState(int failureCount, Instant blockedUntil, Instant expiresAt) {}
}
