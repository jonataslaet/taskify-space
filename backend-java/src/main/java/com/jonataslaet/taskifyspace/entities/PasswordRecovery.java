package com.jonataslaet.taskifyspace.entities;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "tb_password_recovery")
public class PasswordRecovery {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String token;

    @Column(nullable = false)
    private Instant expiration;

    @Column(nullable = false)
    private String email;

    @Column(name = "updated_on")
    private LocalDateTime updatedOn;

    @Column(name = "created_on")
    private LocalDateTime createdOn;

    public  PasswordRecovery() {}

    public PasswordRecovery(String token, String email, Instant expiration) {
        this.token = token;
        this.email = email;
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

