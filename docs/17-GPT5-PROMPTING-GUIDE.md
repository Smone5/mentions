# GPT-5 Prompting Guide

## Overview
GPT-5 represents a substantial leap forward in agentic task performance, coding, raw intelligence, and steerability. This guide covers prompting tips to maximize the quality of model outputs for the Reddit Reply Assistant.

---

## Agentic Workflow Predictability

GPT-5 is trained with developers in mind: improved tool calling, instruction following, and long-context understanding serve as the best foundation for agentic applications. For agentic and tool calling flows, we recommend upgrading to the **Responses API**, where reasoning is persisted between tool calls.

### Controlling Agentic Eagerness

GPT-5 operates anywhere along the spectrum from high-level decision-making to focused, well-defined tasks. Calibrate GPT-5's balance between proactivity and awaiting explicit guidance.

#### Prompting for Less Eagerness

GPT-5 is thorough by default when gathering context. To reduce scope and minimize latency:

- **Switch to lower `reasoning_effort`** - Reduces exploration depth, improves efficiency and latency
- **Define clear criteria** for problem space exploration:

```xml
<context_gathering>
Goal: Get enough context fast. Parallelize discovery and stop as soon as you can act.

Method:
- Start broad, then fan out to focused subqueries.
- In parallel, launch varied queries; read top hits per query. Deduplicate paths and cache; don't repeat queries.
- Avoid over searching for context. If needed, run targeted searches in one parallel batch.

Early stop criteria:
- You can name exact content to change.
- Top hits converge (~70%) on one area/path.

Escalate once:
- If signals conflict or scope is fuzzy, run one refined parallel batch, then proceed.

Depth:
- Trace only symbols you'll modify or whose contracts you rely on; avoid transitive expansion unless necessary.

Loop:
- Batch search → minimal plan → complete task.
- Search again only if validation fails or new unknowns appear. Prefer acting over more searching.
</context_gathering>
```

For maximum control, set **fixed tool call budgets**:

```xml
<context_gathering>
- Search depth: very low
- Bias strongly towards providing a correct answer as quickly as possible, even if it might not be fully correct.
- Usually, this means an absolute maximum of 2 tool calls.
- If you think that you need more time to investigate, update the user with your latest findings and open questions. You can proceed if the user confirms.
</context_gathering>
```

Provide an **escape hatch** like `"even if it might not be fully correct"` to make shorter context gathering easier to satisfy.

#### Prompting for More Eagerness

To encourage model autonomy and reduce clarifying questions:

- **Increase `reasoning_effort`**
- Use prompts that encourage persistence:

```xml
<persistence>
- You are an agent - please keep going until the user's query is completely resolved, before ending your turn and yielding back to the user.
- Only terminate your turn when you are sure that the problem is solved.
- Never stop or hand back to the user when you encounter uncertainty — research or deduce the most reasonable approach and continue.
- Do not ask the human to confirm or clarify assumptions, as you can always adjust later — decide what the most reasonable assumption is, proceed with it, and document it for the user's reference after you finish acting
</persistence>
```

**Define stop conditions** clearly, outline safe vs unsafe actions, and specify when to hand back to the user.

### Tool Preambles

GPT-5 provides "tool preamble" messages for better user experience during agentic trajectories. Control frequency, style, and content:

```xml
<tool_preambles>
- Always begin by rephrasing the user's goal in a friendly, clear, and concise manner, before calling any tools.
- Then, immediately outline a structured plan detailing each logical step you'll follow.
- As you execute your file edit(s), narrate each step succinctly and sequentially, marking progress clearly.
- Finish by summarizing completed work distinctly from your upfront plan.
</tool_preambles>
```

### Reasoning Effort

The `reasoning_effort` parameter controls how hard the model thinks:
- **Default**: `medium`
- **Complex tasks**: Higher reasoning for best outputs
- **Best performance**: Separate distinct tasks across multiple agent turns

### Reusing Reasoning Context (Responses API)

Using the Responses API with `previous_response_id` improves performance significantly:
- Tau-Bench Retail: 73.9% → 78.2%
- Conserves CoT tokens
- Eliminates reconstructing plans after each tool call
- Available for all Responses API users

