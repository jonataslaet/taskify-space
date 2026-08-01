package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.CreateUserRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.CreateUserResponseDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserPasswordRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.ReadUserResponseDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.events.UserCreatedEvent;
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
import com.jonataslaet.taskifyspace.utils.EmailUtils;
import org.jspecify.annotations.NonNull;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
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
    private final UserApprovalSubscriptionService userApprovalSubscriptionService;
    private final ApplicationEventPublisher eventPublisher;

    public UserService(
        UserRepository userRepository,
        PasswordEncoder passwordEncoder,
        RefreshTokenService refreshTokenService,
        SpaceMembershipRepository spaceMembershipRepository,
        SpaceRepository spaceRepository,
        TaskRepository taskRepository,
        TaskExecutionRepository taskExecutionRepository,
        UserApprovalSubscriptionService userApprovalSubscriptionService,
        ApplicationEventPublisher eventPublisher) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokenService = refreshTokenService;
        this.spaceMembershipRepository = spaceMembershipRepository;
        this.spaceRepository = spaceRepository;
        this.taskRepository = taskRepository;
        this.taskExecutionRepository = taskExecutionRepository;
        this.userApprovalSubscriptionService = userApprovalSubscriptionService;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public CreateUserResponseDTO createUser(CreateUserRequestDTO request) {
        validatePasswordConfirmationMatches(request);
        String normalizedEmail = EmailUtils.normalize(request.email());
        if (userRepository.existsByEmail(normalizedEmail)) throw new DuplicationException("Email already exists");

        User user = UserMapper.toEntity(request);

        user.setEmail(normalizedEmail);
        user.setStatus(UserStatusEnum.PENDING_EVALUATION);
        user.setRole(UserRoleEnum.ROLE_USER);
        user.setPassword(passwordEncoder.encode(request.password()));
        User savedUser = userRepository.save(user);
        eventPublisher.publishEvent(new UserCreatedEvent(savedUser.getId()));
        return UserMapper.toCreateUserResponseDTO(savedUser);
    }

    public Page<@NonNull ReadUserResponseDTO> findAll(Specification<@NonNull User> userSpecification , Pageable pageable) {
        logger.info("Fetching all users with filters: {} and pageable: {}", userSpecification, pageable);
        return userRepository.findAll(userSpecification, pageable).map(UserMapper::toUserRecordDTO);
    }

    public ReadUserResponseDTO findById(Long userId) {
        logger.info("Fetching user with ID {}", userId);
        return UserMapper.toUserRecordDTO(findUserById(userId));
    }

    public ReadUserResponseDTO findById(User authenticatedUser, Long userId) {
        validateAdminOrSelf(authenticatedUser, userId);
        return findById(userId);
    }

    @Transactional
    public void deleteById(Long userId) {
        logger.info("Attempting to delete user with ID {}", userId);
        User user = findUserById(userId);
        deleteUser(user);
        logger.info("User with ID {} deleted successfully", userId);
    }

    @Transactional
    public boolean deletePendingRegistrationUser(Long userId) {
        logger.info("Attempting to delete pending registration user with ID {}", userId);
        User user = findUserByIdForUpdate(userId);
        if (!UserStatusEnum.PENDING_EVALUATION.equals(user.getStatus())) {
            logger.info("User with ID {} was not deleted because status is {}", userId, user.getStatus());
            return false;
        }

        deleteUser(user);
        logger.info("Pending registration user with ID {} deleted successfully", userId);
        return true;
    }

    private void deleteUser(User user) {
        Long userId = user.getId();
        validateUserIsNotLastActiveGlobalAdmin(user);
        validateUserIsNotCreatorOfAnySpace(userId);
        validateUserIsNotOnlyApprovedSpaceAdmin(userId);

        taskExecutionRepository.deleteExecutorLinksByUserId(userId);
        taskExecutionRepository.deleteExecutionsWithoutExecutors();
        taskRepository.clearCreatorByUserId(userId);
        refreshTokenService.deleteAllByUserId(userId);

        userRepository.delete(user);
    }

    @Transactional
    public void deleteById(User authenticatedUser, Long userId) {
        validateAdminOrSelf(authenticatedUser, userId);
        deleteById(userId);
    }


    @Transactional
    public void updateUser(Long userId, UpdateUserRequestDTO request) {
        logger.info("Updating user with ID {}", userId);
        User user = findUserById(userId);
        String normalizedEmail = EmailUtils.normalize(request.email());
        validateEmailIsAvailableForUpdate(user, normalizedEmail);

        logger.debug("Updating editable profile fields for user ID {}", userId);
        user.setEmail(normalizedEmail);
        user.setName(request.name());

        userRepository.save(user);
        logger.info("User with ID {} updated successfully", userId);
    }

    @Transactional
    public void updatePassword(Long userId, UpdateUserPasswordRequestDTO request) {
        logger.info("Updating password for user with ID {}", userId);

        User user = findUserById(userId);

        if (!passwordEncoder.matches(request.oldPassword(), user.getPassword())) {
            logger.warn("Password mismatch for user ID {}", userId);
            throw new InvalidCredentialsException("Old password does not match");
        }

        logger.debug("Old password validated for user ID {}", userId);
        user.setPassword(passwordEncoder.encode(request.password()));
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
        UserStatusEnum targetStatus = updateUserStatusRequestDTO.status();
        validateStatusChangeDoesNotRemoveLastActiveGlobalAdmin(user, targetStatus);
        user.setStatus(targetStatus);
        userRepository.save(user);
        grantBasicPlanIfPendingUserWasApproved(user, previousStatus, targetStatus);
        if (!Objects.equals(previousStatus, targetStatus)) {
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

    public User findUserByIdForUpdate(Long userId) {
        logger.debug("Finding user with ID {} for update", userId);
        return userRepository.findByIdForUpdate(userId)
            .orElseThrow(() -> {
                logger.warn("User with ID {} not found for update", userId);
                return new ResourceNotFoundException("User not found");
            });
    }

    private void validateEmailIsAvailableForUpdate(User user, String normalizedEmail) {
        if (!Objects.equals(user.getEmail(), normalizedEmail) && userRepository.existsByEmail(normalizedEmail)) {
            throw new DuplicationException("Email already exists");
        }
    }

    private void validatePasswordConfirmationMatches(CreateUserRequestDTO request) {
        if (!Objects.equals(request.password(), request.passwordConfirmation())) {
            throw new InvalidRequestException("Password confirmation does not match");
        }
    }

    private void grantBasicPlanIfPendingUserWasApproved(
        User user, UserStatusEnum previousStatus, UserStatusEnum targetStatus) {
        if (UserStatusEnum.PENDING_EVALUATION.equals(previousStatus) && UserStatusEnum.ACTIVE.equals(targetStatus)) {
            userApprovalSubscriptionService.grantBasicPlanForApprovedUserWithoutPlan(user);
        }
    }

    private void validateAdminOrSelf(User authenticatedUser, Long userId) {
        if (UserRoleEnum.ROLE_ADMIN.equals(authenticatedUser.getRole())
            || authenticatedUser.getId().equals(userId)) {
            return;
        }

        throw new ForbiddenException("Usuario nao possui permissao para acessar esse recurso");
    }

    private void validateUserIsNotOnlyApprovedSpaceAdmin(Long userId) {
        long spacesWhereUserIsOnlyApprovedAdmin = spaceMembershipRepository.countSpacesWhereUserIsOnlyApprovedAdmin(
            userId, SpaceMembershipStatusEnum.APPROVED, SpaceUserRoleEnum.ROLE_SPACE_ADMIN);
        if (spacesWhereUserIsOnlyApprovedAdmin > 0) {
            throw new ForbiddenException("Usuario e o ultimo administrador aprovado de pelo menos um espaco");
        }
    }

    private void validateUserIsNotCreatorOfAnySpace(Long userId) {
        if (spaceRepository.existsByCreatorId(userId)) {
            throw new ForbiddenException("Usuario e dono de pelo menos um espaco e nao pode ser removido");
        }
    }

    private void validateStatusChangeDoesNotRemoveLastActiveGlobalAdmin(User user, UserStatusEnum targetStatus) {
        if (!isActiveGlobalAdmin(user) || UserStatusEnum.ACTIVE.equals(targetStatus)) {
            return;
        }

        validateUserIsNotLastActiveGlobalAdmin(user);
    }

    private void validateUserIsNotLastActiveGlobalAdmin(User user) {
        if (!isActiveGlobalAdmin(user)) return;

        int activeGlobalAdmins = userRepository.findByRoleAndStatusForUpdate(
            UserRoleEnum.ROLE_ADMIN, UserStatusEnum.ACTIVE).size();

        if (activeGlobalAdmins <= 1) {
            throw new ForbiddenException("Sistema precisa manter pelo menos um administrador global ativo");
        }
    }

    private boolean isActiveGlobalAdmin(User user) {
        return UserRoleEnum.ROLE_ADMIN.equals(user.getRole()) && UserStatusEnum.ACTIVE.equals(user.getStatus());
    }
}
