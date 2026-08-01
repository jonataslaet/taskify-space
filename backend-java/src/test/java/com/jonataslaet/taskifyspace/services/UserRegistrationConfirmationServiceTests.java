package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.RegistrationConfirmationException;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository.ConfirmationReference;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

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
    void confirmRegistrationActivatesPendingUserAndConsumesTokenAfterLockingUserFirst() {
        String rawToken = "raw-token";
        String tokenHash = TokenUtils.sha256(rawToken);
        User user = createUser(UserStatusEnum.PENDING_EVALUATION);
        user.requestEmailConfirmation(NOW.plusSeconds(60));
        UserRegistrationConfirmation confirmation = confirmation(tokenHash, user, NOW.plusSeconds(60));
        when(confirmationRepository.findUnusedConfirmationReferencesByTokenHash(tokenHash))
            .thenReturn(List.of(reference(10L, user.getId())));
        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(confirmationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(confirmation));

        confirmationService.confirmRegistration(rawToken);

        assertThat(user.getEmailConfirmedAt()).isEqualTo(NOW);
        assertThat(user.getRegistrationConfirmationExpiresAt()).isNull();
        assertThat(confirmation.getUsedAt()).isEqualTo(NOW);
        assertThat(confirmation.getExpiration()).isEqualTo(NOW);
        verify(userService).changeStatus(user.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.ACTIVE));
        verify(confirmationRepository).save(confirmation);

        InOrder inOrder = inOrder(userService, confirmationRepository);
        inOrder.verify(confirmationRepository).findUnusedConfirmationReferencesByTokenHash(tokenHash);
        inOrder.verify(userService).findUserByIdForUpdate(user.getId());
        inOrder.verify(confirmationRepository).findByIdForUpdate(10L);
    }

    @Test
    void confirmRegistrationConsumesTokenWhenUserIsAlreadyActive() {
        String rawToken = "raw-token";
        String tokenHash = TokenUtils.sha256(rawToken);
        User user = createUser(UserStatusEnum.ACTIVE);
        UserRegistrationConfirmation confirmation = confirmation(tokenHash, user, NOW.minusSeconds(60));
        when(confirmationRepository.findUnusedConfirmationReferencesByTokenHash(tokenHash))
            .thenReturn(List.of(reference(10L, user.getId())));
        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(confirmationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(confirmation));

        confirmationService.confirmRegistration(rawToken);

        assertThat(user.getEmailConfirmedAt()).isEqualTo(NOW);
        assertThat(confirmation.getUsedAt()).isEqualTo(NOW);
        verify(userService, never()).changeStatus(any(), any());
        verify(confirmationRepository).save(confirmation);
    }

    @Test
    void confirmRegistrationRejectsInvalidToken() {
        String rawToken = "raw-token";
        when(confirmationRepository.findUnusedConfirmationReferencesByTokenHash(TokenUtils.sha256(rawToken)))
            .thenReturn(List.of());

        assertThatThrownBy(() -> confirmationService.confirmRegistration(rawToken))
            .isInstanceOfSatisfying(RegistrationConfirmationException.class, exception -> {
                assertThat(exception.getStatus().value()).isEqualTo(400);
                assertThat(exception.getCode()).isEqualTo("REGISTRATION_CONFIRMATION_TOKEN_INVALID");
            });

        verify(userService, never()).findUserByIdForUpdate(any());
        verify(userService, never()).changeStatus(any(), any());
        verify(confirmationRepository, never()).save(any());
    }

    @Test
    void confirmRegistrationDeletesPendingUserWhenTokenAndRegistrationAreExpired() {
        String rawToken = "raw-token";
        String tokenHash = TokenUtils.sha256(rawToken);
        User user = createUser(UserStatusEnum.PENDING_EVALUATION);
        user.requestEmailConfirmation(NOW);
        UserRegistrationConfirmation confirmation = confirmation(tokenHash, user, NOW);
        when(confirmationRepository.findUnusedConfirmationReferencesByTokenHash(tokenHash))
            .thenReturn(List.of(reference(10L, user.getId())));
        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(confirmationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(confirmation));
        when(userService.deleteExpiredPendingRegistrationUser(user.getId(), NOW)).thenReturn(true);

        assertThatThrownBy(() -> confirmationService.confirmRegistration(rawToken))
            .isInstanceOfSatisfying(RegistrationConfirmationException.class, exception -> {
                assertThat(exception.getStatus().value()).isEqualTo(410);
                assertThat(exception.getCode()).isEqualTo("REGISTRATION_CONFIRMATION_EXPIRED_USER_DELETED");
            });

        verify(userService).deleteExpiredPendingRegistrationUser(user.getId(), NOW);
        verify(userService, never()).changeStatus(any(), any());
        verify(confirmationRepository, never()).save(any());
    }

    @Test
    void confirmRegistrationDoesNotDeletePendingUserWhenAnotherConfirmationExtendedRegistration() {
        String rawToken = "raw-token";
        String tokenHash = TokenUtils.sha256(rawToken);
        User user = createUser(UserStatusEnum.PENDING_EVALUATION);
        user.requestEmailConfirmation(NOW.plusSeconds(60));
        UserRegistrationConfirmation confirmation = confirmation(tokenHash, user, NOW);
        when(confirmationRepository.findUnusedConfirmationReferencesByTokenHash(tokenHash))
            .thenReturn(List.of(reference(10L, user.getId())));
        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(confirmationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(confirmation));
        when(userService.deleteExpiredPendingRegistrationUser(user.getId(), NOW)).thenReturn(false);

        assertThatThrownBy(() -> confirmationService.confirmRegistration(rawToken))
            .isInstanceOfSatisfying(RegistrationConfirmationException.class, exception -> {
                assertThat(exception.getStatus().value()).isEqualTo(410);
                assertThat(exception.getCode()).isEqualTo("REGISTRATION_CONFIRMATION_TOKEN_EXPIRED");
            });

        verify(userService).deleteExpiredPendingRegistrationUser(user.getId(), NOW);
        verify(userService, never()).changeStatus(any(), any());
        verify(confirmationRepository, never()).save(any());
    }

    @Test
    void confirmRegistrationRejectsUserThatIsNotPendingOrActive() {
        String rawToken = "raw-token";
        String tokenHash = TokenUtils.sha256(rawToken);
        User user = createUser(UserStatusEnum.SUSPENDED);
        UserRegistrationConfirmation confirmation = confirmation(tokenHash, user, NOW.plusSeconds(60));
        when(confirmationRepository.findUnusedConfirmationReferencesByTokenHash(tokenHash))
            .thenReturn(List.of(reference(10L, user.getId())));
        when(userService.findUserByIdForUpdate(user.getId())).thenReturn(user);
        when(confirmationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(confirmation));

        assertThatThrownBy(() -> confirmationService.confirmRegistration(rawToken))
            .isInstanceOf(InvalidRequestException.class);

        verify(userService, never()).changeStatus(any(), any());
        verify(confirmationRepository, never()).save(any());
    }

    private UserRegistrationConfirmation confirmation(String tokenHash, User user, Instant expiration) {
        UserRegistrationConfirmation confirmation = new UserRegistrationConfirmation(tokenHash, user, expiration);
        confirmation.setId(10L);
        return confirmation;
    }

    private ConfirmationReference reference(Long id, Long userId) {
        return new ConfirmationReference() {
            @Override
            public Long getId() {
                return id;
            }

            @Override
            public Long getUserId() {
                return userId;
            }
        };
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
