## Basic Configuration

git config --global user.name "makutaku"
git config user.name "makutaku"

git config --global user.email "14153280+makutaku@users.noreply.github.com"
git config user.email "14153280+makutaku@users.noreply.github.com"

git config --global core.editor "vim"

# Set the default branch name (useful for new repositories)
git config --global init.defaultBranch master

# Enable colored output for Git commands
git config --global color.ui auto

# Configure Git to cache your credentials for a specified amount of time (in seconds)
git config --global credential.helper 'cache --timeout=3600'

# Set a shorter Git status output
git config --global status.short true

# Set a default push behavior (e.g., only push the current branch)
git config --global push.default simple

# Configure Git to use rebase by default when pulling
git config --global pull.rebase true

# Display a nicer log output with colors, graph, and one-line commits
git config --global alias.lg "log --oneline --graph --decorate"

# Global ignore file (add common files to ignore globally)
git config --global core.excludesfile ~/.gitignore_global

## Aliases

# Shorter aliases for common Git commands
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.cm commit
git config --global alias.df diff
git config --global alias.last 'log -1 HEAD'
git config --global alias.unstage 'reset HEAD --'

# Log with graph and decorations
git config --global alias.lg "log --oneline --graph --decorate"

# Show files that have changed
git config --global alias.changes "log --name-status -10"

## Diff and Merge Tools

# Set the diff tool (useful when resolving conflicts)
git config --global diff.tool vimdiff

# Set the merge tool (useful for resolving merge conflicts)
git config --global merge.tool vimdiff

# Automatically resolve merge conflicts where possible
git config --global merge.conflictstyle diff3


## Performance Optimization

# Automatically prune remote-tracking branches that have been deleted
git config --global fetch.prune true

# Compress Git history to optimize storage
git config --global gc.auto 256

# Speed up large Git repositories
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

## Credential and SSH Configuration

# Enable Git credential caching (to avoid repeated prompts for passwords)
git config --global credential.helper cache

# Store credentials securely in a credential store (recommended for HTTPS-based repos)
git config --global credential.helper store

# Set default SSH key for authentication
git config --global core.sshCommand "ssh -i ~/.ssh/id_rsa"


## Handling Line Endings

# Ensure that line endings are handled properly across platforms
# (For Windows users working in cross-platform environments)
git config --global core.autocrlf true

# (For macOS/Linux users, recommend setting this to false)
git config --global core.autocrlf input

