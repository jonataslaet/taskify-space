package com.jonataslaet.taskifyspace.services.ratelimit;

import com.jonataslaet.taskifyspace.exceptions.RateLimitExceededException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CaffeineAuthRateLimiterTests {

    private MutableClock clock;
    private CaffeineAuthRateLimiter rateLimiter;

    @BeforeEach
    void setUp() {
        clock = new MutableClock(Instant.parse("2026-07-24T12:00:00Z"));
        rateLimiter = new CaffeineAuthRateLimiter(clock);
    }

    @Test
    void loginBlocksByEmailWindowAndAllowsAfterReset() {
        for (int i = 0; i < CaffeineAuthRateLimiter.LOGIN_EMAIL_LIMIT; i++) {
            rateLimiter.checkLogin("192.168.0." + i, "User@Example.COM", "device-" + i);
        }

        assertThatThrownBy(() -> rateLimiter.checkLogin("192.168.1.1", "user@example.com", "device-next"))
            .isInstanceOfSatisfying(RateLimitExceededException.class, exception ->
                assertThat(exception.getRetryAfterSeconds()).isPositive());

        clock.advance(CaffeineAuthRateLimiter.LOGIN_EMAIL_WINDOW.plusSeconds(1));

        assertThatCode(() -> rateLimiter.checkLogin("192.168.1.1", "user@example.com", "device-next"))
            .doesNotThrowAnyException();
    }

    @Test
    void loginAppliesBackoffAfterRepeatedFailuresAndSuccessClearsIt() {
        for (int i = 0; i < CaffeineAuthRateLimiter.LOGIN_FAILURES_BEFORE_BACKOFF; i++) {
            rateLimiter.recordLoginFailure("127.0.0.1", "user@example.com", "device");
        }

        assertThatThrownBy(() -> rateLimiter.checkLogin("127.0.0.1", "user@example.com", "device"))
            .isInstanceOfSatisfying(RateLimitExceededException.class, exception ->
                assertThat(exception.getRetryAfterSeconds())
                    .isEqualTo(CaffeineAuthRateLimiter.INITIAL_LOGIN_BACKOFF.toSeconds()));

        rateLimiter.recordLoginSuccess("127.0.0.1", "user@example.com", "device");

        assertThatCode(() -> rateLimiter.checkLogin("127.0.0.1", "user@example.com", "device"))
            .doesNotThrowAnyException();
    }

    @Test
    void recoveryBlocksRepeatedEmailSendInsideShortWindow() {
        rateLimiter.checkPasswordRecovery("127.0.0.1", "user@example.com", "device");

        assertThatThrownBy(() -> rateLimiter.checkPasswordRecovery("127.0.0.2", "User@Example.COM", "device-2"))
            .isInstanceOf(RateLimitExceededException.class);

        clock.advance(CaffeineAuthRateLimiter.RECOVERY_EMAIL_SEND_WINDOW.plusSeconds(1));

        assertThatCode(() -> rateLimiter.checkPasswordRecovery("127.0.0.2", "User@Example.COM", "device-2"))
            .doesNotThrowAnyException();
    }

    @Test
    void recoveryBlocksEmailAfterHourlyLimit() {
        for (int i = 0; i < CaffeineAuthRateLimiter.RECOVERY_EMAIL_LIMIT; i++) {
            rateLimiter.checkPasswordRecovery("127.0.0." + i, "user@example.com", "device-" + i);
            clock.advance(CaffeineAuthRateLimiter.RECOVERY_EMAIL_SEND_WINDOW.plusSeconds(1));
        }

        assertThatThrownBy(() -> rateLimiter.checkPasswordRecovery("127.0.0.9", "user@example.com", "device-next"))
            .isInstanceOfSatisfying(RateLimitExceededException.class, exception ->
                assertThat(exception.getRetryAfterSeconds()).isPositive());
    }

    private static class MutableClock extends Clock {
        private Instant instant;
        private final ZoneId zone;

        private MutableClock(Instant instant) {
            this(instant, ZoneOffset.UTC);
        }

        private MutableClock(Instant instant, ZoneId zone) {
            this.instant = instant;
            this.zone = zone;
        }

        private void advance(Duration duration) {
            instant = instant.plus(duration);
        }

        @Override
        public ZoneId getZone() {
            return zone;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return new MutableClock(instant, zone);
        }

        @Override
        public Instant instant() {
            return instant;
        }
    }
}
