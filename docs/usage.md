# Usage

Narziss is switch-based.

Open the Narziss popup on any AI chat tab and turn it on. Known supported sites load Narziss automatically; other AI chat pages can be enabled from the popup for the current tab.

## Control

- ON/OFF: enables or disables prompt injection.

## Growth navigation

When you type messages such as "我不知道学什么", "下一步该学什么", or "帮我补齐短板", Narziss uses bounded local chat memory, the Human Skill Tree reference map, the GitHub skill catalog, and the goal-specific skill tree to recommend the next learning node.

The recommendation should identify the skill, explain the gap it fills, give short reasons, and end with one active-recall checkpoint.

## Gap triangle

When Narziss is on, a small triangle appears on the chat page. Hover or click it to see the knowledge gap Narziss currently infers from the local learning state, such as `缺少：RAG Architecture: key mechanism`.

## Chat memory capture

Narziss captures a bounded slice of recent visible chat messages and stores compact learning signals locally in browser extension storage. This is used to infer repeated confusion, missing prerequisites, and the next useful learning step.

## GitHub skill catalog

Narziss fetches `skills/*/SKILL.md` from `24kchengYe/human-skill-tree` through the public GitHub API and caches a compact catalog locally for 24 hours. The catalog is used as the broad knowledge map; chat memory is used as evidence of what this learner may be missing.

## Learning flow

The user does not select phases or depth manually. Narziss privately:

1. identifies the learning goal;
2. builds a knowledge map of 3-7 small nodes;
3. chooses the next useful node;
4. teaches and checks it in short exchanges;
5. corrects misunderstandings;
6. consolidates the completed structure;
7. reinforces memory and suggests an adjacent topic.

The map and mastery score stay hidden. When a node reaches about 90% mastery, Narziss asks whether to move to the next node. It switches only after the learner agrees.

## Expected flow

1. Turn Narziss on.
2. Type what you want to learn.
3. Answer the model's question.
4. Confirm when Narziss asks to move to the next knowledge node.
5. Ask for a summary when you want to review the completed structure.

It is okay to answer "不会", "不清楚", "不知道", or "没懂". Narziss treats those as learning signals and should lower the difficulty instead of pressuring you to guess.
