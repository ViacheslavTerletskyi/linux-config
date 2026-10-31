import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets

// Calendar: days → (click title) months → (click title) years.
// Arrows / mouse wheel move by month, year or 12 years depending on the view.
DropdownPopup {
    id: pop

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    property string view: "days" // days | months | years
    readonly property int yearsStart: year - year % 12

    contentWidth: 300

    // Same language as the UI, but weeks always start on Monday.
    // (MonthGrid takes the first day from the locale; en_GB = English with Monday first.)
    readonly property var calLocale: Theme.locale.firstDayOfWeek === Locale.Monday ? Theme.locale : Qt.locale("en_GB")

    function reset() {
        today = new Date();
        year = today.getFullYear();
        month = today.getMonth();
        view = "days";
    }
    function step(dir) {
        if (view === "days") {
            const m = month + dir;
            year += Math.floor(m / 12);
            month = (m % 12 + 12) % 12;
        } else if (view === "months") {
            year += dir;
        } else {
            year += 12 * dir;
        }
    }
    function monthName(m, fmt) {
        return Theme.capitalize(Theme.locale.standaloneMonthName(m, fmt));
    }

    onOpenChanged: if (open) reset()

    // Header: ‹ title ›
    RowLayout {
        Layout.fillWidth: true
        NavButton { text: "\uf053"; onClicked: pop.step(-1) }
        NavButton {
            Layout.fillWidth: true
            bold: true
            text: pop.view === "days" ? pop.monthName(pop.month, Locale.LongFormat) + " " + pop.year
                : pop.view === "months" ? String(pop.year)
                : pop.yearsStart + " – " + (pop.yearsStart + 11)
            onClicked: pop.view = pop.view === "days" ? "months" : pop.view === "months" ? "years" : "days"
        }
        NavButton { text: "\uf054"; onClicked: pop.step(1) }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 230

        WheelHandler {
            onWheel: ev => pop.step(ev.angleDelta.y > 0 ? -1 : 1)
        }

        // Days
        ColumnLayout {
            anchors.fill: parent
            visible: pop.view === "days"
            spacing: 2

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: pop.calLocale
                delegate: Text {
                    required property var model
                    text: Theme.capitalize(model.shortName)
                    color: Theme.overlay0
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
            MonthGrid {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                month: pop.month
                year: pop.year
                locale: pop.calLocale
                spacing: 2
                delegate: Rectangle {
                    required property var model
                    readonly property bool inMonth: model.month === grid.month
                    readonly property bool weekend: model.date.getDay() === 0 || model.date.getDay() === 6
                    radius: Theme.radius
                    color: model.today ? Theme.blue : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: parent.model.day
                        opacity: parent.inMonth ? 1 : 0.3
                        color: parent.model.today ? Theme.crust : parent.weekend ? Theme.red : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: parent.model.today
                    }
                }
            }
        }

        // Months / years: 3×4 grid
        GridLayout {
            anchors.fill: parent
            visible: pop.view !== "days"
            columns: 3
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: 12
                delegate: NavButton {
                    required property int index
                    readonly property int value: pop.view === "months" ? index : pop.yearsStart + index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: pop.view === "months" ? pop.monthName(index, Locale.ShortFormat) : String(value)
                    current: pop.view === "months"
                        ? (pop.year === pop.today.getFullYear() && index === pop.today.getMonth())
                        : value === pop.today.getFullYear()
                    selected: pop.view === "months" ? index === pop.month : value === pop.year
                    onClicked: {
                        if (pop.view === "months") { pop.month = index; pop.view = "days"; }
                        else { pop.year = value; pop.view = "months"; }
                    }
                }
            }
        }
    }

    NavButton {
        Layout.alignment: Qt.AlignHCenter
        text: "Today"
        onClicked: pop.reset()
    }

    component NavButton: Rectangle {
        id: btn
        property alias text: label.text
        property bool bold: false
        property bool current: false   // today's month/year
        property bool selected: false  // month/year being viewed
        signal clicked
        implicitWidth: label.implicitWidth + 16
        implicitHeight: 30
        radius: Theme.radius
        color: current ? Theme.blue : area.containsMouse ? Theme.surface1 : selected ? Theme.surface0 : "transparent"
        Text {
            id: label
            anchors.centerIn: parent
            color: btn.current ? Theme.crust : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: btn.bold || btn.current
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
