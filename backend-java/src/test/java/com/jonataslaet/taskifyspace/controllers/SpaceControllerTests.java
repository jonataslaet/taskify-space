package com.jonataslaet.taskifyspace.controllers;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantSummaryDTO;
import com.jonataslaet.taskifyspace.entities.User;
import com.jonataslaet.taskifyspace.services.SpaceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SpaceControllerTests {

    @Mock
    private SpaceService spaceService;

    private SpaceController spaceController;

    @BeforeEach
    void setUp() {
        spaceController = new SpaceController(spaceService);
    }

    @Test
    void readParticipantsByNameReturnsParticipantSummaries() {
        User authenticatedUser = new User();
        List<ParticipantSummaryDTO> participants = List.of(
            new ParticipantSummaryDTO(1L, "Ana"),
            new ParticipantSummaryDTO(2L, "Maria"));

        when(spaceService.readParticipantsByName(10L, authenticatedUser, "a"))
            .thenReturn(participants);

        var response = spaceController.readParticipantsByName(10L, "a", authenticatedUser);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isSameAs(participants);
        verify(spaceService).readParticipantsByName(10L, authenticatedUser, "a");
    }
}
