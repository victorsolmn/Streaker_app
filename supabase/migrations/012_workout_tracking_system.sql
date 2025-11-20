-- Migration: Workout Tracking System
-- Created: 2025-11-20
-- Description: Add interactive workout tracking with AI-generated workouts
-- Tables: workout_sessions, workout_sets, workout_templates

-- ============================================================================
-- WORKOUT SESSIONS TABLE
-- Stores completed workout sessions with metadata and stats
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.workout_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Session Metadata
  workout_name TEXT NOT NULL,
  workout_type TEXT, -- "Strength", "Cardio", "Full Body", "HIIT", etc.
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (completed_at - started_at)) / 60
  ) STORED,

  -- Workout Stats (aggregated from sets)
  total_exercises INTEGER DEFAULT 0,
  total_sets INTEGER DEFAULT 0,
  total_reps INTEGER DEFAULT 0,
  total_volume_kg DECIMAL(10,2) DEFAULT 0, -- sum(weight_kg × reps)

  -- Additional Context
  notes TEXT,
  ai_generated BOOLEAN DEFAULT false,
  template_id UUID, -- Reference to workout_templates if created from template

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_duration CHECK (completed_at >= started_at),
  CONSTRAINT valid_stats CHECK (
    total_exercises >= 0 AND
    total_sets >= 0 AND
    total_reps >= 0 AND
    total_volume_kg >= 0
  )
);

-- ============================================================================
-- WORKOUT SETS TABLE
-- Stores individual exercise set data for each workout session
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.workout_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,

  -- Exercise Information
  exercise_name TEXT NOT NULL,
  exercise_order INTEGER NOT NULL, -- Order of exercise in the workout (1, 2, 3...)
  set_number INTEGER NOT NULL, -- Set number for this exercise (1, 2, 3...)

  -- Performance Data
  reps_completed INTEGER NOT NULL,
  weight_kg DECIMAL(6,2), -- NULL for bodyweight exercises
  rest_seconds INTEGER DEFAULT 60,

  -- Metadata
  notes TEXT,
  skipped BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_exercise_order CHECK (exercise_order > 0),
  CONSTRAINT valid_set_number CHECK (set_number > 0),
  CONSTRAINT valid_reps CHECK (reps_completed >= 0),
  CONSTRAINT valid_weight CHECK (weight_kg IS NULL OR weight_kg >= 0),
  CONSTRAINT valid_rest CHECK (rest_seconds >= 0)
);

-- ============================================================================
-- WORKOUT TEMPLATES TABLE
-- Stores saved workout templates (AI-generated or user-created)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Template Information
  name TEXT NOT NULL,
  description TEXT,
  workout_type TEXT, -- "Strength", "Cardio", "Full Body", etc.
  estimated_duration_minutes INTEGER,
  equipment_needed TEXT[], -- ["Dumbbells", "Barbell", "Bodyweight", etc.]
  difficulty_level TEXT CHECK (difficulty_level IN ('Beginner', 'Intermediate', 'Advanced')),

  -- Exercise Data (stored as JSONB for flexibility)
  exercises JSONB NOT NULL,
  /* Example structure:
  [
    {
      "name": "Push-ups",
      "sets": 3,
      "reps": 10,
      "rest_seconds": 60,
      "weight_kg": null,
      "notes": "Keep core tight",
      "muscle_groups": ["Chest", "Triceps", "Shoulders"]
    },
    {
      "name": "Squats",
      "sets": 4,
      "reps": 15,
      "rest_seconds": 90,
      "weight_kg": 60,
      "notes": "Full depth",
      "muscle_groups": ["Quads", "Glutes", "Hamstrings"]
    }
  ]
  */

  -- Template Metadata
  is_favorite BOOLEAN DEFAULT false,
  times_completed INTEGER DEFAULT 0,
  last_completed_at TIMESTAMPTZ,
  source TEXT DEFAULT 'user' CHECK (source IN ('user', 'ai')),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_duration CHECK (estimated_duration_minutes IS NULL OR estimated_duration_minutes > 0),
  CONSTRAINT valid_exercises CHECK (jsonb_array_length(exercises) > 0)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Workout Sessions Indexes
CREATE INDEX idx_workout_sessions_user_id ON public.workout_sessions(user_id);
CREATE INDEX idx_workout_sessions_user_date ON public.workout_sessions(user_id, completed_at DESC);
CREATE INDEX idx_workout_sessions_workout_type ON public.workout_sessions(workout_type);
CREATE INDEX idx_workout_sessions_template ON public.workout_sessions(template_id) WHERE template_id IS NOT NULL;

