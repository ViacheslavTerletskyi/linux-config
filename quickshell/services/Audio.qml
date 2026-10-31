pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Hardware outputs / inputs (not app streams).
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    // App streams: playing sound / using a microphone (internal helper streams excluded).
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream)
    readonly property var playback: streams.filter(n => n.audio && n.properties["media.class"] === "Stream/Output/Audio")
    readonly property var recording: streams.filter(n => n.audio && n.properties["media.class"] === "Stream/Input/Audio")

    // Nodes must be tracked, otherwise their audio props stay unbound.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function setVolume(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }
    function setMicVolume(v) {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMicMute() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }
    function appName(n) {
        const p = n?.properties ?? {};
        return p["application.name"] || p["application.process.binary"] || nodeName(n);
    }
    function appIcon(n) {
        const p = n?.properties ?? {};
        return p["application.icon-name"] || p["application.process.binary"] || "";
    }
    function nodeName(n) {
        return n?.description || n?.nickname || n?.name || "";
    }
}