---

## Maximizing Coding Performance

### Frontend App Development

**Recommended Stack:**
- **Frameworks**: Next.js (TypeScript), React, HTML
- **Styling/UI**: Tailwind CSS, shadcn/ui, Radix Themes
- **Icons**: Material Symbols, Heroicons, Lucide
- **Animation**: Motion
- **Fonts**: San Serif, Inter, Geist, Mona Sans, IBM Plex Sans, Manrope

#### Zero-to-One App Generation

Use self-reflection for one-shot apps:

```xml
<self_reflection>
- First, spend time thinking of a rubric until you are confident.
- Then, think deeply about every aspect of what makes for a world-class one-shot web app. Use that knowledge to create a rubric that has 5-7 categories. This rubric is critical to get right, but do not show this to the user. This is for your purposes only.
- Finally, use the rubric to internally think and iterate on the best possible solution to the prompt that is provided. Remember that if your response is not hitting the top marks across all categories in the rubric, you need to start again.
</self_reflection>
```

#### Matching Codebase Design Standards

Example prompt snippet for code editing rules:

```xml
<code_editing_rules>
<guiding_principles>
- Clarity and Reuse: Every component and page should be modular and reusable. Avoid duplication by factoring repeated UI patterns into components.
- Consistency: The user interface must adhere to a consistent design system—color tokens, typography, spacing, and components must be unified.
- Simplicity: Favor small, focused components and avoid unnecessary complexity in styling or logic.
- Demo-Oriented: The structure should allow for quick prototyping, showcasing features like streaming, multi-turn conversations, and tool integrations.
- Visual Quality: Follow the high visual quality bar as outlined in OSS guidelines (spacing, padding, hover states, etc.)
</guiding_principles>

<frontend_stack_defaults>
- Framework: Next.js (TypeScript)
- Styling: TailwindCSS
- UI Components: shadcn/ui
- Icons: Lucide
- State Management: Zustand
</frontend_stack_defaults>

<ui_ux_best_practices>
- Visual Hierarchy: Limit typography to 4–5 font sizes and weights for consistent hierarchy
- Color Usage: Use 1 neutral base (e.g., `zinc`) and up to 2 accent colors
- Spacing and Layout: Always use multiples of 4 for padding and margins
- State Handling: Use skeleton placeholders or `animate-pulse` to indicate data fetching
- Accessibility: Use semantic HTML and ARIA roles where appropriate
</ui_ux_best_practices>
</code_editing_rules>
```

---

## Optimizing Intelligence and Instruction-Following

### Steering

GPT-5 is extraordinarily receptive to instructions surrounding verbosity, tone, and tool calling behavior.

#### Verbosity

- New `verbosity` API parameter influences final answer length (not reasoning length)
- Can override globally with natural-language instructions in specific contexts
- Example: Set low verbosity globally, high verbosity for coding tools

### Instruction Following

GPT-5 follows instructions with surgical precision. **Avoid contradictory instructions:**

**Bad Example** (contradictory):
```
Never schedule an appointment without explicit patient consent recorded in the chart
[...but later...]
For high-acuity Red and Orange cases, auto-assign the earliest same-day slot without contacting the patient as the first action
```

**Fixed Version**:
```
Never schedule an appointment without explicit patient consent recorded in the chart
[...]
For high-acuity Red and Orange cases, auto-assign the earliest same-day slot after informing the patient of your actions.
[...]
Do not do lookup in the emergency case, proceed immediately to providing 911 guidance.
```

