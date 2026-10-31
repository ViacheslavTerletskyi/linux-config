pragma Singleton
import QtQuick
import Quickshell

// Catppuccin Mocha — matches the GTK theme.
Singleton {
    readonly property color crust: "#11111b"
    readonly property color mantle: "#181825"
    readonly property color base: "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color overlay0: "#6c7086"
    readonly property color subtext: "#a6adc8"
    readonly property color text: "#cdd6f4"
    readonly property color blue: "#89b4fa"
    readonly property color teal: "#94e2d5"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color peach: "#fab387"
    readonly property color red: "#f38ba8"
    readonly property color mauve: "#cba6f7"

    readonly property string fontFamily: "CaskaydiaCove Nerd Font"   // bar text + icons
    readonly property string uiFont: "Adwaita Sans"                  // body text in larger surfaces
    readonly property int fontSize: 13

    // UI language = system language (LANG). Qt.locale() would follow LC_TIME instead.
    readonly property var locale: Qt.locale((Quickshell.env("LANG") ?? "en_US").split(".")[0])
    function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

    readonly property int barHeight: 30
    readonly property int spacing: 4
    readonly property int padding: 8
    readonly property int radius: 6
}
