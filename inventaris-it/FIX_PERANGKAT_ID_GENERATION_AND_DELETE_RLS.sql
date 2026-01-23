-- ============================================================
-- FIX: Make perangkat ID generation atomic + enable DELETE
--
-- Goals:
-- 1) Ensure id_perangkat (and nama_perangkat) are generated inside INSERT,
--    so frontend cannot accidentally show/produce duplicate "urutan".
-- 2) Enforce global uniqueness of RIGHT(id_perangkat, 4) with a partial unique index.
-- 3) Allow DELETE for:
--    - profiles.role = 'administrator'
--    - user_categories.name = 'Koordinator IT Support' (standard users)
--    - (optional legacy) profiles.role = 'it_support'
--
-- Run in Supabase SQL Editor.
-- ============================================================

BEGIN;

-- Lock: prevent concurrent creation while we enforce constraints
SELECT pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));

-- 0) SAFETY CHECK (no auto-fix):
-- If duplicates exist today, you will manually delete them first.
DO $$
DECLARE
  v_dup_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_dup_count
  FROM (
    SELECT RIGHT(id_perangkat, 4) AS urutan4
    FROM perangkat
    WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
    GROUP BY RIGHT(id_perangkat, 4)
    HAVING COUNT(*) > 1
  ) d;

  IF v_dup_count > 0 THEN
    RAISE EXCEPTION
      'Cannot enforce uniqueness: found % duplicated urutan(4). Please delete duplicates first, then re-run this script.',
      v_dup_count
      USING ERRCODE = '23514';
  END IF;
END $$;

-- 1) Enforce global uniqueness of the last 4 digits for valid IDs
CREATE UNIQUE INDEX IF NOT EXISTS perangkat_urutan4_global_unique
ON perangkat ((RIGHT(id_perangkat, 4)))
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';

-- 2) Ensure generate_id_perangkat() is the GLOBAL-UNIQUE implementation
-- (Some DBs may still have the older per-kode/per-month implementation.)
CREATE OR REPLACE FUNCTION public.generate_id_perangkat(p_kode TEXT)
RETURNS TEXT AS $$
DECLARE
  v_tahun TEXT;
  v_bulan_single TEXT; -- 1-12 (no leading zero)
  v_urutan INT;
  v_urutan_str TEXT;
  v_id_perangkat TEXT;
  v_max_sequence INT;
BEGIN
  v_tahun := TO_CHAR(NOW(), 'YYYY');
  v_bulan_single := TO_CHAR(NOW(), 'FMMM');

  -- Global lock to avoid race conditions in concurrent calls
  PERFORM pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));

  SELECT COALESCE(
    MAX(CAST(RIGHT(id_perangkat, 4) AS INTEGER)),
    0
  )
  INTO v_max_sequence
  FROM perangkat
  WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';

  v_urutan := v_max_sequence + 1;
  v_urutan_str := LPAD(v_urutan::TEXT, 4, '0');
  v_id_perangkat := p_kode || '.' || v_tahun || '.' || v_bulan_single || '.' || v_urutan_str;

  RETURN v_id_perangkat;
END;
$$ LANGUAGE plpgsql;

-- 3) Trigger: generate id_perangkat + nama_perangkat on insert when missing (atomic)
CREATE OR REPLACE FUNCTION public.perangkat_before_insert_generate_ids()
RETURNS TRIGGER AS $$
DECLARE
  v_max_sequence INT;
  v_tahun TEXT;
  v_bulan_single TEXT;
  v_urutan INT;
  v_urutan_str TEXT;
BEGIN
  -- Global lock so the next "urutan4" cannot collide under concurrency
  PERFORM pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));

  -- If id_perangkat not provided, generate it (atomic in the same transaction)
  IF NEW.id_perangkat IS NULL OR NEW.id_perangkat = '' THEN
    -- Generate next global sequence directly here (don't depend on old function behavior)
    v_tahun := TO_CHAR(NOW(), 'YYYY');
    v_bulan_single := TO_CHAR(NOW(), 'FMMM');

    SELECT COALESCE(
      MAX(CAST(RIGHT(id_perangkat, 4) AS INTEGER)),
      0
    )
    INTO v_max_sequence
    FROM perangkat
    WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';

    v_urutan := v_max_sequence + 1;
    v_urutan_str := LPAD(v_urutan::TEXT, 4, '0');
    NEW.id_perangkat := NEW.jenis_perangkat_kode || '.' || v_tahun || '.' || v_bulan_single || '.' || v_urutan_str;
  END IF;

  -- If nama_perangkat not provided, build it from lokasi_kode + last4
  IF (NEW.nama_perangkat IS NULL OR NEW.nama_perangkat = '')
     AND NEW.lokasi_kode IS NOT NULL
     AND NEW.lokasi_kode <> '' THEN
    NEW.nama_perangkat := NEW.lokasi_kode || '-' || RIGHT(NEW.id_perangkat, 4);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS perangkat_before_insert_generate_ids ON perangkat;
CREATE TRIGGER perangkat_before_insert_generate_ids
BEFORE INSERT ON perangkat
FOR EACH ROW
EXECUTE FUNCTION public.perangkat_before_insert_generate_ids();

-- 4) RLS: allow DELETE for administrator + koordinator IT support (+ legacy it_support)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'perangkat'
      AND policyname = 'Allow delete perangkat for admin/koordinator'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Allow delete perangkat for admin/koordinator"
      ON perangkat
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM profiles p
          LEFT JOIN user_categories uc ON uc.id = p.user_category_id
          WHERE p.id = auth.uid()
            AND (
              p.role = 'administrator'
              OR p.role = 'it_support'
              OR uc.name = 'Koordinator IT Support'
            )
        )
      );
    $policy$;
  END IF;
END $$;

COMMIT;

-- ============================================================
-- Helpful query (run BEFORE re-running this script):
-- Shows all duplicates to review & delete manually.
-- ============================================================
-- SELECT RIGHT(id_perangkat, 4) AS urutan4, COUNT(*) AS cnt,
--        STRING_AGG(id_perangkat, ', ' ORDER BY id_perangkat) AS ids
-- FROM perangkat
-- WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
-- GROUP BY RIGHT(id_perangkat, 4)
-- HAVING COUNT(*) > 1
-- ORDER BY urutan4;

