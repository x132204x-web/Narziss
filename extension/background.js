const GITHUB_API = "https://api.github.com";
const MAX_README_CHARS = 14000;
const MAX_TREE_ENTRIES = 350;
const MAX_SOURCE_FILES = 6;
const MAX_SOURCE_CHARS = 7000;
const MAX_TOTAL_SOURCE_CHARS = 26000;

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

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
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
