if (!globalThis.__NARZISS_CONTENT_LOADED__) {
globalThis.__NARZISS_CONTENT_LOADED__ = true;

const DEFAULT_STATE = {
  enabled: false,
  topic: "",
  phase: "activation",
  depthLevel: 1
};

const PHASE_GUIDANCE = {
  activation: "Ask a simple intuitive question or provide a simple A/B/C choice. The goal is to enter the topic smoothly.",
  construction: "Ask the user to explain the idea in their own words. Encourage an example. Do not correct yet.",
  disruption: "Identify one contradiction, missing assumption, or gap. Challenge it with one counterexample-style question.",
  synthesis: "Provide the final learning synthesis only now: clean definition, step-by-step mechanism, simple real-world example, and one-line intuition."
};

let submitLock = false;
let lastToastTimer = 0;

function buildPrompt(userMessage, state) {
  const topic = state.topic || "user-selected topic from the current conversation";
  const phase = state.phase || DEFAULT_STATE.phase;
  const depthLevel = Number(state.depthLevel || DEFAULT_STATE.depthLevel);
  const isSynthesis = phase === "synthesis";
  const phaseGuidance = PHASE_GUIDANCE[phase] || PHASE_GUIDANCE.activation;
  const hardRules = isSynthesis
    ? [
        "You may now synthesize the concept.",
        "Output exactly these four sections: Clean definition, Step-by-step mechanism, Simple real-world example, One-line intuition.",
        "Keep the synthesis concise and learner-friendly.",
        "Do not add unrelated study advice."
      ]
    : [
        "Do not directly explain the concept.",
        "Ask exactly ONE question.",
        "Do not provide definitions, summaries, bullet explanations, or full answers.",
        "Do not skip to synthesis.",
        "If the user asks for an explanation, transform it into a thinking question.",
        "Output only the next Narziss turn."
      ];

  return [
    "Role:",
    "You are Narziss, a Socratic Learning System embedded inside an LLM chat interface.",
    "Your purpose is not to answer questions directly. Your purpose is to transform the user's learning request into a structured cognitive learning process.",
    "",
    "Current State:",
    `topic: ${topic}`,
    `phase: ${phase}`,
    `depth_level: ${depthLevel}`,
    "",
    "Phase Task:",
    phaseGuidance,
    "",
    "Hard Rules:",
    ...hardRules.map((rule, index) => `${index + 1}. ${rule}`),
    "",
    "User Message:",
    userMessage
  ].join("\n");
}

async function readState() {
  const stored = await chrome.storage.sync.get(DEFAULT_STATE);
  return { ...DEFAULT_STATE, ...stored };
}

function isEditableElement(element) {
  if (!element) return false;
  const tagName = element.tagName?.toLowerCase();
  return tagName === "textarea" || tagName === "input" || element.isContentEditable;
}

function findEditable() {
  const active = document.activeElement;
  if (isEditableElement(active)) return active;

  const selectors = [
    "textarea",
    "input[type='text']",
    "input:not([type])",
    "div[contenteditable='true']",
    "[role='textbox'][contenteditable='true']",
    "[role='textbox']",
    "[data-testid='composer-text-input']",
    "[data-testid='chat-input']",
    "[data-testid='sendbox-textarea']",
    "[data-slate-editor='true']",
    "#prompt-textarea"
  ];

  for (const selector of selectors) {
    const candidates = [...document.querySelectorAll(selector)].filter(isVisible);
    const candidate = candidates.at(-1);
    if (candidate && isEditableElement(candidate)) return candidate;
  }

  return null;
}

function isVisible(element) {
  const rect = element.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
}

function getEditableText(element) {
  if (!element) return "";
  if ("value" in element) return element.value;
  return element.innerText || element.textContent || "";
}

function setEditableText(element, text) {
  if (!element) return false;

  element.focus();

  if ("value" in element) {
    element.value = text;
    element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
    element.dispatchEvent(new Event("change", { bubbles: true }));
    return true;
  }

  const selection = window.getSelection();
  const range = document.createRange();
  element.replaceChildren();
  element.append(document.createTextNode(text));
  range.selectNodeContents(element);
  range.collapse(false);
  selection.removeAllRanges();
  selection.addRange(range);
  element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
  return true;
}

function isSendControl(element) {
  const control = element.closest?.("button, [role='button']");
  if (!control) return false;
  const label = [
    control.getAttribute("aria-label"),
    control.getAttribute("data-testid"),
    control.getAttribute("title"),
    control.getAttribute("type"),
    control.textContent
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  return /send|submit|发送|送信|提交|arrow-up|paper-airplane/.test(label);
}

async function wrapCurrentMessage() {
  if (submitLock) return false;

  const state = await readState();
  if (!state.enabled) return false;

  const editable = findEditable();
  const currentText = getEditableText(editable).trim();
  if (!editable || !currentText || currentText.startsWith("Role:\nYou are Narziss")) return false;

  const prompt = buildPrompt(currentText, state);
  const didSet = setEditableText(editable, prompt);
  if (didSet) showToast("Narziss prompt injected");
  return didSet;
}

function showToast(message) {
  window.clearTimeout(lastToastTimer);
  document.querySelector(".narziss-toast")?.remove();

  const toast = document.createElement("div");
  toast.className = "narziss-toast";
  toast.textContent = message;
  document.documentElement.append(toast);

  lastToastTimer = window.setTimeout(() => {
    toast.remove();
  }, 1600);
}

document.addEventListener(
  "keydown",
  (event) => {
    if (submitLock) return;
    if (event.defaultPrevented || event.isComposing) return;
    if (event.key !== "Enter" || event.shiftKey || event.altKey || event.ctrlKey || event.metaKey) return;
    if (!isEditableElement(event.target)) return;

    event.preventDefault();
    event.stopPropagation();

    void wrapCurrentMessage().then(() => {
      submitLock = true;
      event.target.dispatchEvent(
        new KeyboardEvent("keydown", {
          key: "Enter",
          code: "Enter",
          bubbles: true,
          cancelable: true
        })
      );
      window.setTimeout(() => {
        submitLock = false;
      }, 200);
    });
  },
  true
);

document.addEventListener(
  "click",
  (event) => {
    if (!isSendControl(event.target)) return;

    if (submitLock) return;
    event.preventDefault();
    event.stopPropagation();

    const target = event.target.closest("button, [role='button']");
    void wrapCurrentMessage().then(() => {
      submitLock = true;
      target.click();
      window.setTimeout(() => {
        submitLock = false;
      }, 200);
    });
  },
  true
);

document.addEventListener(
  "submit",
  (event) => {
    if (submitLock) return;

    const editable = findEditable();
    if (!editable || !event.target.contains(editable)) return;

    event.preventDefault();
    event.stopPropagation();

    void wrapCurrentMessage().then(() => {
      submitLock = true;
      event.target.requestSubmit?.();
      window.setTimeout(() => {
        submitLock = false;
      }, 200);
    });
  },
  true
);
}
