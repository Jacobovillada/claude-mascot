# Claude Mascot 🧠

**A pixel art buddy for macOS that tells you when Claude Code needs you.**

[Leer en español](README.es.md)

![Claude Mascot waving from its laptop](docs/mascota.png)

## Meet the mascot

Claude Mascot is a small pixel art character that lives on your Mac. While Claude works, it sits at its little laptop, typing lines of code.

When Claude asks you a question, needs a permission or finishes a task, the mascot notices. An exclamation mark pops over its head, its laptop screen turns orange with a big "?" or "!", and it jumps up and down waving at you.

## What it does

- **Shows up on top of everything.** Any app, any desktop, even full screen apps.
- **Tells you what Claude needs.** The speech bubble shows the question and which conversation it comes from.
- **Takes you there in one click.** Click the mascot and it opens that exact conversation in the Claude app.
- **Gets out of your way.** Click the X to dismiss it, or drag it anywhere on your screen. It hides by itself once you reply.
- **Knows when to stay quiet.** No alerts when you are already looking at that conversation, and none for scheduled tasks.
- **Runs 100% locally.** Nothing leaves your Mac.

## Requirements

- macOS 13 or later with Xcode command line tools (`xcode-select --install`)
- Claude Code, in the terminal or in the Claude desktop app

## Install

```bash
git clone https://github.com/Jacobovillada/claude-mascot.git ~/mascota-claude
~/mascota-claude/scripts/instalar.sh
```

Try it right away:

```bash
curl -s -X POST -d '{}' http://127.0.0.1:4956/prueba
```

Logs live in `~/Library/Logs/mascota-claude.log`. Optional settings (project aliases, sound) go in `~/.config/mascota-claude/config.json`; see `config.ejemplo.json`.

## Uninstall

```bash
~/mascota-claude/scripts/desinstalar.sh
```

## License

MIT. A personal project, not affiliated with Anthropic. Claude is a trademark of Anthropic.
