package com.jonataslaet.taskifyspace.controllers;

import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceMembershipRecordDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.SpaceRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import com.jonataslaet.taskifyspace.services.SpaceService;
import com.jonataslaet.taskifyspace.specifications.SpecificationTemplate;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/spaces")
public class SpaceController {

    private final SpaceService spaceService;

    public SpaceController(SpaceService spaceService) {
        this.spaceService = spaceService;
    }

    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull SpaceRecordDTO>> readAllSpaces(
        SpecificationTemplate.SpaceSpecification spaceSpecification,
        @RequestParam(value = "spaceUserRole", required = false) SpaceUserRoleEnum spaceUserRole,
        @RequestParam(value = "spaceMembershipStatus", required = false)
        SpaceMembershipStatusEnum spaceMembershipStatus,
        Pageable pageable, @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull SpaceRecordDTO> SpaceModelPage =
            spaceService.findAll(
                spaceSpecification, pageable, authenticatedUser, spaceUserRole, spaceMembershipStatus);
        return ResponseEntity.status(HttpStatus.OK).body(SpaceModelPage);
    }

    @JsonView(SpaceRecordDTO.SpaceView.ReadSpace.class)
    @PostMapping
    public ResponseEntity<@NonNull SpaceRecordDTO> createSpace(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Validated(SpaceRecordDTO.SpaceView.CreateSpace.class)
        @JsonView(SpaceRecordDTO.SpaceView.CreateSpace.class) SpaceRecordDTO spaceRecordDTO){
        return ResponseEntity.status(HttpStatus.CREATED).body(spaceService.createSpace(spaceRecordDTO, authenticatedUser));
    }

    @GetMapping("/{spaceId}/participants")
    public ResponseEntity<@NonNull Page<@NonNull ParticipantDTO>> readParticipants(
        Pageable pageable, @PathVariable("spaceId") Long spaceId,
        @RequestParam(value = "name", required = false) String name,
        @RequestParam(value = "spaceUserRole", required = false) SpaceUserRoleEnum spaceUserRole,
        @RequestParam(value = "taskCategories", required = false) List<TaskCategoryEnum> taskCategories,
        @AuthenticationPrincipal User authenticatedUser) {
        Page<@NonNull ParticipantDTO> pagedSpacememberships =
            spaceService.readParticipants(pageable, spaceId, authenticatedUser, name, spaceUserRole, taskCategories);
        return ResponseEntity.status(HttpStatus.OK).body(pagedSpacememberships);
    }

    @JsonView(SpaceRecordDTO.SpaceView.ReadSpace.class)
    @GetMapping("/{spaceId}")
    public ResponseEntity<@NonNull SpaceRecordDTO> getSpaceById(
        @PathVariable("spaceId") Long spaceId,
        @AuthenticationPrincipal User authenticatedUser) {
        SpaceRecordDTO foundSpace = spaceService.getSpaceById(authenticatedUser, spaceId);
        return ResponseEntity.ok(foundSpace);
    }

    @PutMapping("/{spaceId}")
    public ResponseEntity<@NonNull SpaceRecordDTO> updateSpace(
        @PathVariable("spaceId") Long spaceId, @AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Validated(SpaceRecordDTO.SpaceView.UpdateSpace.class)
        @JsonView(SpaceRecordDTO.SpaceView.UpdateSpace.class) SpaceRecordDTO spaceRecordDTO) {

        SpaceRecordDTO updatedSpace = spaceService.updateSpace(authenticatedUser, spaceId, spaceRecordDTO);
        return ResponseEntity.ok(updatedSpace);
    }

    @DeleteMapping("/{spaceId}")
    public ResponseEntity<@NonNull Void> deleteSpace(
        @AuthenticationPrincipal User authenticatedUser, @PathVariable("spaceId") Long spaceId) {
        spaceService.deleteSpace(authenticatedUser, spaceId);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{spaceId}")
    public ResponseEntity<@NonNull Void> toggleActiveSpace(
        @AuthenticationPrincipal User authenticatedUser, @PathVariable("spaceId") Long spaceId) {
        spaceService.toggleActiveSpace(authenticatedUser, spaceId);
        return ResponseEntity.noContent().build();
    }
}
