DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM users
        GROUP BY lower(trim(email))
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Cannot normalize user emails while case-insensitive duplicates exist';
    END IF;
END $$;

UPDATE users
SET email = lower(trim(email))
WHERE email <> lower(trim(email));

UPDATE tb_password_recovery
SET email = lower(trim(email))
WHERE email <> lower(trim(email));

ALTER TABLE users
    ADD CONSTRAINT ck_users_email_normalized
        CHECK (email = lower(trim(email)));

ALTER TABLE tb_password_recovery
    ADD CONSTRAINT ck_password_recovery_email_normalized
        CHECK (email = lower(trim(email)));

CREATE UNIQUE INDEX ux_users_email_lower
    ON users (lower(email));
