package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.repositories.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

@Service
@ConditionalOnProperty(
    prefix = "security.email.registration-confirmation.cleanup",
    name = "enabled",
    havingValue = "true")
public class UserRegistrationConfirmationCleanupService {

    private static final Logger LOGGER =
        LoggerFactory.getLogger(UserRegistrationConfirmationCleanupService.class);

    private final UserRepository userRepository;
    private final UserService userService;
    private final Clock clock;

    @Value("${security.email.registration-confirmation.cleanup.batch-size:100}")
    private int batchSize = 100;

    public UserRegistrationConfirmationCleanupService(
        UserRepository userRepository,
        UserService userService,
        Clock clock) {
        this.userRepository = userRepository;
        this.userService = userService;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${security.email.registration-confirmation.cleanup.fixed-delay:60000}")
    @Transactional
    public void deleteExpiredPendingRegistrationUsers() {
        deleteExpiredPendingRegistrationUsers(Instant.now(clock));
    }

    public int deleteExpiredPendingRegistrationUsers(Instant now) {
        List<Long> userIds = userRepository.findExpiredUnconfirmedRegistrationUserIdsForUpdate(
            now, UserStatusEnum.PENDING_EVALUATION.name(), batchSize);

        int deletedUsers = 0;
        for (Long userId : userIds) {
            try {
                if (userService.deleteExpiredPendingRegistrationUser(userId, now)) {
                    deletedUsers++;
                }
            } catch (Exception exception) {
                LOGGER.warn("Unable to delete expired pending registration user {}", userId, exception);
            }
        }
        return deletedUsers;
    }
}
