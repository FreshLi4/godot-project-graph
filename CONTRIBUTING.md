# Contributing

Thanks for helping improve FreshLi4 Project Graph.

Before changing code, read `AGENTS.md`, `REQUIREMENTS.md`, and `docs/ARCHITECTURE.md`. Keep the scanner independent from editor UI, avoid executing scanned project code, and add fixture coverage for behavior changes.

Run both checks before opening a pull request:

```bash
godot --headless --path . --script tests/test_runner.gd
godot --headless --editor --path . --quit-after 120 -- --project-graph-smoke
```

Open pull requests as focused changes with a short explanation of user impact and verification evidence.
