CREATE TABLE task_schedules (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL,
    day_of_month INTEGER,
    CONSTRAINT uk_task_schedule_task UNIQUE (task_id),
    CONSTRAINT fk_task_schedules_task
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT ck_task_schedules_day_of_month
        CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31)
);

CREATE TABLE task_schedule_week_days (
    task_schedule_id BIGINT NOT NULL,
    week_day VARCHAR(255) NOT NULL,
    CONSTRAINT fk_task_schedule_week_days_schedule
        FOREIGN KEY (task_schedule_id) REFERENCES task_schedules (id) ON DELETE CASCADE,
    CONSTRAINT uq_task_schedule_week_days UNIQUE (task_schedule_id, week_day)
);
