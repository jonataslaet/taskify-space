package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

@Schema(description = "Task data transfer object")
@JsonInclude(JsonInclude.Include.NON_NULL)
public record TaskRecordDTO(

    @JsonView({TaskView.ReadTask.class, TaskView.UpdateTask.class})
    @Schema(example = "1")
    Long id,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    @Schema(example = "1")
    Long spaceId,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    @Schema(example = "Passar a vassoura no quarto 1 da casa")
    String description,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    @Schema(example = "78.0")
    BigDecimal score,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    @Schema(example = "OPERATIONAL")
    TaskCategoryEnum category,

    @JsonView({TaskView.ReadTask.class})
    @Schema(example = "true")
    Boolean active
) {
    public interface TaskView {
        interface CreateTask {}
        interface ReadTask {}
        interface UpdateTask {}
    }
}
