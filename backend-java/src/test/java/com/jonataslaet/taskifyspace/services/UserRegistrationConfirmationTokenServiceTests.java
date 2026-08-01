package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UserRegistrationConfirmationEmail;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserRegistrationConfirmationTokenServiceTests {

    private static final Instant NOW = Instant.parse("2026-08-01T12:00:00Z");

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserRegistrationConfirmationRepository confirmationRepository;

    private UserRegistrationConfirmationTokenService tokenService;

    @BeforeEach
    void setUp() {
        tokenService = new UserRegistrationConfirmationTokenService(
            userRepository,
            confirmationRepository,
            Clock.fixed(NOW, ZoneOffset.UTC));
        ReflectionTestUtils.setField(tokenService, "tokenMinutes", 5L);
    }

    @Test
    void createConfirmationTokenStoresHashedTokenForPendingUser() {
        User user = createUser(UserStatusEnum.PENDING_EVALUATION);
        when(userRepository.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));

        Optional<UserRegistrationConfirmationEmail> result = tokenService.createConfirmationToken(user.getId());

        assertThat(result).isPresent();
        assertThat(result.get().address()).isEqualTo(user.getEmail());
        assertThat(result.get().token()).isNotBlank();
        verify(confirmationRepository).expireValidConfirmationsByUserId(user.getId(), NOW);

        ArgumentCaptor<UserRegistrationConfirmation> confirmationCaptor =
            ArgumentCaptor.forClass(UserRegistrationConfirmation.class);
        verify(confirmationRepository).save(confirmationCaptor.capture());
        UserRegistrationConfirmation confirmation = confirmationCaptor.getValue();

        assertThat(confirmation.getUser()).isSameAs(user);
        assertThat(confirmation.getExpiration()).isEqualTo(NOW.plusSeconds(300));
        assertThat(confirmation.getTokenHash()).isEqualTo(TokenUtils.sha256(result.get().token()));
    }

    @Test
    void createConfirmationTokenReturnsEmptyWhenUserIsNotPending() {
        User user = createUser(UserStatusEnum.ACTIVE);
        when(userRepository.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));

        Optional<UserRegistrationConfirmationEmail> result = tokenService.createConfirmationToken(user.getId());

        assertThat(result).isEmpty();
        verify(confirmationRepository, never()).expireValidConfirmationsByUserId(any(), any());
        verify(confirmationRepository, never()).save(any());
    }

    private User createUser(UserStatusEnum status) {
        User user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");
        user.setName("User");
        user.setPassword("encoded-password");
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(status);
        return user;
    }
}
