import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen

    implicitWidth: pill.width
    implicitHeight: pill.height

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": "Open Panel",        "action": "panel",    "icon": "camera-video" },
            { "label": "Open Clips Folder", "action": "folder",   "icon": "folder-open"  },
            { "label": I18n.tr("actions.widget-settings"), "action": "settings", "icon": "settings" }
        ]
        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(root.screen)
            if (action === "panel") {
                if (root.pluginApi?.mainInstance)
                    root.pluginApi.mainInstance.hasNewClip = false
                root.pluginApi?.openPanel(root.screen, root)
            } else if (action === "folder") {
                root.pluginApi?.mainInstance?.openFolder()
            } else if (action === "settings") {
                BarService.openPluginSettings(root.screen, root.pluginApi.manifest)
            }
        }
    }

    BarPill {
        id: pill
        screen: root.screen
        tooltipText: root.pluginApi?.mainInstance?.hasNewClip ? "New clip saved!" : "Clips"
        icon: "camera-video"
        onClicked: {
            if (root.pluginApi?.mainInstance)
                root.pluginApi.mainInstance.hasNewClip = false
            root.pluginApi?.openPanel(root.screen, root)
        }
        onRightClicked: PanelService.showContextMenu(contextMenu, root, root.screen)
    }
}
