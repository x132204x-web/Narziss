const DEFAULT_STATE = {
  enabled: false,
  growthProfile: {
    background: "",
    careerGoal: "AI Product Manager",
    interests: [],
    learningPreference: "concise definition, then question"
  }
};

const elements = {
  enabled: document.querySelector("#enabled"),
  background: document.querySelector("#background"),
  careerGoal: document.querySelector("#careerGoal"),
  status: document.querySelector("#status")
};

let saveTimer = 0;
let statusTimer = 0;

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
    growthProfile: {
      background: elements.background.value.trim(),
      careerGoal: elements.careerGoal.value.trim() || "AI Product Manager",
      interests: [],
      learningPreference: "concise definition, then question"
    }
  };
}

function render(state) {
  elements.enabled.checked = state.enabled;
  elements.background.value = state.growthProfile?.background || "";
  elements.careerGoal.value = state.growthProfile?.careerGoal || "AI Product Manager";
}

function setStatus(text) {
  elements.status.textContent = text;
  window.clearTimeout(statusTimer);
  statusTimer = window.setTimeout(() => {
    elements.status.textContent = "";
  }, 1200);
}

function persistFromForm() {
  void writeState(getFormState());
}

elements.enabled.addEventListener("change", () => {
  if (elements.enabled.checked) {
    void injectIntoActiveTab().catch(() => {
      setStatus("Open an AI chat tab first");
    });
  }
  persistFromForm();
});

for (const input of [elements.background, elements.careerGoal]) {
  input.addEventListener("input", () => {
    window.clearTimeout(saveTimer);
    saveTimer = window.setTimeout(persistFromForm, 350);
  });
}

void readState().then((state) => {
  render(state);
  if (state.enabled) {
    void injectIntoActiveTab().catch(() => {});
  }
});
