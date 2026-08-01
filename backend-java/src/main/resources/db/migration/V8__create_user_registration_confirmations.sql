CREATE TABLE user_registration_confirmations (
    id BIGSERIAL PRIMARY KEY,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    expiration TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    updated_on TIMESTAMP,
    created_on TIMESTAMP,
    CONSTRAINT fk_user_registration_confirmations_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_user_registration_confirmations_user_id
    ON user_registration_confirmations (user_id);
