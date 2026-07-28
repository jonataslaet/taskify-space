package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.TaskCategoryEnum;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;

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

    @Column(nullable = false)
    private Boolean active = Boolean.FALSE;

    private Instant createdAt;

    @ManyToOne
    @JoinColumn(name = "user_id")
    private User creator;

    @ManyToOne
    @JoinColumn(name = "space_id", nullable = false)
    private Space space;

    @OneToOne(
        mappedBy = "task",
        cascade = CascadeType.ALL,
        orphanRemoval = true
    )
    private TaskSchedule schedule;

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
        return Boolean.TRUE.equals(active);
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public User getCreator() {
        return creator;
    }

    public void setCreator(User creator) {
        this.creator = creator;
    }

    public TaskSchedule getSchedule() {
        return schedule;
    }

    public void setSchedule(TaskSchedule schedule) {
        if (this.schedule == schedule) return;
        if (this.schedule != null) {
            this.schedule.setTask(null);
        }
        this.schedule = schedule;
        if (schedule != null) {
            schedule.setTask(this);
        }
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
