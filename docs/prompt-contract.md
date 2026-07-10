# Prompt Contract

Narziss uses webpage prompt injection. Each outgoing message is wrapped with the saved learning state and an adaptive learning contract. The extension masks the wrapped user message after sending.

## Learning pipeline

The target model privately follows seven steps:

1. identify the learning intent and scope;
2. build an ordered map of 3-7 atomic knowledge nodes;
3. choose the smallest prerequisite or highest-value unfinished node;
4. teach that node with one concise anchor and one question;
5. check understanding and correct misconceptions;
6. consolidate the completed knowledge structure;
7. reinforce retrieval and suggest an adjacent learning goal.

The learner sees only the current teaching turn, not the full map or internal scores.

## Short node cycle

Mastery is estimated only for the current knowledge node:

- 0-39: simplify the anchor;
- 40-69: resolve partial understanding;
- 70-89: ask one decisive check;
- 90-100: confirm the demonstrated ability and ask whether to continue.

Narziss aims to resolve a node in 2-4 useful exchanges. It must not repeat equivalent questions or prolong a node to fill turns. At 90% or above it sets `awaitingTransition` and asks the learner before switching. A declined transition produces one targeted reinforcement question.

## Adaptive depth

The target model infers `novice`, `basic`, `intermediate`, `advanced`, or `stuck`. Difficulty ranges from recognition questions for novice or stuck learners to boundary and transfer questions for advanced learners.

Answers such as "不会", "不清楚", "不知道", "没懂", "不确定", "看不出来", "not sure", or "I don't know" trigger a micro-hint and an easier question. Empty pressure such as "为什么？", "你觉得呢？", or "再想想？" is forbidden.

## Hidden state marker

Each model response ends with one compact marker:

```text
<!--NARZISS_STATE:{"topic":"...","knowledgeMap":["..."],"completedNodes":[],"currentNode":"...","nextNode":"...","mastery":0,"learnerDepth":"novice","learningStage":"intent","awaitingTransition":false,"turnsOnNode":0}-->
```

The marker is an HTML comment, so Markdown renderers normally hide it. The content script also validates and removes either this format or legacy bracket markers from the rendered page. Invalid or missing markers are ignored and the last valid state is retained.

## Learner-facing output

Normal teaching turns contain at most two short sentences: one useful learning statement and exactly one question. Internal phases, maps, scores, and markers must not be explained or displayed. Multi-section output is reserved for an explicitly requested summary.

## Control boundary

This remains a strong prompt contract rather than system-level control. Models may ignore instructions, estimate mastery poorly, or omit the marker. Website rendering changes may also interfere with masking.
