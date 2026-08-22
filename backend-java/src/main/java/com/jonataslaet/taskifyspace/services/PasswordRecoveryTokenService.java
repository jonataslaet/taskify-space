package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.PasswordRecoveryEmail;
import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import com.jonataslaet.taskifyspace.utils.EmailUtils;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;

@Service
public class PasswordRecoveryTokenService {

    private static final int TOKEN_DIGITS = 6;
    private static final int MAX_TOKEN_GENERATION_ATTEMPTS = 10;

    @Value("${security.email.password-recover.token.minutes:10}")
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
        String normalizedEmail = EmailUtils.normalize(email);
        User user = userRepository.findByEmailForUpdate(normalizedEmail).orElse(null);
        if (Objects.isNull(user)) {
            return Optional.empty();
        }

        Instant now = Instant.now(clock);
        passwordRecoveryService.expireValidPasswordRecoveriesByEmail(user.getEmail(), now);

        String rawToken = generateUniqueRecoveryToken(now);
        PasswordRecovery passwordRecovery = new PasswordRecovery(TokenUtils.sha256(rawToken),
            user.getEmail(), now.plusSeconds(60 * tokenMinutes)
        );
        passwordRecoveryService.savePasswordRecovery(passwordRecovery);

        return Optional.of(new PasswordRecoveryEmail(user.getEmail(), rawToken));
    }

    private String generateUniqueRecoveryToken(Instant now) {
        for (int attempt = 0; attempt < MAX_TOKEN_GENERATION_ATTEMPTS; attempt++) {
            String rawToken = TokenUtils.generateNumericToken(TOKEN_DIGITS);
            if (!passwordRecoveryService.hasValidPasswordRecovery(rawToken, now)) {
                return rawToken;
            }
        }

        throw new IllegalStateException("Unable to generate a unique password recovery token");
    }
}
