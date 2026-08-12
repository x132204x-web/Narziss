const GITHUB_API = "https://api.github.com";
const MAX_README_CHARS = 14000;
const MAX_TREE_ENTRIES = 350;
const MAX_SOURCE_FILES = 6;
const MAX_SOURCE_CHARS = 7000;
const MAX_TOTAL_SOURCE_CHARS = 26000;
const SKILL_CATALOG_REPO = {
  owner: "24kchengYe",
  repo: "human-skill-tree"
};
const SKILL_CATALOG_CACHE_KEY = "narzissHumanSkillCatalog";
const SKILL_CATALOG_CACHE_TTL = 24 * 60 * 60 * 1000;
const MAX_SKILL_FILES = 80;
const MAX_SKILL_CONTENT_CHARS = 1800;

const IMPORTANT_FILES = [
  /^package\.json$/i,
  /^pyproject\.toml$/i,
  /^cargo\.toml$/i,
  /^go\.mod$/i,
  /^composer\.json$/i,
  /^gemfile$/i,
  /^requirements\.txt$/i,
  /^dockerfile$/i,
  /^docker-compose\.ya?ml$/i,
  /^(?:extension\/)?manifest\.json$/i,
  /^src\/(index|main|app)\.[^/]+$/i,
  /^(index|main|app)\.[^/]+$/i,
  /^(?:src\/|app\/|extension\/)?(?:[^/]+\/)*(background|content|server|cli)\.(js|jsx|ts|tsx|mjs|cjs|py|go|rs)$/i,
  /^cmd\/[^/]+\/main\.go$/i,
  /^src\/lib\.rs$/i
];

async function githubFetch(path, options = {}) {
  const response = await fetch(`${GITHUB_API}${path}`, {
    ...options,
    headers: {
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      ...options.headers
    }
  });

  if (!response.ok) {
    const error = new Error(`GitHub request failed (${response.status})`);
    error.status = response.status;
    throw error;
  }

  return response;
}

async function readJson(path) {
  return (await githubFetch(path)).json();
}

async function readText(path, accept) {
  return (await githubFetch(path, { headers: { Accept: accept } })).text();
}

function chooseImportantFiles(tree) {
  const blobs = tree
    .filter((entry) => entry.type === "blob" && entry.size <= 120000)
    .map((entry) => entry.path);
  const selected = [];

  for (const pattern of IMPORTANT_FILES) {
    const match = blobs.find((path) => pattern.test(path) && !selected.includes(path));
    if (match) selected.push(match);
    if (selected.length >= MAX_SOURCE_FILES) break;
  }

  return selected;
}

function formatTree(tree) {
  return tree
    .filter((entry) => entry.type === "tree" || entry.type === "blob")
    .slice(0, MAX_TREE_ENTRIES)
    .map((entry) => `${entry.type === "tree" ? "D" : "F"} ${entry.path}`)
    .join("\n");
}

async function fetchSourceFile(owner, repo, path) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  const text = await readText(
    `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/contents/${encodedPath}`,
    "application/vnd.github.raw+json"
  );
  return text.slice(0, MAX_SOURCE_CHARS);
}

async function collectRepository(owner, repo) {
  const basePath = `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}`;
  const metadata = await readJson(basePath);
  const branch = metadata.default_branch;

  const [languagesResult, readmeResult, treeResult] = await Promise.allSettled([
    readJson(`${basePath}/languages`),
    readText(`${basePath}/readme`, "application/vnd.github.raw+json"),
    readJson(`${basePath}/git/trees/${encodeURIComponent(branch)}?recursive=1`)
  ]);

  const languages = languagesResult.status === "fulfilled" ? languagesResult.value : {};
  const readme = readmeResult.status === "fulfilled" ? readmeResult.value.slice(0, MAX_README_CHARS) : "";
  const tree = treeResult.status === "fulfilled" && Array.isArray(treeResult.value.tree)
    ? treeResult.value.tree
    : [];
  const importantPaths = chooseImportantFiles(tree);
  const sourceResults = await Promise.allSettled(
    importantPaths.map((path) => fetchSourceFile(owner, repo, path))
  );

  let usedSourceChars = 0;
  const sourceFiles = [];
  sourceResults.forEach((result, index) => {
    if (result.status !== "fulfilled" || usedSourceChars >= MAX_TOTAL_SOURCE_CHARS) return;
    const remaining = MAX_TOTAL_SOURCE_CHARS - usedSourceChars;
    const content = result.value.slice(0, remaining);
    usedSourceChars += content.length;
    sourceFiles.push({ path: importantPaths[index], content });
  });

  return {
    repository: {
      owner,
      name: metadata.name,
      fullName: metadata.full_name,
      description: metadata.description || "",
      url: metadata.html_url,
      homepage: metadata.homepage || "",
      defaultBranch: branch,
      stars: metadata.stargazers_count,
      forks: metadata.forks_count,
      license: metadata.license?.spdx_id || "Unknown",
      topics: metadata.topics || [],
      archived: metadata.archived,
      updatedAt: metadata.updated_at
    },
    languages,
    readme,
    tree: formatTree(tree),
    treeTruncated: Boolean(treeResult.status === "fulfilled" && treeResult.value.truncated),
    sourceFiles
  };
}

