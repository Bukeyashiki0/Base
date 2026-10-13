-- Uso actual y pico real (max_utilization) de processes y sessions desde el arranque.
-- En RAC usar gv$resource_limit (añadir inst_id).
SELECT resource_name, current_utilization, max_utilization, limit_value
FROM   v$resource_limit
WHERE  resource_name IN ('processes', 'sessions');
