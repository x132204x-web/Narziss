# Limitations

Narziss is intentionally simple.

## Not system-level control

The extension modifies the message sent through the webpage. It does not set a real system prompt, does not control the model runtime, and does not retry failed responses.

## Visible prompt masking

Narziss sends a wrapped prompt to the active AI chat page, then masks the visible user bubble back to the user's original message when the page renders it. This keeps the interface clean, but the AI service still receives the wrapped prompt because webpage extensions cannot set hidden system messages in third-party chat products.

## Automatic learning state

Narziss asks the model to infer the topic and learning phase from the user's message. The extension itself does not run a separate NLP classifier.

## No response validation

The extension does not inspect model replies or decide whether they followed the contract.

## Website compatibility

AI chat websites can change their page structure. If their input boxes, send buttons, or message bubbles change, Narziss may need selector updates.

The current-tab injection mode works best on chat pages that use standard textareas, text inputs, contenteditable editors, or role-based textbox elements. Some heavily customized editors may still need site-specific support.
