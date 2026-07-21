package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.ParticipantDTO;
import com.jonataslaet.taskifyspace.entities.SpaceMembership;
import com.jonataslaet.taskifyspace.entities.User;

import java.math.BigDecimal;

public class ParticipantMapper {

    public static ParticipantDTO toDTO(User user, BigDecimal score) {
        return new ParticipantDTO(user.getId(), user.getName(), null, score);
    }

    public static ParticipantDTO toDTO(SpaceMembership spaceMembership, BigDecimal score) {
        User user = spaceMembership.getUser();
        return new ParticipantDTO(user.getId(), user.getName(), spaceMembership.getSpaceUserRole(), score);
    }
}
