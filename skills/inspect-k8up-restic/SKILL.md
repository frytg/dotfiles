---
name: inspect-k8up-restic
description: >-
  Set up, inspect, verify, and restore K8up backups on Kubernetes by reading the underlying restic repositories directly
  and the backup pods' own logs, instead of trusting K8up job status. Covers the failure modes that make "Complete"
  jobs hold empty snapshots (unreadable PGDATA, root-owned 0600 files, missing Schedules, mismatched repo passwords,
  stale S3 keys), pg_dump backupcommand setup for databases, isolated Restore-CR test restores, restoring SQL dumps,
  and a pg_resetwal runbook for corrupted Postgres with no usable backup. Use when the user asks to "check backups",
  "verify k8up", "are my backups empty", "list restic snapshots", "restore from k8up", "restore a PVC", "set up k8up for
  a namespace", "back up postgres with k8up", or says a restore came back empty or "path not found".
license: MIT
metadata:
  author: frytg
  agent: claude
  category: engineering
  tags:
    - kubernetes
    - backup
    - restic
    - homelab
---

# Inspect K8up / Restic backups

A K8up backup is verified only when its restic snapshot holds the expected bytes and a test restore of it brings the app
up. A green `Complete` job proves nothing: restic logs per-path errors, still writes a snapshot, and K8up marks the job
successful. This skill produces a per-PVC verdict (OK, partial, empty, not covered) backed by snapshot sizes and backup
log lines, plus the exact manifest or restore steps to fix each gap.

## When to use

- The user wants to know whether backups actually contain data.
- A K8up restore finished but restored nothing, or logged `path data/<pvc>: not found`.
- A new namespace or database needs K8up backups.
- Data must be restored from a snapshot into a PVC or a database.
- Postgres won't start (`could not locate a valid checkpoint record`) and backups turn out to be empty.

## Hard boundary: read-only by default

Inspection is read-only: `restic snapshots|ls|stats|dump` with `--no-lock`, `kubectl get|logs|describe`, log-store
queries, and `kubectl apply --dry-run=server`. Everything else mutates state and needs explicit confirmation in the
current session. That includes `kubectl apply`, Backup or Restore CRs, scaling deployments, `restic forget|prune|unlock`,
`pg_resetwal`, and re-encrypting sops secrets. Surface the exact command and its blast radius, then wait. If the host
repo has its own deploy policy (for example an `AGENTS.md` rule), it wins.

Never print secret values. Compare secrets by hash (`… | shasum | cut -c1-12`), never by echoing them.

## How K8up lays out data

- One restic repository per cluster host, usually one bucket prefix per host, each with its own repo password.
- Each namespace with a `Schedule` runs a backup pod that mounts every eligible PVC at `/data/<pvc-name>`.
- Restic snapshot `host` = the namespace. Snapshot `paths` = `/data/<pvc-name>`, one snapshot per PVC.
- PVCs **without** a `k8up.io/backup` annotation are backed up by default. Opt out with `k8up.io/backup: 'false'`.
- A PVC annotated `'true'` in a namespace **without** a `Schedule` is never backed up.
- A pod annotated `k8up.io/backupcommand` is exec'd, and its stdout becomes a stdin snapshot (a `.sql` file, say).
- A folder restore runs `restic restore <id>:/data/<pvc> --target /restore`. An empty snapshot therefore fails with
  `path data/<pvc>: not found`, which is the signature of a backup that never captured data.

## Known failure modes

1. **Empty snapshot behind a Complete job.** Logs show `/data/<pvc> during scan` and `during archival` errors, then
   `"bytes processed": 0` and `"bytes added"` ≈ 350. `restic snapshots` shows `0 B`.
2. **Partial snapshot.** Most bytes land, but specific files fail `during archival`. Often these are the small files
   that matter most (auth stores, `core.config`, pairing or fabric files). A large size hides it, so always grep the
   error lines.
3. **Permission denied, silently.** The backup pod runs with an empty `securityContext`, so it uses the image's
   non-root user. It can't read `0700` dirs owned by another uid (Postgres PGDATA is uid 70 on Alpine images) or
   root-owned `0600` files.
4. **Live database copied as files.** Even when readable, a file copy of a running PGDATA isn't consistent. Use a
   `pg_dump` backupcommand instead.
5. **Wrong database dumped.** `POSTGRES_DB` can be an empty `initdb` leftover while the app uses another database.
   Check database sizes before trusting the dump target.
