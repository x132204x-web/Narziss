# Limitations

Narziss is intentionally simple.

## Not system-level control

The extension modifies the message sent through the webpage. It does not set a real system prompt, does not control the model runtime, and does not retry failed responses.

## Visible prompt masking

Narziss sends a wrapped prompt to the active AI chat page, then masks the visible user bubble back to the user's original message when the page renders it. This keeps the interface clean, but the AI service still receives the wrapped prompt because webpage extensions cannot set hidden system messages in third-party chat products.

## Local learning state

Narziss estimates the topic, knowledge map, learner depth, and mastery locally from the user's messages. This avoids visible machine state markers in model replies, but the estimate is intentionally lightweight and can be imperfect.

## Legacy state marker cleanup

Current prompts forbid machine state markers. The extension still removes legacy Narziss markers if an old prompt or cached conversation produces one.

## Public GitHub data

Project explanations use GitHub's unauthenticated public API and do not support private repositories. GitHub may rate-limit repeated analysis. Large READMEs, trees, and source files are deliberately truncated to keep prompts bounded, so the explanation may not cover every subsystem.

## Website compatibility

AI chat websites can change their page structure. If their input boxes, send buttons, or message bubbles change, Narziss may need selector updates.

The current-tab injection mode works best on chat pages that use standard textareas, text inputs, contenteditable editors, or role-based textbox elements. Some heavily customized editors may still need site-specific support.
