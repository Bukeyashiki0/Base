-- Reparto de sesiones de usuario por username/program (total y activas).
-- En RAC usar gv$session (añadir inst_id).
SELECT username, program, COUNT(*) total,
       SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) activas
FROM   v$session
WHERE  type = 'USER'
GROUP  BY username, program
ORDER  BY 3 DESC;
