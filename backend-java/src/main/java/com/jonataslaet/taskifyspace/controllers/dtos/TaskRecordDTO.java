package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;

import java.math.BigDecimal;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record TaskRecordDTO(

    @JsonView({TaskView.ReadTask.class, TaskView.UpdateTask.class})
    Long id,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    Long spaceId,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    String description,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    BigDecimal score,

    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    TaskCategoryEnum category,

    @JsonView({TaskView.ReadTask.class})
    Boolean active,

    @JsonView({TaskView.ReadTask.class})
    String creatorName
) {
    public interface TaskView {
        interface CreateTask {}
        interface ReadTask {}
        interface UpdateTask {}
    }
}
