package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
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
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserRegistrationConfirmationCleanupServiceTests {

    private static final Instant NOW = Instant.parse("2026-08-01T12:05:00Z");

    @Mock
    private UserRegistrationConfirmationRepository confirmationRepository;

    @Mock
    private UserService userService;

    private UserRegistrationConfirmationCleanupService cleanupService;

    @BeforeEach
    void setUp() {
        cleanupService = new UserRegistrationConfirmationCleanupService(
            confirmationRepository,
            userService,
            Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void deleteExpiredPendingRegistrationUsersDeletesUsersFoundByRepository() {
        when(confirmationRepository.findPendingUserIdsWithExpiredConfirmationAndNoValidConfirmation(
            NOW, UserStatusEnum.PENDING_EVALUATION))
            .thenReturn(List.of(1L, 2L));
        when(userService.deletePendingRegistrationUser(1L)).thenReturn(true);
        when(userService.deletePendingRegistrationUser(2L)).thenReturn(false);

        int deletedUsers = cleanupService.deleteExpiredPendingRegistrationUsers(NOW);

        assertThat(deletedUsers).isEqualTo(1);
        verify(userService).deletePendingRegistrationUser(1L);
        verify(userService).deletePendingRegistrationUser(2L);
    }
}
