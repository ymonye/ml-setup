# Update Ubuntu:
sudo apt-get update

# Upgrade Ubuntu:
sudo apt-get upgrade

# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 22

# Verify the Node.js version:
node -v # Should print "v22.18.0".
nvm current # Should print "v22.18.0".

# Verify npm version:
npm -v # Should print "10.9.3".

# Install Bunch of Coding CLIs:
npm install -g @anthropic-ai/claude-code
npm install -g @charmland/crush
npm install -g @google/gemini-cli
npm install -g @openai/codex
npm install -g @qwen-code/qwen-code
npm install -g opencode-ai@latest
curl https://cursor.com/install -fsS | bash
