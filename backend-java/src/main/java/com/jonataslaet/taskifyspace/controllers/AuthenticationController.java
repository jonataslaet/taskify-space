package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.*;
import com.jonataslaet.taskifyspace.services.AuthenticationService;
import jakarta.validation.Valid;
import org.jspecify.annotations.NonNull;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthenticationController {

    private final AuthenticationService authenticationService;

    public AuthenticationController(AuthenticationService authenticationService) {
        this.authenticationService = authenticationService;
    }

    @PostMapping("/login")
    public ResponseEntity<@NonNull AuthenticationResponseRecordDTO> login(
        @RequestBody @Valid CredentialsRecordDTO credentialsRecordDTO,
        @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
        @RequestHeader(value = "User-Agent", required = false) String userAgent,
        @RequestHeader(value = "X-Forwarded-For", required = false) String ip) {
        AuthenticationResponseRecordDTO authenticationResponseRecordDTO = authenticationService.login(
            credentialsRecordDTO, deviceId, userAgent, firstForwardedIp(ip));
        return ResponseEntity.ok(authenticationResponseRecordDTO);
    }

    @PostMapping("/refresh")
    public ResponseEntity<@NonNull AuthenticationResponseRecordDTO> refresh(
        @RequestBody @Valid RefreshTokenRecordDTO request,
        @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
        @RequestHeader(value = "User-Agent", required = false) String userAgent,
        @RequestHeader(value = "X-Forwarded-For", required = false) String ip) {
        AuthenticationResponseRecordDTO dto = authenticationService.refresh(
            refreshTokenOrNull(request), deviceId, userAgent, firstForwardedIp(ip));
        return ResponseEntity.ok(dto);
    }

    @PostMapping("/logout")
    public ResponseEntity<@NonNull Void> logout(@RequestBody @Valid RefreshTokenRecordDTO request) {
        authenticationService.logout(refreshTokenOrNull(request));
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/recovery-token")
    public ResponseEntity<?> recoveryToken(
        @RequestBody @Valid EmailDTO emailDTO,
        @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
        @RequestHeader(value = "X-Forwarded-For", required = false) String ip) {
        authenticationService.recoveryToken(emailDTO, firstForwardedIp(ip), deviceId);
        return ResponseEntity.ok("Caso esse email exista, será enviado a ele um link para resetar a senha");
    }

    @PostMapping("/new-password/{token}")
    public ResponseEntity<?> renewPassword(@PathVariable String token,
        @RequestBody @Valid PasswordResetDTO passwordResetDTO) {
        authenticationService.resetPassword(token, passwordResetDTO);
        return ResponseEntity.noContent().build();
    }

    private String refreshTokenOrNull(RefreshTokenRecordDTO request) {
        return request == null ? null : request.refreshToken();
    }

    private String firstForwardedIp(String forwardedFor) {
        if (forwardedFor == null || forwardedFor.isBlank()) {
            return forwardedFor;
        }
        return forwardedFor.split(",", 2)[0].trim();
    }
}
