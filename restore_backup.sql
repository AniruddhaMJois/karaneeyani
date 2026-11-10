-- ====================================================================
-- KARANEEYAANI DATABASE RESTORATION FROM BACKUP
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/tkxwdjmydomimtykvjle/sql
-- ====================================================================

-- 1. Create goals table
CREATE TABLE IF NOT EXISTS public.goals (
    id text NOT NULL,
    user_id text NOT NULL,
    title text NOT NULL,
    description text DEFAULT ''::text,
    category text DEFAULT ''::text,
    status text DEFAULT 'active'::text NOT NULL,
    end_date timestamp with time zone,
    selected_dates text[] DEFAULT '{}'::text[],
    order_index integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT goals_pkey PRIMARY KEY (id),
    CONSTRAINT goals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'trashed'::text])))
);

ALTER TABLE public.goals OWNER TO postgres;

-- 2. Create tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id text NOT NULL,
    user_id text NOT NULL,
    title text NOT NULL,
    description text DEFAULT ''::text,
    status text DEFAULT 'active'::text NOT NULL,
    is_completed boolean DEFAULT false NOT NULL,
    completed_at timestamp with time zone,
    end_date timestamp with time zone,
    has_alarm boolean DEFAULT false NOT NULL,
    alarm_time timestamp with time zone,
    goal_id text,
    order_index integer DEFAULT 0 NOT NULL,
    repeat_days integer[] DEFAULT '{}'::integer[],
    progress_status text DEFAULT ''::text,
    extension_series_id text,
    extended_days_count integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT tasks_pkey PRIMARY KEY (id),
    CONSTRAINT tasks_status_check CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'trashed'::text])))
);

ALTER TABLE public.tasks OWNER TO postgres;

-- 3. Create users_auth table
CREATE TABLE IF NOT EXISTS public.users_auth (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id text NOT NULL,
    username text NOT NULL,
    pin_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_auth_pkey PRIMARY KEY (id),
    CONSTRAINT users_auth_user_id_key UNIQUE (user_id),
    CONSTRAINT users_auth_username_key UNIQUE (username)
);

ALTER TABLE public.users_auth OWNER TO postgres;

-- 4. Create Indexes
CREATE INDEX IF NOT EXISTS idx_goals_status ON public.goals USING btree (status);
CREATE INDEX IF NOT EXISTS idx_goals_user_id ON public.goals USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_completed_at ON public.tasks USING btree (completed_at);
CREATE INDEX IF NOT EXISTS idx_tasks_end_date ON public.tasks USING btree (end_date);
CREATE INDEX IF NOT EXISTS idx_tasks_extension_series ON public.tasks USING btree (extension_series_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks USING btree (status);
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON public.tasks USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users_auth USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_users_auth_username ON public.users_auth USING btree (lower(username));

-- 5. Row Level Security & Policies
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_auth ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Allow users to manage their own goals" ON public.goals;
    DROP POLICY IF EXISTS "Allow users to manage their own tasks" ON public.tasks;
    DROP POLICY IF EXISTS "Allow public read/insert on users_auth" ON public.users_auth;
END $$;

CREATE POLICY "Allow users to manage their own goals" ON public.goals TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow users to manage their own tasks" ON public.tasks TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/insert on users_auth" ON public.users_auth TO authenticated, anon USING (true) WITH CHECK (true);

-- 6. Role Grants
GRANT ALL ON TABLE public.goals TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.tasks TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.users_auth TO anon, authenticated, service_role;

-- 7. Restore Data from Backup
INSERT INTO public.users_auth (id, user_id, username, pin_hash, created_at, updated_at) 
VALUES ('f5053d74-0f29-4502-9371-57484419c9bf', '6e57b9a0-0f61-48bd-a49d-1f5bcbe279cf', 'flow_master', '5b0fdedeb861f02b93c3337c5983e5e47b8522db84d3a391362546221dc67ba4', '2026-10-21 16:11:42.218+00', '2026-10-21 16:11:42.219+00')
ON CONFLICT (id) DO NOTHING;
