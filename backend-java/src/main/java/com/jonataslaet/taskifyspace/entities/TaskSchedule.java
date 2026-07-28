package com.jonataslaet.taskifyspace.entities;

import jakarta.persistence.*;

import java.time.DayOfWeek;
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;

@Entity
@Table(
    name = "task_schedules",
    uniqueConstraints = {
        @UniqueConstraint(
            name = "uk_task_schedule_task",
            columnNames = "task_id"
        )
    }
)
public class TaskSchedule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(
        name = "task_id",
        nullable = false,
        unique = true
    )
    private Task task;

    @ElementCollection
    @CollectionTable(
        name = "task_schedule_week_days",
        joinColumns = @JoinColumn(name = "task_schedule_id")
    )
    @Enumerated(EnumType.STRING)
    @Column(name = "week_day", nullable = false)
    private Set<DayOfWeek> daysOfWeek = new HashSet<>();

    @Column(name = "day_of_month")
    private Integer dayOfMonth;

    public TaskSchedule() {
    }

    public Long getId() {
        return id;
    }

    public Task getTask() {
        return task;
    }

    public Set<DayOfWeek> getDaysOfWeek() {
        return daysOfWeek;
    }

    public Integer getDayOfMonth() {
        return dayOfMonth;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setTask(Task task) {
        this.task = task;
    }

    public void setDaysOfWeek(Set<DayOfWeek> daysOfWeek) {
        this.daysOfWeek = Objects.nonNull(daysOfWeek) ? new HashSet<>(daysOfWeek) : new HashSet<>();
    }

    public void setDayOfMonth(Integer dayOfMonth) {
        this.dayOfMonth = dayOfMonth;
    }
}
