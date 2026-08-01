package com.jonataslaet.taskifyspace.services;

import com.jonataslaet.taskifyspace.events.UserCreatedEvent;
import org.junit.jupiter.api.Test;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class UserRegistrationConfirmationEmailListenerTests {

    @Test
    void sendConfirmationEmailDelegatesToRequestService() {
        UserRegistrationConfirmationRequestService requestService =
            mock(UserRegistrationConfirmationRequestService.class);
        UserRegistrationConfirmationEmailListener listener =
            new UserRegistrationConfirmationEmailListener(requestService);

        listener.sendConfirmationEmail(new UserCreatedEvent(10L));

        verify(requestService).requestConfirmationToken(10L);
    }
}
