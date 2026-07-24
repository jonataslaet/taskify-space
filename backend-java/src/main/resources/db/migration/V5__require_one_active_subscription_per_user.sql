DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM subscriptions
        WHERE status IN ('ACTIVE', 'TRIALING')
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Cannot require one active subscription per user while duplicates exist';
    END IF;
END $$;

CREATE UNIQUE INDEX ux_subscriptions_one_active_subscription_per_user
    ON subscriptions (user_id)
    WHERE status IN ('ACTIVE', 'TRIALING');
