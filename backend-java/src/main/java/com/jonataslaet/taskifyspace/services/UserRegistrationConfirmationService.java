package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.controllers.dtos.UpdateUserStatusRequestDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.entities.UserRegistrationConfirmation;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.exceptions.InvalidRequestException;
import com.jonataslaet.taskifyspace.exceptions.RegistrationConfirmationException;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository.ConfirmationReference;
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

    @Transactional(noRollbackFor = RegistrationConfirmationException.class)
    public void confirmRegistration(String rawToken) {
        if (Objects.isNull(rawToken) || rawToken.isBlank()) {
            throw invalidTokenException();
        }

        Instant now = Instant.now(clock);
        String tokenHash = TokenUtils.sha256(rawToken);
        ConfirmationReference reference = findUnusedConfirmationReference(tokenHash);
        User user = userService.findUserByIdForUpdate(reference.getUserId());
        UserRegistrationConfirmation confirmation = findUnusedConfirmationForUpdate(reference.getId(), tokenHash, user);

        if (UserStatusEnum.ACTIVE.equals(user.getStatus())) {
            user.confirmEmail(now);
            confirmation.markUsed(now);
            confirmationRepository.save(confirmation);
            return;
        }

        if (!UserStatusEnum.PENDING_EVALUATION.equals(user.getStatus())) {
            throw new InvalidRequestException("Cadastro nao pode ser confirmado no status atual do usuario");
        }

        if (!confirmation.getExpiration().isAfter(now)) {
            boolean userDeleted = userService.deleteExpiredPendingRegistrationUser(user.getId(), now);
            throw userDeleted
                ? RegistrationConfirmationException.expiredRegistrationDeleted()
                : RegistrationConfirmationException.expiredToken();
        }

        user.confirmEmail(now);
        confirmation.markUsed(now);
        userService.changeStatus(user.getId(), new UpdateUserStatusRequestDTO(UserStatusEnum.ACTIVE));
        confirmationRepository.save(confirmation);
    }

    private ConfirmationReference findUnusedConfirmationReference(String tokenHash) {
        List<ConfirmationReference> confirmations =
            confirmationRepository.findUnusedConfirmationReferencesByTokenHash(tokenHash);
        if (Objects.isNull(confirmations) || confirmations.isEmpty()) {
            throw invalidTokenException();
        }
        if (confirmations.size() > 1) {
            throw new InvalidRequestException("Token de confirmacao de cadastro duplicado");
        }
        return confirmations.getFirst();
    }

    private UserRegistrationConfirmation findUnusedConfirmationForUpdate(
        Long confirmationId,
        String tokenHash,
        User user) {
        UserRegistrationConfirmation confirmation = confirmationRepository.findByIdForUpdate(confirmationId)
            .orElseThrow(this::invalidTokenException);
        if (!Objects.equals(tokenHash, confirmation.getTokenHash())
            || Objects.nonNull(confirmation.getUsedAt())
            || Objects.isNull(confirmation.getUser())
            || !Objects.equals(user.getId(), confirmation.getUser().getId())) {
            throw invalidTokenException();
        }
        return confirmation;
    }

    private RegistrationConfirmationException invalidTokenException() {
        return RegistrationConfirmationException.invalidToken();
    }
}
