package com.jonataslaet.taskifyspace.entities.enums;

import java.util.Objects;

public enum FeatureEnum {
    CREATE_SPACE,
    READ_SPACE,
    UPDATE_SPACE,
    DELETE_SPACE,
    ACTIVE_OR_INACTIVE_SPACE,

    CREATE_TASK,
    READ_TASK,
    UPDATE_TASK,
    DELETE_TASK,

    FINISH_TASK,

    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT,
    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
    APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER;

    public boolean isUsageMetered() {
        return switch (this) {
            case CREATE_SPACE, CREATE_TASK, FINISH_TASK,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER -> true;
            case READ_SPACE, UPDATE_SPACE, DELETE_SPACE,
                 ACTIVE_OR_INACTIVE_SPACE,
                 READ_TASK, UPDATE_TASK, DELETE_TASK -> false;
        };
    }

    public boolean supportsSpaceUserRoleScope() {
        return switch (this) {
            case CREATE_SPACE,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN,
                 APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER -> false;
            case READ_SPACE, UPDATE_SPACE, DELETE_SPACE,
                 ACTIVE_OR_INACTIVE_SPACE,
                 CREATE_TASK, READ_TASK, UPDATE_TASK, DELETE_TASK,
                 FINISH_TASK -> true;
        };
    }

    public SpaceUserRoleEnum approvalSpaceUserRole() {
        return switch (this) {
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_PARTICIPANT -> SpaceUserRoleEnum.ROLE_SPACE_PARTICIPANT;
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_ADMIN -> SpaceUserRoleEnum.ROLE_SPACE_ADMIN;
            case APPROVE_SPACE_MEMBERSHIP_ROLE_SPACE_MANAGER -> SpaceUserRoleEnum.ROLE_SPACE_MANAGER;
            case CREATE_SPACE, READ_SPACE, UPDATE_SPACE, DELETE_SPACE,
                 ACTIVE_OR_INACTIVE_SPACE,
                 CREATE_TASK, READ_TASK, UPDATE_TASK, DELETE_TASK,
                 FINISH_TASK -> null;
        };
    }

    public boolean approvesSpaceMembershipRole(SpaceUserRoleEnum spaceUserRole) {
        return Objects.equals(approvalSpaceUserRole(), spaceUserRole);
    }
}
