package com.jonataslaet.taskifyspace.configurations;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.services.CustomUserDetailsService;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
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
        Algorithm algorithm = Algorithm.HMAC256(secretKey);
        JWTVerifier jwtVerifier = JWT.require(algorithm).acceptLeeway(3).build();
        DecodedJWT decodedJWT = jwtVerifier.verify(token);
        UserDetails userDetails = userService.loadUserByUsername(decodedJWT.getSubject());
        if (!userDetails.isEnabled()) {
            throw new InvalidAuthenticationException("Usuario nao esta ativo");
        }
        return new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
    }

    private void setTokenAuthentication(String[] fulltoken) {
        SecurityContextHolder.getContext().setAuthentication(this.validateToken(fulltoken[1]));
    }

    public void authenticate(String header) {
        String[] fulltoken = header.split(" ");
        setTokenAuthentication(fulltoken);
    }
}
