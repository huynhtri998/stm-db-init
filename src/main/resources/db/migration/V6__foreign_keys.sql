-- USER references
ALTER TABLE project_service.projects
    ADD CONSTRAINT fk_projects_owner
        FOREIGN KEY (owner_id)
            REFERENCES user_service.users(id)
            ON DELETE CASCADE;

ALTER TABLE project_service.project_members
    ADD CONSTRAINT fk_project_members_project
        FOREIGN KEY (project_id)
            REFERENCES project_service.projects(id)
            ON DELETE CASCADE;

ALTER TABLE project_service.project_members
    ADD CONSTRAINT fk_project_members_user
        FOREIGN KEY (user_id)
            REFERENCES user_service.users(id)
            ON DELETE CASCADE;

ALTER TABLE task_service.tasks
    ADD CONSTRAINT fk_tasks_assignee
        FOREIGN KEY (assignee_id)
            REFERENCES user_service.users(id)
            ON DELETE SET NULL;

ALTER TABLE task_service.tags
    ADD CONSTRAINT fk_tags_owner
        FOREIGN KEY (owner_id)
            REFERENCES user_service.users(id)
            ON DELETE CASCADE;

ALTER TABLE task_service.tasks
    ADD CONSTRAINT fk_tasks_project
        FOREIGN KEY (project_id)
            REFERENCES project_service.projects(id)
            ON DELETE SET NULL;

ALTER TABLE task_service.task_tags
    ADD CONSTRAINT fk_task_tags_task
        FOREIGN KEY (task_id)
            REFERENCES task_service.tasks(id)
            ON DELETE CASCADE;

ALTER TABLE task_service.task_tags
    ADD CONSTRAINT fk_task_tags_tag
        FOREIGN KEY (tag_id)
            REFERENCES task_service.tags(id)
            ON DELETE CASCADE;

ALTER TABLE notification_service.notification_subscriptions
    ADD CONSTRAINT fk_notif_sub_user
        FOREIGN KEY (user_id)
            REFERENCES user_service.users(id)
            ON DELETE CASCADE;

ALTER TABLE notification_service.notifications
    ADD CONSTRAINT fk_notif_user
        FOREIGN KEY (user_id)
            REFERENCES user_service.users(id)
            ON DELETE CASCADE;

ALTER TABLE notification_service.notifications
    ADD CONSTRAINT fk_notif_task
        FOREIGN KEY (related_task_id)
            REFERENCES task_service.tasks(id)
            ON DELETE SET NULL;
