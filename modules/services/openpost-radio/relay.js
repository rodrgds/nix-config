// Send pre-encoded broadcasts. No scene rendering, audio decoding, or encoding here.
import { spawn, execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  mkdir,
  readFile,
  writeFile,
  rename,
  readdir,
  rm,
  open,
} from "node:fs/promises";
import { createWriteStream } from "node:fs";
import { pipeline } from "node:stream/promises";
import { join } from "node:path";
const run = promisify(execFile);
const state = process.env.RGO_MUSIC_STATE ?? "/var/lib/openpost-radio";
const cache = process.env.RGO_MUSIC_BUFFER ?? "/var/cache/openpost-radio";
const host = process.env.RGO_MUSIC_NAS_HOST ?? "kraktoos@100.88.5.41";
const key =
  process.env.RGO_MUSIC_NAS_KEY ??
  join(process.env.CREDENTIALS_DIRECTORY ?? "", "nas-key");
const output = (process.env.RGO_MUSIC_OUTPUTS ?? "").trim();
if (!output) throw Error("missing stream output");
const sshArgs = [
  "-T",
  "-oBatchMode=yes",
  "-oIdentitiesOnly=yes",
  "-oStrictHostKeyChecking=yes",
  "-oLogLevel=ERROR",
  "-oConnectTimeout=10",
  "-oServerAliveInterval=10",
  "-oServerAliveCountMax=2",
  ...(process.env.RGO_MUSIC_NAS_KNOWN_HOSTS
    ? ["-oUserKnownHostsFile=" + process.env.RGO_MUSIC_NAS_KNOWN_HOSTS]
    : []),
  "-i",
  key,
  host,
];
const pause = (ms) => new Promise((r) => setTimeout(r, ms));
const fileName = (i) => `chunk-${String(i).padStart(5, "0")}.ts`;
await mkdir(state, { recursive: true });
await mkdir(cache, { recursive: true });
async function manifest() {
  try {
    const { stdout } = await run(
      "ssh",
      [...sshArgs, "read programmes/current.json"],
      { timeout: 90000, maxBuffer: 1048576 },
    );
    const m = JSON.parse(stdout);
    if (
      !/^p-[a-z0-9-]+$/.test(m.id) ||
      m.chunkSeconds !== 240 ||
      !Number.isInteger(m.count) ||
      m.count < 1 ||
      m.count > 1000 ||
      !Number.isFinite(m.anchor) ||
      m.seconds !== m.count * m.chunkSeconds ||
      !Number.isInteger(m.ready) ||
      m.ready < 1 ||
      m.ready > m.count
    )
      throw Error("invalid broadcast manifest");
    await writeFile(join(state, "programme.json"), stdout);
    return m;
  } catch (e) {
    return readFile(join(state, "programme.json"), "utf8").then(
      JSON.parse,
      () => {
        throw e;
      },
    );
  }
}
let ff = null,
  stopping = false;