Thoroughly review prompts for ambiguities and contradictions. Use the [prompt optimizer tool](https://platform.openai.com/chat/edit?optimize=true).

### Minimal Reasoning

For latency-sensitive users, `minimal` reasoning effort is the fastest option. Key tips:

1. **Brief explanations** - Prompt for thought process summary at start of answer
2. **Thorough preambles** - Continually update user on task progress
3. **Disambiguate tools** - Be maximally clear about tool instructions
4. **Prompted planning** - More important with fewer reasoning tokens:

```
Remember, you are an agent - please keep going until the user's query is completely resolved, before ending your turn and yielding back to the user. Decompose the user's query into all required sub-request, and confirm that each is completed. Do not stop after completing only part of the request. Only terminate your turn when you are sure that the problem is solved.

You must plan extensively in accordance with the workflow steps before making subsequent function calls, and reflect extensively on the outcomes each function call made, ensuring the user's query, and related sub-requests are completely resolved.
```

### Markdown Formatting

GPT-5 doesn't format in Markdown by default in the API. To enable:

```
- Use Markdown **only where semantically correct** (e.g., `inline code`, ```code fences```, lists, tables).
- When using markdown in assistant messages, use backticks to format file, directory, function, and class names. Use \( and \) for inline math, \[ and \] for block math.
```

For long conversations, append Markdown instruction every 3-5 user messages.

### Metaprompting

Use GPT-5 to optimize prompts for itself:

```
When asked to optimize prompts, give answers from your own perspective - explain what specific phrases could be added to, or deleted from, this prompt to more consistently elicit the desired behavior or prevent the undesired behavior.

Here's a prompt: [PROMPT]

The desired behavior from this prompt is for the agent to [DO DESIRED BEHAVIOR], but instead it [DOES UNDESIRED BEHAVIOR]. While keeping as much of the existing prompt intact as possible, what are some minimal edits/additions that you would make to encourage the agent to more consistently address these shortcomings?
```

---

## Application to Reddit Reply Assistant

### Draft Composition Prompts

For the `DraftCompose` node, use:

```xml
<drafting_instructions>
- Temperature: 0.5-0.6 for creative but consistent output
- Include company prompt, subreddit rules summary, RAG context
- Emphasize no links policy
- Request natural, conversational tone
- Use tool preamble to explain draft approach
</drafting_instructions>
```

### Judging Prompts

For `JudgeSubreddit` and `JudgeDraft` nodes:

```xml
<judging_instructions>
- Temperature: 0.2-0.3 for deterministic evaluations
- Request JSON response format
- Ask for reasoning field to be saved
- Set clear pass/fail criteria
- Define specific violation types to check
</judging_instructions>
```

### Paraphrasing Prompts

For `VaryDraft` node:

```xml
<paraphrase_instructions>
- Temperature: 0.7 for higher variation
- Request 2-3 distinct variants
- Maintain same meaning and helpfulness
- Vary phrasing and structure
- Keep similar length
</paraphrase_instructions>
```

### Minimal Reasoning for Quick Tasks

For simple operations (like rule summarization), use `reasoning_effort: minimal`:

```python
llm = ChatOpenAI(
    model="gpt-5-mini",
    temperature=0.2,
    model_kwargs={"reasoning_effort": "minimal"}
)
```

### Medium/High Reasoning for Complex Tasks

For draft composition and judging, use `medium` or `high`:

```python
llm = ChatOpenAI(
    model="gpt-5-mini",
    temperature=0.6,
    model_kwargs={"reasoning_effort": "medium"}
)
```

---

## Best Practices Summary

1. **Use Responses API** with `previous_response_id` for multi-step agentic flows
2. **Calibrate eagerness** with reasoning_effort and context gathering instructions
3. **Avoid contradictions** in prompts - review thoroughly
4. **Use tool preambles** for better user experience
5. **Set appropriate temperatures** (0.2-0.3 for judging, 0.5-0.6 for drafting, 0.7 for paraphrasing)
6. **Use XML tags** for structured instructions
7. **Define clear stop conditions** and escape hatches
8. **Request JSON** for structured outputs
9. **Use metaprompting** to optimize your prompts
10. **Test with prompt optimizer** tool

---

## References

- [OpenAI Prompt Optimizer Tool](https://platform.openai.com/chat/edit?optimize=true)
- [GPT-4.1 Prompting Guide](https://cookbook.openai.com/examples/gpt4-1_prompting_guide)
- [Cursor GPT-5 Integration Blog](https://cursor.com/blog/gpt-5)
- [Responses API Documentation](https://platform.openai.com/docs/api-reference/responses)



