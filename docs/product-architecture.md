# Narziss Product Architecture

Narziss is a personal growth navigation system layered on top of AI chat products.

It is not just an AI tutor. Its job is to help a learner answer three recurring questions:

- What should I learn next?
- Do I really understand this skill?
- How does this learning connect to my long-term goal?

## Reference Positioning

Human Skill Tree is useful as a reference because it treats learning as a structured skill system rather than a loose chat. Narziss should borrow that spirit, but adapt it to a browser extension and long-term personal growth memory.

The key distinction:

- Human Skill Tree: a broad collection of reusable learning skills and curricula.
- Narziss: a personal growth layer that reads the user's goal, memory, progress, weak spots, and current AI chat context to recommend the next learning action.

## Product Pillars

### 1. Skill Tree

Narziss needs domain skill trees, starting with narrow high-value trees instead of trying to cover everything.

The first built-in tree should be `AI Product Manager`:

```text
AI Product Manager
├── AI Foundations
│   ├── Python
│   ├── Machine Learning
│   ├── Neural Networks
│   ├── LLM
│   ├── RAG
│   └── Agent
├── Product Capability
│   ├── User Research
│   ├── Product Design
│   └── Data Analysis
└── Engineering Capability
    ├── API
    ├── Database
    └── Deployment
```

Each node should have:

- `id`
- `name`
- `description`
- `prerequisites`
- `importance`
- `recommendedOrder`
- `recommendedResources`
- `assessmentRubric`
- `reviewSchedule`

### 2. Personal Growth Memory

Narziss should not store raw chat logs as its primary memory. It should store learning state:

- user interests
- career goal
- learning history
- mastered skills
- weak skills
- common mistakes
- learning preferences
- review schedule

Example:

```json
{
  "profile": {
    "background": "GIS",
    "careerGoal": "AI Product Manager",
    "learningPreference": "concise definition, then question"
  },
  "skills": {
    "llm": {
      "conceptualUnderstanding": 70,
      "applicationAbility": 50,
      "explanationAbility": 65,
      "projectAbility": 40,
      "mastery": 56
    },
    "agent": {
      "mastery": 50
    },
    "database": {
      "mastery": 30,
      "weaknesses": ["schema design", "query planning"]
    }
  }
}
```

### 3. Learning Recommendation

When the user says "I don't know what to learn", Narziss should not ask a broad question first. It should recommend from:

- career goal
- skill tree gaps
- current mastery
- learning history
- active projects
- recent industry relevance

Recommendation shape:

```text
Based on your goal of becoming an AI Product Manager, your product thinking is stronger than your engineering foundation.

Next skill: RAG architecture.

Why:
1. It connects directly to AI product design.
2. It is a foundation for Agent systems.
3. It turns LLM knowledge into buildable product architecture.

First checkpoint: can you explain why RAG needs retrieval before generation?
```

### 4. Scientific Learning Loop

Each learning node runs through a short loop:

```text
Recommend node
↓
Active recall check
↓
Micro-teach only the missing part
↓
Feynman explanation test
↓
Application or transfer test
↓
Mastery update
↓
Spaced review scheduling
↓
Next node recommendation
```

The tutor must not stretch a node indefinitely. Once mastery is high enough, it should offer the next useful node.

### 5. Mastery Model

"Learned" is not binary. Narziss should score each skill across four dimensions:

- conceptual understanding
- application ability
- explanation ability
- project ability

Node mastery should be a weighted score, not a simple self-report.

Example:

```json
{
  "skillId": "transformer",
  "conceptualUnderstanding": 80,
  "applicationAbility": 50,
  "explanationAbility": 70,
  "projectAbility": 40,
  "mastery": 60
}
```

### 6. Growth System

The user should see growth, not just receive chat replies.

The extension popup should eventually become a compact dashboard:

```text
AI Product Manager Lv.8

AI Foundations      60%
Product Capability  80%
Engineering         30%

Current task:
RAG architecture

Next recommendation:
Database basics for retrieval systems
```

## Product Flow

```text
User goal
↓
Generate or select personal Skill Tree
↓
Analyze growth memory
↓
Recommend next learning node
↓
Teach with active recall and Socratic prompts
↓
Run Feynman and transfer checks
↓
Update mastery
↓
Schedule review
↓
Recommend next node
```

## Version Roadmap

### v0.8.0: Growth Navigator Foundation

- Add a built-in `AI Product Manager` skill tree.
- Add local growth profile storage.
- Add "I don't know what to learn" recommendation mode.
- Keep all data local in browser storage.
- Update prompt to include career goal, current tree, and weak nodes.

### v0.9.0: Mastery Rubric

- Track conceptual, application, explanation, and project ability separately.
- Add Feynman and transfer-test prompt modes.
- Add review scheduling metadata.

### v1.0.0: Growth Dashboard

- Replace the simple popup with a compact skill tree dashboard.
- Show progress bars, current task, next recommendation, and review queue.
- Keep the chat injection clean and lightweight.

### Later

- Optional cloud sync.
- Import/export memory.
- Community skill tree packs.
- More built-in trees, such as `AI Engineer`, `GIS + AI`, `Founder`, and `Data Analyst`.

## Product Principle

Narziss should feel less like a teacher answering questions and more like a quiet career navigator that remembers where the learner is, knows the map, and always points to the next useful step.
