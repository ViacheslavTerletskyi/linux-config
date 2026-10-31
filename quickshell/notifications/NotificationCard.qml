import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services
import qs.theme

// One notification. Click body: default action. ×: dismiss.
Rectangle {
    id: card

    required property Notification notif
    property bool popup: false
    readonly property bool hovered: hover.hovered
    readonly property string file: Notifs.fileOf(notif)   // e.g. a screenshot → click shows it in the folder
    signal expired

    implicitHeight: layout.implicitHeight + 20
    radius: Theme.radius
    color: Theme.mantle
    border.width: 1
    border.color: notif.urgency === NotificationUrgency.Critical ? Theme.red : Theme.surface1

    HoverHandler { id: hover }

    Timer {
        running: card.popup && interval > 0 && !card.hovered
        interval: Notifs.timeoutFor(card.notif)
        onTriggered: card.expired()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: card.file !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            const def = card.notif.actions.find(a => a.identifier === "default");
            if (def) def.invoke();
            else if (card.file !== "") Notifs.showInFolder(card.file);
            if (card.popup) card.expired();
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Screenshot (or other image file): thumbnail instead of an icon
        Image {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 72
            Layout.preferredHeight: 48
            visible: card.file !== ""
            source: card.file !== "" ? "file://" + card.file : ""
            sourceSize.width: 144
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        IconImage {
            Layout.alignment: Qt.AlignTop
            implicitSize: 40
            visible: card.file === "" && source != ""
            source: card.notif.image !== "" ? card.notif.image
                : card.notif.appIcon !== "" ? Quickshell.iconPath(card.notif.appIcon, true) : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: card.notif.appName
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                }
                Text {
                    text: ""
                    color: closeArea.containsMouse ? Theme.red : Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: card.notif.dismiss()
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: card.notif.summary
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notif.body
                textFormat: Text.StyledText
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 8
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: actionRepeater.count > 0

                Repeater {
                    id: actionRepeater
                    model: card.notif.actions.filter(a => a.identifier !== "default")
                    delegate: Rectangle {
                        required property NotificationAction modelData
                        implicitWidth: actionText.implicitWidth + 16
                        implicitHeight: actionText.implicitHeight + 8
                        radius: Theme.radius
                        color: actionArea.containsMouse ? Theme.surface1 : Theme.surface0
                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
