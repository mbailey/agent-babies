#!/usr/bin/env bash
#
# Agent Babies installer
# https://github.com/mbailey/agent-babies
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mbailey/agent-babies/master/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/mbailey/agent-babies/master/install.sh | bash -s -- -y  # non-interactive
#
# What it does:
#   1. Checks you're on Apple Silicon
#   2. Installs prerequisites (Homebrew, uv, Node.js)
#   3. Installs Pi coding agent (via npm)
#   4. Installs MLX and downloads a model sized for your Mac
#   5. Installs VoiceMode for local voice (optional)
#   6. Creates the agent-baby CLI and default system prompt
#
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────

INTERACTIVE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes) INTERACTIVE=false; shift ;;
        *) shift ;;
    esac
done

# ─── Colors ──────────────────────────────────────────────────────────

# Respect NO_COLOR (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" BOLD="" NC=""
else
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
fi

info()   { echo -e "${BLUE}▸${NC} $*"; }
ok()     { echo -e "${GREEN}✓${NC} $*"; }
warn()   { echo -e "${YELLOW}⚠${NC} $*"; }
error()  { echo -e "${RED}✗${NC} $*" >&2; }
header() { echo -e "\n${BOLD}$*${NC}"; }
die()    { error "$1"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

tty_available() { (exec </dev/tty) 2>/dev/null; }

confirm() {
    local prompt="$1" default="${2:-y}"
    if [[ "$INTERACTIVE" != "true" ]] || ! tty_available; then
        [[ "$default" == "y" ]]
        return
    fi
    local yn
    if [[ "$default" == "y" ]]; then
        read -r -p "$prompt [Y/n] " yn </dev/tty
        [[ ! "$yn" =~ ^[Nn] ]]
    else
        read -r -p "$prompt [y/N] " yn </dev/tty
        [[ "$yn" =~ ^[Yy] ]]
    fi
}

# ─── Preflight ───────────────────────────────────────────────────────

echo ""
echo "${BOLD}Agent Babies${NC} — they're little, but they're learning."
echo ""

# macOS only
[[ "$(uname -s)" == "Darwin" ]] || die "Agent Babies requires macOS."

# Apple Silicon only
CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
[[ "$CHIP" == *"Apple"* ]] || die "Agent Babies requires Apple Silicon (M1/M2/M3/M4). Detected: $CHIP"

# RAM detection
RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
RAM_GB=$((RAM_BYTES / 1073741824))
ok "$CHIP — ${RAM_GB}GB unified memory"

# ─── Model Selection ────────────────────────────────────────────────

if   [[ $RAM_GB -ge 64 ]]; then
    MODEL="mlx-community/gemma-4-31b-it-4bit"
    MODEL_LABEL="Gemma 4 31B (dense, strongest)"
    MODEL_SIZE="~17GB"
elif [[ $RAM_GB -ge 32 ]]; then
    MODEL="mlx-community/Qwen3.5-35B-A3B-4bit"
    MODEL_LABEL="Qwen 3.5 35B MoE (best balance)"
    MODEL_SIZE="~20GB"
elif [[ $RAM_GB -ge 16 ]]; then
    MODEL="mlx-community/gemma-4-e4b-it-4bit"
    MODEL_LABEL="Gemma 4 E4B (good all-rounder)"
    MODEL_SIZE="~2.5GB"
else
    MODEL="mlx-community/gemma-4-e2b-it-4bit"
    MODEL_LABEL="Gemma 4 E2B (fast and light)"
    MODEL_SIZE="~1.5GB"
fi

info "Selected model: $MODEL_LABEL ($MODEL_SIZE)"

# ─── Directories (needed early for venv) ────────────────────────────

AGENT_BABIES_HOME="$HOME/.agent-babies"
BIN_DIR="$AGENT_BABIES_HOME/bin"
CONFIG_DIR="$AGENT_BABIES_HOME/config"
PROMPTS_DIR="$AGENT_BABIES_HOME/prompts"

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$PROMPTS_DIR"

# ─── Prerequisites ──────────────────────────────────────────────────

header "Step 1/5: Prerequisites"

# Homebrew (needed for Node.js, portaudio, ffmpeg)
if command_exists brew; then
    ok "Homebrew found"
else
    info "Homebrew is needed for system packages (Node.js, audio libraries)."
    if confirm "Install Homebrew? (may ask for password)"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
        command_exists brew || die "Homebrew installation failed"
        ok "Homebrew installed"
    else
        die "Homebrew is required. Install manually: https://brew.sh"
    fi
fi

# uv (fast Python package manager — installs without sudo)
if command_exists uv; then
    ok "uv found"
else
    info "Installing uv (fast Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    command_exists uv || die "uv installation failed"
    ok "uv installed"
fi

# Node.js (for Pi coding agent)
if command_exists node; then
    ok "Node.js $(node --version)"
else
    info "Installing Node.js via Homebrew..."
    brew install node
    ok "Node.js $(node --version)"
fi

# ─── Pi Coding Agent ────────────────────────────────────────────────

header "Step 2/5: Pi coding agent"

if command_exists pi; then
    ok "Pi already installed"
else
    info "Installing Pi coding agent..."
    npm install -g @mariozechner/pi-coding-agent
    ok "Pi installed"
fi

# ─── MLX & Model ────────────────────────────────────────────────────

header "Step 3/5: MLX + model download"

# Create a virtual environment for Agent Babies Python packages
VENV_DIR="$AGENT_BABIES_HOME/venv"
if [[ -d "$VENV_DIR" ]] && "$VENV_DIR/bin/python3" -c "import mlx_lm" 2>/dev/null; then
    ok "mlx-lm already installed"
else
    info "Setting up Python environment..."
    uv venv "$VENV_DIR" --python 3.11 2>/dev/null || uv venv "$VENV_DIR"
    info "Installing mlx-lm (this may take a minute)..."
    uv pip install --python "$VENV_DIR/bin/python3" mlx-lm
    ok "mlx-lm installed"
fi

# Use the venv python for model operations
BABY_PYTHON="$VENV_DIR/bin/python3"

# Download model
info "Downloading model: $MODEL_LABEL ($MODEL_SIZE)"
info "This may take a while on first install..."
"$BABY_PYTHON" -c "
from huggingface_hub import snapshot_download
snapshot_download('$MODEL', local_files_only=False)
" 2>/dev/null && ok "Model ready" || {
    info "Triggering model download via mlx-lm..."
    "$BABY_PYTHON" -m mlx_lm.generate --model "$MODEL" --prompt "Hello" --max-tokens 1 2>/dev/null || true
    ok "Model ready"
}

