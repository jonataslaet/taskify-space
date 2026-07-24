DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM spaces
        WHERE creator_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Cannot require spaces.creator_id while spaces without creator exist';
    END IF;
END $$;

ALTER TABLE spaces
    ALTER COLUMN creator_id SET NOT NULL;
