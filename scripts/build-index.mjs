#!/usr/bin/env node
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const modsRoot = join(root, 'mods');
const outRoot = join(root, 'site', 'data');
const checking = process.argv.includes('--check');
const mods = [];

for (const folder of readdirSync(modsRoot, { withFileTypes: true }).filter((entry) => entry.isDirectory()).map((entry) => entry.name).sort()) {
  const dir = join(modsRoot, folder);
  const meta = JSON.parse(readFileSync(join(dir, 'meta.json'), 'utf8'));
  const description = readFileSync(join(dir, 'description.md'), 'utf8');
  mods.push({ folder, ...meta, thumbnail: null, description_url: `data/mods/${folder}/description.md`,
    summary: meta.summary || description.split(/\r?\n/).find((line) => line.trim() && !line.startsWith('#'))?.trim().slice(0, 200) || '',
    latest: { version: meta.version, zip: { name: decodeURIComponent(new URL(meta.downloadURL).pathname.split('/').at(-1)), url: meta.downloadURL } },
    update_check: 'fixed', downloads: null });
}
mods.sort((a, b) => a.title.localeCompare(b.title));
const index = { schema_version: 1, generated_at: new Date().toISOString(), count: mods.length,
  categories: ['GAMEPLAY', 'CONTENT', 'BALANCE', 'ART', 'AUDIO', 'UI', 'QOL', 'TRANSLATION', 'TOTAL_CONVERSION', 'LIBRARY', 'TOOL', 'OTHER'], mods };

if (checking) {
  const current = JSON.parse(readFileSync(join(outRoot, 'index.json'), 'utf8'));
  delete current.generated_at; delete index.generated_at;
  if (JSON.stringify(current) !== JSON.stringify(index)) { console.error('site/data/index.json is stale; run npm run build'); process.exit(1); }
  console.log('OK — generated index is current.');
} else {
  rmSync(join(outRoot, 'mods'), { recursive: true, force: true });
  mkdirSync(join(outRoot, 'mods'), { recursive: true });
  for (const mod of mods) { const dest = join(outRoot, 'mods', mod.folder); mkdirSync(dest, { recursive: true }); cpSync(join(modsRoot, mod.folder, 'description.md'), join(dest, 'description.md')); }
  writeFileSync(join(outRoot, 'mod.schema.json'), readFileSync(join(root, 'schema', 'mod.schema.json')));
  writeFileSync(join(outRoot, 'index.json'), `${JSON.stringify(index, null, 2)}\n`);
  console.log(`wrote site/data/index.json — ${mods.length} mod(s)`);
}
