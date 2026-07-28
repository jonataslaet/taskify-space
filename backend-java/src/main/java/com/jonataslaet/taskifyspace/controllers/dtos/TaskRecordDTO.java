package com.jonataslaet.taskifyspace.controllers.dtos;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonView;
import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record TaskRecordDTO(

    @JsonView({TaskView.ReadTask.class, TaskView.UpdateTask.class})
    @Positive(groups = TaskView.UpdateTask.class, message = "Id da tarefa deve ser positivo")
    Long id,

    @NotNull(groups = TaskView.CreateTask.class, message = "Id do espaco e obrigatorio")
    @Positive(groups = {TaskView.CreateTask.class, TaskView.UpdateTask.class}, message = "Id do espaco deve ser positivo")
    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    Long spaceId,

    @NotBlank(groups = TaskView.CreateTask.class, message = "Descricao da tarefa e obrigatoria")
    @Pattern(groups = TaskView.UpdateTask.class, regexp = ".*\\S.*", message = "Descricao da tarefa nao pode estar em branco")
    @Size(groups = {TaskView.CreateTask.class, TaskView.UpdateTask.class}, max = 255, message = "Descricao da tarefa deve ter no maximo 255 caracteres")
    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    String description,

    @NotNull(groups = TaskView.CreateTask.class, message = "Pontuacao da tarefa e obrigatoria")
    @Positive(groups = {TaskView.CreateTask.class, TaskView.UpdateTask.class}, message = "Pontuacao da tarefa deve ser positiva")
    @Digits(groups = {TaskView.CreateTask.class, TaskView.UpdateTask.class}, integer = 36, fraction = 2, message = "Pontuacao da tarefa deve ter no maximo 36 digitos inteiros e 2 casas decimais")
    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    BigDecimal score,

    @NotNull(groups = TaskView.CreateTask.class, message = "Categoria da tarefa e obrigatoria")
    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    TaskCategoryEnum category,

    @Valid
    @JsonView({TaskView.CreateTask.class, TaskView.ReadTask.class, TaskView.UpdateTask.class})
    TaskScheduleRecordDTO schedule,

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
