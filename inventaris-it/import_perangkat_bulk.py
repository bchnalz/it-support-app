#!/usr/bin/env python3
"""
Bulk Import Script for Perangkat Data
Handles 793+ records with automatic transformations and storage handling
"""

import csv
import os
import sys
from datetime import datetime
from typing import List, Dict, Optional
from supabase import create_client, Client

# Fix Windows console encoding for emojis
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# Try to load from .env file if python-dotenv is available
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv not installed, will use environment variables only

# Configuration - Support both Python and Vite naming conventions
SUPABASE_URL = os.environ.get("SUPABASE_URL") or os.environ.get("VITE_SUPABASE_URL", "")
# Prefer service role key (bypasses RLS) for bulk imports, fallback to anon key
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY") or os.environ.get("VITE_SUPABASE_ANON_KEY", "")
BATCH_SIZE = 100  # Insert in batches for better performance

def init_supabase() -> Client:
    """Initialize Supabase client"""
    if not SUPABASE_URL:
        print("❌ ERROR: SUPABASE_URL not set!")
        print("\n📝 How to set it:")
        print("   Option 1: Set environment variable:")
        print("     Windows PowerShell: $env:SUPABASE_URL='your-url'")
        print("     Windows CMD: set SUPABASE_URL=your-url")
        print("     Linux/Mac: export SUPABASE_URL='your-url'")
        print("\n   Option 2: Create .env file in same directory:")
        print("     SUPABASE_URL=your-url")
        print("     SUPABASE_KEY=your-key")
        print("\n   Option 3: Edit this script and set values directly")
        sys.exit(1)
    
    if not SUPABASE_KEY:
        print("❌ ERROR: SUPABASE_KEY not set!")
        print("\n📝 How to set it:")
        print("   Option 1: Set environment variable:")
        print("     Windows PowerShell: $env:SUPABASE_KEY='your-key'")
        print("     Windows CMD: set SUPABASE_KEY=your-key")
        print("     Linux/Mac: export SUPABASE_KEY='your-key'")
        print("\n   Option 2: Create .env file in same directory:")
        print("     SUPABASE_URL=your-url")
        print("     SUPABASE_KEY=your-key")
        print("\n   Option 3: Edit this script and set values directly")
        sys.exit(1)
    
    # Validate URL format
    if not SUPABASE_URL.startswith('http'):
        print(f"❌ ERROR: Invalid SUPABASE_URL format: {SUPABASE_URL}")
        print("   URL should start with https://")
        sys.exit(1)
    
    try:
        return create_client(SUPABASE_URL, SUPABASE_KEY)
    except Exception as e:
        print(f"❌ ERROR: Failed to create Supabase client: {e}")
        print(f"   URL: {SUPABASE_URL[:50]}...")
        print(f"   Key: {SUPABASE_KEY[:20]}...")
        sys.exit(1)

def convert_date(date_str: str) -> Optional[str]:
    """Parse date from various formats (DD/MM/YYYY HH:MM, MM/DD/YYYY HH:MM, etc.) to ISO format"""
    if not date_str or date_str.strip() == '-' or not date_str.strip():
        return None
    
    date_str = date_str.strip()
    
    # Try multiple date formats
    formats = [
        '%d/%m/%Y %H:%M',      # DD/MM/YYYY HH:MM
        '%m/%d/%Y %H:%M',      # MM/DD/YYYY HH:MM
        '%d/%m/%Y',            # DD/MM/YYYY
        '%m/%d/%Y',            # MM/DD/YYYY
        '%Y-%m-%d %H:%M:%S',   # ISO with time
        '%Y-%m-%d',            # ISO date only
    ]
    
    for fmt in formats:
        try:
            dt = datetime.strptime(date_str, fmt)
            return dt.isoformat()
        except ValueError:
            continue
    
    # If all formats fail, try to parse with dateutil (more flexible)
    try:
        from dateutil import parser
        dt = parser.parse(date_str)
        return dt.isoformat()
    except (ImportError, ValueError):
        pass
    
    print(f"⚠️  Warning: Could not parse date '{date_str}' - using None")
    return None

def clean_value(value: str) -> Optional[str]:
    """Clean value: trim spaces, convert '-' to None"""
    if not value:
        return None
    value = value.strip()
    if value == '-' or value == '':
        return None
    return value

