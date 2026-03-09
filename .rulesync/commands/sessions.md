---
description: 'Manage Claude Code session history - list, load, alias, and edit sessions'
targets: ["claudecode"]
---

# Sessions Command

Manage Claude Code session history - list, load, alias, and edit sessions stored in `~/.claude/sessions/`.

## Usage

`/sessions [list|load|alias|info|help] [options]`

## Actions

### List Sessions

Display all sessions with metadata, filtering, and pagination.

```bash
/sessions                              # List all sessions (default)
/sessions list                         # Same as above
/sessions list --limit 10              # Show 10 sessions
/sessions list --date 2026-02-01       # Filter by date
/sessions list --search abc            # Search by session ID
```

**Script:**

```bash
SESSION_DIR="${HOME}/.claude/sessions"
ALIAS_FILE="${HOME}/.claude/session-aliases.json"

if [ ! -d "$SESSION_DIR" ]; then
  echo "No sessions directory found at $SESSION_DIR"
  exit 1
fi

# Build alias lookup (sessionPath -> aliasName)
declare -A ALIAS_MAP
if [ -f "$ALIAS_FILE" ]; then
  while IFS='=' read -r name path; do
    ALIAS_MAP["$path"]="$name"
  done < <(python3 -c "
import json, sys
with open('$ALIAS_FILE') as f:
    data = json.load(f)
for a in data.get('aliases', []):
    print(a['name'] + '=' + a['sessionPath'])
" 2>/dev/null)
fi

TOTAL=$(find "$SESSION_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
echo "Sessions (showing up to 20 of ${TOTAL}):"
echo ""
printf "%-10s %-12s %-6s %-8s %-6s %s\n" "ID" "Date" "Time" "Size" "Lines" "Alias"
echo "────────────────────────────────────────────────────"

find "$SESSION_DIR" -maxdepth 1 -name '*.md' -print0 \
  | xargs -0 ls -t \
  | head -20 \
  | while read -r filepath; do
    filename=$(basename "$filepath")
    # Extract short ID from filename (strip date prefix and .md suffix)
    short_id=$(echo "$filename" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_//' | sed 's/\.md$//' | cut -c1-8)
    [ -z "$short_id" ] && short_id="(none)"
    # Extract date from filename
    file_date=$(echo "$filename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || stat -f '%Sm' -t '%Y-%m-%d' "$filepath")
    file_time=$(stat -f '%Sm' -t '%H:%M' "$filepath")
    file_size=$(du -h "$filepath" | cut -f1 | tr -d ' ')
    line_count=$(wc -l < "$filepath" | tr -d ' ')
    alias_name="${ALIAS_MAP[$filename]:-}"
    printf "%-10s %-12s %-6s %-8s %-6s %s\n" "$short_id" "$file_date" "$file_time" "$file_size" "$line_count" "$alias_name"
done
```

### Load Session

Load and display a session's content (by ID or alias).

```bash
/sessions load <id|alias>             # Load session
/sessions load 2026-02-01             # By date (for no-id sessions)
/sessions load a1b2c3d4               # By short ID
/sessions load my-alias               # By alias name
```

**Script:**

```bash
SESSION_DIR="${HOME}/.claude/sessions"
ALIAS_FILE="${HOME}/.claude/session-aliases.json"
ID="$1"

if [ -z "$ID" ]; then
  echo "Usage: /sessions load <id|alias>"
  exit 1
fi

# Try to resolve as alias first
RESOLVED=""
if [ -f "$ALIAS_FILE" ]; then
  RESOLVED=$(python3 -c "
import json, sys
with open('$ALIAS_FILE') as f:
    data = json.load(f)
for a in data.get('aliases', []):
    if a['name'] == '$ID':
        print(a['sessionPath'])
        break
" 2>/dev/null)
fi

SESSION_ID="${RESOLVED:-$ID}"

# Find the session file
FILEPATH=$(find "$SESSION_DIR" -maxdepth 1 -name "*${SESSION_ID}*" -type f | head -1)
if [ -z "$FILEPATH" ]; then
  echo "Session not found: $ID"
  exit 1
fi

FILENAME=$(basename "$FILEPATH")
LINE_COUNT=$(wc -l < "$FILEPATH" | tr -d ' ')
FILE_SIZE=$(du -h "$FILEPATH" | cut -f1 | tr -d ' ')
TOTAL_ITEMS=$(grep -cE '^\s*- \[' "$FILEPATH" 2>/dev/null || echo "0")
COMPLETED=$(grep -cE '^\s*- \[x\]' "$FILEPATH" 2>/dev/null || echo "0")
IN_PROGRESS=$(grep -cE '^\s*- \[-\]' "$FILEPATH" 2>/dev/null || echo "0")

echo "Session: $FILENAME"
echo "Path: ~/.claude/sessions/$FILENAME"
echo ""
echo "Statistics:"
echo "  Lines: $LINE_COUNT"
echo "  Total items: $TOTAL_ITEMS"
echo "  Completed: $COMPLETED"
echo "  In progress: $IN_PROGRESS"
echo "  Size: $FILE_SIZE"
echo ""

# Show aliases for this session
if [ -f "$ALIAS_FILE" ]; then
  ALIASES=$(python3 -c "
import json
with open('$ALIAS_FILE') as f:
    data = json.load(f)
names = [a['name'] for a in data.get('aliases', []) if a['sessionPath'] == '$FILENAME']
if names:
    print(', '.join(names))
" 2>/dev/null)
  if [ -n "$ALIASES" ]; then
    echo "Aliases: $ALIASES"
    echo ""
  fi
fi

# Extract title from frontmatter if present
TITLE=$(sed -n '/^---$/,/^---$/{ /^title:/s/^title:\s*//p; }' "$FILEPATH")
if [ -n "$TITLE" ]; then
  echo "Title: $TITLE"
  echo ""
fi
```

