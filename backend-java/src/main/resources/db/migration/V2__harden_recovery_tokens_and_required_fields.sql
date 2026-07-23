UPDATE users
SET status = 'PENDING_EVALUATION'
WHERE status IS NULL;

ALTER TABLE users
    ALTER COLUMN status SET NOT NULL;

UPDATE spaces
SET active = FALSE
WHERE active IS NULL;

ALTER TABLE spaces
    ALTER COLUMN active SET DEFAULT FALSE,
    ALTER COLUMN active SET NOT NULL;

UPDATE tasks
SET active = FALSE
WHERE active IS NULL;

ALTER TABLE tasks
    ALTER COLUMN active SET DEFAULT FALSE,
    ALTER COLUMN active SET NOT NULL;

ALTER TABLE tb_password_recovery
    ADD COLUMN IF NOT EXISTS token_hash VARCHAR(64);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'tb_password_recovery'
            AND column_name = 'token'
    ) THEN
        UPDATE tb_password_recovery
        SET token_hash = token,
            expiration = CURRENT_TIMESTAMP
        WHERE token_hash IS NULL;

        ALTER TABLE tb_password_recovery
            DROP COLUMN token;
    END IF;
END $$;

UPDATE tb_password_recovery
SET token_hash = repeat('0', 64),
    expiration = CURRENT_TIMESTAMP
WHERE token_hash IS NULL;

ALTER TABLE tb_password_recovery
    ALTER COLUMN token_hash SET NOT NULL;

CREATE INDEX IF NOT EXISTS ix_password_recovery_token_hash
    ON tb_password_recovery (token_hash);
