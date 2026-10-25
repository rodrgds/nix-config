import gzip, hashlib, json, os, struct, subprocess, sys, tempfile, unittest
from pathlib import Path
R = Path(__file__).resolve().parents[1] / "modules/shared/nas-backup/receiver.py"
def wire(p, commit=True, digest=None):
 return struct.pack("!I",len(p))+p+struct.pack("!I",0)+(json.dumps({"sha256":digest or hashlib.sha256(p).hexdigest(),"bytes":len(p)}).encode()+b"\n" if commit else b"")
class Tests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory(); self.root=Path(self.t.name).resolve()/"backup"; self.root.mkdir()
 def tearDown(self): self.t.cleanup()
 def runrx(self,data,name="montra-db",kind="gzip"):
  return subprocess.run([sys.executable,str(R),"--root",str(self.root)],input=data,capture_output=True,env=dict(os.environ,SSH_ORIGINAL_COMMAND=f"upload {name} {kind}"))
 def snaps(self): return sorted((self.root/"montra-db").glob("snapshot-*"))
 def test_no_commit(self):
  self.assertNotEqual(self.runrx(wire(gzip.compress(b"prefix"),False)).returncode,0); self.assertEqual(self.snaps(),[])
 def test_success(self):
  p=gzip.compress(b"complete"); r=self.runrx(wire(p)); self.assertEqual(r.returncode,0,r.stderr); m=json.loads(r.stdout); self.assertEqual(m["checksum"],hashlib.sha256(p).hexdigest()); self.assertEqual((self.snaps()[0]/"data.gz").read_bytes(),p)
 def test_corruption(self):
  for p,d in [(gzip.compress(b"x")[:-3],None),(gzip.compress(b"x"),"0"*64)]: self.assertNotEqual(self.runrx(wire(p,digest=d)).returncode,0)
  self.assertEqual(self.snaps(),[])
 def test_retention(self):
  for _ in range(9):
   r=self.runrx(wire(gzip.compress(b"x"))); self.assertEqual(r.returncode,0,r.stderr)
  before=self.snaps(); self.assertEqual(len(before),7); self.runrx(wire(gzip.compress(b"x"),False)); self.assertEqual(before,self.snaps()); self.assertEqual(list((self.root/"montra-db").glob(".partial-*")),[])
 def test_wrong_dataset_kind(self):
  self.assertNotEqual(self.runrx(wire(gzip.compress(b"sql")), "vaultwarden", "gzip").returncode, 0)
  self.assertEqual(list(self.root.glob('*/snapshot-*')), [])
 def test_oversized_upload_preserves_successful_snapshot(self):
  import importlib.util, io
  from unittest.mock import patch
  spec = importlib.util.spec_from_file_location('receiver', R)
  receiver = importlib.util.module_from_spec(spec); spec.loader.exec_module(receiver)
  previous = gzip.compress(b'previous backup')
  good = self.runrx(wire(previous))
  self.assertEqual(good.returncode, 0, good.stderr)
  before = self.snaps()
  # Small test budgets exercise the real streaming and publication boundary.
  # The valid payloads differ only in which resource budget they exceed.
  for payload, message in [(bytes(range(256)), 'compressed byte limit'),
                           (b'x' * 2048, 'expanded byte limit')]:
   with self.subTest(message=message), patch.dict(receiver.__dict__, MAX_UPLOAD_BYTES=128, MAX_EXPANDED_BYTES=1024):
    with self.assertRaisesRegex(ValueError, message):
     receiver.receive(str(self.root), 'upload montra-db gzip', io.BytesIO(wire(gzip.compress(payload))))
    self.assertEqual(self.snaps(), before)
    self.assertEqual((before[0] / 'data.gz').read_bytes(), previous)
    self.assertEqual(list((self.root / 'montra-db').glob('.partial-*')), [])
  boundary = gzip.compress(b'x' * 1024)
  with patch.dict(receiver.__dict__, MAX_UPLOAD_BYTES=len(boundary), MAX_EXPANDED_BYTES=1024):
   receipt = receiver.receive(str(self.root), 'upload montra-db gzip', io.BytesIO(wire(boundary)))
  self.assertEqual(gzip.decompress((self.root / receipt['label'] / 'data.gz').read_bytes()), b'x' * 1024)
 def test_unsafe_tar_links(self):
  import io, tarfile
  for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE):
   data = io.BytesIO()
   with tarfile.open(fileobj=data, mode='w') as archive:
    member = tarfile.TarInfo('files/escape'); member.type = kind; member.linkname = '/etc/passwd'
    archive.addfile(member)
   result = self.runrx(wire(gzip.compress(data.getvalue())), 'vaultwarden', 'tar-gzip')
   self.assertNotEqual(result.returncode, 0, result.stderr)
  self.assertEqual(list(self.root.glob('*/snapshot-*')), [])
 def test_confinement(self):
  for n in ["../escape","unknown","montra-db;touch /tmp/no"]: self.assertNotEqual(self.runrx(wire(gzip.compress(b"x")),n).returncode,0)
  (self.root/"montra-db").symlink_to(self.t.name); self.assertNotEqual(self.runrx(wire(gzip.compress(b"x"))).returncode,0)


