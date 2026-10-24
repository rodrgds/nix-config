(function (root) {
  'use strict';
  const node = typeof module !== 'undefined' && module.exports;
  const G = node ? require('./geometry.js') : root.TechnicalGeometry;
  const SHEET = node ? require('./sheet.js') : root.TechnicalSheet;
  const {add, sub, dot, cross, ROLES} = G;

  function createCamera({azimuth = -135, elevation = Math.asin(1 / Math.sqrt(3)) * 180 / Math.PI, roll = 16} = {}) {
    if (![azimuth, elevation, roll].every(Number.isFinite) || Math.abs(elevation) > 90) throw Error('Invalid camera angles');
    const a = azimuth * Math.PI / 180, e = elevation * Math.PI / 180, r = roll * Math.PI / 180;
    const direction = [Math.cos(e) * Math.cos(a), Math.cos(e) * Math.sin(a), Math.sin(e)];
    const right = [-Math.sin(a), Math.cos(a), 0], up = cross(direction, right);
    return {
      direction,
      project: p => {
        const x = dot(p, right), y = -dot(p, up);
        return [x * Math.cos(r) - y * Math.sin(r), x * Math.sin(r) + y * Math.cos(r), dot(p, direction)];
      }
    };
  }
  const defaultCamera = createCamera();
  const project = (point, camera) => (camera ? createCamera(camera) : defaultCamera).project(point);

  const escape = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
  const round = n => Number(n.toFixed(4));
  const rank = line => ROLES.indexOf(line.role);
  const shift = (part, amount) => part.explosion.map(n => n * amount);

  function contours(part, direction) {
    const edges = new Map();
    for (const f of part.triangles) {
      const ab = sub(part.vertices[f[1]], part.vertices[f[0]]), ac = sub(part.vertices[f[2]], part.vertices[f[0]]), n = cross(ab, ac);
      const length = Math.hypot(...n), flat = length <= Math.hypot(...ab) * Math.hypot(...ac) * 1e-12;
      for (let j = 0; j < 3; j++) {
        const a = f[j], b = f[(j + 1) % 3], key = a < b ? `${a}:${b}` : `${b}:${a}`;
        if (!edges.has(key)) edges.set(key, {a, b, uses: 0, signs: []});
        const edge = edges.get(key);
        edge.uses++;
        if (!flat) edge.signs.push(dot(n, direction) / length);
      }
    }
    return [...edges.values()].filter(e => {
      if (!e.signs.length) return false;
      if (e.uses === 1) return true;
      const low = Math.min(...e.signs), high = Math.max(...e.signs);
      return low <= 1e-8 && high >= -1e-8 && (low < -1e-8 || high > 1e-8);
    });
  }

  function chain(segments) {
    const ends = new Map(), used = new Uint8Array(segments.length);
    segments.forEach(([a, b], i) => {
      for (const end of [a, b]) {
        if (!ends.has(end)) ends.set(end, []);
        ends.get(end).push(i);
      }
    });
    const extend = (from, add) => {
      for (let tail = from; ;) {
        const next = ends.get(tail).find(i => !used[i]);
        if (next === undefined) return;
        used[next] = 1;
        const [a, b] = segments[next];
        tail = a === tail ? b : a;
        add(tail);
      }
    };
    let d = '';
    segments.forEach(([a, b], i) => {
      if (used[i]) return;
      used[i] = 1;
      const points = [a, b];
      extend(b, end => points.push(end));
      extend(a, end => points.unshift(end));
      d += 'M' + points.join('L');
    });
    return d;
  }

  function checkPart(p) {
    if (p.triangles.some(f => f.length !== 3 || f.some(i => !Number.isInteger(i) || i < 0 || i >= p.vertices.length))) {
      throw Error(`Part ${p.id} has a triangle that references a missing vertex`);
    }
    if (!p.vertices.every(G.isPoint) || !p.lines.every(l => G.isPoint(l.a) && G.isPoint(l.b))) {
      throw Error(`Part ${p.id} has a point without three finite coordinates`);
    }
  }

  function fit(scenes) {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    const extend = ([x, y]) => {
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    };
    for (const {meshes, trails} of scenes) {
      for (const mesh of meshes) {
        mesh.points.forEach(extend);
        for (const l of mesh.lines) [l.a, l.b].forEach(extend);
      }
      for (const t of trails) [t.a, t.b].forEach(extend);
    }
    if (![minX, minY, maxX, maxY].every(Number.isFinite)) throw Error('Drawing geometry must contain finite vertices');
    const scale = Math.min((SHEET.width - SHEET.margin * 2) / (maxX - minX || 1), (SHEET.height - SHEET.margin * 2) / (maxY - minY || 1));
    const bounds = {width: (maxX - minX) * scale, height: (maxY - minY) * scale};
    bounds.x = (SHEET.width - bounds.width) / 2;
    bounds.y = (SHEET.height - bounds.height) / 2;
    return {scale, bounds, offset: [bounds.x - minX * scale, bounds.y - minY * scale]};
  }

  function occluder(meshes, paper, depthTolerance) {
    const triangles = [], cells = new Map(), cellSize = 1.5;
    const cell = n => Math.floor(n / cellSize);
    for (const mesh of meshes) {
      if (mesh.part.transparent) continue;
      const points = mesh.points.map(paper);
      for (const face of mesh.part.triangles) {
        const [a, b, c] = face.map(i => points[i]);
        const den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1]);
        const span = Math.max((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2, (b[0] - c[0]) ** 2 + (b[1] - c[1]) ** 2, (c[0] - a[0]) ** 2 + (c[1] - a[1]) ** 2);
        if (Math.abs(den) <= span * 1e-9) continue;
        const id = triangles.push({a, b, c, den}) - 1;
        for (let x = cell(Math.min(a[0], b[0], c[0])); x <= cell(Math.max(a[0], b[0], c[0])); x++) {
          for (let y = cell(Math.min(a[1], b[1], c[1])); y <= cell(Math.max(a[1], b[1], c[1])); y++) {
            const key = x + ',' + y;
            if (!cells.has(key)) cells.set(key, []);
            cells.get(key).push(id);
          }
        }
      }
    }
    return p => {
      for (const id of cells.get(cell(p[0]) + ',' + cell(p[1])) || []) {
        const {a, b, c, den} = triangles[id];
        const u = ((b[1] - c[1]) * (p[0] - c[0]) + (c[0] - b[0]) * (p[1] - c[1])) / den;
        if (u < -.000001 || u > 1.000001) continue;
        const v = ((c[1] - a[1]) * (p[0] - c[0]) + (a[0] - c[0]) * (p[1] - c[1])) / den;
        if (v < -.000001 || u + v > 1.000001) continue;
        if (u * a[2] + v * b[2] + (1 - u - v) * c[2] > p[2] + depthTolerance) return false;
      }
      return true;
    };
  }

  function inker({paper, scale, visible, sample}) {
    const point = p => `${round(p[0])} ${round(p[1])}`;
    return lines => {
      const paths = new Map(), seen = new Set();
      for (const {a: from, b: to, role} of lines.sort((a, b) => rank(a) - rank(b))) {
        const a = paper(from), b = paper(to);
        const key = [a, b].map(q => point(q) + ' ' + round(q[2] * scale)).sort().join('|');
        if (seen.has(key)) continue;
        seen.add(key);
        const steps = Math.max(1, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / sample));
        let run = null, previous = null;
        const keep = (start, end) => {
          const ends = [point(start), point(end)];
          if (ends[0] === ends[1]) return;
          if (!paths.has(role)) paths.set(role, []);
          paths.get(role).push(ends);
        };
        for (let i = 0; i <= steps; i++) {
          const at = a.map((n, k) => n + (b[k] - n) * i / steps);
          if (visible(at)) {
            run ??= at;
          } else if (run !== null) {
            if (previous) keep(run, previous);
            run = null;
          }
          previous = at;
        }
        if (run !== null) keep(run, previous);
      }
      return [...paths].map(([role, segments]) => `<path data-line-role="${role}" fill="none" d="${chain(segments)}"/>`).join('');
    };
  }

  function render(parts, {explosion = 1, isolated = null, sample = .045, camera, fitExplosion = explosion, trails = []} = {}) {
    for (const [name, value] of [['Explosion', explosion], ['Fit explosion', fitExplosion]]) {
      if (!Number.isFinite(value) || value < 0 || value > 2) throw Error(name + ' must be 0–2');
    }
    if (!Number.isFinite(sample) || sample < .01 || sample > .2) throw Error('Invalid paper-space sampling');
    if (!Array.isArray(trails)) throw Error('Trails must be an array');
    const view = camera ? createCamera(camera) : defaultCamera;
    const shown = isolated === null ? parts : parts.filter(p => p.id === String(isolated));
    if (!shown.length) throw Error('Unknown part');
    shown.forEach(checkPart);

    const byId = new Map(parts.map(p => [p.id, p]));
    const trailEnd = (point, id, amount) => {
      G.point3(point, 'A trail end');
      if (id === undefined || id === null) return point;
      if (!byId.has(String(id))) throw Error(`Trail refers to unknown part ${id}`);
      return add(point, shift(byId.get(String(id)), amount));
    };
    const scene = amount => ({
      meshes: shown.map(part => {
        const offset = shift(part, amount), place = v => view.project(add(v, offset));
        return {part, points: part.vertices.map(place), lines: part.lines.map(l => ({role: l.role, a: place(l.a), b: place(l.b)}))};
      }),
      trails: isolated === null ? trails.map(t => {
        const a = trailEnd(t.a, t.from, amount), b = trailEnd(t.b, t.to, amount);
        return {role: G.lineRole(t.role ?? 'axis'), a: view.project(a), b: view.project(b), collapsed: Math.hypot(...sub(a, b)) <= 1e-9};
      }) : []
    });

    const current = scene(explosion);
    const {scale, bounds, offset} = fit(fitExplosion === explosion ? [current] : [current, scene(fitExplosion)]);
    const paper = p => [offset[0] + p[0] * scale, offset[1] + p[1] * scale, p[2]];
    const ink = inker({paper, scale, sample, visible: occluder(current.meshes, paper, .01 / scale)});

    const groups = current.meshes.map(({part, points, lines}) => {
      const outlines = contours(part, view.direction).map(({a, b}) => ({a: points[a], b: points[b], role: 'outline'}));
      const id = `part-${escape(part.id)}-${escape(SHEET.slug(part.name))}`;
      return `<g id="${id}" data-item="${escape(part.id)}" data-name="${escape(part.name)}"><title>${escape(part.name)}</title>${ink([...lines, ...outlines])}</g>`;
    });
    const trailInk = ink(current.trails.filter(t => !t.collapsed));
    if (trailInk) groups.push(`<g data-trails="">${trailInk}</g>`);
    return {markup: groups.join(''), bounds, scale, offset};
  }

  const api = {SHEET, createCamera, project, render};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.TechnicalProjection = api;
})(globalThis);
