package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import com.jonataslaet.taskifyspace.controllers.dtos.CredentialsRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.EmailDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PasswordRecoveryCodeDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PasswordResetDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.PasswordResetSessionDTO;
import com.jonataslaet.taskifyspace.entities.PasswordRecovery;
import com.jonataslaet.taskifyspace.entities.RefreshToken;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.RateLimitExceededException;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import com.jonataslaet.taskifyspace.services.ratelimit.AuthRateLimiter;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
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
    private PasswordRecoveryRequestService passwordRecoveryRequestService;

    @Mock
    private AuthRateLimiter authRateLimiter;

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
            passwordRecoveryRequestService,
            validator,
            authRateLimiter);
    }

    @Test
    void loginRejectsNullCredentialsBeforeLoadingUser() {
        assertThatThrownBy(() -> authenticationService.login(null, "device", "agent", "127.0.0.1"))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(userRepository, never()).findByEmail(anyString());
        verify(passwordEncoder, never()).matches(anyString(), anyString());
        verify(refreshTokenService, never()).issue(any(User.class), anyString(), anyString(), anyString());
    }

    @Test
    void loginRejectsBlankCredentialsBeforeLoadingUser() {
        CredentialsRecordDTO credentials = new CredentialsRecordDTO(" ", "");

        assertThatThrownBy(() -> authenticationService.login(credentials, "device", "agent", "127.0.0.1"))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(userRepository, never()).findByEmail(anyString());
        verify(passwordEncoder, never()).matches(anyString(), anyString());
        verify(refreshTokenService, never()).issue(any(User.class), anyString(), anyString(), anyString());
    }

    @Test
    void loginNormalizesEmailBeforeLoadingUser() {
        CredentialsRecordDTO credentials = new CredentialsRecordDTO(" User@Example.COM ", "Strong1!");
        User user = createUser(UserStatusEnum.ACTIVE);

        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(credentials.password(), user.getPassword())).thenReturn(true);
        when(tokenConfiguration.createAccessToken(user)).thenReturn("access-token");
        when(refreshTokenService.issue(user, "device", "agent", "127.0.0.1")).thenReturn("refresh-token");

        authenticationService.login(credentials, "device", "agent", "127.0.0.1");

        verify(authRateLimiter).checkLogin("127.0.0.1", "user@example.com", "device");
        verify(authRateLimiter).recordLoginSuccess("127.0.0.1", "user@example.com", "device");
        verify(authRateLimiter, never()).recordLoginFailure(anyString(), anyString(), anyString());
        verify(userRepository).findByEmail("user@example.com");
    }

    @Test
    void loginDoesNotLoadUserWhenRateLimited() {
        CredentialsRecordDTO credentials = new CredentialsRecordDTO("user@example.com", "Strong1!");
        doThrow(new RateLimitExceededException("Too many attempts", 60))
            .when(authRateLimiter).checkLogin("127.0.0.1", "user@example.com", "device");

        assertThatThrownBy(() -> authenticationService.login(credentials, "device", "agent", "127.0.0.1"))
            .isInstanceOf(RateLimitExceededException.class);

        verify(userRepository, never()).findByEmail(anyString());
        verify(passwordEncoder, never()).matches(anyString(), anyString());
        verify(refreshTokenService, never()).issue(any(User.class), anyString(), anyString(), anyString());
    }

    @Test
    void loginRecordsFailureWhenCredentialsAreInvalid() {
        CredentialsRecordDTO credentials = new CredentialsRecordDTO(" User@Example.COM ", "Strong1!");
        when(userRepository.findByEmail("user@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authenticationService.login(credentials, "device", "agent", "127.0.0.1"))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(authRateLimiter).checkLogin("127.0.0.1", "user@example.com", "device");
        verify(authRateLimiter).recordLoginFailure("127.0.0.1", "user@example.com", "device");
        verify(authRateLimiter, never()).recordLoginSuccess(anyString(), anyString(), anyString());
    }

    @Test
    void refreshRejectsBlankRefreshTokenBeforeValidation() {
        assertThatThrownBy(() -> authenticationService.refresh(" ", "device", "agent", "127.0.0.1"))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(refreshTokenService, never()).validate(any());
    }

    @Test
    void logoutRejectsBlankRefreshTokenBeforeRevocation() {
        assertThatThrownBy(() -> authenticationService.logout(" "))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(refreshTokenService, never()).revoke(any());
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

        verify(passwordRecoveryService, never()).consumeResetSession(anyString());
    }

    @Test
    void resetPasswordRejectsWeakNewPasswordBeforeLoadingRecoveryToken() {
        PasswordResetDTO passwordResetDTO = new PasswordResetDTO("weakpass", "weakpass");

        assertThatThrownBy(() -> authenticationService.resetPassword("token", passwordResetDTO))
            .isInstanceOf(InvalidAuthenticationException.class);

        verify(passwordRecoveryService, never()).consumeResetSession(anyString());
    }

    @Test
    void resetPasswordRevokesRefreshTokensAfterPasswordChange() {
        User user = createUser(UserStatusEnum.ACTIVE);
        PasswordRecovery passwordRecovery = new PasswordRecovery(
            "token-hash",
            "request-token-hash",
            user.getEmail(),
            Instant.now().plusSeconds(300));
        ReflectionTestUtils.setField(passwordRecovery, "email", " User@Example.COM ");
        PasswordResetDTO passwordResetDTO = new PasswordResetDTO("Strong1!", "Strong1!");

        when(passwordRecoveryService.consumeResetSession("reset-session")).thenReturn(passwordRecovery);
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(passwordEncoder.encode(passwordResetDTO.newPassword())).thenReturn("encoded-new-password");

        authenticationService.resetPassword("reset-session", passwordResetDTO);

        verify(passwordRecoveryService).consumeResetSession("reset-session");
        verify(userRepository).save(user);
        verify(refreshTokenService).revokeAllByUserId(user.getId());
    }

    @Test
    void createPasswordResetSessionDelegatesCodeValidationToRecoveryService() {
        PasswordRecoveryCodeDTO codeDTO = new PasswordRecoveryCodeDTO("123456");
        when(passwordRecoveryService.createResetSession("request-token", "123456"))
            .thenReturn("reset-session");

        PasswordResetSessionDTO result = authenticationService.createPasswordResetSession("request-token", codeDTO);

        assertThat(result.token()).isEqualTo("reset-session");
        verify(passwordRecoveryService).createResetSession("request-token", "123456");
    }

    @Test
    void recoveryTokenRejectsBlankEmailBeforeQueueingRequest() {
        assertThatThrownBy(() -> authenticationService.recoveryToken(new EmailDTO(" ")))
            .isInstanceOf(InvalidRequestException.class);

        verify(passwordRecoveryRequestService, never()).requestRecoveryToken(anyString());
    }

    @Test
    void recoveryTokenQueuesRequestWithoutLoadingUserSynchronously() {
        String email = " User@Example.COM ";

        authenticationService.recoveryToken(new EmailDTO(email), "127.0.0.1", "device");

        verify(authRateLimiter).checkPasswordRecovery("127.0.0.1", "user@example.com", "device");
        verify(passwordRecoveryRequestService).requestRecoveryToken("user@example.com");
        verify(userRepository, never()).findByEmailForUpdate(anyString());
        verify(passwordRecoveryService, never()).expireValidPasswordRecoveriesByEmail(anyString(), any(Instant.class));
        verify(passwordRecoveryService, never()).savePasswordRecovery(any(PasswordRecovery.class));
    }

    @Test
    void recoveryTokenDoesNotQueueRequestWhenRateLimited() {
        EmailDTO emailDTO = new EmailDTO("user@example.com");
        doThrow(new RateLimitExceededException("Too many recovery requests", 300))
            .when(authRateLimiter).checkPasswordRecovery("127.0.0.1", "user@example.com", "device");

        assertThatThrownBy(() -> authenticationService.recoveryToken(emailDTO, "127.0.0.1", "device"))
            .isInstanceOf(RateLimitExceededException.class);

        verify(passwordRecoveryRequestService, never()).requestRecoveryToken(anyString());
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
