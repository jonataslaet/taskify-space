ALTER TABLE users
    ADD COLUMN email_confirmed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN registration_confirmation_expires_at TIMESTAMP WITH TIME ZONE;

UPDATE users
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

CREATE INDEX ix_users_registration_confirmation_cleanup
    ON users (registration_confirmation_expires_at, id)
    WHERE status = 'PENDING_EVALUATION'
        AND email_confirmed_at IS NULL
        AND registration_confirmation_expires_at IS NOT NULL;

CREATE INDEX ix_user_registration_confirmations_user_unused_expiration
    ON user_registration_confirmations (user_id, expiration)
    WHERE used_at IS NULL;
