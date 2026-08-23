package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.utils.EmailUtils;
import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "tb_password_recovery", indexes = {
    @Index(name = "ix_password_recovery_token_hash", columnList = "token_hash"),
    @Index(name = "ix_password_recovery_request_token_hash", columnList = "request_token_hash"),
    @Index(name = "ix_password_recovery_reset_session_hash", columnList = "reset_session_hash")
})
public class PasswordRecovery {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "token_hash", nullable = false, length = 64)
    private String tokenHash;

    @Column(name = "request_token_hash", nullable = false, length = 64)
    private String requestTokenHash;

    @Column(nullable = false)
    private Instant expiration;

    @Column(nullable = false)
    private String email;

    @Column(name = "failed_attempts", nullable = false)
    private int failedAttempts;

    @Column(name = "used_at")
    private Instant usedAt;

    @Column(name = "reset_session_hash", length = 64)
    private String resetSessionHash;

    @Column(name = "reset_session_expiration")
    private Instant resetSessionExpiration;

    @Column(name = "reset_session_used_at")
    private Instant resetSessionUsedAt;

    @Column(name = "updated_on")
    private LocalDateTime updatedOn;

    @Column(name = "created_on")
    private LocalDateTime createdOn;

    public  PasswordRecovery() {}

    public PasswordRecovery(String tokenHash, String requestTokenHash, String email, Instant expiration) {
        this.tokenHash = tokenHash;
        this.requestTokenHash = requestTokenHash;
        this.email = EmailUtils.normalize(email);
        this.expiration = expiration;
    }

    @PrePersist
    public void prePersist() {
        createdOn = LocalDateTime.now();
    }

    @PreUpdate
    public void preUpdate() {
        updatedOn = LocalDateTime.now();
    }

    public void setExpiration(Instant now) {
        this.expiration = now;
    }

    public String getEmail() {
        return this.email;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public String getRequestTokenHash() {
        return requestTokenHash;
    }

    public int getFailedAttempts() {
        return failedAttempts;
    }

    public Instant getExpiration() {
        return expiration;
    }

    public Instant getUsedAt() {
        return usedAt;
    }

    public String getResetSessionHash() {
        return resetSessionHash;
    }

    public Instant getResetSessionExpiration() {
        return resetSessionExpiration;
    }

    public Instant getResetSessionUsedAt() {
        return resetSessionUsedAt;
    }

    public void recordFailedAttempt(Instant now, int maxAttempts) {
        failedAttempts++;
        if (failedAttempts >= maxAttempts) {
            expiration = now;
        }
    }

    public void startResetSession(String resetSessionHash, Instant resetSessionExpiration, Instant now) {
        this.usedAt = now;
        this.expiration = now;
        this.resetSessionHash = resetSessionHash;
        this.resetSessionExpiration = resetSessionExpiration;
        this.resetSessionUsedAt = null;
    }

    public void consumeResetSession(Instant now) {
        this.resetSessionUsedAt = now;
        this.resetSessionExpiration = now;
    }
}

