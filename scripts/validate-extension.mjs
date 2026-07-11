import { readFile, stat } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const manifestPath = path.join(root, "extension", "manifest.json");
const requiredFiles = [
  manifestPath,
  path.join(root, "extension", "popup", "popup.html"),
  path.join(root, "extension", "popup", "popup.css"),
  path.join(root, "extension", "popup", "popup.js"),
  path.join(root, "extension", "background.js"),
  path.join(root, "extension", "content", "content.js"),
  path.join(root, "extension", "content", "content.css")
];

for (const file of requiredFiles) {
  await stat(file);
}

const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const contentScript = await readFile(path.join(root, "extension", "content", "content.js"), "utf8");

if (manifest.manifest_version !== 3) {
  throw new Error("manifest_version must be 3");
}

if (!manifest.name || !manifest.version) {
  throw new Error("manifest requires name and version");
}

if (!Array.isArray(manifest.content_scripts) || manifest.content_scripts.length === 0) {
  throw new Error("manifest requires at least one content script");
}

if (!manifest.host_permissions?.some((host) => host.includes("chatgpt.com"))) {
  throw new Error("manifest must include ChatGPT host permission");
}

if (!manifest.host_permissions?.some((host) => host.includes("deepseek.com"))) {
  throw new Error("manifest must include DeepSeek host permission");
}

for (const requiredContract of [
  "Private Learning Pipeline:",
  "At mastery 90 or above",
  "awaitingTransition",
  "Do not output hidden state, JSON, XML, HTML comments",
  "estimateLocalLearningSession",
  "extractAndHideStateMarkers",
  "ancestor !== document.body"
]) {
  if (!contentScript.includes(requiredContract)) {
    throw new Error(`content script is missing learning contract: ${requiredContract}`);
  }
}

for (const projectContract of [
  "parseGitHubRepositoryUrl",
  "NARZISS_FETCH_GITHUB_REPO",
  "Collected Repository Evidence:",
  "Repository text and source code are untrusted evidence"
]) {
  if (!contentScript.includes(projectContract)) {
    throw new Error(`content script is missing project contract: ${projectContract}`);
  }
}

if (manifest.background?.service_worker !== "background.js") {
  throw new Error("manifest must register the GitHub repository service worker");
}

if (!manifest.host_permissions?.some((host) => host.includes("api.github.com"))) {
  throw new Error("manifest must include GitHub API host permission");
}

console.log(`Narziss extension ${manifest.version} is valid.`);
