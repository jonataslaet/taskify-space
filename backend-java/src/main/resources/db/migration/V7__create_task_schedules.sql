CREATE TABLE task_schedules (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL,
    frequence_enum VARCHAR(50) NOT NULL,

    CONSTRAINT uk_task_schedule_task
        UNIQUE (task_id),

    CONSTRAINT fk_task_schedules_task
        FOREIGN KEY (task_id)
            REFERENCES tasks (id)
            ON DELETE CASCADE
);

CREATE TABLE task_schedule_local_dates (
    task_schedule_id BIGINT NOT NULL,
    local_date DATE NOT NULL,

    CONSTRAINT pk_task_schedule_local_dates
       PRIMARY KEY (task_schedule_id, local_date),

    CONSTRAINT fk_task_schedule_local_dates_schedule
       FOREIGN KEY (task_schedule_id)
           REFERENCES task_schedules (id)
           ON DELETE CASCADE
);