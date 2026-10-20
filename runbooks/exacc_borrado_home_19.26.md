# Remediación de vulnerabilidades — Copia y borrado de homes y restos antiguos

**Contexto:** después de los parcheos previos de GI y RDBMS, y una vez comprobado que el home nuevo funciona bien, se comprimen y eliminan los homes y restos antiguos que ha marcado el escáner de vulnerabilidades. La intervención es **sin afectación y online**: no se para ninguna BBDD ni el clúster.

| Marcador | Nodo |
|---|---|
| `nodo1` | Primer nodo del clúster (sustituir por el hostname real) |
| `nodo2` | Segundo nodo del clúster (sustituir por el hostname real) |

Todos los comandos se lanzan como **root**, salvo los que indican otro usuario. Los pasos largos (los `tar` de homes completos) conviene lanzarlos dentro de `screen -S remediacion`. Si se corta la sesión, se recupera con `screen -r remediacion`.

---

## Resumen de lo que marca el escáner y qué se hace con cada ruta

| Ruta marcada | Qué es | Acción |
|---|---|---|
| `/u02/app/oracle/product/19.0.0.0/dbhome_3/...` (OPatch/jre, jdk, jdk/jre) | Home viejo **OraHome3 (19.26)**, sin BBDD | Copia en ambos nodos y borrado con `dbaascli dbhome delete` |
| `/u01/app/19.0.0.0/grid/OPatch.ORG/jre` | Copia antigua de OPatch del grid | Copia y `rm` en ambos nodos |
| `/acfs01/app_acfs/exapatch/OraHome100/...` | Restos de un parche antiguo en el área de staging | Copia y `rm` una sola vez (ACFS es compartido) |
| `/opt/oracle.ahf/common/cvu/jdk...` | CVU antiguo que descomprimió exachk | Copia y `rm` en ambos nodos, conservando el `cvupack_*.zip` nuevo |
| `/u01/app/19.0.0.0/grid/OPatch/jre`, `/grid/jdk`, `/grid/tomcat` | Grid **activo** | **No se borra.** Se comprueba la versión (Fase 6) |
| `/acfs01/ords/jdk-17.0.9` | JDK de ORDS | **No se borra** sin confirmar si ORDS está en uso (Fase 6) |

---

## Fase 0 — Comprobaciones previas

### 0.1 Ninguna BBDD usa dbhome_3

Como **oracle**, en nodo1:

```bash
for db in $(srvctl config database); do echo "== $db"; srvctl config database -d $db | grep -i "oracle home"; done
```

Todas las BBDD deben apuntar a `/u02/app/oracle/product/19.0.0.0/dbhome_2`.

> ⚠ **Si alguna BBDD apunta a dbhome_3, PARA AQUÍ.** Ese home no se puede borrar hasta mover la BBDD.

### 0.2 Homes registrados

Como root, en nodo1:

```bash
dbaascli system getDBHomes
```

Comprueba dos cosas:

- `OraHome3` → `/u02/app/oracle/product/19.0.0.0/dbhome_3`, versión 19.26. Es el home que se borra.
- `OraHome1` → `/u02/app/oracle/product/19.0.0.0/dbhome_2`, versión 19.31. Es el home en uso.

Revisa la salida completa y confirma que **no aparece ningún home llamado `OraHome100`**. Si aparece, no se toca la Fase 4.

### 0.3 Espacio para las copias

En nodo1:

```bash
df -h /u02
du -sh /u02/app/oracle/product/19.0.0.0/dbhome_3
```

En nodo2:

```bash
df -h /u02
du -sh /u02/app/oracle/product/19.0.0.0/dbhome_3
```

El espacio libre en `/u02` debe ser holgadamente mayor que el tamaño del home. Comprimido ocupa menos, pero es mejor tener margen.

### 0.4 Crear el directorio de copias

En nodo1 y en nodo2:

```bash
mkdir -p /u02/backup_vulnerabilidades
```

---

## Fase 1 — dbhome_3 (OraHome3, 19.26)

### 1.1 Copia en nodo1

```bash
cd /u02/app/oracle/product/19.0.0.0 && tar -czpf /u02/backup_vulnerabilidades/dbhome_3_$(hostname -s).tar.gz dbhome_3
```

```bash
tar -tzf /u02/backup_vulnerabilidades/dbhome_3_$(hostname -s).tar.gz > /dev/null && echo "BACKUP OK"
```

### 1.2 Copia en nodo2

```bash
cd /u02/app/oracle/product/19.0.0.0 && tar -czpf /u02/backup_vulnerabilidades/dbhome_3_$(hostname -s).tar.gz dbhome_3
```

