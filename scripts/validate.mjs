#!/usr/bin/env node
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const modsRoot = join(root, 'mods');
const categories = new Set(['GAMEPLAY', 'CONTENT', 'BALANCE', 'ART', 'AUDIO', 'UI', 'QOL', 'TRANSLATION', 'TOTAL_CONVERSION', 'LIBRARY', 'TOOL', 'OTHER']);
const profiles = new Set(['content', 'overhaul', 'total_conversion']);
const permissions = new Set(['network', 'filesystem', 'engine_internals']);
const games = new Set(['red', 'blue', 'yellow', 'gold', 'gen1', 'gen2', 'all']);
const semver = /^\d+\.\d+\.\d+(?:[-+].*)?$/;
const idPattern = /^[A-Za-z0-9_-]+$/;
const allowedKeys = new Set(['id', 'title', 'author', 'summary', 'version', 'categories', 'tags', 'repo', 'downloadURL', 'api', 'game_version', 'games', 'profile', 'affects_link', 'experimental', 'permissions', 'dependencies', 'conflicts', 'license']);
const errors = [];
const seen = new Set();

for (const folder of readdirSync(modsRoot, { withFileTypes: true }).filter((entry) => entry.isDirectory()).map((entry) => entry.name).sort()) {
  const dir = join(modsRoot, folder);
  const metaPath = join(dir, 'meta.json');
  const descriptionPath = join(dir, 'description.md');
  let meta;
  try { meta = JSON.parse(readFileSync(metaPath, 'utf8')); }
  catch (error) { errors.push(`${folder}: invalid meta.json (${error.message})`); continue; }
  if (!existsSync(descriptionPath) || !readFileSync(descriptionPath, 'utf8').trim()) errors.push(`${folder}: description.md is required`);
  for (const file of readdirSync(dir).sort()) if (!['meta.json', 'description.md', 'thumbnail.png', 'thumbnail.jpg'].includes(file)) errors.push(`${folder}: unexpected file ${file}`);
  for (const key of Object.keys(meta)) if (!allowedKeys.has(key)) errors.push(`${folder}: unknown field ${key}`);
  for (const key of ['id', 'title', 'author', 'version', 'categories', 'repo', 'downloadURL']) if (meta[key] === undefined) errors.push(`${folder}: missing ${key}`);
  if (!idPattern.test(meta.id ?? '')) errors.push(`${folder}: invalid id`);
  if (!semver.test(meta.version ?? '')) errors.push(`${folder}: invalid semver ${meta.version}`);
  const [folderAuthor, folderId] = folder.split('@');
  if (folderId !== meta.id) errors.push(`${folder}: folder id must equal ${meta.id}`);
  const slug = (value) => String(value).toLowerCase().replace(/[^a-z0-9]/g, '');
  if (slug(folderAuthor) !== slug(meta.author)) errors.push(`${folder}: folder author must match ${meta.author}`);
  if (seen.has(meta.id)) errors.push(`${folder}: duplicate id ${meta.id}`); else seen.add(meta.id);
  if (!Array.isArray(meta.categories) || meta.categories.length < 1 || meta.categories.length > 4 || meta.categories.some((value) => !categories.has(value))) errors.push(`${folder}: invalid categories`);
  if (meta.profile && !profiles.has(meta.profile)) errors.push(`${folder}: invalid profile`);
  if (meta.permissions?.some((value) => !permissions.has(value))) errors.push(`${folder}: invalid permission`);
  if (meta.games?.some((value) => !games.has(value))) errors.push(`${folder}: invalid game target`);
  for (const key of ['repo', 'downloadURL']) { try { const url = new URL(meta[key]); if (url.protocol !== 'https:') throw new Error('not HTTPS'); } catch { errors.push(`${folder}: invalid ${key}`); } }
  if (!String(meta.downloadURL ?? '').endsWith('.zip')) errors.push(`${folder}: downloadURL must end in .zip`);
  let releaseName = '';
  try { releaseName = decodeURIComponent(new URL(meta.downloadURL).pathname.split('/').at(-1)); } catch {}
  if (!existsSync(join(root, 'Releases', releaseName))) errors.push(`${folder}: missing Releases/${releaseName}`);
  const expectedName = `${meta.id}_v${meta.version}.zip`;
  if (releaseName !== expectedName) errors.push(`${folder}: release filename must be ${expectedName}`);
}

if (errors.length) { for (const error of errors) console.error(`error  ${error}`); console.error(`\n${errors.length} error(s).`); process.exit(1); }
console.log(`OK — ${seen.size} launcher entries validated.`);
