package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record SpaceRecordDTO(

    @JsonView({SpaceView.ReadSpace.class, SpaceView.UpdateSpace.class})
    Long id,

    @JsonView({SpaceView.CreateSpace.class, SpaceView.ReadSpace.class, SpaceView.UpdateSpace.class})
    String name,

    @JsonView({SpaceView.CreateSpace.class, SpaceView.ReadSpace.class, SpaceView.UpdateSpace.class})
    String spaceAdminName,

    @JsonView({SpaceView.ReadSpace.class})
    Boolean active,

    @JsonView({SpaceView.ReadSpace.class})
    SpaceUserRoleEnum spaceUserRole,

    @JsonView({SpaceView.ReadSpace.class})
    SpaceMembershipStatusEnum spaceMembershipStatus,

    @JsonView({SpaceView.ReadSpace.class})
    Long activeParticipationsCount
) {
    public interface SpaceView {
        interface CreateSpace {}
        interface ReadSpace {}
        interface UpdateSpace {}
    }
}
