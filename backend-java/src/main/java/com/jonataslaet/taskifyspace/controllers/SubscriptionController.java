package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.SubscriptionRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.SubscriptionService;
import jakarta.validation.Valid;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/subscriptions")
public class SubscriptionController {

    private final SubscriptionService subscriptionService;

    public SubscriptionController(SubscriptionService subscriptionService) {
        this.subscriptionService = subscriptionService;
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull SubscriptionRecordDTO>> findAll(Pageable pageable) {
        return ResponseEntity.ok(subscriptionService.findAll(pageable));
    }

    @GetMapping("/me")
    public ResponseEntity<@NonNull List<@NonNull SubscriptionRecordDTO>> findMine(
        @AuthenticationPrincipal User authenticatedUser) {
        return ResponseEntity.ok(subscriptionService.findByUser(authenticatedUser.getId()));
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @GetMapping("/{subscriptionId}")
    public ResponseEntity<@NonNull SubscriptionRecordDTO> findById(@PathVariable Long subscriptionId) {
        return ResponseEntity.ok(subscriptionService.findById(subscriptionId));
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @PostMapping("/users/{userId}/plans/{planId}")
    public ResponseEntity<@NonNull SubscriptionRecordDTO> grantSubscription(
        @PathVariable Long userId,
        @PathVariable Long planId,
        @RequestBody @Valid SubscriptionRecordDTO dto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(subscriptionService.grantSubscription(userId, planId, dto));
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @PatchMapping("/{subscriptionId}/cancel")
    public ResponseEntity<@NonNull Void> cancelSubscription(@PathVariable Long subscriptionId) {
        subscriptionService.cancelSubscription(subscriptionId);
        return ResponseEntity.noContent().build();
    }
}
