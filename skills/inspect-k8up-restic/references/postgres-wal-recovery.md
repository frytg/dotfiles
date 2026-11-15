# Postgres WAL recovery without a usable backup

The last resort when Postgres panics at startup and no snapshot holds data. The goal is a consistent `pg_dump` taken
from a reset **copy** of PGDATA, loaded into a fresh cluster. The original volume is never modified.

Every step here mutates cluster state or data. Get explicit confirmation before step 1, and again before the switch in
step 7.

## Typical signature

```text
LOG:  invalid record length at X/XXXXXXXX: expected at least 24, got 0
LOG:  invalid checkpoint record
PANIC:  could not locate a valid checkpoint record at X/XXXXXXXX
```

Find the trigger in the logs before touching anything. Two postmasters on one volume is the classic cause: look for an
"interrupted … automatic recovery" line from a new pod while the old pod logs "received fast shutdown request". If the
old pod finished with "database system is shut down", its data files were flushed. Only the last seconds of writes are
at risk, and `pg_resetwal` is likely to recover nearly everything.

## Steps

1. **Stop writers.** Scale the database and the app to 0. Wait for the pods to disappear.
2. **Rescue pod.** Use the same Postgres major and image as the damaged cluster. Run it as root with
   `command: ['sleep', 'infinity']`. Mount the damaged PVC **read-only** at `/damaged` and an empty recovery PVC at
   `/recovery`. Alpine Postgres images ship `gosu`, not `su-exec`.
3. **Two copies.**

   ```sh
   cp -a /damaged /recovery/pristine
   cp -a /damaged /recovery/work
   ```

4. **Confirm the diagnosis** on `work`:

   ```sh
   gosu postgres pg_controldata /recovery/work | grep -E 'state|checkpoint location|NextXID|NextOID'
   ls -la /recovery/work/pg_wal
   gosu postgres pg_waldump -p /recovery/work/pg_wal -s <segment-start-lsn> | tail -15
   ```

   Note any `CHECKPOINT_*` record's `oid` in the WAL. If it's higher than `NextOID` in `pg_control`, bump it in the
   next step.

5. **Reset the WAL on `work` only.**

   ```sh
   gosu postgres pg_resetwal -n /recovery/work                # dry run
   gosu postgres pg_resetwal -f /recovery/work
   gosu postgres pg_resetwal -o <above-both-oids> -f /recovery/work
   ```

   Leave the XID alone unless `pg_resetwal` refuses. A far-ahead XID needs matching `pg_xact` segments.

6. **Verify and dump.** Start socket-only, check, then dump:

   ```sh
   gosu postgres pg_ctl -D /recovery/work -l /tmp/pg.log -w -o "-c listen_addresses= -c unix_socket_directories=/tmp" start
   psql -h /tmp -U <user> -d <db> -c 'select count(*) from <key tables>'
   psql -h /tmp -U <user> -d <db> -c 'create extension amcheck'
   psql -h /tmp -U <user> -d <db> -c "select count(*) from (select bt_index_check(c.oid, true)
     from pg_index i join pg_class c on c.oid = i.indexrelid join pg_am a on a.oid = c.relam
     join pg_namespace n on n.oid = c.relnamespace
     where a.amname = 'btree' and n.nspname not in ('pg_catalog','information_schema','pg_toast')
       and c.relpersistence <> 't') s"
   psql -h /tmp -U <user> -d <db> -c 'drop extension amcheck'
   pg_dump -h /tmp -U <user> -Fc -f /recovery/<db>.dump <db>
   gosu postgres pg_ctl -D /recovery/work -m fast stop
   ```

   A clean `pg_dump` reads every table, including TOAST, so it doubles as a full read test.

7. **Fresh cluster (confirm first).** Add a new PVC (for example `<db>-v2`), point the Deployment at it, and keep
   `strategy: Recreate`. Let the image run `initdb`. Then:

   ```sh
   kubectl cp <ns>/<rescue-pod>:/recovery/<db>.dump <scratch>/<db>.dump    # compare sha256 on both sides
   kubectl exec -i -n <ns> deploy/<db> -- pg_restore -U <user> -d <db> --no-owner --exit-on-error --single-transaction < <scratch>/<db>.dump
   ```

   Compare row counts with step 6, scale the app up, and check its health endpoint.

8. **Clean up.** Delete the rescue pod. Keep the damaged PVC and the recovery PVC until the user confirms the
   recovered data, then let them delete both.

## Never

- Run `pg_resetwal` on the original volume.
- Start the reset cluster as the long-term database. Always dump and restore into a fresh `initdb`.
- Switch the app before row counts match.
