package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;

public class ParticipantMapper {

    public static ParticipantDTO toDTO(User user) {
        return new ParticipantDTO(user.getId(), user.getName(), null);
    }

    public static ParticipantDTO toDTO(SpaceMembership spaceMembership) {
        return toDTO(spaceMembership.getUser());
    }
}
