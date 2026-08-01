package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.CreateUserRequestDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.CreateUserResponseDTO;
import com.jonataslaet.taskifyspace.controllers.dtos.ReadUserResponseDTO;
import com.jonataslaet.taskifyspace.entities.User;

import java.util.Objects;

public class UserMapper {

    public static User toEntity(CreateUserRequestDTO request) {
        User user = new User();
        user.setEmail(request.email());
        user.setName(request.name());
        return user;
    }

    public static CreateUserResponseDTO toCreateUserResponseDTO(User user) {
        if (Objects.isNull(user)) return null;
        return new CreateUserResponseDTO(user.getId(), user.getEmail(), user.getName(), user.getStatus(), user.getRole());
    }

    public static ReadUserResponseDTO toUserRecordDTO(User user) {
        if (Objects.isNull(user)) return null;
        return new ReadUserResponseDTO(user.getId(), user.getEmail(), user.getName(), user.getStatus(), user.getRole());
    }

}
