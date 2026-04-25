package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;

@Entity
@Table(name = "tasks")
public class Task {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String description;

    private BigDecimal score;

    @Enumerated(EnumType.STRING)
    private TaskCategoryEnum category;

    private Boolean active;

    @ManyToOne
    @JoinColumn(name = "user_id")
    private User creator;

    @ManyToOne
    @JoinColumn(name = "space_id", nullable = false)
    private Space space;

    public Task() {}

    public Long getId() {
        return id;
    }

    public String getDescription() {
        return description;
    }

    public BigDecimal getScore() {
        return score;
    }

    public TaskCategoryEnum getCategory() {
        return category;
    }

    public Space getSpace() {
        return space;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setScore(BigDecimal score) {
        this.score = score;
    }

    public void setCategory(TaskCategoryEnum category) {
        this.category = category;
    }

    public void setSpace(Space space) {
        this.space = space;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Boolean isActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public User getCreator() {
        return creator;
    }

    public void setCreator(User creator) {
        this.creator = creator;
    }
}
