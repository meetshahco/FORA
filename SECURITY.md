# Security

## Protecting your API keys

API keys are stored in `.env` at the repo root. This file is gitignored and must never be committed.

Before committing, verify:

```bash
git status
```

`.env` should not appear in the output. If it does, remove it from staging with `git restore --staged .env` before proceeding.

**If a key is accidentally pushed**, rotate it immediately — the old key should be treated as compromised regardless of whether anyone else has seen it.

Rotate at:
- Anthropic — https://console.anthropic.com/settings/keys
- Google AI Studio — https://aistudio.google.com/app/apikey
- OpenAI — https://platform.openai.com/api-keys
- Vercel — https://vercel.com/account/tokens

After rotating, remove the key from git history using `git filter-repo` or BFG Repo Cleaner, then force-push. GitHub's secret scanning may also flag it automatically.

---

## Personal data

`profile.json`, the `briefs/` directory, and the `output/` directory are all gitignored. They contain personal career data, application-specific positioning, and generated HTML — none of which belongs in version control.

This repo contains only pipeline code. No personal data is ever committed.

Before any commit, run:

```bash
git status
```

and confirm that none of the following appear as staged or untracked files:

- `profile.json`
- `briefs/*.json` (other than `example-brief.json`)
- `output/`

---

## Encryption at Rest

Because `profile.json` contains your complete career history and personal data in plain text, you should ensure that your machine is protected.

- **macOS:** Enable **FileVault** in System Settings > Privacy & Security > FileVault.
- **Windows:** Enable **BitLocker** or device encryption in Settings > Update & Security > Device encryption.
- **Linux:** Use **LUKS** full-disk encryption.

This prevents unauthorized access to your private profile details if your physical machine is lost or compromised.
