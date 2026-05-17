package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.configurations.TokenConfiguration;
import com.jonataslaet.taskifyspace.controllers.dtos.AuthenticationResponseRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.CredentialsRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.InvalidAuthenticationException;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;

@Service
public class AuthenticationService {

    private final RefreshTokenService refreshTokenService;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenConfiguration tokenConfiguration;

    public AuthenticationService(RefreshTokenService refreshTokenService, UserRepository userRepository,
                                 PasswordEncoder passwordEncoder, TokenConfiguration tokenConfiguration) {
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenConfiguration = tokenConfiguration;
    }

    @Transactional
    public AuthenticationResponseRecordDTO login(
        CredentialsRecordDTO credentialsRecordDTO, String deviceId, String userAgent, String ipAddress) {

        User user = userRepository.findByEmail(credentialsRecordDTO.username()).orElse(null);
        if (Objects.nonNull(user) && isMatchedPassword(credentialsRecordDTO, user.getPassword()) && user.isEnabled()) {
            String accessToken = tokenConfiguration.createAccessToken(user);
            String refreshToken = refreshTokenService.issue(user, deviceId, userAgent, ipAddress);

            return new AuthenticationResponseRecordDTO(user.getId(), user.getEmail(), user.getName(),
                accessToken, refreshToken, user.getRole());
        }
        throw new InvalidAuthenticationException(
            "Email ou senha estão inválidos ou este usuário está pendente de avaliação");
    }

    @Transactional
    public AuthenticationResponseRecordDTO refresh(
        String refreshToken, String deviceId, String userAgent, String ipAddress) {

        var current = refreshTokenService.validate(refreshToken);
        User user = userRepository.findByEmail(current.getUser().getUsername())
            .orElseThrow(() -> new InvalidAuthenticationException("Usuário não encontrado"));

        String newToken = tokenConfiguration.createAccessToken(user);
        String newRefreshToken = refreshTokenService.rotate(refreshToken, deviceId, userAgent, ipAddress);

        return new AuthenticationResponseRecordDTO(
            user.getId(),
            user.getEmail(),
            user.getName(),
            newToken,
            newRefreshToken,
            user.getRole()
        );
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokenService.revoke(rawRefreshToken);
    }

    private boolean isMatchedPassword(CredentialsRecordDTO credentialsRecordDTO, String encodedPassword) {
        return passwordEncoder.matches(credentialsRecordDTO.password(), encodedPassword);
    }

}