### Create Alias

Create a memorable alias for a session.

```bash
/sessions alias <id> <name>           # Create alias
/sessions alias 2026-02-01 today-work # Create alias named "today-work"
```

**Script:**

```bash
SESSION_DIR="${HOME}/.claude/sessions"
ALIAS_FILE="${HOME}/.claude/session-aliases.json"
SESSION_ID="$1"
ALIAS_NAME="$2"

if [ -z "$SESSION_ID" ] || [ -z "$ALIAS_NAME" ]; then
  echo "Usage: /sessions alias <id> <name>"
  exit 1
fi

# Find the session file
FILEPATH=$(find "$SESSION_DIR" -maxdepth 1 -name "*${SESSION_ID}*" -type f | head -1)
if [ -z "$FILEPATH" ]; then
  echo "Session not found: $SESSION_ID"
  exit 1
fi

FILENAME=$(basename "$FILEPATH")

# Initialize alias file if it doesn't exist
if [ ! -f "$ALIAS_FILE" ]; then
  echo '{"aliases":[]}' > "$ALIAS_FILE"
fi

# Add alias using python3 for JSON manipulation
python3 -c "
import json, sys
with open('$ALIAS_FILE', 'r') as f:
    data = json.load(f)
# Remove existing alias with same name
data['aliases'] = [a for a in data.get('aliases', []) if a['name'] != '$ALIAS_NAME']
data['aliases'].append({'name': '$ALIAS_NAME', 'sessionPath': '$FILENAME'})
with open('$ALIAS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print('Alias created: $ALIAS_NAME -> $FILENAME')
"
```

### Remove Alias

Delete an existing alias.

```bash
/sessions alias --remove <name>        # Remove alias
/sessions unalias <name>               # Same as above
```

**Script:**

```bash
ALIAS_FILE="${HOME}/.claude/session-aliases.json"
ALIAS_NAME="$1"

if [ -z "$ALIAS_NAME" ]; then
  echo "Usage: /sessions alias --remove <name>"
  exit 1
fi

if [ ! -f "$ALIAS_FILE" ]; then
  echo "No aliases file found."
  exit 1
fi

python3 -c "
import json, sys
with open('$ALIAS_FILE', 'r') as f:
    data = json.load(f)
before = len(data.get('aliases', []))
data['aliases'] = [a for a in data.get('aliases', []) if a['name'] != '$ALIAS_NAME']
after = len(data['aliases'])
if before == after:
    print('Alias not found: $ALIAS_NAME')
    sys.exit(1)
with open('$ALIAS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print('Alias removed: $ALIAS_NAME')
"
```

### Session Info

Show detailed information about a session.

```bash
/sessions info <id|alias>              # Show session details
```

**Script:**

