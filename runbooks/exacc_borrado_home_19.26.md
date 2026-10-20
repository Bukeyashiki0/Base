# ExaCC Consumer HQ: zip y borrado del home viejo 19.26 (dbhome_3)

Se ha parcheado de 19.26 a 19.31. El home viejo ya no se usa y se va a zipear
a la altura de `19.0.0.0` y después borrar.

| Home | Nombre (dbaascli) | Versión | Estado |
|---|---|---|---|
| `/u02/app/oracle/product/19.0.0.0/dbhome_2` | OraHome1 | 19.31 | **Nuevo, en uso** |
| `/u02/app/oracle/product/19.0.0.0/dbhome_3` | OraHome3 | 19.26 | **Viejo, a borrar** |

Orden: **Norte 1** (standby) → Norte 2 (standby) → Sur 1 → Sur 2 (primary).

> **Ojo:** `dbaascli dbhome purge` actúa sobre **todos los nodos del cluster**
> (Norte 1 y Norte 2 a la vez). Haz el zip (paso 2) en **Norte 1 y Norte 2**
> antes de lanzar el purge (paso 3).

```bash
OLD_HOME=/u02/app/oracle/product/19.0.0.0/dbhome_3
NEW_HOME=/u02/app/oracle/product/19.0.0.0/dbhome_2
```

---

## 1. Comprobaciones: nadie usa dbhome_3

### 1.1 dbaascli (como root)

```bash
dbaascli system getDBHomes
dbaascli dbhome getDetails --homeName OraHome3
```
OK si `OraHome3` **no tiene bases de datos** asociadas
(`databases` vacío o sin entradas).

### 1.2 oratab

```bash
grep -v '^#' /etc/oratab | grep dbhome_3
```
OK si no devuelve nada. Todas las BBDD deben apuntar a `dbhome_2`.

### 1.3 srvctl (como oracle, con entorno de dbhome_2)

```bash
export ORACLE_HOME=$NEW_HOME
for db in $(srvctl config database); do
  echo "== $db"; srvctl config database -d $db | grep -i "oracle home"
done
```
OK si todas muestran `dbhome_2`.

### 1.4 Procesos (como root)

```bash
ps -eo pid,user,args | grep dbhome_3 | grep -v grep
ls -l /proc/[0-9]*/exe 2>/dev/null | grep dbhome_3
```
OK si ambos no devuelven nada (ni pmon, ni listener, ni agentes).

### 1.5 Referencias sueltas

```bash
crontab -l -u oracle 2>/dev/null | grep dbhome_3
grep -l dbhome_3 /home/oracle/.bash_profile /home/oracle/*.env 2>/dev/null
```
Si sale algo, corregirlo a `dbhome_2` antes de seguir.

### 1.6 Inventario

```bash
INV=$(grep inventory_loc /etc/oraInst.loc | cut -d= -f2)
grep dbhome_3 $INV/ContentsXML/inventory.xml
```
Anotar la línea (nombre del home en el inventario). Debe estar sin `REMOVED="T"`.

**Si algún check falla: PARAR.**

---

## 2. Backup: zip a la altura de 19.0.0.0 (como root, en cada nodo)

Como root para poder leer también los ficheros de root dentro del home.

### 2.1 Espacio

```bash
du -sh $OLD_HOME
df -h /u02
```
Hace falta en `/u02` al menos ~la mitad del tamaño del home libre.
Si no hay espacio, NO seguir (o dejar el zip en otro FS con espacio).

### 2.2 Zip

```bash
cd /u02/app/oracle/product/19.0.0.0
nohup zip -r -y -q dbhome_3_19.26.zip dbhome_3 > /tmp/zip_dbhome_3.log 2>&1 &
```
`-y` guarda los enlaces simbólicos como enlaces.

Seguimiento:
```bash
jobs; ls -lh /u02/app/oracle/product/19.0.0.0/dbhome_3_19.26.zip
```

### 2.3 Verificar el zip

```bash
cd /u02/app/oracle/product/19.0.0.0
zip -T dbhome_3_19.26.zip
unzip -l dbhome_3_19.26.zip | tail -1
find dbhome_3 | wc -l
cat /tmp/zip_dbhome_3.log
```
OK si: `test of dbhome_3_19.26.zip OK`, el nº de ficheros del zip
coincide (o casi) con el `find`, y el log no muestra errores.

**Repetir el paso 2 en Norte 2** antes de ir al paso 3.

---

## 3. Desregistrar y borrar el home (como root, en Norte 1)

En ExaCC la forma correcta es con `dbaascli`: desregistra el home del
inventario, limpia los metadatos de las cloud tools y borra el directorio.

### 3.1 Ver la sintaxis de la versión instalada

```bash
dbaascli dbhome purge --help
```

### 3.2 Purge

```bash
dbaascli dbhome purge --homeName OraHome3
```
(Alternativa: `--homePath /u02/app/oracle/product/19.0.0.0/dbhome_3`)

Si el purge se niega porque hay BBDD asociadas: PARAR y volver al paso 1.

> Si el home aparece como *Database Home* en la consola OCI, borrarlo desde
> la consola (o comprobar que desaparece después del purge) para que el
> control plane no quede desincronizado.

---

## 4. Verificación final

```bash
dbaascli system getDBHomes            # ya no aparece OraHome3
ls -ld $OLD_HOME                      # No such file or directory
grep dbhome_3 $INV/ContentsXML/inventory.xml   # nada, o REMOVED="T"
ls -lh /u02/app/oracle/product/19.0.0.0/dbhome_3_19.26.zip   # el zip sigue
df -h /u02
```
Y comprobar que las BBDD siguen OK:
```bash
ps -ef | grep pmon | grep -v grep
srvctl status database -d <DB>
```

---

## 5. Plan B: borrado manual (solo si el purge falla)

Solo si `dbaascli dbhome purge` no funciona y con el zip ya verificado.

```bash
# como oracle: detach del inventario
$OLD_HOME/oui/bin/runInstaller -silent -detachHome ORACLE_HOME=$OLD_HOME

# comprobar
grep dbhome_3 $INV/ContentsXML/inventory.xml     # REMOVED="T" o nada

# como root: borrar el directorio (revisar la ruta antes de pulsar Enter)
rm -rf /u02/app/oracle/product/19.0.0.0/dbhome_3
```
Después: `dbaascli system getDBHomes`. Si OraHome3 sigue apareciendo en
los metadatos, abrir SR o limpiarlo desde la consola OCI.

---

## 6. Resto de nodos

1. **Norte 2**: el purge del paso 3 ya lo borra; solo verificar (paso 4).
2. **Sur 1 / Sur 2** (primary): repetir pasos 1 → 4 (zip en Sur 1 y Sur 2,
   después purge desde Sur 1).

---

## Vuelta atrás

Restaurar desde el zip (como root):
```bash
cd /u02/app/oracle/product/19.0.0.0
unzip -q dbhome_3_19.26.zip
chown -R oracle:oinstall dbhome_3
dbhome_3/root.sh                       # recoloca permisos de root
# como oracle: volver a registrar en inventario
dbhome_3/oui/bin/runInstaller -silent -attachHome ORACLE_HOME=$OLD_HOME ORACLE_HOME_NAME=OraHome3
```
(El zip no guarda propietarios; por eso `chown` + `root.sh`.)
