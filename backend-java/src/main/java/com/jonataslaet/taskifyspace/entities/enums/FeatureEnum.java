package com.jonataslaet.taskifyspace.entities.enums;

public enum FeatureEnum {
    CREATE_SPACE,

    CREATE_TASK,

    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT,
    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER;

    public SpaceUserRoleEnum approvalSpaceUserRole() {
        return switch (this) {
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT -> SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT;
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN -> SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER -> SpaceUserRoleEnum.ROLE_SPACE_MANAGER;
            case CREATE_SPACE, CREATE_TASK -> null;
        };
    }
}
