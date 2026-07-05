import { mkdir, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { readFile } from "node:fs/promises";

const root = process.cwd();
const manifest = JSON.parse(await readFile(path.join(root, "extension", "manifest.json"), "utf8"));
const version = process.env.GITHUB_REF_NAME?.replace(/^v/, "") || manifest.version;
const distDir = path.join(root, "dist");
const archiveName = `narziss-extension-v${version}.zip`;

await rm(distDir, { recursive: true, force: true });
await mkdir(distDir, { recursive: true });

const result = spawnSync("zip", ["-r", path.join("..", "dist", archiveName), "."], {
  cwd: path.join(root, "extension"),
  stdio: "inherit"
});

if (result.status !== 0) {
  throw new Error("Failed to create extension zip. Make sure the zip command is available.");
}

console.log(`Created dist/${archiveName}`);
