package com.jonataslaet.taskifyspace.controllers;

import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.SpaceService;
import com.jonataslaet.taskifyspace.specifications.SpecificationTemplate;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/spaces")
public class SpaceController {

    private final SpaceService spaceService;

    public SpaceController(SpaceService spaceService) {
        this.spaceService = spaceService;
    }

    @Operation(
        summary = "List Spaces",
        description = "Returns a paginated list of Spaces with optional filters"
    )
    @Parameters({
        @Parameter(name = "name", description = "Filter by name (case insensitive)"),
        @Parameter(name = "active", description = "Filter by active (true or false)"),

        @Parameter(name = "page", description = "Page number (0-based)", example = "0"),
        @Parameter(name = "size", description = "Page size", example = "10"),
        @Parameter(name = "sort", description = "Sort criteria (e.g. description,asc)")
    })
    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull SpaceRecordDTO>> readAllSpaces(
        @Parameter(hidden = true) SpecificationTemplate.SpaceSpecification SpaceSpecification,
        @Parameter(hidden = true) Pageable pageable, @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull SpaceRecordDTO> SpaceModelPage =
            spaceService.findAll(SpaceSpecification, pageable, authenticatedUser);
        return ResponseEntity.status(HttpStatus.OK).body(SpaceModelPage);
    }

    @Operation(
        summary = "Create a Space",
        description = "Creates a new Space in the system"
    )
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Space created successfully"),
        @ApiResponse(responseCode = "422", description = "Invalid request payload"),
        @ApiResponse(responseCode = "400", description = "Bad request")
    })
    @JsonView(SpaceRecordDTO.SpaceView.ReadSpace.class)
    @PostMapping
    public ResponseEntity<@NonNull SpaceRecordDTO> createSpace(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @JsonView(SpaceRecordDTO.SpaceView.CreateSpace.class) SpaceRecordDTO spaceRecordDTO){
        return ResponseEntity.status(HttpStatus.CREATED).body(spaceService.createSpace(spaceRecordDTO, authenticatedUser));
    }

    @PostMapping("/{spaceId}/participations")
    public ResponseEntity<@NonNull SpaceRecordDTO> requestParticipation(@PathVariable("spaceId") Long spaceId,
        @AuthenticationPrincipal User authenticatedUser) {
        spaceService.requestParticipation(spaceId, authenticatedUser);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{spaceId}/addParticipant")
    public ResponseEntity<@NonNull Void> addParticipant(
        @PathVariable("spaceId") Long spaceId,
        @RequestParam("email") String email) {
        spaceService.addParticipant(spaceId, email);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{spaceId}/participations")
    public ResponseEntity<@NonNull Page<@NonNull SpaceMembershipRecordDTO>> readParticipations(
        @Parameter(hidden = true) SpecificationTemplate.SpaceMembershipSpecification spaceSpecification,
        @Parameter(hidden = true) Pageable pageable, @PathVariable("spaceId") Long spaceId,
        @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull SpaceMembershipRecordDTO> pagedSpacememberships =
            spaceService.readParticipations(spaceSpecification, pageable, spaceId, authenticatedUser);
        return ResponseEntity.status(HttpStatus.OK).body(pagedSpacememberships);
    }

    @GetMapping("/{spaceId}/participants")
    public ResponseEntity<@NonNull Page<@NonNull ParticipantDTO>> readParticipants(
        @Parameter(hidden = true) Pageable pageable, @PathVariable("spaceId") Long spaceId,
        @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull ParticipantDTO> pagedSpacememberships =
            spaceService.readParticipants(pageable, spaceId, authenticatedUser);
        return ResponseEntity.status(HttpStatus.OK).body(pagedSpacememberships);
    }

    @Operation(
        summary = "Get Space by ID",
        description = "Returns a Space by its identifier"
    )
    @JsonView(SpaceRecordDTO.SpaceView.ReadSpace.class)
    @GetMapping("/{spaceId}")
    public ResponseEntity<@NonNull SpaceRecordDTO> getSpaceById(@PathVariable("spaceId") Long spaceId) {
        SpaceRecordDTO foundSpace = spaceService.getSpaceById(spaceId);
        return ResponseEntity.ok(foundSpace);
    }

    @PutMapping("/{spaceId}")
    public ResponseEntity<@NonNull SpaceRecordDTO> updateSpace(
        @PathVariable("spaceId") Long spaceId, @RequestBody
        @JsonView(SpaceRecordDTO.SpaceView.UpdateSpace.class) SpaceRecordDTO spaceRecordDTO) {

        SpaceRecordDTO updatedSpace = spaceService.updateSpace(spaceId, spaceRecordDTO);
        return ResponseEntity.ok(updatedSpace);
    }

    @DeleteMapping("/{spaceId}")
    public ResponseEntity<@NonNull Void> deleteSpace(
        @PathVariable("spaceId") Long spaceId) {

        spaceService.deleteSpace(spaceId);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{spaceId}")
    public ResponseEntity<@NonNull Void> toggleActiveSpace(@PathVariable("spaceId") Long spaceId) {
        spaceService.toggleActiveSpace(spaceId);
        return ResponseEntity.noContent().build();
    }
}
