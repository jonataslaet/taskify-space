package com.jonataslaet.taskifyspace.mappers;

import com.jonataslaet.taskifyspace.controllers.dtos.UserRecordDTO;
import com.jonataslaet.taskifyspace.entities.User;
import org.springframework.beans.BeanUtils;

import java.util.Objects;

public class UserMapper {

    public static User toEntity(UserRecordDTO userRecordDTO) {
        User user = new User();
        BeanUtils.copyProperties(userRecordDTO, user);
        return user;
    }

    public static UserRecordDTO toUserRecordDTO(User user) {
        if (Objects.isNull(user)) return null;
        return new UserRecordDTO(user.getId(), user.getEmail(),
            user.getName(), user.getStatus(), user.getRole(), null, null
        );
    }

}
