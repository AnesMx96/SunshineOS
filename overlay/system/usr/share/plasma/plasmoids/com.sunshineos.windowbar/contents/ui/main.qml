// Sunshine window title: the title of the active window for the top bar (no window buttons: the windows have their own).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    fullRepresentation: Item { }

    TaskManager.TasksModel {
        id: tasks
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    readonly property var activeIndex: tasks.activeTask
    readonly property bool hasActive: activeIndex && activeIndex.valid
    readonly property string title: hasActive ? String(tasks.data(activeIndex, Qt.DisplayRole)) : "Sunshine OS"

    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.minimumWidth: Kirigami.Units.gridUnit * 11
        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
        Text {
            Layout.fillWidth: true; Layout.leftMargin: 10
            text: root.title; color: "#f4f0eb"; elide: Text.ElideRight
            font.pixelSize: Kirigami.Units.gridUnit * 0.72; font.bold: true
        }
    }
}