```bash
tar -tzf /u02/backup_vulnerabilidades/dbhome_3_$(hostname -s).tar.gz > /dev/null && echo "BACKUP OK"
```

> ⚠ No sigas al paso 1.3 sin ver **"BACKUP OK"** en los dos nodos.

### 1.3 Borrado del home (una sola vez, desde nodo1)

```bash
dbaascli dbhome delete --oracleHomeName OraHome3
```

Este comando borra el home **en ambos nodos** y lo quita del inventario de Oracle y de la metadata de dbaascli. Por eso se usa en lugar de `rm -rf`.

### 1.4 Verificación

En nodo1:

```bash
dbaascli system getDBHomes
```

`OraHome3` ya no debe aparecer.

En nodo1 y en nodo2:

```bash
ls -ld /u02/app/oracle/product/19.0.0.0/dbhome_3
```

Debe devolver `No such file or directory`.

---

## Fase 2 — OPatch.ORG del grid (ambos nodos)

### 2.1 nodo1

```bash
cd /u01/app/19.0.0.0/grid && tar -czpf /u02/backup_vulnerabilidades/grid_OPatch.ORG_$(hostname -s).tar.gz OPatch.ORG
```

```bash
tar -tzf /u02/backup_vulnerabilidades/grid_OPatch.ORG_$(hostname -s).tar.gz > /dev/null && echo "BACKUP OK"
```

```bash
rm -rf /u01/app/19.0.0.0/grid/OPatch.ORG
```

### 2.2 nodo2

```bash
cd /u01/app/19.0.0.0/grid && tar -czpf /u02/backup_vulnerabilidades/grid_OPatch.ORG_$(hostname -s).tar.gz OPatch.ORG
```

```bash
tar -tzf /u02/backup_vulnerabilidades/grid_OPatch.ORG_$(hostname -s).tar.gz > /dev/null && echo "BACKUP OK"
```

```bash
rm -rf /u01/app/19.0.0.0/grid/OPatch.ORG
```

> ⚠ Borra **solo** `OPatch.ORG`. `OPatch` (sin `.ORG`) es el que usa el grid y **no se toca**. Revisa bien el comando antes de pulsar Enter.

### 2.3 Verificación (ambos nodos)

```bash
ls -ld /u01/app/19.0.0.0/grid/OPatch /u01/app/19.0.0.0/grid/OPatch.ORG
```

Debe existir `OPatch` y no debe existir `OPatch.ORG`.

---

## Fase 3 — Staging antiguo en ACFS: exapatch/OraHome100 (una sola vez, desde nodo1)

`/acfs01` es compartido entre los dos nodos, así que esta fase se hace **solo en nodo1**.

### 3.1 Revisar el contenido

```bash
ls -la /acfs01/app_acfs/exapatch/
du -sh /acfs01/app_acfs/exapatch/OraHome100
```

### 3.2 Copia y borrado

```bash
cd /acfs01/app_acfs/exapatch && tar -czpf /u02/backup_vulnerabilidades/exapatch_OraHome100.tar.gz OraHome100
```

```bash
tar -tzf /u02/backup_vulnerabilidades/exapatch_OraHome100.tar.gz > /dev/null && echo "BACKUP OK"
```

```bash
rm -rf /acfs01/app_acfs/exapatch/OraHome100
```

### 3.3 Verificación (desde nodo2, para confirmar que se ve en el ACFS compartido)

```bash
ls -ld /acfs01/app_acfs/exapatch/OraHome100
```

Debe devolver `No such file or directory`.

---

## Fase 4 — CVU antiguo descomprimido (ambos nodos)

Se borra lo que exachk descomprimió del CVU antiguo y se conserva **solo** el `cvupack_*.zip` nuevo. La próxima vez que se ejecute, exachk volverá a descomprimirlo con el JDK actualizado.

### 4.1 nodo1

Revisa el contenido y confirma que está el `cvupack_*.zip` nuevo:

```bash
ls -la /opt/oracle.ahf/common/cvu/
```

> ⚠ Si **no** está el `cvupack_*.zip` nuevo, no sigas: súbelo antes (como en el runbook de parcheo, Fase 0).

```bash
cd /opt/oracle.ahf/common && tar -czpf /u02/backup_vulnerabilidades/ahf_cvu_$(hostname -s).tar.gz cvu
```

```bash
tar -tzf /u02/backup_vulnerabilidades/ahf_cvu_$(hostname -s).tar.gz > /dev/null && echo "BACKUP OK"
```

