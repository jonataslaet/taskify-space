package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UserRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.InvalidCredentialsException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

@ExtendWith(MockitoExtension.class)
class UserServiceTests {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private RefreshTokenService refreshTokenService;

    @Mock
    private SpaceMembershipRepository spaceMembershipRepository;

    @Mock
    private SpaceRepository spaceRepository;

    @Mock
    private TaskRepository taskRepository;

    @Mock
    private TaskExecutionRepository taskExecutionRepository;

    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(
            userRepository,
            passwordEncoder,
            refreshTokenService,
            spaceMembershipRepository,
            spaceRepository,
            taskRepository,
            taskExecutionRepository);
    }

    @Test
    void findByIdAllowsUserToReadOwnProfile() {
        User authenticatedUser = createUser(1L, UserRoleEnum.ROLE_USER);
        when(userRepository.findById(authenticatedUser.getId())).thenReturn(Optional.of(authenticatedUser));

        UserRecordDTO foundUser = userService.findById(authenticatedUser, authenticatedUser.getId());

        assertThat(foundUser.id()).isEqualTo(authenticatedUser.getId());
    }

    @Test
    void findByIdPreventsUserFromReadingAnotherUserProfile() {
        User authenticatedUser = createUser(1L, UserRoleEnum.ROLE_USER);

        assertThatThrownBy(() -> userService.findById(authenticatedUser, 2L))
            .isInstanceOf(ForbiddenException.class);

        verify(userRepository, never()).findById(2L);
    }

    @Test
    void deleteByIdAllowsAdminToDeleteAnyUser() {
        User admin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        User targetUser = createUser(2L, UserRoleEnum.ROLE_USER);
        when(userRepository.findById(targetUser.getId())).thenReturn(Optional.of(targetUser));

        userService.deleteById(admin, targetUser.getId());

        verify(taskExecutionRepository).deleteExecutorLinksByUserId(targetUser.getId());
        verify(taskExecutionRepository).deleteExecutionsWithoutExecutors();
        verify(taskRepository).clearCreatorByUserId(targetUser.getId());
        verify(spaceRepository).clearCreatorByUserId(targetUser.getId());
        verify(refreshTokenService).deleteAllByUserId(targetUser.getId());
        verify(userRepository).delete(targetUser);
    }

    @Test
    void deleteByIdPreventsUserFromDeletingAnotherUser() {
        User authenticatedUser = createUser(1L, UserRoleEnum.ROLE_USER);

        assertThatThrownBy(() -> userService.deleteById(authenticatedUser, 2L))
            .isInstanceOf(ForbiddenException.class);

        verify(userRepository, never()).findById(2L);
        verify(userRepository, never()).delete(any(User.class));
    }

    @Test
    void deleteByIdPreventsRemovingLastApprovedSpaceAdmin() {
        User admin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        User targetUser = createUser(2L, UserRoleEnum.ROLE_USER);
        when(userRepository.findById(targetUser.getId())).thenReturn(Optional.of(targetUser));
        when(spaceMembershipRepository.countSpacesWhereUserIsOnlyApprovedAdmin(
            targetUser.getId(),
            com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.APPROVED,
            com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_ADMIN))
            .thenReturn(1L);

        assertThatThrownBy(() -> userService.deleteById(admin, targetUser.getId()))
            .isInstanceOf(ForbiddenException.class);

        verify(taskExecutionRepository, never()).deleteExecutorLinksByUserId(targetUser.getId());
        verify(userRepository, never()).delete(any(User.class));
    }

    @Test
    void deleteByIdPreventsRemovingLastActiveGlobalAdmin() {
        User admin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        when(userRepository.findById(admin.getId())).thenReturn(Optional.of(admin));
        when(userRepository.findByRoleAndStatusForUpdate(UserRoleEnum.ROLE_ADMIN, UserStatusEnum.ACTIVE))
            .thenReturn(List.of(admin));

        assertThatThrownBy(() -> userService.deleteById(admin, admin.getId()))
            .isInstanceOf(ForbiddenException.class);

        verify(spaceMembershipRepository, never()).countSpacesWhereUserIsOnlyApprovedAdmin(any(), any(), any());
        verify(taskExecutionRepository, never()).deleteExecutorLinksByUserId(admin.getId());
        verify(userRepository, never()).delete(any(User.class));
    }

    @Test
    void deleteByIdAllowsRemovingActiveGlobalAdminWhenAnotherActiveGlobalAdminExists() {
        User authenticatedAdmin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        User targetAdmin = createUser(2L, UserRoleEnum.ROLE_ADMIN);
        when(userRepository.findById(targetAdmin.getId())).thenReturn(Optional.of(targetAdmin));
        when(userRepository.findByRoleAndStatusForUpdate(UserRoleEnum.ROLE_ADMIN, UserStatusEnum.ACTIVE))
            .thenReturn(List.of(authenticatedAdmin, targetAdmin));

        userService.deleteById(authenticatedAdmin, targetAdmin.getId());

        verify(taskExecutionRepository).deleteExecutorLinksByUserId(targetAdmin.getId());
        verify(refreshTokenService).deleteAllByUserId(targetAdmin.getId());
        verify(userRepository).delete(targetAdmin);
    }

    @Test
    void updateUserPreservesRoleStatusAndPassword() {
        User user = new User();
        user.setId(1L);
        user.setEmail("old@example.com");
        user.setName("Old Name");
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setStatus(UserStatusEnum.ACTIVE);
        user.setPassword("encoded-password");

        UserRecordDTO updateRequest = new UserRecordDTO(
            null,
            "new@example.com",
            "New Name",
            UserStatusEnum.SUSPENDED,
            UserRoleEnum.ROLE_ADMIN,
            "new-password",
            "old-password");

        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));

        userService.updateUser(user.getId(), updateRequest);

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        User savedUser = userCaptor.getValue();

        assertThat(savedUser.getEmail()).isEqualTo("new@example.com");
        assertThat(savedUser.getName()).isEqualTo("New Name");
        assertThat(savedUser.getRole()).isEqualTo(UserRoleEnum.ROLE_USER);
        assertThat(savedUser.getStatus()).isEqualTo(UserStatusEnum.ACTIVE);
        assertThat(savedUser.getPassword()).isEqualTo("encoded-password");
    }

    @Test
    void updatePasswordRevokesRefreshTokensAfterPasswordChange() {
        User user = createUser(1L, UserRoleEnum.ROLE_USER);
        UserRecordDTO updateRequest = new UserRecordDTO(
            null,
            null,
            null,
            null,
            null,
            "NewPass1!",
            "OldPass1!");

        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(updateRequest.oldPassword(), user.getPassword())).thenReturn(true);
        when(passwordEncoder.encode(updateRequest.password())).thenReturn("encoded-new-password");

        userService.updatePassword(user.getId(), updateRequest);

        assertThat(user.getPassword()).isEqualTo("encoded-new-password");
        verify(userRepository).save(user);
        verify(refreshTokenService).revokeAllByUserId(user.getId());
    }

    @Test
    void updatePasswordDoesNotRevokeRefreshTokensWhenOldPasswordDoesNotMatch() {
        User user = createUser(1L, UserRoleEnum.ROLE_USER);
        UserRecordDTO updateRequest = new UserRecordDTO(
            null,
            null,
            null,
            null,
            null,
            "NewPass1!",
            "WrongOld1!");

        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(updateRequest.oldPassword(), user.getPassword())).thenReturn(false);

        assertThatThrownBy(() -> userService.updatePassword(user.getId(), updateRequest))
            .isInstanceOf(InvalidCredentialsException.class);

        verify(userRepository, never()).save(any(User.class));
        verify(refreshTokenService, never()).revokeAllByUserId(user.getId());
    }

    @Test
    void changeStatusRejectsNullRequestBeforeLoadingUser() {
        assertThatThrownBy(() -> userService.changeStatus(1L, null))
            .isInstanceOf(InvalidRequestException.class);

        verify(userRepository, never()).findById(1L);
        verify(refreshTokenService, never()).revokeAllByUserId(1L);
    }

    @Test
    void changeStatusRejectsNullStatusBeforeLoadingUser() {
        assertThatThrownBy(() -> userService.changeStatus(1L, new UpdateUserStatusRequestDTO(null)))
            .isInstanceOf(InvalidRequestException.class);

        verify(userRepository, never()).findById(1L);
        verify(refreshTokenService, never()).revokeAllByUserId(1L);
    }

    @Test
    void userIsNotEnabledWhenStatusIsNull() {
        User user = createUser(1L, UserRoleEnum.ROLE_USER);
        user.setStatus(null);

        assertThat(user.isEnabled()).isFalse();
    }

    @Test
    void changeStatusRevokesRefreshTokensWhenStatusChanges() {
        User user = createUser(1L, UserRoleEnum.ROLE_USER);
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));

        userService.changeStatus(user.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.SUSPENDED));

        verify(refreshTokenService).revokeAllByUserId(user.getId());
    }

    @Test
    void changeStatusDoesNotRevokeRefreshTokensWhenStatusIsUnchanged() {
        User user = createUser(1L, UserRoleEnum.ROLE_USER);
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));

        userService.changeStatus(user.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.ACTIVE));

        verify(refreshTokenService, never()).revokeAllByUserId(user.getId());
    }

    @Test
    void changeStatusPreventsSuspendingLastActiveGlobalAdmin() {
        User admin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        when(userRepository.findById(admin.getId())).thenReturn(Optional.of(admin));
        when(userRepository.findByRoleAndStatusForUpdate(UserRoleEnum.ROLE_ADMIN, UserStatusEnum.ACTIVE))
            .thenReturn(List.of(admin));

        assertThatThrownBy(() -> userService.changeStatus(
            admin.getId(),
            new UpdateUserStatusRequestDTO(UserStatusEnum.SUSPENDED)))
            .isInstanceOf(ForbiddenException.class);

        verify(userRepository, never()).save(any(User.class));
        verify(refreshTokenService, never()).revokeAllByUserId(admin.getId());
    }

    @Test
    void changeStatusAllowsSuspendingActiveGlobalAdminWhenAnotherActiveGlobalAdminExists() {
        User admin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        User otherAdmin = createUser(2L, UserRoleEnum.ROLE_ADMIN);
        when(userRepository.findById(admin.getId())).thenReturn(Optional.of(admin));
        when(userRepository.findByRoleAndStatusForUpdate(UserRoleEnum.ROLE_ADMIN, UserStatusEnum.ACTIVE))
            .thenReturn(List.of(admin, otherAdmin));

        userService.changeStatus(admin.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.SUSPENDED));

        assertThat(admin.getStatus()).isEqualTo(UserStatusEnum.SUSPENDED);
        verify(userRepository).save(admin);
        verify(refreshTokenService).revokeAllByUserId(admin.getId());
    }

    @Test
    void changeStatusDoesNotCheckLastActiveGlobalAdminWhenAdminRemainsActive() {
        User admin = createUser(1L, UserRoleEnum.ROLE_ADMIN);
        when(userRepository.findById(admin.getId())).thenReturn(Optional.of(admin));

        userService.changeStatus(admin.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.ACTIVE));

        verify(userRepository, never()).findByRoleAndStatusForUpdate(any(), any());
        verify(refreshTokenService, never()).revokeAllByUserId(admin.getId());
    }

    private User createUser(Long id, UserRoleEnum role) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        user.setName("User " + id);
        user.setRole(role);
        user.setStatus(UserStatusEnum.ACTIVE);
        user.setPassword("encoded-password");
        return user;
    }
}
