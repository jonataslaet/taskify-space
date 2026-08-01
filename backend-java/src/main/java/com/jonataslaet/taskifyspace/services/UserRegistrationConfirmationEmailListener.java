package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.events.UserCreatedEvent;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class UserRegistrationConfirmationEmailListener {

    private final UserRegistrationConfirmationRequestService requestService;

    public UserRegistrationConfirmationEmailListener(UserRegistrationConfirmationRequestService requestService) {
        this.requestService = requestService;
    }

    @Async("userRegistrationTaskExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void sendConfirmationEmail(UserCreatedEvent event) {
        requestService.requestConfirmationToken(event.userId());
    }
}
