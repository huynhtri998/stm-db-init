-- V4__seed_large.sql
-- Mass seeding script for user_service, project_service, task_service, and notification_service

-- 0) Safety & required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- 1) Tweakable sizes (adjust values here)
DO $$
DECLARE
v_users                int := 100000;   -- number of users
  v_roles                int := 2;       -- fixed ADMIN/USER roles
  v_projects             int := 24000;   -- number of projects
  v_project_memberships  int := 60000;   -- number of project members (excluding owners)
  v_tags                 int := 30000;   -- number of tags
  v_tasks                int := 400000;  -- number of tasks
  v_task_tags            int := 600000;  -- number of task-tag relations
  v_notifications        int := 800000;  -- number of notifications
  v_notif_subs_per_user  int := 2;       -- average ~channels/subscriptions per user (0–3 random)
BEGIN
  RAISE NOTICE 'Seeding with: users=%, projects=%, tasks=% ...',
    v_users, v_projects, v_tasks;
END $$;

-- 2) SEED ROLES (simple RBAC)
SET search_path = user_service, public;

INSERT INTO roles(id, name, description)
VALUES
    (gen_random_uuid(), 'ADMIN', 'Administrator'),
    (gen_random_uuid(), 'USER',  'Regular user')
    ON CONFLICT (name) DO NOTHING;

-- 3) USERS
-- Only seed if table is empty to avoid duplication on re-run
WITH need AS (
    SELECT COUNT(*) c FROM users
)
INSERT INTO users (id, email, username, password_hash, full_name, status, last_login_at, version, created_at, updated_at)
SELECT
    gen_random_uuid(),
    ('user'||gs||'@example.com')::citext,
    ('user_'||gs)::citext,
  -- Demo password hash (NOT for production): 'hash_'+gs
    ('hash_'||gs),
    'User '||gs,
    (ARRAY['ACTIVE','LOCKED','DISABLED'])[1 + (random()*2)::int]::user_status,
  NOW() - ((random()*1200)::int || ' minutes')::interval,
  0,
  NOW() - ((random()*90)::int || ' days')::interval,
  NOW()
FROM generate_series(1, (SELECT CASE WHEN c=0 THEN 50000 ELSE 0 END FROM need)) gs
ON CONFLICT DO NOTHING;

-- Temporary table: user id + row_number for fast joins
DROP TABLE IF EXISTS tmp_users;
CREATE TEMP TABLE tmp_users AS
SELECT row_number() OVER ()::int AS rn, id
FROM users;
CREATE INDEX ON tmp_users(rn);

-- Fetch role ids
WITH r AS (
    SELECT id, name FROM roles
)
-- USER_ROLES: ~90% of users are USER, ~10% are ADMIN
INSERT INTO user_roles(user_id, role_id, granted_at)
SELECT u.id,
       (SELECT id FROM roles WHERE name = CASE WHEN random() < 0.1 THEN 'ADMIN' ELSE 'USER' END),
       NOW() - ((random()*365)::int || ' days')::interval
FROM users u
    LEFT JOIN LATERAL (SELECT 1) x ON TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id
    );

-- 4) PROJECTS
SET search_path = project_service, public;

WITH need AS (SELECT COUNT(*) c FROM projects)
INSERT INTO projects (id, owner_id, name, description, visibility, version, created_at, updated_at)
SELECT
    gen_random_uuid(),
    u.id AS owner_id,
    'Project '||gs,
    'Demo project #'||gs,
    (ARRAY['PRIVATE','TEAM','PUBLIC'])[1 + (random()*2)::int]::project_visibility,
  0,
  NOW() - ((random()*120)::int || ' days')::interval,
  NOW()
FROM generate_series(1, (SELECT CASE WHEN c=0 THEN 12000 ELSE 0 END FROM need)) gs
    JOIN tmp_users u
ON u.rn = 1 + ( (gs-1) % (SELECT COUNT(*) FROM tmp_users) );

-- Temporary table for projects
DROP TABLE IF EXISTS tmp_projects;
CREATE TEMP TABLE tmp_projects AS
SELECT row_number() OVER()::int rn, id, owner_id
FROM projects;
CREATE INDEX ON tmp_projects(rn);

-- PROJECT MEMBERS (excluding owners)
-- Each row picks a random project + random user; avoids duplicates (project_id, user_id)
WITH need AS (SELECT (SELECT COUNT(*) FROM project_members) c)
INSERT INTO project_members(project_id, user_id, added_at, is_admin)
SELECT DISTINCT ON (p.id, u.id)
    p.id,
    u.id,
    NOW() - ((random()*90)::int || ' days')::interval,
    (random() < 0.15)
