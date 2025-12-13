import fs from "node:fs/promises";
import path from "node:path";

const repoRoot = path.resolve(process.cwd(), "..");
const webRoot = process.cwd();

const copies = [
  {
    from: path.join(webRoot, "packages", "core", "dist", "index.js"),
    to: path.join(webRoot, "web", "js", "ts", "core.js"),
  },
  {
    from: path.join(webRoot, "packages", "core-worker", "dist", "worker.js"),
    to: path.join(webRoot, "web", "js", "ts", "worker.js"),
  },
  {
    from: path.join(webRoot, "node_modules", "@ffmpeg", "core", "dist", "esm", "ffmpeg-core.js"),
    to: path.join(webRoot, "web", "js", "ffmpeg-core.js"),
  },
  {
    from: path.join(webRoot, "node_modules", "@ffmpeg", "core", "dist", "esm", "ffmpeg-core.wasm"),
    to: path.join(webRoot, "web", "js", "ffmpeg-core.wasm"),
  },
];

await ensureDirs();
await copyAll();

async function ensureDirs() {
  await fs.mkdir(path.join(webRoot, "web", "js", "ts"), { recursive: true });
}

async function copyAll() {
  for (const entry of copies) {
    await assertExists(entry.from);
    await fs.copyFile(entry.from, entry.to);
    const relTo = path.relative(repoRoot, entry.to);
    console.log(`[sync] ${relTo}`);
  }
}

async function assertExists(filePath) {
  try {
    await fs.stat(filePath);
  } catch {
    const rel = path.relative(repoRoot, filePath);
    throw new Error(`Missing file: ${rel}\nRun \`npm run build:ts\` first (or \`npm run build\`).`);
  }
}

