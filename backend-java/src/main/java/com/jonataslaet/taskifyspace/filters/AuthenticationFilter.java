package com.jonataslaet.taskifyspace.filters;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

import static com.jonataslaet.taskifyspace.utils.TokenUtils.isBearerAuthorizationHeader;


public class AuthenticationFilter extends OncePerRequestFilter {

    private final TokenConfiguration tokenConfiguration;
    private final AuthenticationEntryPoint authenticationEntryPoint;

    public AuthenticationFilter(TokenConfiguration tokenConfiguration, AuthenticationEntryPoint authenticationEntryPoint) {
        this.tokenConfiguration = tokenConfiguration;
        this.authenticationEntryPoint = authenticationEntryPoint;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
        throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (!isBearerAuthorizationHeader(header)) {
            filterChain.doFilter(request, response);
            return;
        }
        try {
            tokenConfiguration.authenticate(header);
        } catch (AuthenticationException e) {
            SecurityContextHolder.clearContext();
            authenticationEntryPoint.commence(request, response, e);
            return;
        }
        filterChain.doFilter(request, response);
    }

}
