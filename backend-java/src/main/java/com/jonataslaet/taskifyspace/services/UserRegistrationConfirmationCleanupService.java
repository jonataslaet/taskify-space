package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.UserRegistrationConfirmationRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

@Service
public class UserRegistrationConfirmationCleanupService {

    private static final Logger LOGGER =
        LoggerFactory.getLogger(UserRegistrationConfirmationCleanupService.class);

    private final UserRegistrationConfirmationRepository confirmationRepository;
    private final UserService userService;
    private final Clock clock;

    public UserRegistrationConfirmationCleanupService(
        UserRegistrationConfirmationRepository confirmationRepository,
        UserService userService,
        Clock clock) {
        this.confirmationRepository = confirmationRepository;
        this.userService = userService;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${security.email.registration-confirmation.cleanup.fixed-delay:60000}")
    public void deleteExpiredPendingRegistrationUsers() {
        deleteExpiredPendingRegistrationUsers(Instant.now(clock));
    }

    public int deleteExpiredPendingRegistrationUsers(Instant now) {
        List<Long> userIds = confirmationRepository.findPendingUserIdsWithExpiredConfirmationAndNoValidConfirmation(
            now, UserStatusEnum.PENDING_EVALUATION);

        int deletedUsers = 0;
        for (Long userId : userIds) {
            try {
                if (userService.deletePendingRegistrationUser(userId)) {
                    deletedUsers++;
                }
            } catch (Exception exception) {
                LOGGER.warn("Unable to delete expired pending registration user {}", userId, exception);
            }
        }
        return deletedUsers;
    }
}