FROM generate_series(1, (SELECT CASE WHEN c=0 THEN 30000 ELSE 0 END FROM need)) gs
    JOIN tmp_projects p ON p.rn = 1 + ((gs * 13) % (SELECT COUNT(*) FROM tmp_projects))
    JOIN tmp_users    u ON u.rn = 1 + ((gs * 17) % (SELECT COUNT(*) FROM tmp_users))
WHERE u.id <> p.owner_id
ON CONFLICT DO NOTHING;

-- 5) TASKS, TAGS, TASK_TAGS
SET search_path = task_service, public;

-- TAGS (unique per owner_id, name)
WITH need AS (SELECT COUNT(*) c FROM tags)
INSERT INTO tags (id, owner_id, name, color, created_at)
SELECT
    gen_random_uuid(),
    u.id,
    ('tag_'||((gs-1) % 50))::citext,    -- each user up to 50 unique tag names
  to_hex( (random()*16777215)::int ), -- random hex color
  NOW() - ((random()*60)::int || ' days')::interval
FROM generate_series(1, (SELECT CASE WHEN c=0 THEN 15000 ELSE 0 END FROM need)) gs
    JOIN tmp_users u
ON u.rn = 1 + ( (gs-1) % (SELECT COUNT(*) FROM tmp_users) )
    ON CONFLICT DO NOTHING;

-- Temporary table for tags
DROP TABLE IF EXISTS tmp_tags;
CREATE TEMP TABLE tmp_tags AS
SELECT row_number() OVER()::int rn, id, owner_id
FROM tags;
CREATE INDEX ON tmp_tags(rn);

-- TASKS
-- Each task randomly assigned to a project and optionally an assignee; random timestamps
WITH need AS (SELECT COUNT(*) c FROM tasks)
INSERT INTO tasks (id, project_id, assignee_id, title, description, status, priority,
                   due_date, completed_at, estimate_minutes, version, created_at, updated_at)
SELECT
    gen_random_uuid(),
    p.id AS project_id,
    CASE WHEN random() < 0.15 THEN NULL ELSE u.id END AS assignee_id,
    'Task '||gs,
    'Lorem ipsum task #'||gs,
    (ARRAY['TODO','IN_PROGRESS','DONE','CANCELLED'])[1 + (random()*3)::int]::task_status,
  (ARRAY['LOW','MEDIUM','HIGH','CRITICAL'])[1 + (random()*3)::int]::task_priority,
  CASE WHEN random() < 0.70
       THEN (NOW() + ((random()*45)::int || ' days')::interval)
       ELSE NULL END,
  CASE WHEN random() < 0.35
       THEN (NOW() - ((random()*10)::int || ' days')::interval)
       ELSE NULL END,
  (10 + (random()*290)::int),
  0,
  NOW() - ((random()*120)::int || ' days')::interval,
  NOW()
FROM generate_series(1, (SELECT CASE WHEN c=0 THEN 200000 ELSE 0 END FROM need)) gs
JOIN tmp_projects p ON p.rn = 1 + ((gs * 7) % (SELECT COUNT(*) FROM tmp_projects))
JOIN tmp_users    u ON u.rn = 1 + ((gs * 11) % (SELECT COUNT(*) FROM tmp_users));

-- Temporary table for tasks
DROP TABLE IF EXISTS tmp_tasks;
CREATE TEMP TABLE tmp_tasks AS
SELECT row_number() OVER()::int rn, id, project_id, assignee_id
FROM tasks;
CREATE INDEX ON tmp_tasks(rn);

-- TASK_TAGS (M:N) – assign 0..3 tags randomly; ensure unique (task_id, tag_id)
WITH need AS (SELECT COUNT(*) c FROM task_tags)
INSERT INTO task_tags (task_id, tag_id, added_at)
SELECT DISTINCT ON (t.id, tg.id)
    t.id,
    tg.id,
    NOW() - ((random()*50)::int || ' days')::interval
FROM generate_series(1, (SELECT CASE WHEN c=0 THEN 300000 ELSE 0 END FROM need)) gs
    JOIN tmp_tasks t ON t.rn = 1 + ((gs * 5) % (SELECT COUNT(*) FROM tmp_tasks))
    JOIN tmp_tags  tg ON tg.rn = 1 + ((gs * 19 + (random()*5)::int) % (SELECT COUNT(*) FROM tmp_tags))
    ON CONFLICT DO NOTHING;

