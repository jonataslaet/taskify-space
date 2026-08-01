package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.TokenExpirationException;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
import com.jonataslaet.taskifyspace.utils.TokenUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

@Service
@Transactional(readOnly = true)
public class UserRegistrationConfirmationService {

    private final UserRegistrationConfirmationRepository confirmationRepository;
    private final UserService userService;
    private final Clock clock;

    public UserRegistrationConfirmationService(
        UserRegistrationConfirmationRepository confirmationRepository,
        UserService userService,
        Clock clock) {
        this.confirmationRepository = confirmationRepository;
        this.userService = userService;
        this.clock = clock;
    }

    @Transactional(noRollbackFor = TokenExpirationException.class)
    public void confirmRegistration(String rawToken) {
        if (Objects.isNull(rawToken) || rawToken.isBlank()) {
            throw invalidTokenException();
        }

        Instant now = Instant.now(clock);
        UserRegistrationConfirmation confirmation = findUnusedConfirmation(rawToken);
        if (!confirmation.getExpiration().isAfter(now)) {
            deletePendingUserForExpiredConfirmation(confirmation, now);
            throw invalidTokenException();
        }
        User user = confirmation.getUser();

        if (UserStatusEnum.ACTIVE.equals(user.getStatus())) {
            confirmation.markUsed(now);
            confirmationRepository.save(confirmation);
            return;
        }

        if (!UserStatusEnum.PENDING_EVALUATION.equals(user.getStatus())) {
            throw new InvalidRequestException("Cadastro nao pode ser confirmado no status atual do usuario");
        }

        confirmation.markUsed(now);
        userService.changeStatus(user.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.ACTIVE));
        confirmationRepository.save(confirmation);
    }

    private UserRegistrationConfirmation findUnusedConfirmation(String rawToken) {
        List<UserRegistrationConfirmation> confirmations =
            confirmationRepository.findUnusedConfirmationsForUpdate(TokenUtils.sha256(rawToken));
        if (Objects.isNull(confirmations) || confirmations.isEmpty()) {
            throw invalidTokenException();
        }
        if (confirmations.size() > 1) {
            throw new InvalidRequestException("Token de confirmacao de cadastro duplicado");
        }
        return confirmations.getFirst();
    }

    private void deletePendingUserForExpiredConfirmation(UserRegistrationConfirmation confirmation, Instant now) {
        User user = confirmation.getUser();
        if (Objects.isNull(user)) {
            return;
        }

        boolean hasAnotherValidConfirmation =
            confirmationRepository.existsByUserIdAndUsedAtIsNullAndExpirationAfter(user.getId(), now);
        if (!hasAnotherValidConfirmation) {
            userService.deletePendingRegistrationUser(user.getId());
        }
    }

    private TokenExpirationException invalidTokenException() {
        return new TokenExpirationException("Token de confirmacao de cadastro invalido ou expirado");
    }
}