6. **Repo password mismatch.** A namespace whose `k8up-backup-repo` secret holds another host's password fails at repo
   open once its bucket points at this host's repo.
7. **Stale S3 keys.** After a key rotation, both the in-cluster K8up secrets and the local sops env must be updated.
   `restic` reports `Stat: Access Denied` on the repo config.
8. **Good backups age out.** `keepDaily: 14` means two weeks of empty snapshots replace the last good one.
9. **Rolling updates on database volumes.** On a single node, a `ReadWriteOnce` local-path volume lets a rolling update
   start a second postmaster on the same PGDATA. This corrupts the WAL. Database Deployments need `strategy: Recreate`.

## 1. Inspect snapshots with restic

1. Find the repo env. Prefer the repo's own recipe (for example `just see-restic <host>`), or decrypt a sops env file
   into the process only: `sops exec-env .env.<host>.sops.yaml '<restic command>'`. It must provide
   `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Never write the plaintext to
   disk.
2. List the latest snapshot per namespace and PVC:

   ```sh
   restic snapshots --no-lock --latest 1 --compact
   ```

3. If restic fails with `Access Denied`, the S3 key in the env is stale or lacks rights. Stop and tell the user which
   env file to update. Don't read cluster secrets to work around it unless the user asks.
4. Flag every row with `0 B`, or with a size far below the PVC's real usage.
5. Check the contents of a suspicious snapshot:

   ```sh
   restic ls --no-lock <snapshot-id> | head -20
   restic stats --no-lock <snapshot-id> --mode restore-size
   ```

6. Cross-check against the Kubernetes view:
   `kubectl get snapshots.k8up.io -n <namespace> --sort-by=.spec.date`.

## 2. Inspect backup pod logs

Restic's per-path errors only show up in the backup pod logs.

1. Collect logs from the backup pods that remain (`successfulJobsHistoryLimit` keeps a few):

   ```sh
   for p in $(kubectl get pods -A --no-headers | awk '$2 ~ /^backup-/ {print $1"/"$2}'); do
     ns=${p%/*}; pod=${p#*/}; echo "== $ns $pod"
     kubectl -n "$ns" logs "$pod" | grep -E 'foldername|during scan|during archival|"bytes processed"' | grep -v prometheus
   done
   ```

2. For history beyond the retained pods, query the cluster log store for `k8s_pod_name` matching `backup-.*` and the
   strings `"bytes processed"` or `during scan`, grouped by namespace.
3. Map each `stats` line to the `foldername` line just before it. That pairing is the per-PVC result.

## 3. Check coverage

1. List PVCs and their annotations:

   ```sh
   kubectl get pvc -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,BACKUP:.metadata.annotations.k8up\\.io/backup
   ```

2. List Schedules: `kubectl get schedules.k8up.io -A`.
3. Flag PVCs that hold state but sit in a namespace without a Schedule.
4. Flag database pods without a `k8up.io/backupcommand` annotation.
5. Confirm each Schedule's bucket matches its host, and that its repo password hash matches the host's other
   namespaces.

## 4. Report

```text
<host> — <date>, source: restic + backup logs

OK
- <namespace>/<pvc>: <size>, <N> files

Partial (files failing during archival)
- <namespace>/<pvc>: <size>; failing: <paths>; cause: <uid/mode>

Empty (0 B every run since <date>)
- <namespace>/<pvc>: cause: <reason>; fix: <one line>

Not covered (no Schedule or no backupcommand)
- <namespace>/<pvc or db>

