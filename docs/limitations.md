# Limitations

Narziss is intentionally simple in v0.1.0.

## Not system-level control

The extension modifies the message sent through the webpage. It does not set a real system prompt, does not control the model runtime, and does not retry failed responses.

## No automatic detection

Narziss does not detect whether the user is trying to learn. The user decides when to turn it on.

## No response validation

The extension does not inspect model replies or decide whether they followed the contract.

## Website compatibility

ChatGPT and DeepSeek can change their page structure. If their input boxes or send buttons change, Narziss may need selector updates.
