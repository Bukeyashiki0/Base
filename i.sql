nohup impdp \"/ as sysdba\" directory=KK schemas=OPERATIONS,TAXONOMIES \
  dumpfile=RTSK8142623_%U.dmp parallel=4 table_exists_action=replace \
  metrics=y logtime=all logfile=RTSK8142623_import.log > imp_nohup.out 2>&1 &
