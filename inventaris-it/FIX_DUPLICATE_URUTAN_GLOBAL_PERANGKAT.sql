-- ============================================================
-- FIX: Duplicate "urutan" (last 4 digits) across perangkat IDs
-- Target: make RIGHT(id_perangkat, 4) globally unique.
--
-- What this script does:
-- 1) Renumbers existing duplicates (keeps the earliest row, renumbers the rest)
-- 2) Adds a DB-level partial UNIQUE index to prevent recurrence
--
-- Safe assumptions:
-- - Primary key is perangkat.id (UUID)
-- - id_perangkat format: XXX.YYYY.M(or MM).NNNN (NNNN is the "urutan")
-- - We only touch rows matching the valid format regex below
--
-- Run in Supabase SQL editor.
-- ============================================================

BEGIN;

-- Prevent concurrent renumbering / generation while we normalize
SELECT pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));

-- 1) Normalize existing duplicates on the last 4 digits (RIGHT(id_perangkat, 4))
WITH
valid AS (
  SELECT
    id,
    id_perangkat,
    created_at,
    RIGHT(id_perangkat, 4) AS seq4
  FROM perangkat
  WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
),
ranked AS (
  SELECT
    v.*,
    ROW_NUMBER() OVER (
      PARTITION BY v.seq4
      ORDER BY v.created_at NULLS LAST, v.id
    ) AS rn
  FROM valid v
),
to_fix AS (
  -- Keep rn=1 as-is; renumber rn>1
  SELECT
    r.id,
    r.id_perangkat,
    r.created_at,
    r.seq4
  FROM ranked r
  WHERE r.rn > 1
),
ordered AS (
  -- Deterministic ordering of renumbers
  SELECT
    tf.id,
    ROW_NUMBER() OVER (
      ORDER BY tf.seq4, tf.created_at NULLS LAST, tf.id
    ) AS fix_idx
  FROM to_fix tf
),
maxseq AS (
  SELECT
    COALESCE(MAX(CAST(RIGHT(id_perangkat, 4) AS INTEGER)), 0) AS max_seq
  FROM perangkat
  WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
)
UPDATE perangkat p
SET id_perangkat =
  regexp_replace(
    p.id_perangkat,
    '[0-9]{4}$',
    LPAD((maxseq.max_seq + ordered.fix_idx)::TEXT, 4, '0')
  )
FROM ordered, maxseq
WHERE p.id = ordered.id;

-- 2) Enforce global uniqueness of the last 4 digits going forward
-- Partial index: only applies to rows with valid format (so legacy/bad-format rows won't block the index)
CREATE UNIQUE INDEX IF NOT EXISTS perangkat_urutan4_global_unique
ON perangkat ((RIGHT(id_perangkat, 4)))
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';

COMMIT;

-- ============================================================
-- Verification queries
-- ============================================================

-- Any remaining duplicate urutan (should be zero rows)
SELECT
  RIGHT(id_perangkat, 4) AS urutan4,
  COUNT(*) AS cnt,
  STRING_AGG(id_perangkat, ', ' ORDER BY id_perangkat) AS ids
FROM perangkat
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
GROUP BY RIGHT(id_perangkat, 4)
HAVING COUNT(*) > 1
ORDER BY urutan4;

-- Show the current highest urutan (sanity check)
SELECT
  id_perangkat,
  RIGHT(id_perangkat, 4) AS urutan4,
  created_at
FROM perangkat
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
ORDER BY CAST(RIGHT(id_perangkat, 4) AS INTEGER) DESC
LIMIT 20;