Fixes, ordered by impact
1. …
```

## 5. Set up or fix backups

Server-dry-run every manifest. Apply only after confirmation.

1. **Operator:** install via the `k8up-io/k8up` Helm chart into `k8up-system`. See the
   [install docs](https://docs.k8up.io/k8up/how-tos/installation.html).
2. **Secrets per namespace:** `k8up-backup-repo` (key `password`, this host's repo password) and
   `k8up-backup-credentials` (keys `username`, `password` for S3). Copy them from a working namespace on the same host
   and change only `namespace:`, without writing plaintext:

   ```sh
   sops -d <working>/k8up-credentials.sops.yaml \
     | sed -E 's/^([[:space:]]*namespace: )<old>$/\1<new>/' \
     | sops encrypt --filename-override <new>/k8up-credentials.sops.yaml --input-type yaml --output-type yaml /dev/stdin \
     > <new>/k8up-credentials.sops.yaml
   ```

   Use `[[:space:]]`, not `\s`, because BSD sed on macOS doesn't understand `\s`. Verify by decrypting, counting
   namespace lines, and comparing value hashes with the source.

3. **Schedule per namespace:**

   ```yaml
   apiVersion: k8up.io/v1
   kind: Schedule
   metadata:
     name: pvc-backup
     namespace: <namespace>
   spec:
     backend:
       repoPasswordSecretRef: { name: k8up-backup-repo, key: password }
       s3:
         endpoint: https://<s3-endpoint>
         bucket: <bucket>/<host-repo>
         accessKeyIDSecretRef: { name: k8up-backup-credentials, key: username }
         secretAccessKeySecretRef: { name: k8up-backup-credentials, key: password }
     backup:
       schedule: '<m> <h> * * *' # offset per namespace
       failedJobsHistoryLimit: 7
       successfulJobsHistoryLimit: 3
       # only when files are root-owned 0600; grants the backup pod root read on every PVC in the namespace
       podSecurityContext:
         runAsUser: 0
     check:
       schedule: '<m> <h> * * 0'
     prune:
       schedule: '<m> <h> * * 0'
       retention: { keepLast: 7, keepDaily: 14 }
   ```

   Offset `check` and `prune` between namespaces that share a repo, since both lock it.

4. **Postgres:** annotate the pod template, opt the PVC out, and use `Recreate`:

   ```yaml
   # PVC
   metadata:
     annotations:
       k8up.io/backup: 'false'
   # Deployment
   spec:
     strategy:
       type: Recreate
     template:
       metadata:
         annotations:
           k8up.io/backupcommand: sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" --clean --if-exists <db>'
           k8up.io/file-extension: .sql
   ```

   Before writing it, list database sizes and dump the one that holds the data. Test the exact command in the pod and
   count the output: `kubectl exec deploy/<db> -- sh -c '<command>' | wc -c`. For a large database, test with
   `--schema-only`.

5. **Caches:** annotate cache-only PVCs (an LRU Valkey, say) with `k8up.io/backup: 'false'`.
6. **Prove it:** after applying, either trigger a one-off `Backup` CR (needs confirmation) or wait for the next run.
   Then repeat steps 1–2 and confirm non-zero sizes and no error lines.

## 6. Restore

Always restore next to the live data, never over it. Verify the result, then switch.

**Files (PVC snapshot):**

1. Pick a snapshot whose size is plausible (step 1). Never restore a `0 B` snapshot.
2. Create a recovery PVC and a Restore CR:

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: <pvc>-recovery
     namespace: <namespace>
     annotations: { k8up.io/backup: 'false' }
   spec:
     accessModes: [ReadWriteOnce]
     resources: { requests: { storage: <size> } }
   ---
   apiVersion: k8up.io/v1
   kind: Restore
   metadata:
     name: <pvc>-recovery
     namespace: <namespace>
   spec:
     snapshot: <full-snapshot-id>
     restoreMethod:
       folder: { claimName: <pvc>-recovery }
     podSecurityContext: { runAsUser: 0 }
     backend: <same backend block as the Schedule>
   ```

3. Read the restore pod log. If it ends with `path data/<pvc>: not found`, the snapshot is empty, so go back to step 1.
4. Mount the recovery PVC in a throwaway pod, check the files, then point the workload's `claimName` at it.

**Database (pg_dump snapshot):**

1. Find the dump path: `restic ls --no-lock <snapshot-id>`.
2. Copy it out: `restic dump --no-lock <snapshot-id> <path> > <scratch>/<db>.sql`.
3. Start a fresh Postgres on a new PVC and keep the app scaled to 0.
4. Load it: `kubectl exec -i deploy/<db> -- psql -U <user> -d <db> -v ON_ERROR_STOP=1 < <scratch>/<db>.sql`.
5. Compare row counts on the key tables, then scale the app up.

**Corrupted Postgres with no usable backup:** follow
[references/postgres-wal-recovery.md](references/postgres-wal-recovery.md).

## Checklist

- [ ] Sizes come from `restic snapshots` or the backup logs, not job status.
- [ ] Every flagged PVC has a cause (uid/mode, no Schedule, wrong database, stale key).
- [ ] Database backups use a tested `pg_dump` backupcommand, and the PVC opts out.
- [ ] Database Deployments use `strategy: Recreate`.
- [ ] Mutating commands were listed with their blast radius and confirmed before running.
- [ ] No secret value appeared in output.
