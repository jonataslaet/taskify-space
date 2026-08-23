ALTER TABLE tb_password_recovery
    ADD COLUMN IF NOT EXISTS request_token_hash VARCHAR(64),
    ADD COLUMN IF NOT EXISTS failed_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS used_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS reset_session_hash VARCHAR(64),
    ADD COLUMN IF NOT EXISTS reset_session_expiration TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS reset_session_used_at TIMESTAMP WITH TIME ZONE;

UPDATE tb_password_recovery
SET request_token_hash = token_hash
WHERE request_token_hash IS NULL;

ALTER TABLE tb_password_recovery
    ALTER COLUMN request_token_hash SET NOT NULL;

CREATE INDEX IF NOT EXISTS ix_password_recovery_request_token_hash
    ON tb_password_recovery (request_token_hash);

CREATE INDEX IF NOT EXISTS ix_password_recovery_reset_session_hash
    ON tb_password_recovery (reset_session_hash);