class StreamingFixture(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory(); self.dir=Path(self.t.name).resolve(); self.root=self.dir/"backups"; self.root.mkdir()
  self.bin=self.dir/"bin"; self.bin.mkdir()
  shim=self.bin/"ssh"
  shim.write_text("#!"+sys.executable+"\nimport os,sys\nos.environ['SSH_ORIGINAL_COMMAND']=sys.argv[-1]\nos.execv(sys.executable,[sys.executable,os.environ['RECEIVER'],'--root',os.environ['BACKUP_ROOT']])\n")
  shim.chmod(0o700)
  self.env=dict(os.environ,PATH=str(self.bin)+os.pathsep+os.environ['PATH'],RECEIVER=str(R),BACKUP_ROOT=str(self.root))
 def tearDown(self): self.t.cleanup()
 def send(self,command,dataset="montra-db",kind="gzip"):
  return subprocess.run([sys.executable,str(R.with_name("sender.py")),dataset,kind,command],env=self.env,capture_output=True,timeout=30)

class StreamingTests(StreamingFixture):
 def test_sender_success(self):
  result=self.send("printf complete | gzip")
  self.assertEqual(result.returncode,0,result.stderr)
  receipt=json.loads(result.stdout); self.assertEqual(receipt['kind'],'gzip')
  self.assertEqual(gzip.decompress((self.root/receipt['label']/"data.gz").read_bytes()),b"complete")
 def test_sender_failed_producer_with_valid_gzip(self):
  result=self.send("{ printf partial; exit 23; } | gzip")
  self.assertNotEqual(result.returncode,0)
  self.assertEqual(list(self.root.glob("*/snapshot-*")),[])
 def test_sqlite_archive_restore_with_files(self):
  import sqlite3,tarfile,io
  app=self.dir/"app"; app.mkdir(); (app/"uploads").mkdir(); (app/"uploads"/"asset").write_bytes(b"image")
  with sqlite3.connect(app/"db.sqlite3") as db:
   db.execute("create table secrets(value text)"); db.execute("insert into secrets values (?)",("hello ' world",))
  command=f"{sys.executable} {R.with_name('sqlite_archive.py')} {app} db.sqlite3"
  result=self.send(command,"vaultwarden","tar-gzip")
  self.assertEqual(result.returncode,0,result.stderr)
  receipt=json.loads(result.stdout)
  with tarfile.open(self.root/receipt['label']/"data.gz",'r:gz') as archive:
   names=archive.getnames(); self.assertNotIn('files/db.sqlite3',names)
   sql=b''.join(archive.extractfile(n).read() for n in sorted(names) if n.startswith('database/'))
   self.assertEqual(archive.extractfile('files/uploads/asset').read(),b'image')
  with sqlite3.connect(':memory:') as db:
   db.executescript(sql.decode()); self.assertEqual(db.execute('select value from secrets').fetchone()[0],"hello ' world")
 def test_tar_corrupt_no_commit(self):
  import io,tarfile
  data=io.BytesIO()
  with tarfile.open(fileobj=data,mode='w') as archive:
   member=tarfile.TarInfo('asset'); member.size=4; archive.addfile(member,io.BytesIO(b'data'))
  bad=gzip.compress(data.getvalue()[:1024])
  result=subprocess.run([sys.executable,str(R),'--root',str(self.root)],input=wire(bad),capture_output=True,env=dict(os.environ,SSH_ORIGINAL_COMMAND='upload openpost-media tar-gzip'))
  self.assertNotEqual(result.returncode,0); self.assertEqual(list(self.root.glob('*/snapshot-*')),[])

 def test_restore_stop_removes_disposable_state(self):
  import signal,time
  result=self.send("printf 'SELECT 1;\\n' | gzip", "openpost-db")
  self.assertEqual(result.returncode,0,result.stderr)
  result=self.send("tar -czf - --files-from /dev/null", "openpost-media", "tar-gzip")
  self.assertEqual(result.returncode,0,result.stderr)
  containers=self.dir/'containers'; containers.mkdir()
  ready=self.dir/'import.started'; runtime=self.dir/'runtime'; runtime.mkdir()
  podman=self.bin/'podman'
  podman.write_text('#!'+sys.executable+'\n'+'''import os,sys,time
from pathlib import Path
args=sys.argv[1:]; registry=Path(os.environ['TEST_CONTAINERS'])
if args[0]=='create':
 (registry/args[args.index('--name')+1]).touch()
elif args[0]=='exec' and 'psql' in args:
 Path(os.environ['TEST_IMPORT_STARTED']).touch()
 time.sleep(30)
elif args[0]=='rm':
 for argument in args[1:]:
  (registry/argument).unlink(missing_ok=True)
''')
  podman.chmod(0o700)
  env=dict(self.env,TEST_CONTAINERS=str(containers),TEST_IMPORT_STARTED=str(ready),
           RUNTIME_DIRECTORY=str(runtime),
           NAS_RESTORE_POSTGRES_IMAGE='docker.io/library/postgres:17-alpine@sha256:'+'a'*64)
  proc=subprocess.Popen([sys.executable,str(R.with_name('restore_check.py')),'openpost-db'],env=env,start_new_session=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  try:
   deadline=time.monotonic()+5
   while not ready.exists():
    if proc.poll() is not None or time.monotonic()>deadline:
     self.fail('restore did not reach PostgreSQL import')
    time.sleep(.02)
   self.assertEqual(len(list(containers.iterdir())),1)
   os.killpg(proc.pid,signal.SIGTERM)
   proc.communicate(timeout=5)
   self.assertNotEqual(proc.returncode,0)
   self.assertEqual(list(containers.iterdir()),[])
   self.assertEqual(list(runtime.iterdir()),[])
  finally:
   try: os.killpg(proc.pid,signal.SIGKILL)
   except ProcessLookupError: pass
   proc.communicate()



class MediaTests(unittest.TestCase):
 def test_media_pagination_and_failed_sources(self):
  import datetime,importlib.util,io,tarfile
  from types import SimpleNamespace
  from unittest.mock import patch
  import boto3
  from botocore.exceptions import ClientError
  from botocore.response import StreamingBody
  from botocore.stub import Stubber
  spec=importlib.util.spec_from_file_location('media',R.with_name('media.py'))
  media=importlib.util.module_from_spec(spec); spec.loader.exec_module(media)
  env={'OPENPOST_BACKUP_S3_BUCKET':'fixture','RCLONE_CONFIG_OPENPOST_ENDPOINT':'https://s3.example.invalid',
       'RCLONE_CONFIG_OPENPOST_REGION':'auto','RCLONE_CONFIG_OPENPOST_ACCESS_KEY_ID':'fixture',
       'RCLONE_CONFIG_OPENPOST_SECRET_ACCESS_KEY':'fixture'}
  modified=datetime.datetime(2026,1,1,tzinfo=datetime.timezone.utc)
  asset={'Key':'folder/ação file','Size':4,'ETag':'"version-one"','LastModified':modified}
  empty={'Key':'empty','Size':0,'ETag':'"empty"','LastModified':modified}
  for mode in ('success','precondition','truncated','changed'):
   with self.subTest(mode=mode):
    client=boto3.client('s3',region_name='us-east-1',aws_access_key_id='fixture',aws_secret_access_key='fixture')
    stub=Stubber(client)
    def listing(first):
     stub.add_response('list_objects_v2',{'Contents':[first],'IsTruncated':True,'NextContinuationToken':'next'}, {'Bucket':'fixture'})
     stub.add_response('list_objects_v2',{'Contents':[empty],'IsTruncated':False}, {'Bucket':'fixture','ContinuationToken':'next'})
    listing(asset)
    request={'Bucket':'fixture','Key':asset['Key'],'IfMatch':asset['ETag']}
    raw=io.BytesIO(b'dat' if mode=='truncated' else b'data')
    if mode=='precondition':
     stub.add_client_error('get_object',service_error_code='PreconditionFailed',http_status_code=412,expected_params=request)
    else:
     stub.add_response('get_object',{'Body':StreamingBody(raw,4),'ContentLength':4},request)
     if mode!='truncated':
      stub.add_response('get_object',{'Body':StreamingBody(io.BytesIO(b''),0),'ContentLength':0},
                        {'Bucket':'fixture','Key':'empty','IfMatch':'"empty"'})
      listing(dict(asset,ETag='"version-two"') if mode=='changed' else asset)
    output=io.BytesIO()
    with stub,patch.dict(os.environ,env),patch.object(media.boto3,'client',return_value=client),patch.object(sys,'stdout',SimpleNamespace(buffer=output)):
     if mode=='success':
      media.main()
     else:
      error={'precondition':ClientError,'truncated':OSError,'changed':RuntimeError}[mode]
      with self.assertRaises(error): media.main()
     stub.assert_no_pending_responses()
    if mode!='precondition': self.assertTrue(raw.closed)
    if mode=='success':
     with tarfile.open(fileobj=io.BytesIO(output.getvalue()),mode='r:gz') as archive:
      self.assertEqual(archive.getnames(),['media/folder/ação file','media/empty'])
      self.assertEqual(archive.extractfile('media/folder/ação file').read(),b'data')
      self.assertEqual(archive.extractfile('media/empty').read(),b'')

class DownloadTests(StreamingFixture):
 def test_download_latest_and_confinement(self):
  payload=gzip.compress(b'restore evidence')
  result=subprocess.run([sys.executable,str(R),'--root',str(self.root)],input=wire(payload),capture_output=True,env=dict(os.environ,SSH_ORIGINAL_COMMAND='upload montra-db gzip'))
  self.assertEqual(result.returncode,0,result.stderr)
  downloaded=subprocess.run([sys.executable,str(R),'--root',str(self.root)],capture_output=True,env=dict(os.environ,SSH_ORIGINAL_COMMAND='download montra-db'))
  self.assertEqual(downloaded.returncode,0,downloaded.stderr)
  manifest,data=downloaded.stdout.split(b'\n',1)
  self.assertEqual(data,payload); self.assertEqual(json.loads(manifest)['checksum'],hashlib.sha256(payload).hexdigest())
  for command in ('download ../escape','download unknown','download montra-db;id'):
   failed=subprocess.run([sys.executable,str(R),'--root',str(self.root)],capture_output=True,env=dict(os.environ,SSH_ORIGINAL_COMMAND=command))
   self.assertNotEqual(failed.returncode,0)

class RestoreTests(unittest.TestCase):
 def test_sqlite_restore_rejects_external_file_operations(self):
  import importlib.util, io, shlex, tarfile
  spec=importlib.util.spec_from_file_location('restore_check',R.with_name('restore_check.py'))
  module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
  for operation in ('shell', 'attach', 'vacuum'):
   with self.subTest(operation=operation), tempfile.TemporaryDirectory() as directory:
    root=Path(directory).resolve(); marker=root/'external-file'; runtime=root/'runtime'; runtime.mkdir()
    sql='CREATE TABLE test(value TEXT);\n'
    if operation=='shell': sql+=f'.shell printf unsafe > {shlex.quote(str(marker))}\n'
    elif operation=='attach': sql+=f"ATTACH DATABASE '{marker}' AS outside;\nCREATE TABLE outside.leak(value TEXT);\n"
    else: sql+=f"VACUUM INTO '{marker}';\n"
    archive=root/'snapshot.gz'
    with tarfile.open(archive,'w:gz') as output:
     payload=sql.encode(); member=tarfile.TarInfo('database/00000000.sql'); member.size=len(payload)
     output.addfile(member,io.BytesIO(payload))
    with self.assertRaises(ValueError): module.sqlite_check(archive,str(runtime))
    self.assertFalse(marker.exists(), operation+' escaped the restore database')

 def test_sqlite_restore_check(self):
  import importlib.util,sqlite3
  spec=importlib.util.spec_from_file_location('restore_check',R.with_name('restore_check.py'))
  module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory); app=root/'app'; app.mkdir()
   with sqlite3.connect(app/'db.sqlite3') as db:
    db.execute('create table test(value text)'); db.execute('insert into test values (?)',('evidence',))
   archived=subprocess.run([sys.executable,str(R.with_name('sqlite_archive.py')),str(app),'db.sqlite3'],capture_output=True,check=True)
   archive=root/'snapshot.gz'; archive.write_bytes(archived.stdout)
   module.sqlite_check(archive,directory)
   with sqlite3.connect(root/'database.sqlite') as db:
    self.assertEqual(db.execute('select value from test').fetchone()[0],'evidence')

class RestoreResourceTests(unittest.TestCase):
 def setUp(self):
  import importlib.util
  spec=importlib.util.spec_from_file_location('resource_restore',R.with_name('restore_check.py'))
  self.restore=importlib.util.module_from_spec(spec); spec.loader.exec_module(self.restore)
  self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name)

 def fetch(self, payload, claimed=None, **changes):
  import io
  from unittest.mock import patch
  destination=self.root/'download.gz'
  manifest=dict(label='directus/snapshot-20261025T140000000000Z-'+'a'*32,
                bytes=len(payload) if claimed is None else claimed,
                checksum=hashlib.sha256(payload).hexdigest(),kind='tar-gzip',verifiedAt='2026-10-25T14:00:00Z')
  manifest.update(changes)
  class Pipe(io.BytesIO):
   high_water=0
   def read(pipe, size=-1):
    if destination.exists(): pipe.high_water=max(pipe.high_water,destination.stat().st_size)
    return super().read(size)
  pipe=Pipe(json.dumps(manifest).encode()+b'\n'+payload)
  from types import SimpleNamespace
  process=SimpleNamespace(stdout=pipe,wait=lambda:0,poll=lambda:0)
  with patch.object(self.restore.socket,'getaddrinfo',return_value=[]), patch.object(self.restore.subprocess,'Popen',return_value=process):
   try: return self.restore.fetch('directus',destination)
   finally:
    self.assertLessEqual(pipe.high_water,4096,'NAS stream grew the staging file beyond its actual byte budget')

 def test_download_real_byte_cap_and_failure_cleanup(self):
  from unittest.mock import patch
  with patch.dict(self.restore.__dict__,DATASET_LIMITS={'directus':(4096,16384)}):
   with self.assertRaises(ValueError): self.fetch(b'x'*131072,claimed=4096)
  self.assertFalse((self.root/'download.gz').exists(),'failed download left staging bytes')

 def test_download_exact_boundary_and_invalid_receipts(self):
  from unittest.mock import patch
  with patch.dict(self.restore.__dict__,DATASET_LIMITS={'directus':(4096,16384)}):
   self.fetch(b'x'*4096)
   self.assertEqual((self.root/'download.gz').read_bytes(),b'x'*4096)
   (self.root/'download.gz').unlink()
   for changes in ({'bytes':4097},{'bytes':True},{'bytes':-1},{'bytes':'4096'},
                   {'checksum':'private-bad-hash'},{'kind':'gzip'},{'extra':'private-field'}):
    with self.subTest(changes=changes), self.assertRaises(ValueError) as error:
     self.fetch(b'x'*4096,**changes)
    self.assertNotIn('private-',str(error.exception))
    self.assertFalse((self.root/'download.gz').exists(),'invalid manifest created a staging file')
   for changes in ({'checksum':'0'*64},{'bytes':4096}):
    with self.subTest(changes=changes), self.assertRaises(ValueError): self.fetch(b'x'*4095,**changes)
    self.assertFalse((self.root/'download.gz').exists(),'checksum/truncated download left staging bytes')

 def archive(self, metadata=None, files=0):
  import io,tarfile
  data=io.BytesIO()
  with tarfile.open(fileobj=data,mode='w',format=tarfile.PAX_FORMAT) as archive:
   sql=b'CREATE TABLE fixture(value TEXT);\nINSERT INTO fixture VALUES (\'preserved\');\n'
   member=tarfile.TarInfo('database/00000000.sql'); member.size=len(sql)
   if metadata: member.pax_headers={'comment':metadata}
   archive.addfile(member,io.BytesIO(sql))
   for index in range(files): archive.addfile(tarfile.TarInfo('files/'+str(index)))
  path=self.root/'archive.gz'; path.write_bytes(gzip.compress(data.getvalue()))
  return path,len(data.getvalue())

 def test_expansion_boundary_and_bomb_including_tar_trailer(self):
  from unittest.mock import patch
  from contextlib import closing
  import sqlite3
  path,expanded=self.archive()
  with patch.dict(self.restore.__dict__,DATASET_LIMITS={'directus':(4096,expanded)}):
   self.restore.sqlite_check(path,self.root)
  with closing(sqlite3.connect(self.root/'database.sqlite')) as db:
   self.assertEqual(db.execute('SELECT value FROM fixture').fetchall(),[('preserved',)])
  (self.root/'database.sqlite').unlink()
  # The extra gzip member is valid and lies after tar's logical EOF. It must
  # still count, rather than disappearing when the tar iterator finishes.
  path.write_bytes(path.read_bytes()+gzip.compress(b'\0'*65536))
  with patch.dict(self.restore.__dict__,DATASET_LIMITS={'directus':(4096,expanded)}):
   with self.assertRaisesRegex(ValueError,'expanded byte limit'):
    self.restore.sqlite_check(path,self.root)
  self.assertFalse((self.root/'database.sqlite').exists())

 def test_tar_metadata_and_entry_budgets_before_restore(self):
  from unittest.mock import patch
  for metadata,files,budget in [('x'*32768,0,{'MAX_TAR_METADATA_BYTES':1024}),
                                (None,20,{'MAX_TAR_HEADERS':10})]:
   with self.subTest(budget=budget):
    (self.root/'database.sqlite').unlink(missing_ok=True)
    path,_=self.archive(metadata,files)
    with patch.dict(self.restore.__dict__,**budget):
     with self.assertRaisesRegex(ValueError,'tar .* limit'):
      self.restore.sqlite_check(path,self.root)
    self.assertFalse((self.root/'database.sqlite').exists())

 def test_sqlite_actual_file_growth_is_bounded(self):
  import io,tarfile
  from unittest.mock import patch
  path=self.root/'growth.gz'
  payload=b'CREATE TABLE growth(value); INSERT INTO growth VALUES (zeroblob(1048576));\n'
  with tarfile.open(path,'w:gz') as archive:
   member=tarfile.TarInfo('database/00000000.sql'); member.size=len(payload)
   archive.addfile(member,io.BytesIO(payload))
  with patch.dict(self.restore.__dict__,SQLITE_FILE_BYTES=16384):
   with self.assertRaises(ValueError): self.restore.sqlite_check(path,self.root)
  self.assertLessEqual((self.root/'database.sqlite').stat().st_size,16384)

 def test_tar_metadata_rejection_precedes_large_allocation(self):
  import tracemalloc
  path,_=self.archive('x'*(16*1024**2))
  tracemalloc.start()
  try:
   with self.assertRaisesRegex(ValueError,'tar metadata limit'):
    self.restore.sqlite_check(path,self.root)
   _,peak=tracemalloc.get_traced_memory()
  finally: tracemalloc.stop()
  self.assertLess(peak,2*1024**2,'parser allocated the hostile metadata before rejecting it')
  self.assertFalse((self.root/'database.sqlite').exists())

 def test_cli_private_cache_success_failure_and_interruption(self):
  import signal,time
  path,_=self.archive('normal bounded PAX metadata')
  cache=self.root/'cache'; cache.mkdir()
  runtime=self.root/'runtime'; runtime.mkdir()
  binary=self.root/'bin'; binary.mkdir()
  shim=binary/'ssh'
  shim.write_text('#!'+sys.executable+'''
import hashlib,json,os,sys,time
from pathlib import Path
data=Path(os.environ['FIXTURE_ARCHIVE']).read_bytes()
manifest=dict(label='directus/snapshot-20261025T140000000000Z-'+'a'*32,
              bytes=len(data), checksum=hashlib.sha256(data).hexdigest())
if os.environ['FIXTURE_MODE']=='checksum': manifest['checksum']='0'*64
sys.stdout.buffer.write(json.dumps(manifest).encode()+b'\\n'+data)
sys.stdout.buffer.flush()
if os.environ['FIXTURE_MODE']=='interrupt':
 Path(os.environ['FIXTURE_READY']).touch()
 time.sleep(30)
''')
  shim.chmod(0o700)
  for mode in ('success','checksum','interrupt'):
   with self.subTest(mode=mode):
    # systemd creates CacheDirectory and removes staging in ExecStopPost. Here
    # we exercise CLI success/error/TERM cleanup before that fallback is needed.
    staging=cache/'staging'
    if staging.exists(): staging.rmdir()
    ready=self.root/'ready'
    env=dict(os.environ,PATH=str(binary)+os.pathsep+os.environ['PATH'],
             CACHE_DIRECTORY=str(cache),RUNTIME_DIRECTORY=str(runtime),
             FIXTURE_ARCHIVE=str(path),FIXTURE_MODE=mode,FIXTURE_READY=str(ready))
    proc=subprocess.Popen([sys.executable,str(R.with_name('restore_check.py')),'directus'],
                          env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    try:
     if mode=='interrupt':
      deadline=time.monotonic()+5
      while not ready.exists():
       self.assertIsNone(proc.poll(),'CLI exited before interruptible download')
       if time.monotonic()>deadline: self.fail('fixture download did not start')
       time.sleep(.02)
      self.assertEqual(list(runtime.iterdir()),[],'archive staging used shared runtime tmpfs')
      self.assertTrue(list(staging.iterdir()),'private cache staging was not used')
      proc.send_signal(signal.SIGTERM)
     stdout,stderr=proc.communicate(timeout=5)
     if mode=='success': self.assertEqual(proc.returncode,0,stderr)
     else:
      self.assertNotEqual(proc.returncode,0)
      self.assertNotIn(b'preserved',stdout+stderr)
     self.assertEqual(list(staging.iterdir()),[],'CLI left disposable staging files')
     self.assertEqual(list(runtime.iterdir()),[])
    finally:
     if proc.poll() is None: proc.kill()
     proc.communicate()


if __name__=="__main__": unittest.main()
