package com.jonataslaet.taskifyspace.controllers;

import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UserRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.UserService;
import com.jonataslaet.taskifyspace.specifications.SpecificationTemplate;
import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/users")
public class UserController {

    final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public ResponseEntity<@NonNull UserRecordDTO> createUser(
        @RequestBody @Validated(UserRecordDTO.UserView.CreateUser.class)
        @JsonView(UserRecordDTO.UserView.CreateUser.class) UserRecordDTO userRecordDTO){
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.createUser(userRecordDTO));
    }

    @GetMapping("/{userId}")
    public ResponseEntity<@NonNull UserRecordDTO> getOneUser(@PathVariable(value = "userId") Long userId){
        return ResponseEntity.status(HttpStatus.OK).body(userService.findById(userId));
    }

    @GetMapping
    public ResponseEntity<@NonNull Page<@NonNull UserRecordDTO>> getAllUsers(
        SpecificationTemplate.UserSpecification userSpecification, Pageable pageable){
        Page<@NonNull UserRecordDTO> userModelPage = userService.findAll(userSpecification, pageable);
        return ResponseEntity.status(HttpStatus.OK).body(userModelPage);
    }

    @PutMapping
    public ResponseEntity<@NonNull Void> updateMe(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Validated(UserRecordDTO.UserView.UpdateUser.class)
        @JsonView(UserRecordDTO.UserView.UpdateUser.class) UserRecordDTO UserRecordDTO){
        userService.updateUser(authenticatedUser.getId(), UserRecordDTO);
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }

    @PutMapping("/password")
    public ResponseEntity<@NonNull Void> updatePassword(@AuthenticationPrincipal User authenticatedUser,
        @RequestBody @Validated(UserRecordDTO.UserView.PasswordPut.class)
        @JsonView(UserRecordDTO.UserView.PasswordPut.class) UserRecordDTO userRecordDTO){
        userService.updatePassword(authenticatedUser.getId(), userRecordDTO);
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }

    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    @PatchMapping("/{id}/status")
    public ResponseEntity<Void> updateStatus(
        @PathVariable Long id, @RequestBody UpdateUserStatusRequestDTO request) {

        userService.changeStatus(id, request);

        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{userId}")
    public ResponseEntity<@NonNull Void> deleteUser(@PathVariable(value = "userId") Long userId){
        userService.deleteById(userId);
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }
}
