package com.jonataslaet.taskifyspace.entities;

import com.jonataslaet.taskifyspace.entities.enums.FrequenceEnum;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import java.time.LocalDate;
import java.util.HashSet;
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

    @ElementCollection(fetch = FetchType.LAZY)
    @CollectionTable(
        name = "task_schedule_local_dates",
        joinColumns = @JoinColumn(name = "task_schedule_id"),
        uniqueConstraints = {
            @UniqueConstraint(
                name = "uk_task_schedule_local_date",
                columnNames = {
                    "task_schedule_id",
                    "local_date"
                }
            )
        }
    )
    @Column(name = "local_date", nullable = false)
    private Set<LocalDate> localDates = new HashSet<>();

    @Enumerated(EnumType.STRING)
    @Column(name = "frequence", nullable = false)
    private FrequenceEnum frequenceEnum;

    public TaskSchedule() {
    }

    public Long getId() {
        return id;
    }

    public Task getTask() {
        return task;
    }

    public Set<LocalDate> getLocalDates() {
        return localDates;
    }

    public FrequenceEnum getFrequenceEnum() {
        return frequenceEnum;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setTask(Task task) {
        this.task = task;
    }

    public void setLocalDates(Set<LocalDate> localDates) {
        this.localDates = localDates == null
            ? new HashSet<>()
            : new HashSet<>(localDates);
    }

    public void setFrequenceEnum(FrequenceEnum frequenceEnum) {
        this.frequenceEnum = frequenceEnum;
    }
}