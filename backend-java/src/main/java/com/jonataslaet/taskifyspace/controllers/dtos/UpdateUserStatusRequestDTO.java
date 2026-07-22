package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.entities.enums.UserStatusEnum;
import jakarta.validation.constraints.NotNull;

public record UpdateUserStatusRequestDTO(
    @NotNull(message = "Status is required")
    UserStatusEnum status
) {
}
