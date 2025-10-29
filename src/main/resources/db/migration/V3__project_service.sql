SET search_path = project_service, public;

-- PROJECTS
CREATE TABLE IF NOT EXISTS projects (
                                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL, -- FK to user_service.users(id)
    name TEXT NOT NULL,
    description TEXT,
    visibility project_visibility NOT NULL DEFAULT 'PRIVATE',
    version INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT uq_project_owner_name UNIQUE (owner_id, name),
    CONSTRAINT ck_project_name_len CHECK (char_length(name) BETWEEN 1 AND 120)
    );

-- TEAM MEMBERS (optional collaborative feature)
CREATE TABLE IF NOT EXISTS project_members (
                                               project_id UUID NOT NULL,
                                               user_id UUID NOT NULL,
                                               added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (project_id, user_id)
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_projects_owner ON projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_projects_visibility ON projects(visibility);
CREATE INDEX IF NOT EXISTS idx_projects_created_at ON projects(created_at);

-- Update trigger
CREATE OR REPLACE FUNCTION set_timestamp_project_service() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_projects_set_timestamp ON projects;
CREATE TRIGGER trg_projects_set_timestamp
    BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION set_timestamp_project_service();
