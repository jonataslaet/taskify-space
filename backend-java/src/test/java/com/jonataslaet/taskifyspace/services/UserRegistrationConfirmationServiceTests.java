package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.TokenExpirationException;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

@ExtendWith(MockitoExtension.class)
class UserRegistrationConfirmationServiceTests {

    private static final Instant NOW = Instant.parse("2026-08-01T12:00:00Z");

    @Mock
    private UserRegistrationConfirmationRepository confirmationRepository;

    @Mock
    private UserService userService;

    private UserRegistrationConfirmationService confirmationService;

    @BeforeEach
    void setUp() {
        confirmationService = new UserRegistrationConfirmationService(
            confirmationRepository,
            userService,
            Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void confirmRegistrationActivatesPendingUserAndConsumesToken() {
        String rawToken = "raw-token";
        User user = createUser(UserStatusEnum.PENDING_EVALUATION);
        UserRegistrationConfirmation confirmation = new UserRegistrationConfirmation(
            TokenUtils.sha256(rawToken), user, NOW.plusSeconds(60));
        when(confirmationRepository.findValidConfirmationsForUpdate(TokenUtils.sha256(rawToken), NOW))
            .thenReturn(List.of(confirmation));

        confirmationService.confirmRegistration(rawToken);

        assertThat(confirmation.getUsedAt()).isEqualTo(NOW);
        assertThat(confirmation.getExpiration()).isEqualTo(NOW);
        verify(userService).changeStatus(user.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.ACTIVE));
        verify(confirmationRepository).save(confirmation);
    }

    @Test
    void confirmRegistrationConsumesTokenWhenUserIsAlreadyActive() {
        String rawToken = "raw-token";
        User user = createUser(UserStatusEnum.ACTIVE);
        UserRegistrationConfirmation confirmation = new UserRegistrationConfirmation(
            TokenUtils.sha256(rawToken), user, NOW.plusSeconds(60));
        when(confirmationRepository.findValidConfirmationsForUpdate(TokenUtils.sha256(rawToken), NOW))
            .thenReturn(List.of(confirmation));

        confirmationService.confirmRegistration(rawToken);

        assertThat(confirmation.getUsedAt()).isEqualTo(NOW);
        verify(userService, never()).changeStatus(any(), any());
        verify(confirmationRepository).save(confirmation);
    }

    @Test
    void confirmRegistrationRejectsInvalidOrExpiredToken() {
        String rawToken = "raw-token";
        when(confirmationRepository.findValidConfirmationsForUpdate(TokenUtils.sha256(rawToken), NOW))
            .thenReturn(List.of());

        assertThatThrownBy(() -> confirmationService.confirmRegistration(rawToken))
            .isInstanceOf(TokenExpirationException.class);

        verify(userService, never()).changeStatus(any(), any());
        verify(confirmationRepository, never()).save(any());
    }

    @Test
    void confirmRegistrationRejectsUserThatIsNotPendingOrActive() {
        String rawToken = "raw-token";
        User user = createUser(UserStatusEnum.SUSPENDED);
        UserRegistrationConfirmation confirmation = new UserRegistrationConfirmation(
            TokenUtils.sha256(rawToken), user, NOW.plusSeconds(60));
        when(confirmationRepository.findValidConfirmationsForUpdate(TokenUtils.sha256(rawToken), NOW))
            .thenReturn(List.of(confirmation));

        assertThatThrownBy(() -> confirmationService.confirmRegistration(rawToken))
            .isInstanceOf(InvalidRequestException.class);

        verify(userService, never()).changeStatus(any(), any());
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
