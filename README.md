# Agent Babies

**They're little, but they're learning.**

Local AI agents that run on your Mac. Zero cloud costs. Full privacy. Your conversations never leave your machine.

<!-- TODO: Hero image — Muppet Babies-inspired title card (nano-banana) -->

## Why

Some things shouldn't leave the house. Health questions, personal notes, family conversations, financial planning — you want an AI assistant for these, but you don't want them on someone else's server.

Agent Babies gives you a local AI agent that runs entirely on your Mac using open-source models. It won't be as smart as Claude or GPT — but for everyday tasks, it's surprisingly capable. And it's yours.

## What you get

- **A local AI agent** that runs in your terminal, with tools to read, write, and edit files
- **Voice conversations** via [VoiceMode](https://github.com/mbailey/voicemode) — talk to your agent like a person
- **Auto-tuned for your Mac** — picks the best model for your hardware (8GB to 128GB+)
- **Privacy by default** — nothing leaves your machine. No API keys. No cloud. No telemetry
- **Built on open-source** — [Pi coding agent](https://github.com/mariozechner/pi-coding-agent) + [MLX](https://github.com/ml-explore/mlx) + open-weight models

## Requirements

- **Mac with Apple Silicon** (M1, M2, M3, M4 — any variant)
- **macOS 14+** (Sonoma or later)
- **Python 3.10+** and **Node.js 18+**

### Model selection by RAM

Agent Babies automatically picks the best model for your Mac:

| Your Mac | Model | Active Params | Speed | Quality |
|----------|-------|--------------|-------|---------|
| 8 GB | Gemma 4 E2B | 2B | ~155 tok/s | Good for simple tasks |
| 16 GB | Gemma 4 E4B | 4B | ~92 tok/s | Good all-rounder |
| 32 GB | Qwen 3.5 35B MoE | 3B (of 35B) | ~110 tok/s | Surprisingly capable |
| 64 GB+ | Gemma 4 31B | 31B dense | ~23 tok/s | Strongest local model |

*Speeds measured on Mac Studio M4 Max. Your speeds will vary — M1 will be roughly half.*

## Quick start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/mbailey/agent-babies/master/install.sh | bash

# Spawn your first baby
agent-baby spawn

# Talk to it
agent-baby chat
```

That's it. The installer handles Python, Node, MLX, model download, and Pi setup.

### With voice (optional)

```bash
# Install VoiceMode for local speech-to-text and text-to-speech
agent-baby install-voice

# Start a voice conversation
agent-baby talk
```

## How it works

```
┌──────────────────────────────────────────────────┐
│              Your Mac                             │
│                                                   │
│  ┌──────────┐    ┌──────────┐    ┌─────────────┐ │
│  │ agent-   │───>│ Pi agent │───>│ MLX server  │ │
│  │ baby CLI │    │ (tools)  │    │ (open model)│ │
│  └──────────┘    └────┬─────┘    └─────────────┘ │
│                       │ MCP bridge                │
│                  ┌────┴─────┐                     │
│                  │VoiceMode │                     │
│                  │ Whisper  │ (speech-to-text)    │
│                  │ Kokoro   │ (text-to-speech)    │
│                  └──────────┘                     │
│                                                   │
│  Everything runs here. Nothing leaves.            │
└──────────────────────────────────────────────────┘
```

**Stack:**
- **[MLX](https://github.com/ml-explore/mlx)** — Apple's native ML framework. Runs models directly on the GPU cores in your Mac's chip. 2x faster than Ollama for the same models.
- **[Pi coding agent](https://github.com/mariozechner/pi-coding-agent)** — Lightweight agent harness with file read/write/edit tools. Gives the model hands.
- **[VoiceMode](https://github.com/mbailey/voicemode)** — Local speech-to-text (Whisper) and text-to-speech (Kokoro). Voice conversations without any cloud services.

## What can a baby do?

An agent baby is a small local model with basic tools. It's great at:

- **Summarising** — feed it a document, get a summary
- **Drafting** — write first drafts of emails, notes, plans
- **Organising** — sort files, tag content, triage inboxes
- **Answering questions** — about files on your machine
- **Simple coding** — scripts, config files, small edits
- **Voice chat** — casual conversation, thinking out loud

It's _not_ great at complex reasoning, multi-step planning, or tasks requiring deep domain expertise. That's what the big models are for. A baby knows its limits.

## Training

Agent Babies aren't just running a raw model — they come with trained skills and system prompts that make them more useful out of the box. The training lives in the [`minions`](https://github.com/ai-cora/minions) repo, where we iteratively improve prompts and measure quality.

The name comes from Muppet Babies — the 80s cartoon where baby versions of the Muppets went on adventures that were smaller-scale but still meaningful. Same energy here.

## Remote models

Got a Mac Studio with 128GB? Run the model there, chat from your laptop:

```bash
# On your Mac Studio — start the model server
agent-baby server

# On your MacBook Air — point at the Studio
export AGENT_BABIES_LLM_URL=http://mac-studio.local:8090/v1
agent-baby chat
```

Voice works too — VoiceMode runs locally on whatever machine you're chatting from, while the model runs on the remote Mac.

## FAQ

**Q: How is this different from Ollama?**
Ollama gives you a model. Agent Babies gives you an _agent_ — a model with tools, a personality, memory, and optionally a voice. It's the difference between an engine and a car.

**Q: Do I need a powerful Mac?**
Any Mac with Apple Silicon works. An M1 MacBook Air with 8GB runs the smallest model at ~155 tokens/second — that's fast enough for real conversations.

**Q: Can I use my own models?**
Yes. Any model that runs on MLX works. The auto-selection just picks sensible defaults.

**Q: Is this related to Claude/Anthropic?**
Agent Babies was created by Mike Bailey with help from Cora (his Claude-powered AI assistant). The babies themselves run open-source models — no Claude or Anthropic services are used at runtime.

## Credits

Built by [Mike Bailey](https://github.com/mbailey) and [Cora 7](https://cora7.com).

Training, skill development, and iterative improvement by Cora — she's the one teaching the babies.

## License

MIT
