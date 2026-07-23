CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    birth_date DATE,
    status VARCHAR(255),
    role VARCHAR(255) NOT NULL
);

CREATE TABLE plans (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(255),
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE plan_feature_limits (
    plan_id BIGINT NOT NULL,
    feature VARCHAR(255) NOT NULL,
    usage_limit BIGINT,
    CONSTRAINT fk_plan_feature_limits_plan
        FOREIGN KEY (plan_id) REFERENCES plans (id)
);

CREATE TABLE spaces (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    creator_id BIGINT,
    CONSTRAINT fk_spaces_creator
        FOREIGN KEY (creator_id) REFERENCES users (id)
);

CREATE TABLE space_memberships (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    space_id BIGINT NOT NULL,
    space_user_role VARCHAR(255) NOT NULL,
    space_membership_status_enum VARCHAR(255) NOT NULL,
    CONSTRAINT uq_space_memberships_user_space UNIQUE (user_id, space_id),
    CONSTRAINT fk_space_memberships_user
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_space_memberships_space
        FOREIGN KEY (space_id) REFERENCES spaces (id)
);

CREATE TABLE tasks (
    id BIGSERIAL PRIMARY KEY,
    description VARCHAR(255),
    score NUMERIC(38, 2),
    category VARCHAR(255),
    active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    user_id BIGINT,
    space_id BIGINT NOT NULL,
    CONSTRAINT fk_tasks_creator
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_tasks_space
        FOREIGN KEY (space_id) REFERENCES spaces (id)
);

CREATE TABLE tasks_executions (
    id BIGSERIAL PRIMARY KEY,
    space_id BIGINT NOT NULL,
    task_id BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_tasks_executions_space
        FOREIGN KEY (space_id) REFERENCES spaces (id),
    CONSTRAINT fk_tasks_executions_task
        FOREIGN KEY (task_id) REFERENCES tasks (id)
);

CREATE TABLE task_execution_users (
    task_execution_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    PRIMARY KEY (task_execution_id, user_id),
    CONSTRAINT fk_task_execution_users_execution
        FOREIGN KEY (task_execution_id) REFERENCES tasks_executions (id),
    CONSTRAINT fk_task_execution_users_user
        FOREIGN KEY (user_id) REFERENCES users (id)
);

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
    CONSTRAINT fk_subscriptions_user
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_subscriptions_plan
        FOREIGN KEY (plan_id) REFERENCES plans (id)
);

CREATE TABLE refresh_tokens (
    id BIGSERIAL PRIMARY KEY,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    issued_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITHOUT TIME ZONE,
    replaced_by_hash VARCHAR(64),
    device_id VARCHAR(255),
    user_agent VARCHAR(255),
    ip_address VARCHAR(255),
    CONSTRAINT fk_refresh_tokens_user
        FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX ix_refresh_token_user ON refresh_tokens (user_id);
CREATE INDEX ix_refresh_token_expires ON refresh_tokens (expires_at);

CREATE TABLE tb_password_recovery (
    id BIGSERIAL PRIMARY KEY,
    token VARCHAR(255) NOT NULL,
    expiration TIMESTAMP WITH TIME ZONE NOT NULL,
    email VARCHAR(255) NOT NULL,
    updated_on TIMESTAMP,
    created_on TIMESTAMP
);
