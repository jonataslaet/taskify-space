-- ============================================================
-- USERS
-- ============================================================

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    birth_date DATE,
    status VARCHAR(255) NOT NULL DEFAULT 'PENDING_EVALUATION',
    role VARCHAR(255) NOT NULL,
    email_confirmed_at TIMESTAMP WITH TIME ZONE,
    registration_confirmation_expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT ck_users_email_normalized
       CHECK (email = lower(trim(email)))
);


-- ============================================================
-- PLANS
-- ============================================================

CREATE TABLE plans (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(255),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE plan_feature_limits (
     plan_id BIGINT NOT NULL,
     feature VARCHAR(255) NOT NULL,
     usage_limit BIGINT,

     CONSTRAINT fk_plan_feature_limits_plan
         FOREIGN KEY (plan_id) REFERENCES plans (id)
);


-- ============================================================
-- SPACES
-- ============================================================

CREATE TABLE spaces (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE,
    creator_id BIGINT NOT NULL,
    available BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT fk_spaces_creator
        FOREIGN KEY (creator_id) REFERENCES users (id)
);


-- ============================================================
-- SPACE MEMBERSHIPS
-- ============================================================

CREATE TABLE space_memberships (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    space_id BIGINT NOT NULL,
    space_user_role VARCHAR(255) NOT NULL,
    space_membership_status_enum VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT uq_space_memberships_user_space
       UNIQUE (user_id, space_id),

    CONSTRAINT fk_space_memberships_user
       FOREIGN KEY (user_id) REFERENCES users (id),

    CONSTRAINT fk_space_memberships_space
       FOREIGN KEY (space_id) REFERENCES spaces (id)
);

-- ============================================================
-- TASK CATEGORIES
-- ============================================================

CREATE TABLE task_categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    user_id BIGINT,
    space_id BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT fk_task_categories_creator
        FOREIGN KEY (user_id) REFERENCES users (id),

    CONSTRAINT fk_task_categories_space
        FOREIGN KEY (space_id)
            REFERENCES spaces (id)
            ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_task_categories_space_name_lower ON task_categories (space_id, LOWER(name));


-- ============================================================
-- TASKS
-- ============================================================

CREATE TABLE tasks (
    id BIGSERIAL PRIMARY KEY,
    description VARCHAR(255),
    score NUMERIC(38, 2),
    category_id BIGINT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    user_id BIGINT,
    space_id BIGINT NOT NULL,

    CONSTRAINT fk_tasks_creator
       FOREIGN KEY (user_id) REFERENCES users (id),

    CONSTRAINT fk_tasks_space
       FOREIGN KEY (space_id) REFERENCES spaces (id),

    CONSTRAINT fk_tasks_category
       FOREIGN KEY (category_id) REFERENCES task_categories (id)
);


-- ============================================================
-- TASK EXECUTIONS
-- ============================================================

CREATE TABLE tasks_executions (
    id BIGSERIAL PRIMARY KEY,
    space_id BIGINT NOT NULL,
    task_id BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT fk_tasks_executions_space
      FOREIGN KEY (space_id) REFERENCES spaces (id),

    CONSTRAINT fk_tasks_executions_task
      FOREIGN KEY (task_id) REFERENCES tasks (id)
);


-- ============================================================
-- TASK EXECUTION USERS
-- ============================================================

CREATE TABLE task_execution_users (
    task_execution_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,

    PRIMARY KEY (task_execution_id, user_id),

    CONSTRAINT fk_task_execution_users_execution
      FOREIGN KEY (task_execution_id)
          REFERENCES tasks_executions (id),

    CONSTRAINT fk_task_execution_users_user
      FOREIGN KEY (user_id)
          REFERENCES users (id)
);


-- ============================================================
-- TASK SCHEDULES
-- ============================================================

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


-- ============================================================
-- SUBSCRIPTIONS
-- ============================================================

CREATE TABLE subscriptions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    plan_id BIGINT NOT NULL,
    status VARCHAR(255) NOT NULL,
    provider VARCHAR(255) NOT NULL,
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    external_customer_id VARCHAR(255),
    external_subscription_id VARCHAR(255),
    external_price_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT fk_subscriptions_user
       FOREIGN KEY (user_id) REFERENCES users (id),

    CONSTRAINT fk_subscriptions_plan
       FOREIGN KEY (plan_id) REFERENCES plans (id)
);


-- ============================================================
-- AUTHENTICATION / REFRESH TOKENS
-- ============================================================

CREATE TABLE refresh_tokens (
    id BIGSERIAL PRIMARY KEY,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    replaced_by_hash VARCHAR(64),
    device_id VARCHAR(255),
    user_agent VARCHAR(255),
    ip_address VARCHAR(255),

    CONSTRAINT fk_refresh_tokens_user
        FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX ix_refresh_token_user
    ON refresh_tokens (user_id);

CREATE INDEX ix_refresh_token_expires
    ON refresh_tokens (expires_at);


-- ============================================================
-- PASSWORD RECOVERY
-- ============================================================

CREATE TABLE tb_password_recovery (
    id BIGSERIAL PRIMARY KEY,
    token VARCHAR(255) NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    request_token_hash VARCHAR(64) NOT NULL,
    expiration TIMESTAMP WITH TIME ZONE NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    used_at TIMESTAMP WITH TIME ZONE,
    reset_session_hash VARCHAR(64),
    reset_session_expiration TIMESTAMP WITH TIME ZONE,
    reset_session_used_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_password_recovery_request_token_hash
    ON tb_password_recovery (request_token_hash);

CREATE INDEX ix_password_recovery_reset_session_hash
    ON tb_password_recovery (reset_session_hash);

CREATE INDEX ix_password_recovery_token_hash
    ON tb_password_recovery (token_hash);


-- ============================================================
-- USER REGISTRATION CONFIRMATION
-- ============================================================

CREATE TABLE user_registration_confirmations (
     id BIGSERIAL PRIMARY KEY,
     token_hash VARCHAR(64) NOT NULL UNIQUE,
     user_id BIGINT NOT NULL,
     expiration TIMESTAMP WITH TIME ZONE NOT NULL,
     used_at TIMESTAMP WITH TIME ZONE,
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
     updated_at TIMESTAMP WITH TIME ZONE,

     CONSTRAINT fk_user_registration_confirmations_user
         FOREIGN KEY (user_id)
             REFERENCES users (id)
             ON DELETE CASCADE
);

CREATE INDEX ix_user_registration_confirmations_user_id
    ON user_registration_confirmations (user_id);

CREATE INDEX ix_user_registration_confirmations_user_unused_expiration
    ON user_registration_confirmations (user_id, expiration)
    WHERE used_at IS NULL;

CREATE INDEX ix_users_registration_confirmation_cleanup
    ON users (registration_confirmation_expires_at, id)
    WHERE status = 'PENDING_EVALUATION'
        AND email_confirmed_at IS NULL
        AND registration_confirmation_expires_at IS NOT NULL;

-- ============================================================
-- SUBSCRIPTION INDEXES
-- ============================================================

CREATE UNIQUE INDEX ux_subscriptions_one_active_subscription_per_user
    ON subscriptions (user_id)
    WHERE status IN ('ACTIVE', 'TRIALING');