package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Space data transfer object")
@JsonInclude(JsonInclude.Include.NON_NULL)
public record SpaceRecordDTO(

    @JsonView({SpaceView.ReadSpace.class, SpaceView.UpdateSpace.class})
    @Schema(example = "1")
    Long id,

    @JsonView({SpaceView.CreateSpace.class, SpaceView.ReadSpace.class, SpaceView.UpdateSpace.class})
    @Schema(example = "Minha casa")
    String name,

    @JsonView({SpaceView.CreateSpace.class, SpaceView.ReadSpace.class, SpaceView.UpdateSpace.class})
    @Schema(example = "Minha casa")
    String spaceAdminName,

    @JsonView({SpaceView.ReadSpace.class})
    @Schema(example = "true")
    Boolean active,

    @JsonView({SpaceView.ReadSpace.class})
    @Schema(example = "ROLE_SPACE_PARTICIPANT")
    SpaceUserRoleEnum spaceUserRole,

    @JsonView({SpaceView.ReadSpace.class})
    @Schema(example = "APPROVED")
    SpaceMembershipStatusEnum spaceMembershipStatus
) {
    public interface SpaceView {
        interface CreateSpace {}
        interface ReadSpace {}
        interface UpdateSpace {}
    }
}
