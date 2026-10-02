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
  shim.write_text("#!/usr/bin/env python3\nimport os,sys\nos.environ['SSH_ORIGINAL_COMMAND']=sys.argv[-1]\nos.execv(sys.executable,[sys.executable,os.environ['RECEIVER'],'--root',os.environ['BACKUP_ROOT']])\n")
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

 def test_restore_stop_drops_temporary_database(self):
  import signal,time
  result=self.send("printf 'SELECT 1;\\n' | gzip", "openpost-db")
  self.assertEqual(result.returncode,0,result.stderr)
  result=self.send("tar -czf - --files-from /dev/null", "openpost-media", "tar-gzip")
  self.assertEqual(result.returncode,0,result.stderr)
  log=self.dir/'commands.log'; runtime=self.dir/'runtime'; runtime.mkdir()
  podman=self.bin/'podman'
  podman.write_text("#!/usr/bin/env python3\nimport os,sys,time\nwith open(os.environ['TEST_COMMAND_LOG'],'a') as f: f.write(' '.join(sys.argv[1:])+'\\n')\nif 'psql' in sys.argv: time.sleep(30)\n")
  podman.chmod(0o700)
  env=dict(self.env,TEST_COMMAND_LOG=str(log),RUNTIME_DIRECTORY=str(runtime))
  proc=subprocess.Popen([sys.executable,str(R.with_name('restore_check.py')),'openpost-db'],env=env,start_new_session=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  try:
   deadline=time.monotonic()+5
   while not log.exists() or 'psql' not in log.read_text():
    if proc.poll() is not None or time.monotonic()>deadline:
     self.fail('restore did not reach PostgreSQL import')
    time.sleep(.02)
   os.killpg(proc.pid,signal.SIGTERM)
   proc.communicate(timeout=5)
   self.assertNotEqual(proc.returncode,0)
   commands=[line.split() for line in log.read_text().splitlines()]
   created=[line[-1] for line in commands if 'createdb' in line]
   dropped=[line[-1] for line in commands if 'dropdb' in line]
   self.assertEqual(dropped,created)
   self.assertEqual(list(runtime.iterdir()),[])
  finally:
   try: os.killpg(proc.pid,signal.SIGKILL)
   except ProcessLookupError: pass
   proc.communicate()



class MediaTests(unittest.TestCase):
 def test_media_stream_and_failed_download(self):
  import io,tarfile
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory); binary=root/'rclone'
   binary.write_text("#!/usr/bin/env python3\nimport json,os,sys\nif sys.argv[1]=='lsjson': print(json.dumps([{'Path':'folder/asset','Size':4,'ModTime':'2026-01-01'}]))\nelse:\n sys.stdout.buffer.write(b'data'); sys.exit(int(os.environ.get('FAIL_DOWNLOAD','0')))\n")
   binary.chmod(0o700)
   env=dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'],OPENPOST_BACKUP_S3_BUCKET='fixture')
   command=[sys.executable,str(R.with_name('media.py'))]
   result=subprocess.run(command,env=env,capture_output=True)
   self.assertEqual(result.returncode,0,result.stderr)
   with tarfile.open(fileobj=io.BytesIO(result.stdout),mode='r:gz') as archive:
    self.assertEqual(archive.extractfile('media/folder/asset').read(),b'data')
   result=subprocess.run(command,env=dict(env,FAIL_DOWNLOAD='8'),capture_output=True)
   self.assertNotEqual(result.returncode,0)

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

if __name__=="__main__": unittest.main()
