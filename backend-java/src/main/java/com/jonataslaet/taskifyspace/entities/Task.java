package com.jonataslaet.taskifyspace.entities;

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

    @ManyToOne
    @JoinColumn(name = "category_id")
    private TaskCategory category;

    @Column(nullable = false)
    private Boolean active = Boolean.FALSE;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

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

    public Space getSpace() {
        return space;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setScore(BigDecimal score) {
        this.score = score;
    }

    public TaskCategory getCategory() {
        return category;
    }

    public void setCategory(TaskCategory category) {
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

    public void setActive(Boolean active) {
        this.active = active;
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
        createdAt = Instant.now();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = Instant.now();
    }
}
