package com.jonataslaet.taskifyspace.entities.enums;

public enum FeatureEnum {

    CREATE_SPACE("Criação de espaços"),

    CREATE_TASK("Criação de tarefas"),

    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT("Quantidade de participantes aprovados no espaço"),

    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN("Quantidade de administradores aprovados no espaço"),

    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER("Quantidade de gerentes aprovados no 3 dóespaço");

    private final String description;

    FeatureEnum(String description) {
        this.description = description;
    }

    public String getDescription() {
        return description;
    }

    public SpaceUserRoleEnum approvalSpaceUserRole() {
        return switch (this) {
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT -> SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT;
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN -> SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER -> SpaceUserRoleEnum.ROLE_SPACE_MANAGER;
            case CREATE_SPACE, CREATE_TASK -> null;
        };
    }
}