# ─── Configure ──────────────────────────────────────────────────────

header "Step 4/5: Configuration"

# Save model choice
echo "$MODEL" > "$CONFIG_DIR/model"
echo "$MODEL_LABEL" > "$CONFIG_DIR/model-label"
echo "$RAM_GB" > "$CONFIG_DIR/ram-gb"

# Configure Pi to talk to local MLX server
PI_DIR="$HOME/.pi/agent"
mkdir -p "$PI_DIR"

cat > "$PI_DIR/models.json" <<JSON
{
  "providers": {
    "local": {
      "baseUrl": "http://localhost:8090/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false,
        "maxTokensField": "max_tokens"
      },
      "models": [
        {
          "id": "$MODEL",
          "name": "$MODEL_LABEL",
          "contextWindow": 32768,
          "maxTokens": 8192
        }
      ]
    }
  }
}
JSON
ok "Pi configured for local model"

# Default system prompt
cat > "$PROMPTS_DIR/default.md" <<'PROMPT'
# Agent Baby

You are a helpful local AI assistant running on this Mac. You're small but capable.

## What you're good at

- Answering questions about files on this machine
- Summarising documents
- Drafting text (emails, notes, plans)
- Simple coding tasks (scripts, configs, small edits)
- Casual conversation and thinking out loud

## What you're not great at

- Complex multi-step reasoning (ask a bigger model)
- Tasks requiring up-to-date internet knowledge
- Very long documents (your context window is limited)

## How to behave

