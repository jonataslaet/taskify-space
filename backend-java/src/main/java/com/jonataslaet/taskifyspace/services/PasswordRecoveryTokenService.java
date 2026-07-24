package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Service
public class PasswordRecoveryTokenService {

    @Value("${security.email.password-recover.token.minutes}")
    private Long tokenMinutes;

    private final UserRepository userRepository;
    private final PasswordRecoveryService passwordRecoveryService;
    private final Clock clock;

    public PasswordRecoveryTokenService(
        UserRepository userRepository,
        PasswordRecoveryService passwordRecoveryService,
        Clock clock) {
        this.userRepository = userRepository;
        this.passwordRecoveryService = passwordRecoveryService;
        this.clock = clock;
    }

    @Transactional
    public Optional<PasswordRecoveryEmail> createRecoveryToken(String email) {
        User user = userRepository.findByEmailForUpdate(email).orElse(null);
        if (Objects.isNull(user)) {
            return Optional.empty();
        }

        Instant now = Instant.now(clock);
        passwordRecoveryService.expireValidPasswordRecoveriesByEmail(user.getEmail(), now);

        String rawToken = UUID.randomUUID().toString();
        PasswordRecovery passwordRecovery = new PasswordRecovery(
            TokenUtils.sha256(rawToken),
            user.getEmail(),
            now.plusSeconds(60 * tokenMinutes)
        );
        passwordRecoveryService.savePasswordRecovery(passwordRecovery);

        return Optional.of(new PasswordRecoveryEmail(user.getEmail(), rawToken));
    }
}
