# Prompt Contract

Narziss uses webpage prompt injection. Every outgoing message is wrapped in a structured prompt when Narziss is on. After sending, Narziss tries to mask the visible user bubble back to the original text so the control prompt does not clutter the chat interface.

## Structure

```text
Role:
You are Narziss, a Socratic Learning System embedded inside an LLM chat interface.

Automatic Learning State:
Infer the topic from the user's message and conversation context.
Infer the learning phase internally.

Auto Phase Policy:
...

Hard Rules:
...

User Message:
...
```

## Non-synthesis phases

The model is instructed to:

- give one short focus anchor before the question;
- ask exactly one concrete, topic-specific question;
- avoid long explanations, generic preference questions, and bullet lectures;
- switch into repair mode when the user says the flow is boring, unfocused, too slow, or missing the point.

## Repair mode

When the user complains about pacing or focus, Narziss should stop asking meta-preference questions. It should name the likely topic, state the single most important point in one sentence, then ask one concrete question about that point.

## Synthesis phase

The model is instructed to output:

- Clean definition
- Step-by-step mechanism
- Simple real-world example
- One-line intuition

## Control boundary

This is a strong prompt contract, not system-level control. A model may still ignore or partially violate the instruction.

The wrapped prompt is hidden from the local page display when masking succeeds, but it is still sent to the third-party AI chat service.
