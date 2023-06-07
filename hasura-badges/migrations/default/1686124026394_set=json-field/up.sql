
ALTER TABLE badges DROP COLUMN data;
ALTER TABLE badges ADD COLUMN data jsonb not null default '{}'::jsonb;
 
