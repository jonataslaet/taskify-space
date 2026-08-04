package com.jonataslaet.taskifyspace.filters;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;

import static com.jonataslaet.taskifyspace.utils.TokenUtils.isBearerAuthorizationHeader;


public class AuthenticationFilter extends OncePerRequestFilter {

    private final TokenConfiguration tokenConfiguration;
    private final AuthenticationEntryPoint authenticationEntryPoint;
    private final String[] getPublicRoutes;
    private final String[] postPublicRoutes;

    public AuthenticationFilter(TokenConfiguration tokenConfiguration, AuthenticationEntryPoint authenticationEntryPoint) {
        this(tokenConfiguration, authenticationEntryPoint, new String[0], new String[0]);
    }

    public AuthenticationFilter(
        TokenConfiguration tokenConfiguration,
        AuthenticationEntryPoint authenticationEntryPoint,
        String[] getPublicRoutes,
        String[] postPublicRoutes) {
        this.tokenConfiguration = tokenConfiguration;
        this.authenticationEntryPoint = authenticationEntryPoint;
        this.getPublicRoutes = Arrays.copyOf(getPublicRoutes, getPublicRoutes.length);
        this.postPublicRoutes = Arrays.copyOf(postPublicRoutes, postPublicRoutes.length);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = requestPathWithoutContext(request);
        String method = request.getMethod();

        if (HttpMethod.OPTIONS.matches(method)) {
            return true;
        }
        if (HttpMethod.GET.matches(method)) {
            return matchesAny(getPublicRoutes, path);
        }
        if (HttpMethod.POST.matches(method)) {
            return matchesAny(postPublicRoutes, path);
        }
        return false;
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

    private boolean matchesAny(String[] patterns, String path) {
        return Arrays.stream(patterns).anyMatch(pattern -> matches(pattern, path));
    }

    private boolean matches(String pattern, String path) {
        if (pattern.endsWith("/**")) {
            String prefix = pattern.substring(0, pattern.length() - 3);
            return path.equals(prefix) || path.startsWith(prefix + "/");
        }

        if (pattern.endsWith("/*")) {
            String prefix = pattern.substring(0, pattern.length() - 2);
            if (!path.startsWith(prefix + "/")) {
                return false;
            }
            return path.indexOf('/', prefix.length() + 1) == -1;
        }

        return path.equals(pattern);
    }

    private String requestPathWithoutContext(HttpServletRequest request) {
        String requestUri = request.getRequestURI();
        String contextPath = request.getContextPath();
        if (contextPath != null && !contextPath.isBlank() && requestUri.startsWith(contextPath)) {
            return requestUri.substring(contextPath.length());
        }
        return requestUri;
    }

}
