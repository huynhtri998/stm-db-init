SET search_path = task_service, public;

-- TASKS
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID,             -- FK -> project_service.projects(id)
    assignee_id UUID,            -- FK -> user_service.users(id)
    title TEXT NOT NULL,
    description TEXT,
    status task_status NOT NULL DEFAULT 'TODO',
    priority task_priority NOT NULL DEFAULT 'MEDIUM',
    due_date TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    estimate_minutes INT,        -- optional estimate
    version INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT ck_task_title_len CHECK (char_length(title) BETWEEN 1 AND 200),
    CONSTRAINT ck_task_dates CHECK (
(due_date IS NULL OR due_date >= created_at)
    )
    );

-- TAGS
CREATE TABLE IF NOT EXISTS tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL,      -- user who created tag (user_service.users)
    name CITEXT NOT NULL,
    color TEXT,                  -- hex or token
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (owner_id, name)
    );

-- M:N TASK_TAGS
CREATE TABLE IF NOT EXISTS task_tags (
    task_id UUID NOT NULL,
    tag_id UUID NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (task_id, tag_id)
    );

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status_due ON tasks(status, due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);

-- Update trigger
CREATE OR REPLACE FUNCTION set_timestamp_task_service() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tasks_set_timestamp ON tasks;
CREATE TRIGGER trg_tasks_set_timestamp
    BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION set_timestamp_task_service();
