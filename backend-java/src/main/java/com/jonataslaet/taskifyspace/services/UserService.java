package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UserRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.DuplicationException;
import com.jonataslaet.taskifyspace.exceptions.ForbiddenException;
import com.jonataslaet.taskifyspace.exceptions.InvalidCredentialsException;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;
import com.jonataslaet.taskifyspace.mappers.UserMapper;
import com.jonataslaet.taskifyspace.repositories.SpaceMembershipRepository;
import com.jonataslaet.taskifyspace.repositories.SpaceRepository;
import com.jonataslaet.taskifyspace.repositories.TaskExecutionRepository;
import com.jonataslaet.taskifyspace.repositories.TaskRepository;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.jspecify.annotations.NonNull;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;

@Service
@Transactional(readOnly = true)
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final RefreshTokenService refreshTokenService;
    private final SpaceMembershipRepository spaceMembershipRepository;
    private final SpaceRepository spaceRepository;
    private final TaskRepository taskRepository;
    private final TaskExecutionRepository taskExecutionRepository;

    public UserService(
        UserRepository userRepository,
        PasswordEncoder passwordEncoder,
        RefreshTokenService refreshTokenService,
        SpaceMembershipRepository spaceMembershipRepository,
        SpaceRepository spaceRepository,
        TaskRepository taskRepository,
        TaskExecutionRepository taskExecutionRepository) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokenService = refreshTokenService;
        this.spaceMembershipRepository = spaceMembershipRepository;
        this.spaceRepository = spaceRepository;
        this.taskRepository = taskRepository;
        this.taskExecutionRepository = taskExecutionRepository;
    }

    @Transactional
    public UserRecordDTO createUser(UserRecordDTO userRecordDTO) {
        if (userRepository.existsByEmail(userRecordDTO.email())) {
            throw new DuplicationException("Email already exists");
        }

        if(userRecordDTO.role().equals(UserRoleEnum.ROLE_ADMIN)){
            throw new ForbiddenException("Role admin is not allowed");
        }

        UserRoleEnum.validateExistence(userRecordDTO.role());
        User user = UserMapper.toEntity(userRecordDTO);

        user.setStatus(UserStatusEnum.PENDING_EVALUATION);
        user.setPassword(passwordEncoder.encode(userRecordDTO.password()));
        return UserMapper.toUserRecordDTO(userRepository.save(user));
    }

    public Page<@NonNull UserRecordDTO> findAll(Specification<@NonNull User> userSpecification , Pageable pageable) {
        logger.info("Fetching all users with filters: {} and pageable: {}", userSpecification, pageable);
        return userRepository.findAll(userSpecification, pageable).map(UserMapper::toUserRecordDTO);
    }

    public UserRecordDTO findById(Long userId) {
        logger.info("Fetching user with ID {}", userId);
        return UserMapper.toUserRecordDTO(findUserById(userId));
    }

    public UserRecordDTO findById(User authenticatedUser, Long userId) {
        validateAdminOrSelf(authenticatedUser, userId);
        return findById(userId);
    }

    @Transactional
    public void deleteById(Long userId) {
        logger.info("Attempting to delete user with ID {}", userId);
        User user = findUserById(userId);
        validateUserIsNotLastActiveGlobalAdmin(user);
        validateUserIsNotOnlyApprovedSpaceAdmin(userId);

        taskExecutionRepository.deleteExecutorLinksByUserId(userId);
        taskExecutionRepository.deleteExecutionsWithoutExecutors();
        taskRepository.clearCreatorByUserId(userId);
        spaceRepository.clearCreatorByUserId(userId);
        refreshTokenService.deleteAllByUserId(userId);

        userRepository.delete(user);
        logger.info("User with ID {} deleted successfully", userId);
    }

    @Transactional
    public void deleteById(User authenticatedUser, Long userId) {
        validateAdminOrSelf(authenticatedUser, userId);
        deleteById(userId);
    }


    @Transactional
    public void updateUser(Long userId, UserRecordDTO userRecordDto) {
        logger.info("Updating user with ID {}", userId);
        User user = findUserById(userId);

        logger.debug("Updating editable profile fields for user ID {}", userId);
        user.setEmail(userRecordDto.email());
        user.setName(userRecordDto.name());

        userRepository.save(user);
        logger.info("User with ID {} updated successfully", userId);
    }

    @Transactional
    public void updatePassword(Long userId, UserRecordDTO userRecordDTO) {
        logger.info("Updating password for user with ID {}", userId);

        User user = findUserById(userId);

        if (!passwordEncoder.matches(userRecordDTO.oldPassword(), user.getPassword())) {
            logger.warn("Password mismatch for user ID {}", userId);
            throw new InvalidCredentialsException("Old password does not match");
        }

        logger.debug("Old password validated for user ID {}", userId);
        user.setPassword(passwordEncoder.encode(userRecordDTO.password()));
        userRepository.save(user);
        refreshTokenService.revokeAllByUserId(userId);

        logger.info("Password updated successfully for user ID {}", userId);
    }

    @Transactional
    public void changeStatus(Long userId, UpdateUserStatusRequestDTO updateUserStatusRequestDTO) {
        if (Objects.isNull(updateUserStatusRequestDTO) || Objects.isNull(updateUserStatusRequestDTO.status())) {
            throw new InvalidRequestException("Status is required");
        }

        logger.info("Changing user status to {}", updateUserStatusRequestDTO.status());
        User user = findUserById(userId);
        UserStatusEnum previousStatus = user.getStatus();
        validateStatusChangeDoesNotRemoveLastActiveGlobalAdmin(user, updateUserStatusRequestDTO.status());
        user.setStatus(updateUserStatusRequestDTO.status());
        userRepository.save(user);
        if (!Objects.equals(previousStatus, updateUserStatusRequestDTO.status())) {
            refreshTokenService.revokeAllByUserId(userId);
        }
        logger.info("User status changed successfully to {}", userId);
    }

    public User findUserById(Long userId) {
        logger.debug("Finding user with ID {}", userId);
        return userRepository.findById(userId)
            .orElseThrow(() -> {
                logger.warn("User with ID {} not found", userId);
                return new ResourceNotFoundException("User not found");
            });
    }

    private void validateAdminOrSelf(User authenticatedUser, Long userId) {
        if (UserRoleEnum.ROLE_ADMIN.equals(authenticatedUser.getRole())
            || authenticatedUser.getId().equals(userId)) {
            return;
        }

        throw new ForbiddenException("Usuario nao possui permissao para acessar esse recurso");
    }

    private void validateUserIsNotOnlyApprovedSpaceAdmin(Long userId) {
        long spacesWhereUserIsOnlyApprovedAdmin =
            spaceMembershipRepository.countSpacesWhereUserIsOnlyApprovedAdmin(
                userId,
                com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum.APPROVED,
                com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum.ROLE_SPACE_ADMIN);
        if (spacesWhereUserIsOnlyApprovedAdmin > 0) {
            throw new ForbiddenException("Usuario e o ultimo administrador aprovado de pelo menos um espaco");
        }
    }

    private void validateStatusChangeDoesNotRemoveLastActiveGlobalAdmin(User user, UserStatusEnum targetStatus) {
        if (!isActiveGlobalAdmin(user) || UserStatusEnum.ACTIVE.equals(targetStatus)) {
            return;
        }

        validateUserIsNotLastActiveGlobalAdmin(user);
    }

    private void validateUserIsNotLastActiveGlobalAdmin(User user) {
        if (!isActiveGlobalAdmin(user)) {
            return;
        }

        int activeGlobalAdmins = userRepository.findByRoleAndStatusForUpdate(
            UserRoleEnum.ROLE_ADMIN,
            UserStatusEnum.ACTIVE).size();

        if (activeGlobalAdmins <= 1) {
            throw new ForbiddenException("Sistema precisa manter pelo menos um administrador global ativo");
        }
    }

    private boolean isActiveGlobalAdmin(User user) {
        return UserRoleEnum.ROLE_ADMIN.equals(user.getRole())
            && UserStatusEnum.ACTIVE.equals(user.getStatus());
    }
}