```bash
SESSION_DIR="${HOME}/.claude/sessions"
ALIAS_FILE="${HOME}/.claude/session-aliases.json"
ID="$1"

if [ -z "$ID" ]; then
  echo "Usage: /sessions info <id|alias>"
  exit 1
fi

# Try to resolve as alias first
RESOLVED=""
if [ -f "$ALIAS_FILE" ]; then
  RESOLVED=$(python3 -c "
import json
with open('$ALIAS_FILE') as f:
    data = json.load(f)
for a in data.get('aliases', []):
    if a['name'] == '$ID':
        print(a['sessionPath'])
        break
" 2>/dev/null)
fi

SESSION_ID="${RESOLVED:-$ID}"

# Find the session file
FILEPATH=$(find "$SESSION_DIR" -maxdepth 1 -name "*${SESSION_ID}*" -type f | head -1)
if [ -z "$FILEPATH" ]; then
  echo "Session not found: $ID"
  exit 1
fi

FILENAME=$(basename "$FILEPATH")
SHORT_ID=$(echo "$FILENAME" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_//' | sed 's/\.md$//' | cut -c1-8)
[ -z "$SHORT_ID" ] && SHORT_ID="(none)"
FILE_DATE=$(echo "$FILENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || stat -f '%Sm' -t '%Y-%m-%d' "$FILEPATH")
MODIFIED=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$FILEPATH")
LINE_COUNT=$(wc -l < "$FILEPATH" | tr -d ' ')
FILE_SIZE=$(du -h "$FILEPATH" | cut -f1 | tr -d ' ')
TOTAL_ITEMS=$(grep -cE '^\s*- \[' "$FILEPATH" 2>/dev/null || echo "0")
COMPLETED=$(grep -cE '^\s*- \[x\]' "$FILEPATH" 2>/dev/null || echo "0")
IN_PROGRESS=$(grep -cE '^\s*- \[-\]' "$FILEPATH" 2>/dev/null || echo "0")

echo "Session Information"
echo "════════════════════"
echo "ID:          $SHORT_ID"
echo "Filename:    $FILENAME"
echo "Date:        $FILE_DATE"
echo "Modified:    $MODIFIED"
echo ""
echo "Content:"
echo "  Lines:         $LINE_COUNT"
echo "  Total items:   $TOTAL_ITEMS"
echo "  Completed:     $COMPLETED"
echo "  In progress:   $IN_PROGRESS"
echo "  Size:          $FILE_SIZE"

# Show aliases
if [ -f "$ALIAS_FILE" ]; then
  ALIASES=$(python3 -c "
import json
with open('$ALIAS_FILE') as f:
    data = json.load(f)
names = [a['name'] for a in data.get('aliases', []) if a['sessionPath'] == '$FILENAME']
if names:
    print(', '.join(names))
" 2>/dev/null)
  if [ -n "$ALIASES" ]; then
    echo "Aliases:     $ALIASES"
  fi
fi
```

### List Aliases

Show all session aliases.

```bash
/sessions aliases                      # List all aliases
```

**Script:**

```bash
ALIAS_FILE="${HOME}/.claude/session-aliases.json"

if [ ! -f "$ALIAS_FILE" ]; then
  echo "Session Aliases (0):"
  echo ""
  echo "No aliases found."
  exit 0
fi

python3 -c "
import json

with open('$ALIAS_FILE') as f:
    data = json.load(f)

aliases = data.get('aliases', [])
print(f'Session Aliases ({len(aliases)}):')
print()

if not aliases:
    print('No aliases found.')
else:
    print(f'{\"Name\":<14} {\"Session File\":<32} Title')
    print('─' * 60)
    for a in aliases:
        name = a['name'][:12]
        path = a['sessionPath']
        if len(path) > 30:
            path = path[:27] + '...'
        title = a.get('title', '')
        print(f'{name:<14} {path:<32} {title}')
"
```

## Arguments

$ARGUMENTS:

- `list [options]` - List sessions
    - `--limit <n>` - Max sessions to show (default: 50)
    - `--date <YYYY-MM-DD>` - Filter by date
    - `--search <pattern>` - Search in session ID
- `load <id|alias>` - Load session content
- `alias <id> <name>` - Create alias for session
- `alias --remove <name>` - Remove alias
- `unalias <name>` - Same as `--remove`
- `info <id|alias>` - Show session statistics
- `aliases` - List all aliases
- `help` - Show this help

## Examples

```bash
# List all sessions
/sessions list

# Create an alias for today's session
/sessions alias 2026-02-01 today

# Load session by alias
/sessions load today

# Show session info
/sessions info today

# Remove alias
/sessions alias --remove today

# List all aliases
/sessions aliases
```

## Notes

- Sessions are stored as markdown files in `~/.claude/sessions/`
- Aliases are stored in `~/.claude/session-aliases.json`
- Session IDs can be shortened (first 4-8 characters usually unique enough)
- Use aliases for frequently referenced sessions
