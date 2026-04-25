package com.jonataslaet.taskifyspace.filters;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

import static com.jonataslaet.taskifyspace.utils.TokenUtils.isValidBearerToken;


public class AuthenticationFilter extends OncePerRequestFilter {

    private final TokenConfiguration tokenConfiguration;

    public AuthenticationFilter(TokenConfiguration tokenConfiguration) {
        this.tokenConfiguration = tokenConfiguration;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
        throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (!isValidBearerToken(header)) {
            filterChain.doFilter(request, response);
            return;
        }
        try {
            tokenConfiguration.authenticate(header);
        } catch (RuntimeException e) {
            SecurityContextHolder.clearContext();
            throw e;
        }
        filterChain.doFilter(request, response);
    }

}