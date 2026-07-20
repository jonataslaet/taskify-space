package com.jonataslaet.taskifyspace.configurations;

import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.services.CustomUserDetailsService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TokenConfigurationTests {

    @Mock
    private CustomUserDetailsService userService;

    private TokenConfiguration tokenConfiguration;

    @BeforeEach
    void setUp() {
        tokenConfiguration = new TokenConfiguration(userService, Clock.systemUTC());
        ReflectionTestUtils.setField(tokenConfiguration, "secretKey", "test-secret");
        ReflectionTestUtils.setField(tokenConfiguration, "ttlAccessToken", 900000L);
        tokenConfiguration.init();
    }

    @Test
    void validateTokenRejectsInactiveUser() {
        User user = createUser(UserStatusEnum.SUSPENDED);
        String token = tokenConfiguration.createAccessToken(user);

        when(userService.loadUserByUsername(user.getEmail())).thenReturn(user);

        assertThatThrownBy(() -> tokenConfiguration.validateToken(token))
            .isInstanceOf(InvalidAuthenticationException.class);
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