-- Workout Sets Indexes
CREATE INDEX idx_workout_sets_session_id ON public.workout_sets(session_id);
CREATE INDEX idx_workout_sets_exercise_order ON public.workout_sets(session_id, exercise_order, set_number);

-- Workout Templates Indexes
CREATE INDEX idx_workout_templates_user_id ON public.workout_templates(user_id);
CREATE INDEX idx_workout_templates_favorite ON public.workout_templates(user_id, is_favorite) WHERE is_favorite = true;
CREATE INDEX idx_workout_templates_source ON public.workout_templates(source);
CREATE INDEX idx_workout_templates_workout_type ON public.workout_templates(workout_type);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_templates ENABLE ROW LEVEL SECURITY;

-- Workout Sessions Policies
CREATE POLICY "Users can view own workout sessions"
  ON public.workout_sessions
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own workout sessions"
  ON public.workout_sessions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workout sessions"
  ON public.workout_sessions
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own workout sessions"
  ON public.workout_sessions
  FOR DELETE
  USING (auth.uid() = user_id);

-- Workout Sets Policies (cascade from sessions)
CREATE POLICY "Users can view own workout sets"
  ON public.workout_sets
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.workout_sessions
      WHERE workout_sessions.id = workout_sets.session_id
      AND workout_sessions.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create workout sets"
  ON public.workout_sets
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workout_sessions
      WHERE workout_sessions.id = workout_sets.session_id
      AND workout_sessions.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update workout sets"
  ON public.workout_sets
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.workout_sessions
      WHERE workout_sessions.id = workout_sets.session_id
      AND workout_sessions.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete workout sets"
  ON public.workout_sets
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.workout_sessions
      WHERE workout_sessions.id = workout_sets.session_id
      AND workout_sessions.user_id = auth.uid()
    )
  );

-- Workout Templates Policies
CREATE POLICY "Users can view own workout templates"
  ON public.workout_templates
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own workout templates"
  ON public.workout_templates
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workout templates"
  ON public.workout_templates
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own workout templates"
  ON public.workout_templates
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to update workout session stats after sets are added
CREATE OR REPLACE FUNCTION public.update_workout_session_stats()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.workout_sessions
  SET
    total_sets = (
      SELECT COUNT(*)
      FROM public.workout_sets
      WHERE session_id = NEW.session_id
      AND skipped = false
    ),
    total_reps = (
      SELECT COALESCE(SUM(reps_completed), 0)
      FROM public.workout_sets
      WHERE session_id = NEW.session_id
      AND skipped = false
    ),
    total_volume_kg = (
      SELECT COALESCE(SUM(COALESCE(weight_kg, 0) * reps_completed), 0)
      FROM public.workout_sets
      WHERE session_id = NEW.session_id
      AND skipped = false
    ),
    total_exercises = (
      SELECT COUNT(DISTINCT exercise_order)
      FROM public.workout_sets
      WHERE session_id = NEW.session_id
      AND skipped = false
    ),
    updated_at = NOW()
  WHERE id = NEW.session_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment template completion count
CREATE OR REPLACE FUNCTION public.increment_template_usage()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.template_id IS NOT NULL THEN
    UPDATE public.workout_templates
    SET
      times_completed = times_completed + 1,
      last_completed_at = NEW.completed_at,
      updated_at = NOW()
    WHERE id = NEW.template_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update workout session stats when sets are added/modified
CREATE TRIGGER trigger_update_workout_stats
  AFTER INSERT OR UPDATE ON public.workout_sets
  FOR EACH ROW
  EXECUTE FUNCTION public.update_workout_session_stats();

-- Increment template usage count when workout is completed
CREATE TRIGGER trigger_increment_template_usage
  AFTER INSERT ON public.workout_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_template_usage();

-- Update timestamps on workout_sessions
CREATE TRIGGER trigger_workout_sessions_updated_at
  BEFORE UPDATE ON public.workout_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Update timestamps on workout_templates
CREATE TRIGGER trigger_workout_templates_updated_at
  BEFORE UPDATE ON public.workout_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- GRANTS
-- ============================================================================

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_sets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_templates TO authenticated;

-- Grant usage on sequences (for auto-generated IDs)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Workout Tracking System migration completed successfully!';
  RAISE NOTICE '📊 Created tables: workout_sessions, workout_sets, workout_templates';
  RAISE NOTICE '🔒 RLS policies enabled for user data isolation';
  RAISE NOTICE '⚡ Triggers configured for automatic stat updates';
  RAISE NOTICE '🎯 Ready for interactive AI workout tracking!';
END $$;
