package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.AuthenticationResponseRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.CredentialsRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.RefreshTokenRecordDTO;
import com.jonataslaet.taskifyspace.services.AuthenticationService;
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
        @RequestBody CredentialsRecordDTO credentialsRecordDTO, @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
        @RequestHeader(value = "User-Agent", required = false) String userAgent,
        @RequestHeader(value = "X-Forwarded-For", required = false) String ip) {
        AuthenticationResponseRecordDTO authenticationResponseRecordDTO = authenticationService.login(
            credentialsRecordDTO, deviceId, userAgent, ip);
        return ResponseEntity.ok(authenticationResponseRecordDTO);
    }

    @PostMapping("/refresh")
    public ResponseEntity<@NonNull AuthenticationResponseRecordDTO> refresh(
        @RequestBody RefreshTokenRecordDTO request, @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
        @RequestHeader(value = "User-Agent", required = false) String userAgent,
        @RequestHeader(value = "X-Forwarded-For", required = false) String ip) {
        AuthenticationResponseRecordDTO dto = authenticationService.refresh(request.refreshToken(), deviceId, userAgent, ip);
        return ResponseEntity.ok(dto);
    }

    @PostMapping("/logout")
    public ResponseEntity<@NonNull Void> logout(@RequestBody RefreshTokenRecordDTO request) {
        authenticationService.logout(request.refreshToken());
        return ResponseEntity.noContent().build();
    }
}
