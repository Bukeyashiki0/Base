select owner, object_type, object_name, created, last_ddl_time
from dba_objects
where owner in ('OPERATIONS','TAXONOMIES')
  and (created > timestamp '2026-11-17 12:00:00'
       or last_ddl_time > timestamp '2026-11-17 12:00:00')
order by last_ddl_time;