function parseSkillMarkdown(path, content) {
  const titleMatch = content.match(/^#\s+(.+)$/m);
  const nameMatch = content.match(/^name:\s*["']?(.+?)["']?\s*$/m);
  const descriptionMatch = content.match(/^description:\s*["']?(.+?)["']?\s*$/m);
  const firstParagraph = content
    .replace(/^---[\s\S]*?---/, "")
    .split(/\n\s*\n/)
    .map((part) => part.replace(/[#>*`-]/g, "").replace(/\s+/g, " ").trim())
    .find(Boolean);

  return {
    path,
    id: path.replace(/^skills\//, "").replace(/\/SKILL\.md$/i, ""),
    name: (nameMatch?.[1] || titleMatch?.[1] || path.split("/").at(-2) || path).trim().slice(0, 120),
    description: (descriptionMatch?.[1] || firstParagraph || "").trim().slice(0, 500),
    excerpt: content.replace(/\s+/g, " ").trim().slice(0, MAX_SKILL_CONTENT_CHARS)
  };
}

async function collectHumanSkillCatalog(options = {}) {
  const cached = await chrome.storage.local.get(SKILL_CATALOG_CACHE_KEY);
  const cachedCatalog = cached[SKILL_CATALOG_CACHE_KEY];
  if (
    !options.force &&
    cachedCatalog?.updatedAt &&
    Date.now() - cachedCatalog.updatedAt < SKILL_CATALOG_CACHE_TTL &&
    Array.isArray(cachedCatalog.skills)
  ) {
    return { ...cachedCatalog, cacheHit: true };
  }

  const owner = SKILL_CATALOG_REPO.owner;
  const repo = SKILL_CATALOG_REPO.repo;
  const basePath = `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}`;
  const metadata = await readJson(basePath);
  const branch = metadata.default_branch;
  const treeResult = await readJson(`${basePath}/git/trees/${encodeURIComponent(branch)}?recursive=1`);
  const skillPaths = (treeResult.tree || [])
    .filter((entry) => entry.type === "blob" && /^skills\/[^/]+\/SKILL\.md$/i.test(entry.path))
    .map((entry) => entry.path)
    .slice(0, MAX_SKILL_FILES);

  const skillResults = await Promise.allSettled(
    skillPaths.map((path) => fetchSourceFile(owner, repo, path))
  );
  const skills = skillResults
    .map((result, index) => result.status === "fulfilled"
      ? parseSkillMarkdown(skillPaths[index], result.value)
      : null)
    .filter(Boolean);
  const catalog = {
    source: `https://github.com/${owner}/${repo}`,
    defaultBranch: branch,
    skills,
    totalSkills: skills.length,
    truncated: skillPaths.length >= MAX_SKILL_FILES,
    updatedAt: Date.now(),
    cacheHit: false
  };

  await chrome.storage.local.set({ [SKILL_CATALOG_CACHE_KEY]: catalog });
  return catalog;
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "NARZISS_FETCH_SKILL_CATALOG") {
    collectHumanSkillCatalog({ force: message.force === true })
      .then((data) => sendResponse({ ok: true, data }))
      .catch((error) => {
        sendResponse({
          ok: false,
          error: error.status === 403
            ? "GitHub API rate limit reached. Try again later."
            : error.message
        });
      });

    return true;
  }

  if (message?.type !== "NARZISS_FETCH_GITHUB_REPO") return false;

  collectRepository(message.owner, message.repo)
    .then((data) => sendResponse({ ok: true, data }))
    .catch((error) => {
      sendResponse({
        ok: false,
        error: error.status === 404
          ? "Repository not found or is not public."
          : error.status === 403
            ? "GitHub API rate limit reached. Try again later."
            : error.message
      });
    });

  return true;
});