-- 6) NOTIFICATION SERVICE: subscriptions + notifications
SET search_path = notification_service, public;

-- SUBSCRIPTIONS: each user 0–3 channels, unique (user_id, channel)
-- Channel distribution: INAPP ~70%, EMAIL ~50%, WEBHOOK ~20%
WITH need AS (SELECT COUNT(*) c FROM notification_subscriptions),
     chans AS (
         SELECT unnest(ARRAY['INAPP','EMAIL','WEBHOOK'])::notif_channel ch
     )
INSERT INTO notification_subscriptions(id, user_id, channel, is_enabled, created_at)
SELECT
    gen_random_uuid(),
    u.id,
    ch.ch,
    (random() < 0.9),
    NOW() - ((random()*120)::int || ' days')::interval
FROM tmp_users u
    CROSS JOIN chans ch
    JOIN need n ON TRUE
WHERE n.c = 0
  AND (
    (ch.ch = 'INAPP'   AND random() < 0.7) OR
    (ch.ch = 'EMAIL'   AND random() < 0.5) OR
    (ch.ch = 'WEBHOOK' AND random() < 0.2)
    )
ON CONFLICT DO NOTHING;

-- NOTIFICATIONS: sent to random users, optionally linked to a task
WITH need AS (SELECT COUNT(*) c FROM notifications)
INSERT INTO notifications (id, user_id, channel, title, body, related_task_id,
                           scheduled_at, sent_at, status, error, created_at, updated_at)
SELECT
    gen_random_uuid(),
    u.id,
    (ARRAY['INAPP','EMAIL','WEBHOOK'])[1 + (random()*2)::int]::notif_channel,
  'Notice #'||gs,
  CASE WHEN random() < 0.8 THEN 'Auto-generated notice' ELSE NULL END,
  CASE WHEN random() < 0.25
       THEN (SELECT id FROM tmp_tasks ORDER BY random() LIMIT 1)
       ELSE NULL END,
  CASE WHEN random() < 0.20
       THEN NOW() + ((random()*7)::int || ' days')::interval
       ELSE NULL END,
  CASE WHEN random() < 0.65
       THEN NOW() - ((random()*3)::int || ' days')::interval
       ELSE NULL END,
  (ARRAY['PENDING','SENT','FAILED'])[1 + (random()*2)::int]::notif_status,
  CASE WHEN random() < 0.05 THEN 'Simulated delivery error' ELSE NULL END,
  NOW() - ((random()*60)::int || ' days')::interval,
  NOW()
FROM generate_series(1, (SELECT CASE WHEN c=0 THEN 400000 ELSE 0 END FROM need)) gs
JOIN tmp_users u
  ON u.rn = 1 + ((gs * 23) % (SELECT COUNT(*) FROM tmp_users));

-- SCHEDULED JOBS (a few static records)
INSERT INTO scheduled_jobs(id, job_key, cron_expr, is_active, last_run_at, next_run_at, created_at)
VALUES
    (gen_random_uuid(), 'due-reminder-v1',     '0 */5 * * * *', TRUE, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '5 minutes', NOW()),
    (gen_random_uuid(), 'digest-email-daily',  '0 0 7 * * *',  TRUE, NOW() - INTERVAL '1 day',     NOW() + INTERVAL '1 day',     NOW()),
    (gen_random_uuid(), 'cleanup-failed-notif','0 */30 * * * *',TRUE, NOW() - INTERVAL '30 minutes',NOW() + INTERVAL '30 minutes',NOW())
    ON CONFLICT (job_key) DO NOTHING;

-- 7) ANALYZE to optimize query plans
ANALYZE user_service.users;
ANALYZE user_service.roles;
ANALYZE user_service.user_roles;

ANALYZE project_service.projects;
ANALYZE project_service.project_members;

ANALYZE task_service.tasks;
ANALYZE task_service.tags;
ANALYZE task_service.task_tags;

ANALYZE notification_service.notification_subscriptions;
ANALYZE notification_service.notifications;
ANALYZE notification_service.scheduled_jobs;

-- 8) Optional useful indexes for performance testing
-- CREATE INDEX IF NOT EXISTS idx_tasks_assignee_created ON task_service.tasks(assignee_id, created_at DESC);
-- CREATE INDEX IF NOT EXISTS idx_task_tags_tag ON task_service.task_tags(tag_id);
-- CREATE INDEX IF NOT EXISTS idx_projects_owner_created ON project_service.projects(owner_id, created_at DESC);
-- CREATE INDEX IF NOT EXISTS idx_notif_status_created ON notification_service.notifications(status, created_at DESC);
