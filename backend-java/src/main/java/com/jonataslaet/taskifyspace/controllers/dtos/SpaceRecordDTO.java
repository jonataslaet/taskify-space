package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.SpaceMembershipStatusEnum;
import com.jonataslaet.taskifyspace.entities.enums.SpaceUserRoleEnum;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record SpaceRecordDTO(

    @JsonView({SpaceView.ReadSpace.class, SpaceView.UpdateSpace.class})
    @Positive(groups = SpaceView.UpdateSpace.class, message = "Id do espaco deve ser positivo")
    Long id,

    @NotBlank(groups = SpaceView.CreateSpace.class, message = "Nome do espaco e obrigatorio")
    @Pattern(groups = SpaceView.UpdateSpace.class, regexp = ".*\\S.*", message = "Nome do espaco nao pode estar em branco")
    @Size(groups = {SpaceView.CreateSpace.class, SpaceView.UpdateSpace.class}, max = 255, message = "Nome do espaco deve ter no maximo 255 caracteres")
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