def validate_uuids(supabase: Client, csv_file: str) -> Dict[str, bool]:
    """Pre-validate that all UUIDs exist in database"""
    print("🔍 Validating UUIDs...")
    
    petugas_ids = set()
    jenis_barang_ids = set()
    jenis_perangkat_codes = set()
    lokasi_codes = set()
    
    # Detect delimiter first
    with open(csv_file, 'r', encoding='utf-8') as f:
        first_line = f.readline()
        tab_count = first_line.count('\t')
        comma_count = first_line.count(',')
        semicolon_count = first_line.count(';')
        
        if semicolon_count > 0 and semicolon_count >= max(tab_count, comma_count):
            delimiter = ';'
        elif tab_count > comma_count:
            delimiter = '\t'
        else:
            delimiter = ','
        f.seek(0)
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=delimiter)
        for row in reader:
            if row.get('petugas_id'):
                # Clean UUID: strip whitespace
                petugas_ids.add(row['petugas_id'].strip())
            if row.get('jenis_barang'):
                jenis_barang_ids.add(row['jenis_barang'].strip())
            if row.get('jenis_perangkat_kode'):
                jenis_perangkat_codes.add(row['jenis_perangkat_kode'].strip())
            if row.get('lokasi_kode'):
                lokasi_codes.add(row['lokasi_kode'].strip())
    
    # Check petugas_ids
    if petugas_ids:
        # Convert to list and ensure proper UUID format
        petugas_list = list(petugas_ids)
        print(f"🔍 Checking {len(petugas_list)} petugas_id UUIDs...")
        print(f"   Sample UUIDs from CSV: {list(petugas_list)[:2]}")
        
        # Test if we can query profiles at all
        try:
            test_result = supabase.table('profiles').select('id').limit(1).execute()
            print(f"   ✅ Can query profiles table (test query returned {len(test_result.data)} row)")
        except Exception as e:
            print(f"   ⚠️ WARNING: Cannot query profiles table - RLS might be blocking: {e}")
            print(f"   💡 Tip: If UUIDs exist but query fails, use --skip-validation flag")
            return {'valid': False, 'reason': 'Cannot query profiles table - RLS blocking?'}
        
        # Try querying all at once first
        try:
            result = supabase.table('profiles').select('id').in_('id', petugas_list).execute()
            found_petugas = {str(p['id']) for p in result.data}  # Convert to string for comparison
            print(f"   Query returned {len(result.data)} profiles")
        except Exception as e:
            print(f"   ⚠️ Batch query failed: {e}")
            print(f"   💡 This might be an RLS policy issue. Try --skip-validation if UUIDs are correct.")
            # Fallback: query one by one
            found_petugas = set()
            for uuid in petugas_list[:3]:  # Test first 3 only
                try:
                    result = supabase.table('profiles').select('id').eq('id', uuid).execute()
                    if result.data:
                        found_petugas.add(str(uuid))
                        print(f"   ✅ Found: {uuid[:8]}...")
                    else:
                        print(f"   ❌ Not found: {uuid[:8]}...")
                except Exception as e2:
                    print(f"   ⚠️ Error checking {uuid[:8]}...: {e2}")
            
            if len(found_petugas) == 0:
                print(f"   ⚠️ WARNING: Could not find any UUIDs. This might be RLS blocking the query.")
                print(f"   💡 If you're sure the UUIDs exist, use --skip-validation flag")
                return {'valid': False, 'reason': 'RLS might be blocking profile queries'}
        
        # Convert petugas_ids to strings for comparison
        petugas_ids_str = {str(uuid) for uuid in petugas_ids}
        missing_petugas = petugas_ids_str - found_petugas
        
        if missing_petugas:
            print(f"❌ ERROR: Missing petugas_id UUIDs ({len(missing_petugas)}): {list(missing_petugas)[:5]}")
            if len(missing_petugas) > 5:
                print(f"   ... and {len(missing_petugas) - 5} more")
            # Show what was found for debugging
            print(f"✅ Found {len(found_petugas)}/{len(petugas_ids)} petugas_id UUIDs")
            if found_petugas:
                print(f"📋 Sample found UUIDs: {list(found_petugas)[:3]}")
            print(f"💡 If UUIDs exist but query returns 0, this is likely an RLS policy issue.")
            print(f"   Use --skip-validation to proceed (UUIDs will be validated during insert)")
            return {'valid': False}
        print(f"✅ Validated {len(found_petugas)} petugas_id UUIDs")
    
    # Check jenis_barang_ids
    if jenis_barang_ids:
        jenis_barang_list = list(jenis_barang_ids)
        print(f"🔍 Checking {len(jenis_barang_list)} jenis_barang UUIDs...")
        
        found_jenis_barang = set()
        batch_size = 50
        for i in range(0, len(jenis_barang_list), batch_size):
            batch = jenis_barang_list[i:i+batch_size]
            result = supabase.table('ms_jenis_barang').select('id').in_('id', batch).execute()
            batch_found = {j['id'] for j in result.data}
            found_jenis_barang.update(batch_found)
        
        missing_jenis_barang = jenis_barang_ids - found_jenis_barang
        if missing_jenis_barang:
            print(f"❌ ERROR: Missing jenis_barang UUIDs ({len(missing_jenis_barang)}): {list(missing_jenis_barang)[:5]}")
            if len(missing_jenis_barang) > 5:
                print(f"   ... and {len(missing_jenis_barang) - 5} more")
            return {'valid': False}
        print(f"✅ Validated {len(found_jenis_barang)} jenis_barang UUIDs")
    
    # Check jenis_perangkat_codes
    if jenis_perangkat_codes:
        result = supabase.table('ms_jenis_perangkat').select('kode').in_('kode', list(jenis_perangkat_codes)).execute()
        found_codes = {j['kode'] for j in result.data}
        missing_codes = jenis_perangkat_codes - found_codes
        if missing_codes:
            print(f"❌ ERROR: Missing jenis_perangkat_kode: {missing_codes}")
            return {'valid': False}
        print(f"✅ Validated {len(found_codes)} jenis_perangkat_kode values")
    
    # Check lokasi_codes
    if lokasi_codes:
        result = supabase.table('ms_lokasi').select('kode').in_('kode', list(lokasi_codes)).execute()
        found_lokasi = {l['kode'] for l in result.data}
        missing_lokasi = lokasi_codes - found_lokasi
        if missing_lokasi:
            print(f"❌ ERROR: Missing lokasi_kode: {missing_lokasi}")
            return {'valid': False}
        print(f"✅ Validated {len(found_lokasi)} lokasi_kode values")
    
    print("✅ All UUIDs and codes validated successfully!\n")
    return {'valid': True}

