package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

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
    private UserRepository userRepository;

    @Mock
    private UserService userService;

    private UserRegistrationConfirmationCleanupService cleanupService;

    @BeforeEach
    void setUp() {
        cleanupService = new UserRegistrationConfirmationCleanupService(
            userRepository,
            userService,
            Clock.fixed(NOW, ZoneOffset.UTC));
        ReflectionTestUtils.setField(cleanupService, "batchSize", 50);
    }

    @Test
    void deleteExpiredPendingRegistrationUsersDeletesUsersFoundByRepository() {
        when(userRepository.findExpiredUnconfirmedRegistrationUserIdsForUpdate(
            NOW, UserStatusEnum.PENDING_EVALUATION.name(), 50))
            .thenReturn(List.of(1L, 2L));
        when(userService.deleteExpiredPendingRegistrationUser(1L, NOW)).thenReturn(true);
        when(userService.deleteExpiredPendingRegistrationUser(2L, NOW)).thenReturn(false);

        int deletedUsers = cleanupService.deleteExpiredPendingRegistrationUsers(NOW);

        assertThat(deletedUsers).isEqualTo(1);
        verify(userService).deleteExpiredPendingRegistrationUser(1L, NOW);
        verify(userService).deleteExpiredPendingRegistrationUser(2L, NOW);
    }
}
