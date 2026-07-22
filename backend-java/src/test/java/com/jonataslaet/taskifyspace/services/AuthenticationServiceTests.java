package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import com.jonataslaet.taskifyspace.controllers.dtos.EmailDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PasswordResetDTO;
import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.entities.RefreshToken;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthenticationServiceTests {

    @Mock
    private RefreshTokenService refreshTokenService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private TokenConfiguration tokenConfiguration;

    @Mock
    private PasswordRecoveryService passwordRecoveryService;

    @Mock
    private EmailService emailService;

    private Validator validator;

    private AuthenticationService authenticationService;

    @BeforeEach
    void setUp() {
        validator = Validation.buildDefaultValidatorFactory().getValidator();
        authenticationService = new AuthenticationService(
            refreshTokenService,
            userRepository,
            passwordEncoder,
            tokenConfiguration,
            passwordRecoveryService,
            emailService,
            validator);
        ReflectionTestUtils.setField(authenticationService, "tokenMinutes", 30L);
        ReflectionTestUtils.setField(authenticationService, "passwordRecoveryUri", "http://localhost/new-password/");
    }

    @Test
    void refreshRejectsInactiveUserAndDoesNotRotateRefreshToken() {
        String refreshToken = "refresh-token";
        User user = createUser(UserStatusEnum.SUSPENDED);
        RefreshToken current = new RefreshToken();
        current.setUser(user);

        when(refreshTokenService.validate(refreshToken)).thenReturn(current);
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));

        assertThatThrownBy(() -> authenticationService.refresh(refreshToken, "device", "agent", "127.0.0.1"))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(tokenConfiguration, never()).createAccessToken(any(User.class));
        verify(refreshTokenService, never()).rotate(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void resetPasswordRejectsNullNewPasswordBeforeLoadingRecoveryToken() {
        PasswordResetDTO passwordResetDTO = new PasswordResetDTO(null, "Strong1!");

        assertThatThrownBy(() -> authenticationService.resetPassword("token", passwordResetDTO))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(passwordRecoveryService, never()).getValidPasswordRecoveries(anyString(), any(Instant.class));
    }

    @Test
    void resetPasswordRejectsWeakNewPasswordBeforeLoadingRecoveryToken() {
        PasswordResetDTO passwordResetDTO = new PasswordResetDTO("weakpass", "weakpass");

        assertThatThrownBy(() -> authenticationService.resetPassword("token", passwordResetDTO))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(passwordRecoveryService, never()).getValidPasswordRecoveries(anyString(), any(Instant.class));
    }

    @Test
    void recoveryTokenDoesNotRevealMissingEmail() {
        String email = "missing@example.com";
        when(userRepository.findByEmail(email)).thenReturn(Optional.empty());

        authenticationService.recoveryToken(new EmailDTO(email));

        verify(passwordRecoveryService, never()).savePasswordRecovery(any(PasswordRecovery.class));
        verify(emailService, never()).sendEmail(any());
    }

    @Test
    void recoveryTokenCreatesRecoveryAndSendsEmailForExistingUser() {
        User user = createUser(UserStatusEnum.ACTIVE);
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));

        authenticationService.recoveryToken(new EmailDTO(user.getEmail()));

        verify(passwordRecoveryService).savePasswordRecovery(any(PasswordRecovery.class));
        verify(emailService).sendEmail(any());
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
