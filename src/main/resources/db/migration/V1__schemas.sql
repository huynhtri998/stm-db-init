-- Enable required extension (for gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Schemas per service
CREATE SCHEMA IF NOT EXISTS user_service;
CREATE SCHEMA IF NOT EXISTS project_service;
CREATE SCHEMA IF NOT EXISTS task_service;
CREATE SCHEMA IF NOT EXISTS notification_service;

-- Common enum types (kept inside service schemas to avoid cross-coupling)
-- user_service enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname='user_status' AND n.nspname='user_service') THEN
CREATE TYPE user_service.user_status AS ENUM ('ACTIVE', 'LOCKED', 'DISABLED');
END IF;
END$$;

-- project_service enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname='project_visibility' AND n.nspname='project_service') THEN
CREATE TYPE project_service.project_visibility AS ENUM ('PRIVATE', 'TEAM', 'PUBLIC');
END IF;
END$$;

-- task_service enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname='task_status' AND n.nspname='task_service') THEN
CREATE TYPE task_service.task_status AS ENUM ('TODO', 'IN_PROGRESS', 'DONE', 'CANCELLED');
END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname='task_priority' AND n.nspname='task_service') THEN
CREATE TYPE task_service.task_priority AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
END IF;
END$$;

-- notification_service enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname='notif_channel' AND n.nspname='notification_service') THEN
CREATE TYPE notification_service.notif_channel AS ENUM ('INAPP', 'EMAIL', 'WEBHOOK');
END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname='notif_status' AND n.nspname='notification_service') THEN
CREATE TYPE notification_service.notif_status AS ENUM ('PENDING', 'SENT', 'FAILED');
END IF;
END$$;
