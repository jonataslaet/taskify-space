package com.jonataslaet.taskifyspace.filters;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.web.AuthenticationEntryPoint;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

@ExtendWith(MockitoExtension.class)
class AuthenticationFilterTests {

    @Mock
    private TokenConfiguration tokenConfiguration;

    @Mock
    private AuthenticationEntryPoint authenticationEntryPoint;

    @Mock
    private FilterChain filterChain;

    private AuthenticationFilter authenticationFilter;

    @BeforeEach
    void setUp() {
        authenticationFilter = new AuthenticationFilter(tokenConfiguration, authenticationEntryPoint);
    }

    @Test
    void delegatesBearerAuthenticationFailureToEntryPoint() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();
        BadCredentialsException exception = new BadCredentialsException("Token de acesso invalido");
        request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer invalid");

        doThrow(exception).when(tokenConfiguration).authenticate("Bearer invalid");

        authenticationFilter.doFilter(request, response, filterChain);

        verify(authenticationEntryPoint).commence(request, response, exception);
        verify(filterChain, never()).doFilter(any(ServletRequest.class), any(ServletResponse.class));
    }

    @Test
    void continuesFilterChainWhenAuthorizationHeaderIsNotBearer() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();
        request.addHeader(HttpHeaders.AUTHORIZATION, "Basic credentials");

        authenticationFilter.doFilter(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verifyNoInteractions(tokenConfiguration, authenticationEntryPoint);
    }
}
