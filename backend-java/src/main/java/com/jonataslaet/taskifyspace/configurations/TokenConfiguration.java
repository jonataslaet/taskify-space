package com.jonataslaet.taskifyspace.configurations;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.CustomUserDetailsService;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Date;
import java.util.List;
import java.util.Objects;

@Configuration
public class TokenConfiguration {

    @Value("${security.jwt.ttl.token.access}")
    private Long ttlAccessToken;

    @Value("${security.jwt.ttl.token.refresh}")
    private Long ttlRefreshToken;

    @Value("${security.jwt.secret}")
    private String secretKey;

    private final CustomUserDetailsService userService;
    private final Clock clock;

    public TokenConfiguration(CustomUserDetailsService userService, Clock clock) {
        this.userService = userService;
        this.clock = clock;
    }

    @PostConstruct
    protected void init() {
        secretKey = Base64.getEncoder().encodeToString(secretKey.getBytes());
    }

    public String createAccessToken(User user) {
        if (Objects.isNull(user.getStatus())) {
            throw new DisabledException("Usuario nao esta ativo");
        }
        Date now = new Date();
        Date limitDate = Date.from(Instant.now(clock).plusMillis(ttlAccessToken));
        List<String> authorities = new ArrayList<>();
        user.getAuthorities().forEach(role -> authorities.add(role.getAuthority()));
        return JWT.create()
            .withSubject(user.getUsername())
            .withIssuedAt(now)
            .withExpiresAt(limitDate)
            .withClaim("id", user.getId())
            .withClaim("email", user.getEmail())
            .withClaim("name", user.getName())
            .withClaim("status", user.getStatus().toString())
            .withClaim("authorities", authorities)
            .sign(Algorithm.HMAC256(secretKey));
    }

    public Authentication validateToken(String token) {
        if (token == null || token.isBlank()) {
            throw new BadCredentialsException("Token de acesso invalido");
        }

        Algorithm algorithm = Algorithm.HMAC256(secretKey);
        JWTVerifier jwtVerifier = JWT.require(algorithm).acceptLeeway(3).build();
        DecodedJWT decodedJWT;
        try {
            decodedJWT = jwtVerifier.verify(token);
        } catch (JWTVerificationException | IllegalArgumentException e) {
            throw new BadCredentialsException("Token de acesso invalido", e);
        }
        if (decodedJWT.getSubject() == null || decodedJWT.getSubject().isBlank()) {
            throw new BadCredentialsException("Token de acesso invalido");
        }

        UserDetails userDetails = userService.loadUserByUsername(decodedJWT.getSubject());
        if (!userDetails.isEnabled()) {
            throw new DisabledException("Usuario nao esta ativo");
        }
        return new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
    }

    private void setTokenAuthentication(String token) {
        SecurityContextHolder.getContext().setAuthentication(this.validateToken(token));
    }

    public void authenticate(String header) {
        setTokenAuthentication(extractBearerToken(header));
    }

    private String extractBearerToken(String header) {
        if (header == null || header.isBlank()) {
            throw new BadCredentialsException("Token de acesso invalido");
        }

        String[] authorizationParts = header.trim().split("\\s+");
        if (authorizationParts.length != 2
            || !"Bearer".equalsIgnoreCase(authorizationParts[0])
            || authorizationParts[1].isBlank()) {
            throw new BadCredentialsException("Token de acesso invalido");
        }

        return authorizationParts[1];
    }
}
