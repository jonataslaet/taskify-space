package com.jonataslaet.taskifyspace.controllers.dtos;

import com.jonataslaet.taskifyspace.entities.enums.UserRoleEnum;

public record AuthenticationResponseRecordDTO(Long id,
                                              String username, String name, String accessToken, String refreshToken, UserRoleEnum role) {
}