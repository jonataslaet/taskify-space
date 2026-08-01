package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.CreateUserRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.CreateUserResponseDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserPasswordRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.ReadUserResponseDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.UserService;
import com.jonataslaet.taskifyspace.specifications.SpecificationTemplate;
import jakarta.validation.Valid;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/users")
public class UserController {

    final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public ResponseEntity<@NonNull CreateUserResponseDTO> createUser(
        @RequestBody @Valid CreateUserRequestDTO request){
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.createUser(request));
    }

    @GetMapping("/{userId}")
    public ResponseEntity<@NonNull ReadUserResponseDTO> getOneUser(
        @AuthenticationPrincipal User authenticatedUser,
        @PathVariable(value = "userId") Long userId){
        return ResponseEntity.status(HttpStatus.OK).body(userService.findById(authenticatedUser, userId));
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull ReadUserResponseDTO>> getAllUsers(
        SpecificationTemplate.UserSpecification userSpecification, Pageable pageable){
        Page<@NonNull ReadUserResponseDTO> userModelPage = userService.findAll(userSpecification, pageable);
        return ResponseEntity.status(HttpStatus.OK).body(userModelPage);
    }

    @PutMapping
    public ResponseEntity<@NonNull Void> updateMe(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Valid UpdateUserRequestDTO request){
        userService.updateUser(authenticatedUser.getId(), request);
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }

    @PutMapping("/password")
    public ResponseEntity<@NonNull Void> updatePassword(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Valid UpdateUserPasswordRequestDTO request){
        userService.updatePassword(authenticatedUser.getId(), request);
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @PatchMapping("/{id}/status")
    public ResponseEntity<Void> updateStatus(
        @PathVariable Long id, @RequestBody @Valid UpdateUserStatusRequestDTO request) {

        userService.changeStatus(id, request);

        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{userId}")
    public ResponseEntity<@NonNull Void> deleteUser(
        @AuthenticationPrincipal User authenticatedUser,
        @PathVariable(value = "userId") Long userId){
        userService.deleteById(authenticatedUser, userId);
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }
}