process.on("SIGTERM", () => {
  stopping = true;
  ff?.kill("SIGTERM");
});
process.on("SIGINT", () => {
  stopping = true;
  ff?.kill("SIGTERM");
});
while (!stopping) {
  const m = await manifest();
  const seek =
    ((((Date.now() - m.anchor) / 1000) % m.seconds) + m.seconds) % m.seconds;
  const start = Math.floor(seek / m.chunkSeconds);
  if (!m.complete && m.ready < start + 11) {
    console.log(
      `waiting for broadcast buffer: ${m.ready} chunks ready, need ${start + 11}`,
    );
    await pause(15000);
    continue;
  }
  const folder = join(cache, m.id);
  await mkdir(folder, { recursive: true });
  const wanted = (i) =>
    new Set([
      ...Array.from(
        { length: Math.min(11, m.count) },
        (_, n) => (i + n) % m.count,
      ),
    ]);
  const inflight = new Map();
  const available = new Set(
    (await readdir(folder)).flatMap((name) => {
      const match = /^chunk-(\d{5})\.ts\.ready$/.exec(name);
      return match ? [Number(match[1])] : [];
    }),
  );
  async function download(i) {
    if (inflight.has(i)) return inflight.get(i);
    const job = (async () => {
      const file = join(folder, fileName(i));
      if (
        await readFile(file + ".ready", "utf8").then(
          () => true,
          () => false,
        )
      )
        return;
      const child = spawn(
        "ssh",
        [...sshArgs, `read programmes/${m.id}/${fileName(i)}`],
        { stdio: ["ignore", "pipe", "pipe"] },
      );
      let error = "";
      child.stderr.on("data", (b) => (error += b));
      const exit = new Promise((resolve, reject) => {
        child.on("error", reject);
        child.on("close", (c) =>
          c === 0
            ? resolve()
            : reject(Error(error.trim() || `NAS read failed: ${i}`)),
        );
      });
      try {
        await Promise.all([
          pipeline(child.stdout, createWriteStream(file + ".partial")),
          exit,
        ]);
        await rename(file + ".partial", file);
        await writeFile(file + ".ready", "ready");
        available.add(i);
      } catch (e) {
        child.kill();
        await rm(file + ".partial", { force: true });
        throw e;
      }
    })();
    inflight.set(i, job);
    try {
      await job;
    } finally {
      inflight.delete(i);
    }
  }
  async function fill(i) {
    const keep = wanted(i);
    // Prune before downloading, including after a restart far ahead in the
    // programme. Otherwise old and new complete windows double disk usage.
    for (const f of await readdir(folder)) {
      const match = /^chunk-(\d{5})\.ts(?:\.ready|\.partial)?$/.exec(f);
      if (
        match &&
        !keep.has(Number(match[1])) &&
        !inflight.has(Number(match[1]))
      ) {
        await rm(join(folder, f), { force: true });
        available.delete(Number(match[1]));
      }
    }
    const queue = [...keep];
    await Promise.all(
      Array.from({ length: 2 }, async () => {
        while (queue.length) await download(queue.shift());
      }),
    );
    for (const d of await readdir(cache, { withFileTypes: true }))
      if (d.isDirectory() && d.name !== m.id && /^p-[a-z0-9-]+$/.test(d.name))
        await rm(join(cache, d.name), { recursive: true, force: true });
  }
  try {
    await fill(start);
  } catch (e) {
    console.error(e.message);
    await pause(10000);
    continue;
  }
  let offset =
    ((((Date.now() - m.anchor) / 1000) % m.seconds) + m.seconds) % m.seconds;
  let initial = Math.floor(offset / m.chunkSeconds),
    filled = start;
  while (initial !== filled) {
    await fill(initial);
    filled = initial;
    offset =
      ((((Date.now() - m.anchor) / 1000) % m.seconds) + m.seconds) % m.seconds;
    initial = Math.floor(offset / m.chunkSeconds);
  }
  // Align startup to a two-second keyframe. Feed continuous TS packets instead
  // of seeking a looping concat input, whose first partial loop resets DTS.
  offset = Math.floor(offset / 2) * 2;
  const localOffset = offset % m.chunkSeconds;
  const stats = { seconds: 0, bytes: 0 };
  let pending = "",
    errors = "",
    alive = true,
    refill = null,
    lastIndex = initial;
  const args = [
    "-hide_banner",
    "-loglevel",
    "warning",
    "-nostats",
    "-progress",
    "pipe:3",
    "-stats_period",
    "5",
    "-re",
    "-ss",
    String(localOffset),
    "-threads",
    "1",
    "-probesize",
    "524288",
    "-analyzeduration",
    "1000000",
    "-f",
    "mpegts",
    "-i",
    "pipe:0",
    "-map",
    "0:v:0",
    "-map",
    "0:a:0",
    "-c",
    "copy",
    "-f",
    "flv",
    "-flvflags",
    "no_duration_filesize",
    output,
  ];
  ff = spawn("ffmpeg", args, { stdio: ["pipe", "ignore", "pipe", "pipe"] });
  const sender = ff;
  sender.stdin.on("error", () => {}); // EPIPE is handled by the process exit.
  const packetBuffer = Buffer.allocUnsafe(128 * 1024);
  const feed = (async () => {
    let i = initial;
    while (alive && !stopping) {
      try {
        await download(i);
      } catch (error) {
        console.error(`buffer read: ${error.message}`);
        await pause(5000);
        continue;
      }
      const file = await open(join(folder, fileName(i)), "r");
      try {
        while (alive && !stopping && !sender.stdin.destroyed) {
          const { bytesRead } = await file.read(
            packetBuffer,
            0,
            packetBuffer.length,
            null,
          );
          if (!bytesRead) break;
          // Reuse the storage only after the pipe has consumed it. Allocating
          // a fresh Buffer for every read grows the long-running V8 heap.
          await new Promise((resolve, reject) =>
            sender.stdin.write(packetBuffer.subarray(0, bytesRead), (error) =>
              error ? reject(error) : resolve(),
            ),
          );
        }
      } finally {
        await file.close();
      }
      i = (i + 1) % m.count;
    }
  })().catch((error) => {
    if (alive && !stopping) console.error(`packet source: ${error.message}`);
    sender.kill("SIGTERM");
  });
  ff.stdio[3].on("data", (b) => {
    pending += b;
    const lines = pending.split("\n");
    pending = lines.pop();
    for (const line of lines) {
      const [k, v] = line.split("=");
      if (k === "out_time_us" && Number.isFinite(+v)) stats.seconds = +v / 1e6;
      if (k === "total_size" && Number.isFinite(+v)) stats.bytes = +v;
    }
  });
  ff.stderr.on("data", (b) => {
    errors += b;
    const end = errors.lastIndexOf("\n");
    if (end >= 0) {
      process.stderr.write(
        errors
          .slice(0, end + 1)
          .replace(/rtmps?:\/\/[^\s'"\]]+/g, "<stream-output>"),
      );
      errors = errors.slice(end + 1);
    }
  });
  const timer = setInterval(() => {
    const i =
      Math.floor((offset + Math.max(0, stats.seconds)) / m.chunkSeconds) %
      m.count;
    if (i !== lastIndex && !refill) {
      refill = fill(i)
        .then(() => {
          lastIndex = i;
        })
        .catch((e) => console.error(`buffer refill: ${e.message}`))
        .finally(() => {
          refill = null;
        });
    }
    let ahead = 0;
    for (let n = 1; n <= Math.min(10, m.count - 1); n++) {
      if (!available.has((i + n) % m.count)) break;
      ahead++;
    }
    const status = {
      at: Date.now(),
      revision: process.env.RGO_MUSIC_REVISION,
      mode: "packet-copy",
      fps: m.fps,
      width: m.width,
      height: m.height,
      programme: m.id,
      bufferChunks: ahead,
      bufferSeconds: ahead * m.chunkSeconds,
      encoderAlive: alive,
      encoded: { ...stats },
    };
    writeFile(join(state, "status.json.tmp"), JSON.stringify(status))
      .then(() =>
        rename(join(state, "status.json.tmp"), join(state, "status.json")),
      )
      .catch((e) => console.error(e.message));
  }, 5000);
  console.log(
    `relaying ${m.width}x${m.height} at ${m.fps}fps; 10 chunks ahead; no encoding`,
  );
  await new Promise((resolve) => {
    ff.on("close", () => {
      alive = false;
      resolve();
    });
    ff.on("error", (e) => {
      console.error(e.message);
      alive = false;
      resolve();
    });
  });
  clearInterval(timer);
  await feed;
  if (refill) await refill;
  if (!stopping) await pause(5000);
}
