package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UserRegistrationConfirmationEmail;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
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
public class UserRegistrationConfirmationTokenService {

    @Value("${security.email.registration-confirmation.token.minutes:5}")
    private Long tokenMinutes = 5L;

    private final UserRepository userRepository;
    private final UserRegistrationConfirmationRepository confirmationRepository;
    private final Clock clock;

    public UserRegistrationConfirmationTokenService(
        UserRepository userRepository,
        UserRegistrationConfirmationRepository confirmationRepository,
        Clock clock) {
        this.userRepository = userRepository;
        this.confirmationRepository = confirmationRepository;
        this.clock = clock;
    }

    @Transactional
    public Optional<UserRegistrationConfirmationEmail> createConfirmationToken(Long userId) {
        User user = userRepository.findByIdForUpdate(userId).orElse(null);
        if (Objects.isNull(user) || !user.isRegistrationConfirmationPending()) {
            return Optional.empty();
        }

        Instant now = Instant.now(clock);
        Instant expiration = now.plusSeconds(60 * tokenMinutes);
        user.requestEmailConfirmation(expiration);
        confirmationRepository.expireValidConfirmationsByUserId(user.getId(), now);

        String rawToken = UUID.randomUUID().toString();
        UserRegistrationConfirmation confirmation = new UserRegistrationConfirmation(
            TokenUtils.sha256(rawToken),
            user,
            expiration);
        confirmationRepository.save(confirmation);

        return Optional.of(new UserRegistrationConfirmationEmail(user.getEmail(), rawToken));
    }
}
