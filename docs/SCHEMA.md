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

The addon emits:

- exact `references` edges reported by Godot `ResourceLoader`;
- exact `inherits` edges found by the non-executing GDScript declaration pass, directed child → parent with `origin: "GDScriptStatic"`.

Schema-compatible analyzers may add `contains`, `instantiates`, `creates`, and `located_in`. Consumers should interpret `confidence != "exact"` as inferred and potentially runtime-dependent; the native viewer renders those edges as dashed arrows.

## Compatibility rules

- Existing keys keep their meaning within schema version 1.
- Consumers must ignore unknown keys.
- A node ID is the canonical `res://` path in Phase 1.
- Edge IDs are deterministic and unique within a snapshot.
- Breaking changes require a new `schema_version`.
