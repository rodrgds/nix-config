// Keep a repeated programme on one transport clock without decoding media.
const WRAP = 2 ** 33;
const wrap = (n) => ((n % WRAP) + WRAP) % WRAP;

function shiftPes(b, p, ticks) {
  const n = wrap((b[p] & 14) * 2 ** 29 + b[p + 1] * 2 ** 22 +
    (b[p + 2] & 254) * 2 ** 14 + b[p + 3] * 128 + (b[p + 4] >> 1) + ticks);
  b[p] = (b[p] & 240) | (Math.floor(n / 2 ** 30) << 1) | 1;
  b[p + 1] = Math.floor(n / 2 ** 22) & 255;
  b[p + 2] = ((Math.floor(n / 2 ** 15) & 127) << 1) | 1;
  b[p + 3] = Math.floor(n / 128) & 255;
  b[p + 4] = ((n & 127) << 1) | 1;
}

export function shiftTransportTimestamps(bytes, seconds) {
  if (bytes.length % 188) throw Error("incomplete transport packet");
  const ticks = Math.round(seconds * 90000);
  for (let p = 0; p < bytes.length; p += 188) {
    if (bytes[p] !== 0x47) throw Error("invalid transport sync");
    const end = p + 188;
    const control = (bytes[p + 3] >> 4) & 3;
    let payload = p + 4;
    if (control & 2) {
      const length = bytes[p + 4];
      if (p + 5 + length > end) throw Error("invalid adaptation field");
      if (length >= 7 && (bytes[p + 5] & 16)) {
        const q = p + 6;
        const n = wrap(bytes[q] * 2 ** 25 + bytes[q + 1] * 2 ** 17 +
          bytes[q + 2] * 512 + bytes[q + 3] * 2 + (bytes[q + 4] >> 7) + ticks);
        bytes[q] = Math.floor(n / 2 ** 25);
        bytes[q + 1] = Math.floor(n / 2 ** 17) & 255;
        bytes[q + 2] = Math.floor(n / 512) & 255;
        bytes[q + 3] = Math.floor(n / 2) & 255;
        bytes[q + 4] = ((n & 1) << 7) | (bytes[q + 4] & 127);
      }
      payload += 1 + length;
    }
    if (!(control & 1) || !(bytes[p + 1] & 64) || payload + 9 > end) continue;
    if (bytes[payload] !== 0 || bytes[payload + 1] !== 0 || bytes[payload + 2] !== 1) continue;
    const flags = bytes[payload + 7] >> 6;
    if (flags < 2) continue;
    const needed = flags === 3 ? 19 : 14;
    // Our FFmpeg muxer emits each PES timestamp in its first TS packet.
    // Refuse unsupported headers instead of silently shifting only one clock.
    if (payload + needed > end) throw Error("split PES timestamp");
    shiftPes(bytes, payload + 9, ticks);
    if (flags === 3) shiftPes(bytes, payload + 14, ticks);
  }
  return bytes;
}
