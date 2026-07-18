package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UserRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceTests {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(userRepository, passwordEncoder);
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

        userService.deleteById(admin, 2L);

        verify(userRepository).deleteById(2L);
    }

    @Test
    void deleteByIdPreventsUserFromDeletingAnotherUser() {
        User authenticatedUser = createUser(1L, UserRoleEnum.ROLE_USER);

        assertThatThrownBy(() -> userService.deleteById(authenticatedUser, 2L))
            .isInstanceOf(ForbiddenException.class);

        verify(userRepository, never()).deleteById(2L);
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
