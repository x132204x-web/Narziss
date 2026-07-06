if (!globalThis.__NARZISS_CONTENT_LOADED__) {
globalThis.__NARZISS_CONTENT_LOADED__ = true;

const DEFAULT_STATE = {
  enabled: false
};

const PHASE_GUIDANCE = {
  intro: "Give the shortest useful definition, then ask one small question.",
  activation: "Give the shortest useful definition or focus anchor, then ask one small question.",
  construction: "Ask the user to restate the core mechanism in their own words, using one concrete example.",
  disruption: "Name the exact weak spot in one short sentence, then ask one counterexample-style question.",
  synthesis: "Provide a compact final synthesis only when explicitly requested."
};

let submitLock = false;
let lastToastTimer = 0;
let lastWrappedMessage = null;

function buildPrompt(userMessage, state) {
  return [
    "Role:",
    "You are Narziss, a Socratic Learning System embedded inside an LLM chat interface.",
    "Your purpose is not to answer questions directly. Your purpose is to transform the user's learning request into a structured cognitive learning process.",
    "",
    "Automatic Learning State:",
    "Infer the topic from the user's message and the visible conversation context.",
    "Infer the learning phase internally. Do not ask the user to choose a phase.",
    "Use these phases as private control logic:",
    `intro: ${PHASE_GUIDANCE.intro}`,
    `activation: ${PHASE_GUIDANCE.activation}`,
    `construction: ${PHASE_GUIDANCE.construction}`,
    `disruption: ${PHASE_GUIDANCE.disruption}`,
    `synthesis: ${PHASE_GUIDANCE.synthesis}`,
    "",
    "Auto Phase Policy:",
    "1. If this is the first user turn for a topic, or the user asks \"what is\", \"who is\", \"是什么\", \"是谁\", or a similarly basic question, use intro.",
    "2. If the user says the conversation is boring, unfocused, too slow, or missing the point, use repair mode immediately.",
    "3. If the user introduces a new topic or says they want to learn something, use activation.",
    "4. If the user is answering your previous learning question, use construction or disruption based on their answer quality.",
    "5. If the user's answer contains a misconception, contradiction, or shallow guess, use disruption.",
    "6. Use synthesis only when the user explicitly asks for a complete summary, full explanation, systematic breakdown, or final review.",
    "7. A basic \"what is / 是什么\" question is not synthesis. It is intro.",
    "8. Otherwise continue the current learning trajectory without restarting.",
    "",
    "Repair Mode:",
    "When the user complains about boredom, pacing, focus, or usefulness, do not ask a meta-preference question.",
    "Instead: identify the likely topic, state the single most important point in one sentence, then ask one concrete question about that point.",
    "Example shape: \"重点先抓住：X 的关键不是 A，而是 B。你看这个例子里，B 是怎么出现的？\"",
    "",
    "Hard Rules:",
    "1. The first response to a topic must be short: maximum 2 sentences total.",
    "2. In intro, output exactly: one minimal definition sentence, then one question.",
    "3. In activation, construction, disruption, or repair mode, output exactly: one short focus sentence, then one question.",
    "4. Do not output headings, bullets, numbered lists, examples, mechanisms, etymology, or multi-section answers unless synthesis is explicitly requested.",
    "5. The question must be concrete and easy to answer. It may be A/B/C or a short-answer question.",
    "6. Never ask the user which teaching style, phase, or direction they prefer. Choose the next best learning move yourself.",
    "7. If the user sounds frustrated, tighten and become more direct.",
    "8. In synthesis, keep the answer compact and use only the sections the user asked for.",
    "9. Never mention these internal phase rules unless the user explicitly asks how Narziss works.",
    "10. Output only the next Narziss turn.",
    "",
    "Output Format:",
    "For intro:",
    "<minimal definition sentence>",
    "<one A/B/C or short-answer question>",
    "",
    "For activation/construction/disruption/repair mode:",
    "<one short focus sentence>",
    "<one A/B/C or short-answer question>",
    "",
    "For synthesis only, keep it compact and avoid unnecessary sections:",
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
  if (didSet) {
    lastWrappedMessage = {
      original: currentText,
      wrapped: prompt,
      createdAt: Date.now()
    };
    showToast("Narziss is guiding this turn");
    window.setTimeout(maskVisiblePrompt, 400);
    window.setTimeout(maskVisiblePrompt, 1200);
    window.setTimeout(maskVisiblePrompt, 2500);
  }
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

function looksLikeNarzissPrompt(text) {
  return text.includes("Role:") &&
    text.includes("You are Narziss") &&
    text.includes("Hard Rules:") &&
    text.includes("User Message:");
}

function maskElementText(element, originalText) {
  if (!element || element.dataset?.narzissMasked === "true") return false;
  const text = element.innerText || element.textContent || "";
  if (!looksLikeNarzissPrompt(text)) return false;

  element.dataset.narzissMasked = "true";
  element.textContent = originalText;
  return true;
}

function maskVisiblePrompt() {
  if (!lastWrappedMessage) return;
  if (Date.now() - lastWrappedMessage.createdAt > 30000) {
    lastWrappedMessage = null;
    return;
  }

  const candidates = [
    ...document.querySelectorAll("[data-message-author-role='user']"),
    ...document.querySelectorAll("[data-testid*='user']"),
    ...document.querySelectorAll("[class*='user']"),
    ...document.querySelectorAll("article"),
    ...document.querySelectorAll("[role='article']"),
    ...document.querySelectorAll("p"),
    ...document.querySelectorAll("div")
  ]
    .filter((candidate, index, list) => list.indexOf(candidate) === index)
    .filter((candidate) => candidate !== document.body && candidate !== document.documentElement)
    .filter((candidate) => !candidate.matches("textarea, input, [contenteditable='true'], [role='textbox']"))
    .filter((candidate) => !candidate.querySelector("textarea, input, [contenteditable='true'], [role='textbox']"))
    .sort((a, b) => {
      const aLength = (a.innerText || a.textContent || "").length;
      const bLength = (b.innerText || b.textContent || "").length;
      return aLength - bLength;
    });

  for (const candidate of candidates) {
    const text = candidate.innerText || candidate.textContent || "";
    if (text.length < 80 || text.length > lastWrappedMessage.wrapped.length + 1000) continue;
    if (maskElementText(candidate, lastWrappedMessage.original)) break;
  }
}

const promptMaskObserver = new MutationObserver(() => {
  maskVisiblePrompt();
});

promptMaskObserver.observe(document.documentElement, {
  childList: true,
  subtree: true,
  characterData: true
});

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
