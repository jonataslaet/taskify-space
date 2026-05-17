package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.PlanRecordDTO;
import com.jonataslaet.taskifyspace.services.PlanService;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/plans")
public class PlanController {

    private final PlanService planService;

    public PlanController(PlanService planService) {
        this.planService = planService;
    }

    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull PlanRecordDTO>> findAll(Pageable pageable) {
        return ResponseEntity.ok(planService.findAll(pageable));
    }

    @GetMapping("/{planId}")
    public ResponseEntity<@NonNull PlanRecordDTO> findById(@PathVariable Long planId) {
        return ResponseEntity.ok(planService.findById(planId));
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @PostMapping
    public ResponseEntity<@NonNull PlanRecordDTO> createPlan(@RequestBody PlanRecordDTO dto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(planService.createPlan(dto));
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @PutMapping("/{planId}")
    public ResponseEntity<@NonNull PlanRecordDTO> updatePlan(@PathVariable Long planId, @RequestBody PlanRecordDTO dto) {
        return ResponseEntity.ok(planService.updatePlan(planId, dto));
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @PatchMapping("/{planId}")
    public ResponseEntity<@NonNull Void> toggleActive(@PathVariable Long planId) {
        planService.toggleActive(planId);
        return ResponseEntity.noContent().build();
    }
}
