using Godot;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;

namespace FreshLi4.ProjectGraph;

// Keep the exported Godot/JSON dictionary contract at module boundaries.
internal static class GraphData
{
    public static Variant Get(this GDictionary data, string key, Variant fallback = default) => data.TryGetValue(key, out var value) ? value : fallback;
    public static string S(this GDictionary data, string key, string fallback = "") => data.Get(key, fallback).AsString();
    public static int I(this GDictionary data, string key, int fallback = 0) => data.Get(key, fallback).AsInt32();
    public static float F(this GDictionary data, string key, float fallback = 0) => data.Get(key, fallback).AsSingle();
    public static bool B(this GDictionary data, string key, bool fallback = false) => data.Get(key, fallback).AsBool();
    public static GArray A(this GDictionary data, string key) => data.Get(key, new GArray()).AsGodotArray();
    public static GDictionary D(this GDictionary data, string key) => data.Get(key, new GDictionary()).AsGodotDictionary();
    public static Vector2 V(this GDictionary data, string key) => data.Get(key, Vector2.Zero).AsVector2();
}
