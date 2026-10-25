#!/usr/bin/env python3
"""Exercise the deployed personal-data client against a disposable cached image.

Run on the container host, as root, with: sqlite-ingestion.py CONFIG_JSON
CLIENT_TS BUN [--idle|--traffic|--recovery]. See the audit for evaluated inputs.
Only synthetic state is mounted. No image pull/build, host network, production
credentials or production database are used. Recovery mode controls only its
uniquely named disposable systemd service.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid


SCENARIO = r'''
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { realpathSync, writeFileSync } from 'node:fs';
import { PersonalDataDirectus } from './client.mjs';
import { PERSONAL_DATA_SCHEMA } from './schema.mjs';
const apiRequire = createRequire(realpathSync('/directus/node_modules/@directus/api/package.json'));
const sqlite = createRequire(apiRequire.resolve('knex/package.json'))('sqlite3');
const client = new PersonalDataDirectus('http://127.0.0.1:8055', '');
const auth = await client.request('/auth/login', {method:'POST', retries:0,
  body:JSON.stringify({email:'fixture@example.com',password:'synthetic-only-password'})});
const phase = process.argv[2] || 'idle';
const sql = (db,text)=>new Promise((resolve,reject)=>db.all(text,(e,rows)=>e?reject(e):resolve(rows)));
const api = new PersonalDataDirectus('http://127.0.0.1:8055', auth.access_token);
if (phase !== 'verify' && phase !== 'brief') {
await api.request('/collections', {method:'POST',retries:0,body:JSON.stringify({
 collection:'fixture_ingestion',meta:{accountability:'all'},schema:{},fields:[
 {field:'id',type:'string',schema:{is_primary_key:true,is_nullable:false}},
 {field:'value',type:'integer'},
 {field:'date_created',type:'timestamp',meta:{special:['date-created','cast-timestamp']}},
 {field:'date_updated',type:'timestamp',meta:{special:['date-updated','cast-timestamp']}}
 ]})});
// This real committed payload must survive replacement; bootstrap cannot recreate it.
await api.createMany('fixture_ingestion', [{id:'committed-before-lock',value:4242}]);
const reader = await new Promise((resolve,reject)=>{
 const db = new sqlite.Database('/directus/database/data.db',sqlite.OPEN_READONLY,
 e=>e?reject(e):resolve(db));
});
await sql(reader,'BEGIN');
await sql(reader,'SELECT count(*) FROM fixture_ingestion');
// An external read snapshot, like an online integrity scan, prevents rollback-
// journal COMMIT. Keep it until the real client's failed bulk request returns.
let failure;
try { await api.createMany('fixture_ingestion',Array.from({length:100},(_,i)=>({id:`blocked-${i}`,value:i}))); }
catch(e) { failure=e; }
finally { await sql(reader,'ROLLBACK'); await new Promise((r,j)=>reader.close(e=>e?j(e):r())); }
assert(failure,'negative control failed: the reader did not contend with ingestion');
assert.match(failure.message,/SQLITE_BUSY|cannot start a transaction within a transaction/);
console.log('TRIGGER: actual client bulk POST hit SQLite transaction contention');
if (phase === 'traffic' || phase === 'recovery') {
  // Keep using the real API connection, so MIN=0 cannot retire it. This mode
  // has the same recovery assertion as idle mode and must fail without health.
  const until = Date.now() + (phase === 'recovery' ? 300000 : 40000);
  const started = Date.now();
  let previous = started, maxGap = 0;
  if (phase === 'recovery') writeFileSync('/control/triggered', String(started));
  let requests = 0;
  while (Date.now() < until) {
    await api.request('/items/fixture_ingestion?limit=1', {retries:0});
    requests++;
    maxGap = Math.max(maxGap, Date.now() - previous);
    previous = Date.now();
    if (phase === 'recovery') writeFileSync('/control/traffic', JSON.stringify({requests,maxGap,elapsed:Date.now()-started}));
    await new Promise(r=>setTimeout(r,500));
  }
  console.log(`TRAFFIC: ${requests} normal REST reads across 40s`);
  assert.notEqual(phase, 'recovery', 'health recovery exceeded five minutes');
} else {
// Tarn's default idle timeout is 30s, reaped at 1s intervals. An idle connection
// must eventually close and roll back after the failed COMMIT, without restart.
await new Promise(r=>setTimeout(r,32500));
}
}
if (phase === 'brief') {
  const writer = await new Promise((r,j)=>{const x=new sqlite.Database('/directus/database/data.db', e=>e?j(e):r(x));});
  await sql(writer, 'BEGIN EXCLUSIVE');
  writeFileSync('/control/writer', 'locked');
  await new Promise(r=>setTimeout(r,4000));
  await sql(writer, 'ROLLBACK');
  await new Promise((r,j)=>writer.close(e=>e?j(e):r()));
  console.log('PASS: brief exclusive writer released');
  process.exit(0);
}
const probe = await new Promise((resolve,reject)=>{
 const db = new sqlite.Database('/directus/database/data.db',sqlite.OPEN_READONLY,
 e=>e?reject(e):resolve(db));
});
let count, committed;
try {
 count=await sql(probe,'SELECT count(*) AS n FROM fixture_ingestion');
 committed=await sql(probe,'SELECT id,value FROM fixture_ingestion');
}
catch(e) { throw new Error(`persistent source lock after reader closed: ${e.code}`); }
finally { await new Promise((r,j)=>probe.close(e=>e?j(e):r())); }
assert.equal(count[0].n,1,'committed row lost or failed bulk was not rolled back atomically');
assert.deepEqual(committed,[{id:'committed-before-lock',value:4242}]);
console.log('PASS: committed payload survived; all 100 failed-bulk rows absent');
await api.deleteMany('fixture_ingestion',['committed-before-lock']);
await api.createMany('fixture_ingestion',Array.from({length:205},(_,i)=>({id:`good-${i}`,value:i})));
const rows=await api.readAll('fixture_ingestion',{limit:37,sort:['id']});
assert.equal(rows.length,205);
assert.equal(rows.reduce((n,row)=>n+row.value,0),20910);
const result=await api.upsertMany('fixture_ingestion',[{id:'good-0',value:999},{id:'good-204',value:204}]);
assert.deepEqual(result,{created:0,updated:1,skipped:1});
await api.deleteMany('fixture_ingestion',rows.map(row=>row.id));
assert.equal((await api.readAll('fixture_ingestion')).length,0);

for (const name of ['music_scrobbles','workouts']) {
 const definition=PERSONAL_DATA_SCHEMA.find(x=>x.collection===name);
 assert(definition,`missing deployed schema for ${name}`);
 await api.request('/collections',{method:'POST',retries:0,body:JSON.stringify({
   collection:name,meta:{icon:definition.icon,note:definition.note,accountability:'all'},
   schema:{},fields:definition.fields})});
}
const music=Array.from({length:205},(_,i)=>({id:`synthetic-${i}`,source_id:`source-${i}`,
 played_at:'2026-01-01T00:00:00',uts:1767225600+i,artist:'Synthetic Artist',track:`Track ${i}`}));
await api.createMany('music_scrobbles',music);
assert.equal((await api.readAll('music_scrobbles',{limit:37})).length,205);
await api.createMany('workouts',[{id:'synthetic-workout',title:'Synthetic workout',
 start_time:'2026-01-01T00:00:00',duration_minutes:42,payload:{exercises:[{sets:[{weight_kg:12,reps:8}]}]}}]);
await api.updateMany('workouts',[{id:'synthetic-workout',duration_minutes:43}]);
const workout=await api.readOne('workouts','synthetic-workout');
assert.equal(workout.duration_minutes,43);
assert.deepEqual(workout.payload,{exercises:[{sets:[{weight_kg:12,reps:8}]}]});

// Online backup needs a separate connection, so a healthy API alone is not proof.
const db=await new Promise((r,j)=>{const x=new sqlite.Database('/directus/database/data.db',sqlite.OPEN_READONLY,e=>e?j(e):r(x));});
const backup=db.backup('/tmp/fixture-backup.sqlite');
await new Promise((r,j)=>backup.step(-1,e=>e?j(e):r()));
await new Promise((r,j)=>backup.finish(e=>e?j(e):r()));
await new Promise((r,j)=>db.close(e=>e?j(e):r()));
const copy=await new Promise((r,j)=>{const x=new sqlite.Database('/tmp/fixture-backup.sqlite',sqlite.OPEN_READONLY,e=>e?j(e):r(x));});
assert.deepEqual(await sql(copy,'PRAGMA integrity_check'),[{integrity_check:'ok'}]);
assert.equal((await sql(copy,'SELECT count(*) AS n FROM fixture_ingestion'))[0].n,0);
assert.equal((await sql(copy,'SELECT count(*) AS n FROM music_scrobbles'))[0].n,205);
assert.equal((await sql(copy,'SELECT duration_minutes AS n FROM workouts'))[0].n,43);
await new Promise((r,j)=>copy.close(e=>e?j(e):r()));
console.log(`PASS: failed batch rolled back; subsequent 205-row ingestion/upsert/delete and online backup/integrity pass (${phase})`);
'''


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def wait_ready(name, automatic=False):
    for _ in range(150):
        if automatic:
            try:
                if health(name)['Status'] == 'healthy':
                    return
            except (subprocess.CalledProcessError, KeyError):
                pass
            time.sleep(2)
            continue
        ping = subprocess.run(['podman', 'exec', name, 'node', '-e',
            "fetch('http://127.0.0.1:8055/server/ping',{signal:AbortSignal.timeout(1000)}).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
        if ping.returncode == 0:
            return
        time.sleep(2)
    raise AssertionError('synthetic Directus bootstrap failed')


def restarts(unit):
    return int(subprocess.check_output(
        ['systemctl', 'show', unit, '--property=NRestarts', '--value'], text=True))


def health(name):
    return json.loads(subprocess.check_output(
        ['podman', 'inspect', '--format', '{{json .State.Health}}', name],
        text=True, stderr=subprocess.DEVNULL))


def wait_marker(path, seconds=60):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        if path.exists():
            return
        time.sleep(.2)
    raise AssertionError(f'fixture did not reach {path.name}')


def recovery(name, unit, directory):
    # Startup HTTP readiness is a separate gate, never evidence of DB health.
    for _ in range(10):
        subprocess.run(['podman', 'healthcheck', 'run', name],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if health(name)['Status'] == 'healthy':
            break
        time.sleep(1)
    assert health(name)['Status'] == 'healthy'
    assert restarts(unit) == 0, 'bootstrap was restarted'
    brief = subprocess.Popen(['podman', 'exec', name, 'node', '/fixture/scenario.mjs', 'brief'])
    try:
        wait_marker(directory / 'control/writer')
        probe = subprocess.run(['podman', 'healthcheck', 'run', name],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert probe.returncode == 1, 'exclusive writer did not exercise probe failure'
        assert health(name)['FailingStreak'] >= 1
        assert brief.wait(timeout=15) == 0
        run('podman', 'healthcheck', 'run', name, stdout=subprocess.DEVNULL)
        assert health(name)['Status'] == 'healthy'
        assert health(name)['FailingStreak'] == 0
        assert restarts(unit) == 0, 'brief writer contention restarted the service'
        print('PASS: brief writer failed one DB probe, then cleared without restart', flush=True)
    finally:
        if brief.poll() is None:
            brief.terminate()
            brief.wait(timeout=10)

    traffic = subprocess.Popen(['podman', 'exec', name, 'node', '/fixture/scenario.mjs', 'recovery'])
    try:
        wait_marker(directory / 'control/triggered')
        started = time.monotonic()
        # A real persistent lock must fail the real configured probe, while the
        # normal API loop keeps borrowing the broken pooled connection.
        run('podman', 'exec', name, 'node', '-e',
            "fetch('http://127.0.0.1:8055/server/ping').then(r=>process.exit(r.ok?0:1))")
        result = subprocess.run(['podman', 'healthcheck', 'run', name],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert result.returncode == 1, 'persistent lock escaped independent DB probe'
        saw_failures = health(name)['FailingStreak']
        while restarts(unit) == 0 and time.monotonic() - started < 240:
            if traffic.poll() is not None:
                # Podman kills the exec together with the container. NRestarts
                # increments only after systemd's configured restart delay.
                break
            try:
                saw_failures = max(saw_failures, health(name)['FailingStreak'])
            except (subprocess.CalledProcessError, KeyError):
                pass  # Container can disappear while systemd replaces it.
            time.sleep(2)
        restart_deadline = time.monotonic() + 15
        while restarts(unit) == 0 and time.monotonic() < restart_deadline:
            time.sleep(.5)
        assert restarts(unit) == 1, 'persistent lock did not cause exactly one service restart'
        assert saw_failures >= 5, 'did not observe repeated DB health failures'
        traffic.wait(timeout=15)
        receipt = json.loads((directory / 'control/traffic').read_text())
        assert receipt['requests'] >= 100 and receipt['elapsed'] >= 60000
        assert receipt['maxGap'] < 10000, 'traffic left a retirement-sized idle window'
        wait_ready(name, automatic=True)
        run('podman', 'healthcheck', 'run', name, stdout=subprocess.DEVNULL)
        # Startup gate may consume the first invocation after replacement.
        run('podman', 'healthcheck', 'run', name, stdout=subprocess.DEVNULL)
        assert health(name)['Status'] == 'healthy'
        print(f"PASS: health/systemd recovered in {time.monotonic()-started:.1f}s; "
              f"{receipt['requests']} REST reads, max gap {receipt['maxGap']}ms", flush=True)
        run('podman', 'exec', name, 'node', '/fixture/scenario.mjs', 'verify', timeout=180)
        assert restarts(unit) == 1, 'normal CRUD/backup caused another restart'
        run('podman', 'healthcheck', 'run', name, stdout=subprocess.DEVNULL)
        assert health(name)['Status'] == 'healthy'
    finally:
        if traffic.poll() is None:
            traffic.terminate()
            traffic.wait(timeout=10)


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    source = Path(sys.argv[2]).resolve()
    assert source.is_file() and source.name == 'directus.ts'
    image = config['image']
    assert '@sha256:' in image, 'an immutable cached image is required'
    run('podman', 'image', 'exists', image)
    mode = sys.argv[4] if len(sys.argv) > 4 else '--idle'
    assert mode in ('--idle', '--traffic', '--recovery')
    name = 'directus-sqlite-fixture-' + uuid.uuid4().hex[:10]
    unit = name + '.service'
    with tempfile.TemporaryDirectory(prefix='directus-sqlite-fixture-') as temporary:
        directory = Path(temporary)
        directory.chmod(0o700)
        os.chown(directory, 1000, 1000)
        for module in ['directus', 'schema']:
            run(sys.argv[3], 'build', str(source.with_name(module + '.ts')),
                '--target=node', '--outfile', str(directory / ('client.mjs' if module == 'directus' else 'schema.mjs')),
                stdout=subprocess.DEVNULL)
        (directory / 'scenario.mjs').write_text(SCENARIO)
        for path in directory.iterdir():
            path.chmod(0o644)
        env = {k: v for k, v in config['environment'].items() if k.startswith('DB_')}
        assert env['DB_CLIENT'] == 'sqlite3'
        env.update(DB_FILENAME='/directus/database/data.db',
                   KEY='synthetic-key', SECRET='synthetic-secret',
                   ADMIN_EMAIL='fixture@example.com',
                   ADMIN_PASSWORD='synthetic-only-password', TELEMETRY='false')
        command = ['podman', 'run', '--pull=never', '--name', name,
                   '--network=none', '--memory=512m', '--memory-swap=512m',
                   '--cpus=1', '--pids-limit=128', '--cap-drop=ALL',
                   '--security-opt=no-new-privileges', '--user=1000:1000',
                   '--volume', f'{directory}:/fixture:ro']
        if mode == '--recovery':
            # These are the evaluated production health options, not a test copy
            # of its SQL/timeout/retry implementation.
            command += [x for x in config['extraOptions'] if x.startswith('--health-')]
            command += ['--rm']
            for target in ['database', 'control']:
                path = directory / target
                path.mkdir(mode=0o700)
                os.chown(path, 1000, 1000)
                command += ['--volume', f'{path}:' + ('/directus/database' if target == 'database' else '/control')]
        else:
            command += ['--detach', '--tmpfs', '/directus/database:rw,size=128m,mode=1777']
        for target, size in [('uploads', '16m'), ('extensions', '8m')]:
            command += ['--tmpfs', f'/directus/{target}:rw,size={size},mode=1777']
        command += ['--tmpfs', '/tmp:rw,size=64m,mode=1777']
        for key, value in env.items():
            command += ['--env', f'{key}={value}']
        try:
            if mode == '--recovery':
                run('systemd-run', '--quiet', '--collect', '--unit=' + unit,
                    '--property=Restart=' + config['restart'],
                    '--property=RestartSec=' + config['restartSec'],
                    '--property=TimeoutStopSec=15s', '--property=LimitCORE=0',
                    *command, image)
            else:
                run(*command, image, stdout=subprocess.DEVNULL)
            wait_ready(name, automatic=mode == '--recovery')
            if mode == '--recovery':
                recovery(name, unit, directory)
            else:
                run('podman', 'exec', name, 'node', '/fixture/scenario.mjs', mode[2:], timeout=180)
        finally:
            if mode == '--recovery':
                subprocess.run(['systemctl', 'stop', unit], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(['podman', 'rm', '--force', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