- Be concise and direct
- If you're unsure, say so rather than guessing
- If a task is beyond your ability, say "this might be better for a bigger model"
- Use the file tools available to you (read, write, edit, grep, find, ls)
- Never fabricate file contents — always read first

## Privacy

Everything runs locally on this Mac. No data leaves this machine.
PROMPT
ok "Default system prompt created"

# ─── CLI ─────────────────────────────────────────────────────────────

cat > "$BIN_DIR/agent-baby" <<'SCRIPT'
#!/usr/bin/env bash
#
# agent-baby — local AI agents on your Mac
#
set -euo pipefail

AGENT_BABIES_HOME="${AGENT_BABIES_HOME:-$HOME/.agent-babies}"
CONFIG_DIR="$AGENT_BABIES_HOME/config"
PROMPTS_DIR="$AGENT_BABIES_HOME/prompts"
BABY_PYTHON="$AGENT_BABIES_HOME/venv/bin/python3"
MODEL=$(cat "$CONFIG_DIR/model" 2>/dev/null || echo "mlx-community/gemma-4-e2b-it-4bit")
MLX_PORT=8090

RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m' BOLD=$'\033[1m' NC=$'\033[0m'

usage() {
    cat <<EOF
${BOLD}agent-baby${NC} — local AI agents on your Mac

Usage:
  agent-baby spawn [name]     Create a new agent baby
  agent-baby chat [name]      Chat with an agent baby
  agent-baby talk [name]      Voice chat (requires VoiceMode)
  agent-baby list             List babies
  agent-baby stop [name]      Stop an agent baby
  agent-baby server           Start the MLX model server
  agent-baby server-status    Check model server
  agent-baby install-voice    Install VoiceMode for voice chat

Examples:
  agent-baby spawn            # Create default baby
  agent-baby chat             # Chat with default baby
  agent-baby talk             # Voice chat
EOF
}

ensure_server() {
    # Check if server is already responding
    if curl -sf --max-time 2 http://localhost:$MLX_PORT/v1/models &>/dev/null; then
        echo -e "${GREEN}✓${NC} MLX server already running on port $MLX_PORT"
        return 0
    fi

    # Check if port is in use (another server binding)
    if lsof -i :$MLX_PORT &>/dev/null; then
        echo -e "${YELLOW}⚠${NC} Port $MLX_PORT is in use but not responding. Waiting..."
        for _ in {1..15}; do
            if curl -sf --max-time 2 http://localhost:$MLX_PORT/v1/models &>/dev/null; then
                echo -e "${GREEN}✓${NC} MLX server ready on port $MLX_PORT"
                return 0
            fi
            sleep 2
        done
        echo -e "${RED}✗${NC} Server on port $MLX_PORT not responding. Kill existing process or use a different port."
        return 1
    fi

    # Port is free — start our own server
    echo -e "${YELLOW}⚠${NC} MLX server not running. Starting..."
    server_start
}

server_start() {
    echo -e "${BLUE}▸${NC} Starting MLX server with $MODEL..."
    "$BABY_PYTHON" -m mlx_lm.server \
        --model "$MODEL" \
        --host 127.0.0.1 \
        --port $MLX_PORT &

    for _ in {1..30}; do
        if curl -sf --max-time 2 http://localhost:$MLX_PORT/v1/models &>/dev/null; then
            echo -e "${GREEN}✓${NC} Server ready on port $MLX_PORT"
            return 0
        fi
        sleep 1
    done
    echo -e "${RED}✗${NC} Server failed to start"
    return 1
}

cmd_spawn() {
    local name="${1:-baby}"
    ensure_server

    local baby_dir="$AGENT_BABIES_HOME/babies/$name"
    mkdir -p "$baby_dir"/{memory,logs,inbox,outbox}

    if [[ ! -f "$baby_dir/system-prompt.md" ]]; then
        cp "$PROMPTS_DIR/default.md" "$baby_dir/system-prompt.md"
    fi

    echo -e "${GREEN}✓${NC} Baby '$name' ready at $baby_dir"
    echo -e "${BLUE}▸${NC} Run: agent-baby chat $name"
}

cmd_chat() {
    local name="${1:-baby}"
    local baby_dir="$AGENT_BABIES_HOME/babies/$name"

    [[ -d "$baby_dir" ]] || cmd_spawn "$name"
    ensure_server

    echo -e "${BOLD}Chatting with $name${NC} (Ctrl+C to exit)"
    echo ""

    cd "$baby_dir" && pi --provider local \
       --model "$MODEL" \
       --system-prompt "$baby_dir/system-prompt.md"
}

cmd_talk() {
    local name="${1:-baby}"
    local baby_dir="$AGENT_BABIES_HOME/babies/$name"

    [[ -d "$baby_dir" ]] || cmd_spawn "$name"

    if ! command -v voicemode &>/dev/null; then
        echo -e "${YELLOW}⚠${NC} VoiceMode not installed."
        echo -e "${BLUE}▸${NC} Run: agent-baby install-voice"
        exit 1
    fi

    echo -e "${BOLD}Voice chat with $name${NC} (Ctrl+C to exit)"
    echo ""
    echo "Voice chat integration coming soon."
    echo "For now, use: agent-baby chat $name"
}

case "${1:-help}" in
    spawn)          cmd_spawn "${2:-baby}" ;;
    chat)           cmd_chat "${2:-baby}" ;;
    talk)           cmd_talk "${2:-baby}" ;;
    list)           ls -1 "$AGENT_BABIES_HOME/babies/" 2>/dev/null || echo "No babies yet." ;;
    stop)           echo "Stop not yet implemented." ;;
    server)         server_start ;;
    server-status)
        if curl -sf http://localhost:$MLX_PORT/v1/models &>/dev/null; then
            echo -e "${GREEN}✓${NC} MLX server running on port $MLX_PORT"
        else
            echo -e "${RED}✗${NC} MLX server not running"
        fi
        ;;
    install-voice)
        echo -e "${BLUE}▸${NC} Installing VoiceMode..."
        if command -v uv &>/dev/null; then
            curl -fsSL https://getvoicemode.com/install.sh | bash
        else
            echo "uv not found. Install it first: curl -LsSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
        ;;
    help|--help|-h) usage ;;
    *)              echo "Unknown command: $1"; usage; exit 1 ;;