```bash
find /opt/oracle.ahf/common/cvu -mindepth 1 -maxdepth 1 ! -name 'cvupack*.zip' -exec rm -rf {} +
```

```bash
ls -la /opt/oracle.ahf/common/cvu/
```

Solo debe quedar el `cvupack_*.zip`.

### 4.2 nodo2

```bash
ls -la /opt/oracle.ahf/common/cvu/
```

```bash
cd /opt/oracle.ahf/common && tar -czpf /u02/backup_vulnerabilidades/ahf_cvu_$(hostname -s).tar.gz cvu
```

```bash
tar -tzf /u02/backup_vulnerabilidades/ahf_cvu_$(hostname -s).tar.gz > /dev/null && echo "BACKUP OK"
```

```bash
find /opt/oracle.ahf/common/cvu -mindepth 1 -maxdepth 1 ! -name 'cvupack*.zip' -exec rm -rf {} +
```

```bash
ls -la /opt/oracle.ahf/common/cvu/
```

---

## Fase 5 — Verificación final de las rutas eliminadas

En nodo1 y en nodo2:

```bash
for p in \
  /acfs01/app_acfs/exapatch/OraHome100 \
  /opt/oracle.ahf/common/cvu/jdk \
  /u01/app/19.0.0.0/grid/OPatch.ORG \
  /u02/app/oracle/product/19.0.0.0/dbhome_3 ; do
  if [ -e "$p" ]; then echo "SIGUE EXISTIENDO: $p"; else echo "eliminado:        $p"; fi
done
```

Todas las rutas deben salir como `eliminado`.

Comprueba también que la BBDD sigue sana, como **oracle**:

```bash
for db in $(srvctl config database); do srvctl status database -d $db; done
```

---

## Fase 6 — Rutas que NO se borran: comprobar versión

Estas rutas pertenecen a software en uso. Borrarlas rompería el grid o ORDS. Se comprueba su versión actual para documentar si el parcheo a 19.31 ya las resolvió.

### 6.1 Grid: JDK, JRE de OPatch y Tomcat (ambos nodos)

```bash
/u01/app/19.0.0.0/grid/jdk/bin/java -version
```

```bash
/u01/app/19.0.0.0/grid/OPatch/jre/bin/java -version
```

```bash
unzip -p /u01/app/19.0.0.0/grid/tomcat/lib/catalina.jar META-INF/MANIFEST.MF | grep Implementation-Version
```

- Si las versiones son posteriores a las del escáner, el hallazgo ya está resuelto. Basta con pedir un re-escaneo.
- Si son las mismas, se remedian **parcheando**, nunca borrando:
  - **OPatch:** última versión, parche MOS 6880880.
  - **JDK del grid:** JDK Bundle Patch para Grid Infrastructure 19c.
  - **Tomcat:** se actualiza con la RU de GI.

### 6.2 ORDS

```bash
ps -ef | grep -i ords | grep -v grep
```

```bash
/acfs01/ords/jdk-17.0.9/bin/java -version
```

- **Si ORDS está en uso:** hay que actualizar su JDK. No se borra.
- **Si no se usa:** se puede comprimir y borrar `/acfs01/ords` completo, con el mismo patrón de `tar` y `rm` de la Fase 3, una vez confirmado con los responsables de la aplicación.

---

## Marcha atrás

**Directorios borrados con `rm` (OPatch.ORG, exapatch, cvu).** Se restauran descomprimiendo en su directorio padre. Por ejemplo, para OPatch.ORG en nodo1:

```bash
tar -xzpf /u02/backup_vulnerabilidades/grid_OPatch.ORG_$(hostname -s).tar.gz -C /u01/app/19.0.0.0/grid
```

**dbhome_3.** `dbaascli dbhome delete` también quita el home del inventario y de la metadata de dbaascli. Descomprimir la copia recupera los ficheros, pero el home no vuelve a quedar registrado. Si alguna vez se necesitara de nuevo un home 19.26, lo correcto es crearlo con `dbaascli dbhome create --version 19.26.0.0.0`. La copia `tar` sirve como respaldo de ficheros y configuración.

---

## Después de la intervención

- Los ficheros `/u02/backup_vulnerabilidades/*.tar.gz` contienen los binarios vulnerables, comprimidos. Algunos escáneres inspeccionan también el interior de los ficheros comprimidos. Conviene sacar estas copias del servidor, o borrarlas pasado el periodo de retención que se acuerde, para que no vuelvan a aparecer en el escaneo.
- Pedir un re-escaneo de vulnerabilidades para cerrar el cambio.
