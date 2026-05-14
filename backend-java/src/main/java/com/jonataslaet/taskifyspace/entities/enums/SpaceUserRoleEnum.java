package com.jonataslaet.taskifyspace.entities.enums;

public enum SpaceUserRoleEnum {
    ROLE_SPACE_ADMIN(1, "Administrador"),
    ROLE_SPACE_MANAGER(2, "Gerente"),
    ROLE_SPACE_PARTICIPANT(3, "Participante");

    private final int id;
    private final String description;

    SpaceUserRoleEnum(int id, String description) {
        this.id = id;
        this.description = description;
    }

    public int getId() {
        return id;
    }

    public String getDescription() {
        return description;
    }
}
