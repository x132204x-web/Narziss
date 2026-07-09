# Limitations

Narziss is intentionally simple.

## Not system-level control

The extension modifies the message sent through the webpage. It does not set a real system prompt, does not control the model runtime, and does not retry failed responses.

## Visible prompt masking

Narziss sends a wrapped prompt to the active AI chat page, then masks the visible user bubble back to the user's original message when the page renders it. This keeps the interface clean, but the AI service still receives the wrapped prompt because webpage extensions cannot set hidden system messages in third-party chat products.

## Model-assisted learning state

Narziss asks the model to infer the topic, knowledge map, learner depth, and mastery. The extension stores the returned state marker locally for each chat URL, but it does not run a separate classifier. Model estimates can still be imperfect.

## Hidden state marker

The extension inspects model replies only for a compact Narziss state marker, stores valid markers, and removes them from the page. If a model omits or corrupts the marker, Narziss keeps the previous state and the conversation remains usable.

## Public GitHub data

Project explanations use GitHub's unauthenticated public API and do not support private repositories. GitHub may rate-limit repeated analysis. Large READMEs, trees, and source files are deliberately truncated to keep prompts bounded, so the explanation may not cover every subsystem.

## Website compatibility

AI chat websites can change their page structure. If their input boxes, send buttons, or message bubbles change, Narziss may need selector updates.

The current-tab injection mode works best on chat pages that use standard textareas, text inputs, contenteditable editors, or role-based textbox elements. Some heavily customized editors may still need site-specific support.
