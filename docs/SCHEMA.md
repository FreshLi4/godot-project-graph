# Project Graph JSON Schema v1

The Phase 1 export is a JSON object with these top-level keys:

```json
{
  "schema_version": 1,
  "generated_at": "2026-07-28T00:00:00Z",
  "project": {
    "name": "Example",
    "root": "res://"
  },
  "nodes": [],
  "edges": [],
  "stats": {}
}
```

## Node

```json
{
  "id": "res://actors/player.tscn",
  "label": "player.tscn",
  "kind": "Scene",
  "path": "res://actors/player.tscn",
  "missing": false,
  "metadata": {
    "extension": "tscn"
  }
}
```

Phase 1 node kinds are `Scene`, `Script`, `Resource`, `Mesh`, `Texture`, `Audio`, `Shader`, and `Data`.

## Edge

```json
{
  "id": "res://main.tscn|references|res://actors/player.tscn",
  "source": "res://main.tscn",
  "target": "res://actors/player.tscn",
  "relation": "references",
  "origin": "ResourceLoader",
  "confidence": "exact",
  "metadata": {}
}
```

Phase 1 emits only exact `references` edges reported by Godot. Later schema-compatible phases may add relations such as `contains`, `instantiates`, `inherits`, `creates`, and `located_in`.

## Compatibility rules

- Existing keys keep their meaning within schema version 1.
- Consumers must ignore unknown keys.
- A node ID is the canonical `res://` path in Phase 1.
- Edge IDs are deterministic and unique within a snapshot.
- Breaking changes require a new `schema_version`.
