package com.jonataslaet.taskifyspace.entities.enums;

import com.jonataslaet.taskifyspace.exceptions.ResourceNotFoundException;

public enum UserRoleEnum {
    ROLE_ADMIN (0, "Super Administrador"),
    ROLE_USER (1, "Usuário");

    private final int code;
    private final String description;

    UserRoleEnum(int code, String description) {
        this.code = code;
        this.description = description;
    }

    public static void validateExistence(UserRoleEnum userRoleEnum) {
        for (UserRoleEnum current: values()) {
            if (current.equals(userRoleEnum)) {
                return;
            }
        }
        throw new ResourceNotFoundException("Função não encontrada");
    }
}