package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import com.jonataslaet.taskifyspace.entities.RefreshToken;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

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

    private AuthenticationService authenticationService;

    @BeforeEach
    void setUp() {
        authenticationService = new AuthenticationService(
            refreshTokenService,
            userRepository,
            passwordEncoder,
            tokenConfiguration,
            passwordRecoveryService,
            emailService);
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
