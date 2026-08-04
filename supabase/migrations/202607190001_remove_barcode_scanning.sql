-- Remove barcode-scanning support; keep image scanning.

alter table if exists public.food_logs
  drop constraint if exists food_logs_source_chk;

alter table if exists public.food_logs
  add constraint food_logs_source_chk
  check (source in ('manual', 'recipe', 'image_scan', 'imported'));

drop table if exists public.barcode_scans cascade;
