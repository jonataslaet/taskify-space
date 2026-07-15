package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.services.SpaceService;
import com.jonataslaet.taskifyspace.specifications.SpecificationTemplate;
import io.swagger.v3.oas.annotations.Parameter;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/spaces/{spaceId}/participations")
public class SpaceMembershipController {

    private final SpaceService spaceService;

    public SpaceMembershipController(SpaceService spaceService) {
        this.spaceService = spaceService;
    }

    @PostMapping
    public ResponseEntity<@NonNull Void> createParticipation(@AuthenticationPrincipal User authenticatedUser,
        @RequestParam("email") String email, @PathVariable Long spaceId) {
        spaceService.createParticipation(authenticatedUser, spaceId, email);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/request")
    public ResponseEntity<@NonNull SpaceRecordDTO> requestParticipation(@AuthenticationPrincipal User authenticatedUser,
        @PathVariable Long spaceId) {
        spaceService.requestParticipation(spaceId, authenticatedUser);
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull SpaceMembershipRecordDTO>> readParticipations(
        @Parameter(hidden = true) SpecificationTemplate.SpaceMembershipSpecification spaceSpecification,
        @Parameter(hidden = true) Pageable pageable, @PathVariable Long spaceId,
        @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull SpaceMembershipRecordDTO> pagedSpacememberships =
            spaceService.readParticipations(spaceSpecification, pageable, spaceId, authenticatedUser);
        return ResponseEntity.status(HttpStatus.OK).body(pagedSpacememberships);
    }

    @PatchMapping("/{spaceMembershipId}")
    public ResponseEntity<@NonNull SpaceMembershipRecordDTO> updateParticipationStatus(@PathVariable Long spaceId,
        @AuthenticationPrincipal User authenticatedUser, @PathVariable Long spaceMembershipId,
        @RequestParam(value = "status", required = false) SpaceMembershipStatusEnum status,
        @RequestParam(value = "spaceUserRole", required = false) SpaceUserRoleEnum spaceUserRole) {
        SpaceMembershipRecordDTO updatedSpaceMembership = spaceService.updateParticipation(authenticatedUser,
            spaceId, spaceMembershipId, status, spaceUserRole);
        return ResponseEntity.status(HttpStatus.OK).body(updatedSpaceMembership);
    }

    @PatchMapping("/me/block")
    public ResponseEntity<@NonNull Void> blockOwnParticipation(@PathVariable Long spaceId,
        @AuthenticationPrincipal User authenticatedUser) {
        spaceService.blockOwnParticipation(authenticatedUser, spaceId);
        return ResponseEntity.noContent().build();
    }
}
