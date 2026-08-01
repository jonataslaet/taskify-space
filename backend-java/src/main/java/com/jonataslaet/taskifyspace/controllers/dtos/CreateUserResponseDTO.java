package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;
import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import com.jonataslaet.taskifyspace.utils.EmailUtils;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record CreateUserResponseDTO(

    Long id,

    String email,

    String name,

    UserStatusEnum status,

    UserRoleEnum role) {

    public CreateUserResponseDTO {
        email = EmailUtils.normalize(email);
    }
}
