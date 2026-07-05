const DEFAULT_STATE = {
  enabled: false,
  topic: "",
  phase: "activation",
  depthLevel: 1
};

const elements = {
  enabled: document.querySelector("#enabled"),
  topic: document.querySelector("#topic"),
  phase: document.querySelector("#phase"),
  depthLevel: document.querySelector("#depthLevel"),
  depthOutput: document.querySelector("#depthOutput"),
  synthesis: document.querySelector("#synthesis"),
  reset: document.querySelector("#reset"),
  status: document.querySelector("#status")
};

let saveTimer = 0;

async function injectIntoActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id || !tab.url?.startsWith("http")) return;

  await chrome.scripting.insertCSS({
    target: { tabId: tab.id },
    files: ["content/content.css"]
  });
  await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    files: ["content/content.js"]
  });
}

async function readState() {
  const stored = await chrome.storage.sync.get(DEFAULT_STATE);
  return { ...DEFAULT_STATE, ...stored };
}

async function writeState(patch) {
  await chrome.storage.sync.set(patch);
  setStatus("Saved");
}

function getFormState() {
  return {
    enabled: elements.enabled.checked,
    topic: elements.topic.value.trim(),
    phase: elements.phase.value,
    depthLevel: Number(elements.depthLevel.value)
  };
}

function render(state) {
  elements.enabled.checked = state.enabled;
  elements.topic.value = state.topic;
  elements.phase.value = state.phase;
  elements.depthLevel.value = String(state.depthLevel);
  elements.depthOutput.value = String(state.depthLevel);
}

function setStatus(text) {
  elements.status.textContent = text;
  window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    elements.status.textContent = "";
  }, 1200);
}

function persistFromForm() {
  void writeState(getFormState());
}

async function resetTopic() {
  const resetState = {
    topic: "",
    phase: "activation",
    depthLevel: 1
  };
  await writeState(resetState);
  render({ ...(await readState()), ...resetState });
}

async function enterSynthesis() {
  await writeState({ phase: "synthesis" });
  elements.phase.value = "synthesis";
}

elements.enabled.addEventListener("change", () => {
  if (elements.enabled.checked) {
    void injectIntoActiveTab().catch(() => {
      setStatus("Open an AI chat tab first");
    });
  }
  persistFromForm();
});
elements.topic.addEventListener("input", persistFromForm);
elements.phase.addEventListener("change", persistFromForm);
elements.depthLevel.addEventListener("input", () => {
  elements.depthOutput.value = elements.depthLevel.value;
  persistFromForm();
});
elements.reset.addEventListener("click", () => void resetTopic());
elements.synthesis.addEventListener("click", () => void enterSynthesis());

void readState().then((state) => {
  render(state);
  if (state.enabled) {
    void injectIntoActiveTab().catch(() => {});
  }
});
