SET search_path = notification_service, public;

-- SUBSCRIPTIONS: which user wants which channel for which event
CREATE TABLE IF NOT EXISTS notification_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,                 -- user_service.users
    channel notif_channel NOT NULL DEFAULT 'INAPP',
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, channel)
    );

-- NOTIFICATIONS OUTBOX (event-driven or scheduled)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,                 -- recipient
    channel notif_channel NOT NULL DEFAULT 'INAPP',
    title TEXT NOT NULL,
    body TEXT,
    related_task_id UUID,                  -- optional, task_service.tasks
    scheduled_at TIMESTAMPTZ,              -- when to send (nullable = immediate)
    sent_at TIMESTAMPTZ,
    status notif_status NOT NULL DEFAULT 'PENDING',
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

-- Simple “cron” table for periodic jobs (e.g., due reminders)
CREATE TABLE IF NOT EXISTS scheduled_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_key CITEXT NOT NULL UNIQUE,         -- e.g. "due-reminder-v1"
    cron_expr TEXT NOT NULL,                 -- you can store cron or ISO intervals
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notif_user_status ON notifications(user_id, status);
CREATE INDEX IF NOT EXISTS idx_notif_scheduled_at ON notifications(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_notif_created_at ON notifications(created_at);

-- Update trigger
CREATE OR REPLACE FUNCTION set_timestamp_notification_service() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notifications_set_timestamp ON notifications;
CREATE TRIGGER trg_notifications_set_timestamp
    BEFORE UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION set_timestamp_notification_service();
