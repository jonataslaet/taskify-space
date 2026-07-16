package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;

public record UpdateUserStatusRequestDTO(
    UserStatusEnum status
) {
}
