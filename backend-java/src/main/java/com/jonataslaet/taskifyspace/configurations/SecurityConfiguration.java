package com.jonataslaet.taskifyspace.configurations;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jonataslaet.taskifyspace.controllers.dtos.StandardErrorRecordDTO;
import com.jonataslaet.taskifyspace.filters.AuthenticationFilter;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.authentication.www.BasicAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

import java.time.Instant;

@Configuration
@EnableMethodSecurity
public class SecurityConfiguration {
    private static final Logger logger = LoggerFactory.getLogger(SecurityConfiguration.class);

    private final TokenConfiguration tokenConfiguration;
    private final CorsConfigurationSource corsConfigurationSource;
    private final ObjectMapper mapper;
    public static final String[] GET_PUBLIC = {"/public/**", "/privacy-policy"};
    public static final String[] POST_PUBLIC = {
        "/auth/login", "/auth/refresh", "/auth/recovery-token", "/auth/new-password/*", "/users"
    };
    public static final String[] ALL_PUBLIC = {"/actuator/health"};

    public SecurityConfiguration(TokenConfiguration tokenConfiguration, CorsConfigurationSource corsConfigurationSource,
                                 ObjectMapper mapper) {
        this.tokenConfiguration = tokenConfiguration;
        this.corsConfigurationSource = corsConfigurationSource;
        this.mapper = mapper;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.cors(cors -> cors.configurationSource(corsConfigurationSource)).csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(customize ->
                customize.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(ALL_PUBLIC).permitAll()
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers(HttpMethod.GET, GET_PUBLIC).permitAll()
                .requestMatchers(HttpMethod.POST, POST_PUBLIC).permitAll()
                .anyRequest().authenticated())
            .exceptionHandling(ex -> ex
                .accessDeniedHandler(customAccessDeniedHandler())
                .authenticationEntryPoint(customAuthenticationEntryPoint())
            )
            .addFilterBefore(
                new AuthenticationFilter(tokenConfiguration, customAuthenticationEntryPoint()),
                BasicAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AccessDeniedHandler customAccessDeniedHandler() {
        return (request, response, ex) -> {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json;charset=UTF-8");
            logger.warn("Logando erro de permissão");
            StandardErrorRecordDTO err = new StandardErrorRecordDTO();
            err.setTimestamp(Instant.now());
            err.setStatus(HttpStatus.FORBIDDEN.value());
            err.setError("Erro de permissão");
            err.setMessage(ex.getMessage());
            err.setPath(request.getRequestURI());

            response.getWriter().write(mapper.writeValueAsString(err));
        };
    }

    @Bean
    public AuthenticationEntryPoint customAuthenticationEntryPoint() {
        return (request, response, ex) -> {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json;charset=UTF-8");
            StandardErrorRecordDTO err = new StandardErrorRecordDTO();
            err.setTimestamp(Instant.now());
            err.setStatus(HttpStatus.UNAUTHORIZED.value());
            err.setError("Erro de autenticacao");
            String message = resolveAuthenticationMessage(ex);
            err.setMessage(message);
            err.setPath(request.getRequestURI());
            logger.warn("Logando erro de autorizacao: {}", message);
            response.getWriter().write(mapper.writeValueAsString(err));
        };
    }

    private String resolveAuthenticationMessage(AuthenticationException ex) {
        if (ex.getMessage() != null && !ex.getMessage().isBlank()) {
            return ex.getMessage();
        }

        Throwable cause = ex.getCause();
        if (cause != null && cause.getMessage() != null && !cause.getMessage().isBlank()) {
            return cause.getMessage();
        }

        return "Nao autenticado";
    }
}
