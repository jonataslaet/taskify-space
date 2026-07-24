package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.utils.EmailUtils;
import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "tb_password_recovery")
public class PasswordRecovery {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "token_hash", nullable = false, length = 64)
    private String tokenHash;

    @Column(nullable = false)
    private Instant expiration;

    @Column(nullable = false)
    private String email;

    @Column(name = "updated_on")
    private LocalDateTime updatedOn;

    @Column(name = "created_on")
    private LocalDateTime createdOn;

    public  PasswordRecovery() {}

    public PasswordRecovery(String tokenHash, String email, Instant expiration) {
        this.tokenHash = tokenHash;
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
}