esac
SCRIPT

chmod +x "$BIN_DIR/agent-baby"
ok "CLI installed"

# ─── PATH ────────────────────────────────────────────────────────────

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    SHELL_NAME=$(basename "$SHELL")
    RC_FILE="$HOME/.${SHELL_NAME}rc"

    if ! grep -q 'agent-babies/bin' "$RC_FILE" 2>/dev/null; then
        echo '' >> "$RC_FILE"
        echo '# Agent Babies' >> "$RC_FILE"
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$RC_FILE"
        info "Added to PATH in $RC_FILE"
    fi

    export PATH="$BIN_DIR:$PATH"
fi

# ─── VoiceMode (optional) ───────────────────────────────────────────

header "Step 5/5: Voice (optional)"

if command_exists voicemode; then
    ok "VoiceMode already installed"
else
    info "VoiceMode adds voice conversations to your agent babies."
    info "Includes local speech-to-text (Whisper) and text-to-speech (Kokoro)."
    info "Download size: ~3GB"
    echo ""

    if confirm "Install VoiceMode?" "y"; then
        curl -fsSL https://getvoicemode.com/install.sh | bash
        ok "VoiceMode installed"
    else
        info "Skipping. Install later with: agent-baby install-voice"
    fi
fi

# ─── Done ────────────────────────────────────────────────────────────

echo ""
echo "${BOLD}Agent Babies installed!${NC}"
echo ""
echo "  Your Mac:  $CHIP, ${RAM_GB}GB"
echo "  Model:     $MODEL_LABEL"
echo "  CLI:       $BIN_DIR/agent-baby"
echo ""
echo "  ${BOLD}Get started:${NC}"
echo "    agent-baby server     # Start the model server"
echo "    agent-baby spawn      # Create your first baby"
echo "    agent-baby chat       # Start chatting"
if command_exists voicemode; then
echo "    agent-baby talk       # Voice chat"
fi
echo ""
