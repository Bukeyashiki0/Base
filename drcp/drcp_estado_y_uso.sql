-- Comprobar si se usa DRCP. Si status = INACTIVE o v$cpool_conn_info está vacía, no lo usan.
-- La aplicación debe conectar con (SERVER=POOLED) o :POOLED en EZConnect.

-- ¿Está el pool arrancado y con qué tamaño?
SELECT connection_pool, status, minsize, maxsize, num_cbrok, maxconn_cbrok
FROM dba_cpool_info;

-- Uso real del pool
SELECT num_open_servers, num_busy_servers, num_requests, num_waits, num_hits
FROM v$cpool_stats;

-- Conexiones de cliente por programa/usuario
SELECT username, program, COUNT(*)
FROM v$cpool_conn_info
GROUP BY username, program
ORDER BY 3 DESC;

-- Tipo de servidor de las sesiones actuales (DEDICATED / SHARED / POOLED)
SELECT server, COUNT(*) FROM v$session GROUP BY server;
