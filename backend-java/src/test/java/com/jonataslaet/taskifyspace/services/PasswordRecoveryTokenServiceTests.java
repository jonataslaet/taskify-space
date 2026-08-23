package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.PasswordRecoveryEmail;
import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
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
class PasswordRecoveryTokenServiceTests {

    private static final Instant NOW = Instant.parse("2026-07-23T12:00:00Z");

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordRecoveryService passwordRecoveryService;

    private PasswordRecoveryTokenService passwordRecoveryTokenService;

    @BeforeEach
    void setUp() {
        passwordRecoveryTokenService = new PasswordRecoveryTokenService(
            userRepository,
            passwordRecoveryService,
            Clock.fixed(NOW, ZoneOffset.UTC));
        ReflectionTestUtils.setField(passwordRecoveryTokenService, "tokenMinutes", 30L);
    }

    @Test
    void createRecoveryTokenReturnsEmptyForMissingEmail() {
        String email = " Missing@Example.COM ";
        when(userRepository.findByEmailForUpdate("missing@example.com")).thenReturn(Optional.empty());

        Optional<PasswordRecoveryEmail> result = passwordRecoveryTokenService.createRecoveryToken(email);

        assertThat(result).isEmpty();
        verify(userRepository).findByEmailForUpdate("missing@example.com");
        verify(passwordRecoveryService, never()).expireValidPasswordRecoveriesByEmail(any(), any());
        verify(passwordRecoveryService, never()).savePasswordRecovery(any());
    }

    @Test
    void createRecoveryTokenExpiresExistingTokensAndStoresHashedToken() {
        User user = createUser();
        when(userRepository.findByEmailForUpdate(user.getEmail())).thenReturn(Optional.of(user));

        Optional<PasswordRecoveryEmail> result =
            passwordRecoveryTokenService.createRecoveryToken(" User@Example.COM ");

        assertThat(result).isPresent();
        assertThat(result.get().address()).isEqualTo(user.getEmail());
        assertThat(result.get().code()).matches("\\d{6}");
        assertThat(result.get().requestToken()).isNotBlank();
        verify(passwordRecoveryService).expireValidPasswordRecoveriesByEmail(user.getEmail(), NOW);

        ArgumentCaptor<PasswordRecovery> passwordRecoveryCaptor = ArgumentCaptor.forClass(PasswordRecovery.class);
        verify(passwordRecoveryService).savePasswordRecovery(passwordRecoveryCaptor.capture());
        PasswordRecovery passwordRecovery = passwordRecoveryCaptor.getValue();

        assertThat(passwordRecovery.getEmail()).isEqualTo(user.getEmail());
        assertThat(passwordRecovery.getExpiration()).isEqualTo(NOW.plusSeconds(1800));
        assertThat(passwordRecovery.getTokenHash()).isEqualTo(TokenUtils.sha256(result.get().code()));
        assertThat(passwordRecovery.getRequestTokenHash()).isEqualTo(TokenUtils.sha256(result.get().requestToken()));
    }

    private User createUser() {
        User user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");
        user.setName("User");
        user.setPassword("encoded-password");
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        return user;
    }
}
