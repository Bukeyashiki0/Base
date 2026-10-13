-- PGA real por proceso hoy. Para estimar: avg_alloc_mb x nº procesos objetivo + SGA, y comparar con la RAM.
-- En RAC usar gv$process (añadir inst_id).
SELECT COUNT(*) procesos,
       ROUND(AVG(pga_used_mem)/1024/1024,1) avg_used_mb,
       ROUND(AVG(pga_alloc_mem)/1024/1024,1) avg_alloc_mb
FROM v$process;

-- ¿pga_aggregate_limit fijado a mano? (isdefault = FALSE)
SELECT name, value, isdefault FROM v$parameter WHERE name = 'pga_aggregate_limit';

-- En el servidor (SO):
--   free -g
--   grep -i huge /proc/meminfo