def import_perangkat_from_csv(csv_file: str, supabase: Client, dry_run: bool = False):
    """Import perangkat data from CSV file"""
    
    print(f"📂 Reading CSV file: {csv_file}")
    
    perangkat_records = []
    storage_records = []  # Will be processed after perangkat insert
    errors = []
    
    # Detect delimiter by reading first line
    with open(csv_file, 'r', encoding='utf-8') as f:
        first_line = f.readline()
        # Count delimiters
        tab_count = first_line.count('\t')
        comma_count = first_line.count(',')
        semicolon_count = first_line.count(';')
        
        # Determine delimiter
        if semicolon_count > 0 and semicolon_count >= max(tab_count, comma_count):
            delimiter = ';'
            print(f"📄 Detected delimiter: SEMICOLON ({semicolon_count} found)")
        elif tab_count > comma_count:
            delimiter = '\t'
            print(f"📄 Detected delimiter: TAB ({tab_count} found)")
        else:
            delimiter = ','
            print(f"📄 Detected delimiter: COMMA ({comma_count} found)")
        
        # Reset file pointer
        f.seek(0)
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=delimiter)
        
        for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is row 1)
            try:
                # Prepare perangkat record
                perangkat = {
                    'id_perangkat': row['id_perangkat'].strip(),
                    'petugas_id': row['petugas_id'].strip(),
                    'jenis_perangkat_kode': row['jenis_perangkat_kode'].strip(),
                    'serial_number': row['serial_number'].strip(),
                    'lokasi_kode': row['lokasi_kode'].strip(),
                    'nama_perangkat': row['nama_perangkat'].strip(),
                    'jenis_barang_id': row['jenis_barang'].strip(),  # Column name is jenis_barang but maps to jenis_barang_id
                    'merk': clean_value(row.get('merk', '')),
                    'id_remoteaccess': clean_value(row.get('id_remoteaccess', '')),
                    'spesifikasi_processor': clean_value(row.get('spesifikasi_processor', '')),
                    'kapasitas_ram': clean_value(row.get('kapasitas_ram', '')),
                    'mac_ethernet': clean_value(row.get('mac_ethernet', '')),
                    'mac_wireless': clean_value(row.get('mac_wireless', '')),
                    'ip_ethernet': clean_value(row.get('ip_ethernet', '')),
                    'ip_wireless': clean_value(row.get('ip_wireless', '')),
                    'serial_number_monitor': clean_value(row.get('serial_number_monitor', '')),
                    'tanggal_entry': convert_date(row.get('tanggal_entry', '')),
                    'status_perangkat': 'layak'  # Required: constraint only allows 'layak' or 'rusak'
                }
                
                perangkat_records.append(perangkat)
                
                # Prepare storage records (will link by id_perangkat later)
                ssd_capacity = clean_value(row.get('Kapasitas SSD', ''))
                hdd_capacity = clean_value(row.get('Kapasitas HDD', ''))
                
                if ssd_capacity:
                    storage_records.append({
                        'id_perangkat': perangkat['id_perangkat'],
                        'jenis_storage': 'SSD',
                        'kapasitas': ssd_capacity.strip()
                    })
                
                if hdd_capacity:
                    storage_records.append({
                        'id_perangkat': perangkat['id_perangkat'],
                        'jenis_storage': 'HDD',
                        'kapasitas': hdd_capacity.strip()
                    })
                    
            except Exception as e:
                error_msg = f"Row {row_num}: {str(e)}"
                errors.append(error_msg)
                print(f"⚠️  {error_msg}")
    
    if errors:
        print(f"\n❌ Found {len(errors)} errors during parsing:")
        for error in errors[:10]:  # Show first 10 errors
            print(f"   {error}")
        if len(errors) > 10:
            print(f"   ... and {len(errors) - 10} more errors")
        return
    
    print(f"✅ Parsed {len(perangkat_records)} perangkat records")
    print(f"✅ Prepared {len(storage_records)} storage records\n")
    
    if dry_run:
        print("🔍 DRY RUN MODE - No data will be inserted")
        print(f"   Would insert {len(perangkat_records)} perangkat records")
        print(f"   Would insert {len(storage_records)} storage records")
        return
    
    # Step 1: Bulk insert perangkat (in batches)
    print(f"📤 Inserting {len(perangkat_records)} perangkat records in batches of {BATCH_SIZE}...")
    inserted_count = 0
    failed_count = 0
    failed_records = []
    
    for i in range(0, len(perangkat_records), BATCH_SIZE):
        batch = perangkat_records[i:i+BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        total_batches = (len(perangkat_records) + BATCH_SIZE - 1) // BATCH_SIZE
        
        try:
            result = supabase.table('perangkat').insert(batch).execute()
            if result.data:
                inserted_count += len(batch)
                print(f"   ✅ Batch {batch_num}/{total_batches}: Inserted {len(batch)} records ({inserted_count}/{len(perangkat_records)})")
            else:
                # No data returned - might be RLS blocking
                print(f"   ⚠️  Batch {batch_num}/{total_batches}: Insert returned no data (RLS blocking?)")
                failed_count += len(batch)
                failed_records.extend(batch)
        except Exception as e:
            failed_count += len(batch)
            error_msg = str(e)
            print(f"   ❌ Batch {batch_num}/{total_batches}: Failed - {error_msg}")
            # Show first error details
            if hasattr(e, 'message'):
                print(f"      Error details: {e.message}")
            if hasattr(e, 'code'):
                print(f"      Error code: {e.code}")
            
            # Try inserting one by one to identify problematic records
            print(f"      Attempting individual inserts for batch {batch_num}...")
            for record in batch:
                try:
                    result = supabase.table('perangkat').insert(record).execute()
                    if result.data:
                        inserted_count += 1
                        failed_count -= 1
                        print(f"      ✅ Inserted: {record.get('id_perangkat', 'unknown')}")
                    else:
                        failed_records.append(record)
                        print(f"      ❌ No data returned for: {record.get('id_perangkat', 'unknown')} (RLS blocking?)")
                except Exception as e2:
                    failed_records.append(record)
                    error_detail = str(e2)
                    if hasattr(e2, 'message'):
                        error_detail = e2.message
                    print(f"      ❌ Failed: {record.get('id_perangkat', 'unknown')} - {error_detail}")
    
    print(f"\n✅ Inserted {inserted_count} perangkat records")
    if failed_count > 0:
        print(f"❌ Failed to insert {failed_count} perangkat records")
        if failed_records:
            print(f"   Sample failed records (first 5):")
            for rec in failed_records[:5]:
                print(f"      - {rec.get('id_perangkat', 'unknown')}: petugas_id={rec.get('petugas_id', 'N/A')[:8]}...")
        
        print(f"\n⚠️  NOTE: If inserts are failing due to RLS policies, you may need to:")
        print(f"   1. Use a service role key instead of anon key")
        print(f"   2. Check RLS policies on the 'perangkat' table")
        print(f"   3. Ensure the authenticated user has INSERT permissions")
    
    # Step 2: Insert storage records
    print(f"\n📤 Inserting {len(storage_records)} storage records...")
    storage_inserted = 0
    storage_failed = 0
    
    for storage in storage_records:
        try:
            # Get perangkat UUID by id_perangkat
            perangkat_result = supabase.table('perangkat')\
                .select('id')\
                .eq('id_perangkat', storage['id_perangkat'])\
                .single()\
                .execute()
            
            if perangkat_result.data:
                storage_entry = {
                    'perangkat_id': perangkat_result.data['id'],
                    'jenis_storage': storage['jenis_storage'],
                    'kapasitas': storage['kapasitas']
                }
                supabase.table('perangkat_storage').insert(storage_entry).execute()
                storage_inserted += 1
            else:
                print(f"   ⚠️  Warning: Could not find perangkat with id_perangkat: {storage['id_perangkat']}")
                storage_failed += 1
        except Exception as e:
            storage_failed += 1
            print(f"   ❌ Failed to insert storage for {storage['id_perangkat']}: {str(e)}")
    
    print(f"\n✅ Inserted {storage_inserted} storage records")
    if storage_failed > 0:
        print(f"❌ Failed to insert {storage_failed} storage records")
    
    # Final summary
    print("\n" + "="*60)
    print("📊 IMPORT SUMMARY")
    print("="*60)
    print(f"Perangkat records: {inserted_count} inserted, {failed_count} failed")
    print(f"Storage records:   {storage_inserted} inserted, {storage_failed} failed")
    print("="*60)

def main():
    """Main function"""
    if len(sys.argv) < 2:
        print("Usage: python import_perangkat_bulk.py <csv_file> [--dry-run] [--skip-validation]")
        print("\nOptions:")
        print("  --dry-run          : Validate and parse but don't insert data")
        print("  --skip-validation  : Skip UUID validation (not recommended)")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    dry_run = '--dry-run' in sys.argv
    skip_validation = '--skip-validation' in sys.argv
    
    if not os.path.exists(csv_file):
        print(f"❌ ERROR: File not found: {csv_file}")
        sys.exit(1)
    
    print("="*60)
    print("🚀 BULK IMPORT SCRIPT FOR PERANGKAT DATA")
    print("="*60)
    print(f"CSV File: {csv_file}")
    print(f"Dry Run: {dry_run}")
    print("="*60 + "\n")
    
    supabase = init_supabase()
    
    # Validate UUIDs
    if not skip_validation:
        validation = validate_uuids(supabase, csv_file)
        if not validation.get('valid', False):
            reason = validation.get('reason', '')
            if 'RLS' in reason:
                print("\n⚠️  Validation failed due to RLS policy restrictions.")
                print("   If you're certain the UUIDs exist in the database,")
                print("   you can use --skip-validation to proceed.")
                print("   The UUIDs will be validated during the actual insert.")
                response = input("\n   Continue with --skip-validation? (y/n): ")
                if response.lower() == 'y':
                    skip_validation = True
                    print("   ✅ Proceeding with validation skipped\n")
                else:
                    print("\n❌ Validation failed. Exiting.")
                    sys.exit(1)
            else:
                print("\n❌ Validation failed. Please fix the errors above.")
                sys.exit(1)
    else:
        print("⚠️  Skipping UUID validation (--skip-validation flag set)\n")
    
    # Import data
    import_perangkat_from_csv(csv_file, supabase, dry_run=dry_run)
    
    print("\n✅ Import process completed!")

if __name__ == '__main__':
    main()
