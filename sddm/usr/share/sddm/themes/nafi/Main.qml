import QtQuick 2.15
import QtGraphicalEffects 1.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: 640
    height: 480
    color: "#1e1e2e"

    // -- Catppuccin Mocha palette --
    readonly property color crust:    "#11111b"
    readonly property color mantle:   "#181825"
    readonly property color base:     "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color text_:    "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color subtext1: "#bac2de"
    readonly property color lavender: "#b4befe"
    readonly property color blue:     "#89b4fa"
    readonly property color red:      "#f38ba8"
    readonly property color peach:    "#fab387"
    readonly property color green:    "#a6e3a1"
    readonly property color overlay0: "#6c7086"

    // -- Theme config --
    readonly property string fontFamily: config.font || "JetBrainsMono Nerd Font"
    readonly property string brandingText: config.brandingText || "Nafi"
    readonly property string wallpaperPath: config.wallpaperPath || "wallpaper.jpg"

    // -- State --
    property string currentUser: userModel.lastUser
    property int sessionIndex: {
        for (var i = 0; i < sessionModel.rowCount(); i++) {
            var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
            if (name.indexOf("uwsm") !== -1)
                return i
        }
        return sessionModel.lastIndex
    }

    // -- Clock timer --
    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            clockText.text = Qt.formatDateTime(now, "hh:mm")
            dateText.text = Qt.formatDateTime(now, "dddd d MMM yy")
        }
    }

    // -- SDDM signals --
    Connections {
        target: sddm
        function onLoginFailed() {
            errorMessage.text = "Login failed"
            errorMessage.visible = true
            password.text = ""
            password.focus = true
        }
        function onLoginSucceeded() {
            errorMessage.visible = false
        }
    }

    // -- Wallpaper background --
    Image {
        id: wallpaper
        source: root.wallpaperPath
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    // -- Blur effect over wallpaper --
    FastBlur {
        id: blurEffect
        anchors.fill: wallpaper
        source: wallpaper
        radius: 64
    }

    // -- Dark overlay for contrast --
    Rectangle {
        anchors.fill: parent
        color: root.base
        opacity: 0.55
    }

    // -- Main content column --
    Column {
        anchors.centerIn: parent
        spacing: root.height * 0.025
        width: parent.width

        // Clock
        Text {
            id: clockText
            text: Qt.formatDateTime(new Date(), "hh:mm")
            color: root.text_
            font.family: root.fontFamily
            font.pixelSize: root.height * 0.10
            font.weight: Font.Light
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Date
        Text {
            id: dateText
            text: Qt.formatDateTime(new Date(), "dddd d MMM yy")
            color: root.subtext0
            font.family: root.fontFamily
            font.pixelSize: root.height * 0.022
            font.weight: Font.Normal
            font.letterSpacing: 2
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Spacer
        Item { width: 1; height: root.height * 0.02 }

        // Branding text
        Text {
            text: root.brandingText
            color: root.lavender
            font.family: root.fontFamily
            font.pixelSize: root.height * 0.045
            font.weight: Font.DemiBold
            font.letterSpacing: 6
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Spacer
        Item { width: 1; height: root.height * 0.01 }

        // Password field row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.width * 0.008

            // Lock icon
            Text {
                text: "\uf023"
                color: root.subtext0
                font.family: root.fontFamily
                font.pixelSize: root.height * 0.028
                anchors.verticalCenter: parent.verticalCenter
            }

            // Password input box
            Rectangle {
                width: root.width * 0.22
                height: root.height * 0.05
                color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, 0.8)
                border.color: root.surface1
                border.width: 2
                radius: 4
                clip: true

                Rectangle {
                    id: passwordFocusBorder
                    anchors.fill: parent
                    color: "transparent"
                    border.color: root.lavender
                    border.width: 2
                    radius: parent.radius
                    visible: password.activeFocus
                }

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: root.height * 0.01
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    font.family: root.fontFamily
                    font.pixelSize: root.height * 0.022
                    font.letterSpacing: root.height * 0.005
                    passwordCharacter: "\u2022"
                    color: root.text_
                    selectionColor: root.surface1
                    focus: true

                    Text {
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "Enter Password"
                        color: root.overlay0
                        font.family: root.fontFamily
                        font.pixelSize: root.height * 0.02
                        visible: password.text.length === 0 && !password.activeFocus
                    }

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(root.currentUser, password.text, root.sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }
        }

        // Error message
        Text {
            id: errorMessage
            text: ""
            visible: false
            color: root.red
            font.family: root.fontFamily
            font.pixelSize: root.height * 0.018
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Session selector
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.width * 0.006
            visible: sessionModel.rowCount() > 1

            Text {
                text: "Session:"
                color: root.subtext0
                font.family: root.fontFamily
                font.pixelSize: root.height * 0.016
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: root.width * 0.15
                height: root.height * 0.035
                color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, 0.8)
                border.color: root.surface1
                border.width: 1
                radius: 3

                // Currently selected session name
                Text {
                    id: sessionText
                    anchors.fill: parent
                    anchors.leftMargin: root.width * 0.006
                    anchors.rightMargin: root.width * 0.02
                    verticalAlignment: Text.AlignVCenter
                    text: sessionModel.data(sessionModel.index(root.sessionIndex, 0), Qt.DisplayRole) || ""
                    color: root.text_
                    font.family: root.fontFamily
                    font.pixelSize: root.height * 0.015
                    elide: Text.ElideRight
                }

                // Dropdown arrow
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: root.width * 0.006
                    anchors.verticalCenter: parent.verticalCenter
                    text: sessionDropdown.visible ? "\u25B2" : "\u25BC"
                    color: root.subtext0
                    font.pixelSize: root.height * 0.012
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        sessionDropdown.visible = !sessionDropdown.visible
                    }
                }

                // Dropdown list
                Column {
                    id: sessionDropdown
                    visible: false
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.left: parent.left
                    width: parent.width
                    z: 100

                    Repeater {
                        model: sessionModel

                        Rectangle {
                            width: sessionDropdown.width
                            height: root.height * 0.035
                            color: sessionItemMouse.containsMouse
                                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.9)
                                : Qt.rgba(root.crust.r, root.crust.g, root.crust.b, 0.95)
                            border.color: root.surface0
                            border.width: 1
                            radius: 2

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: root.width * 0.006
                                verticalAlignment: Text.AlignVCenter
                                text: model.name || ""
                                color: index === root.sessionIndex ? root.lavender : root.text_
                                font.family: root.fontFamily
                                font.pixelSize: root.height * 0.014
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: sessionItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.sessionIndex = index
                                    sessionDropdown.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // -- Power buttons (bottom right) --
    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: root.height * 0.03
        anchors.rightMargin: root.width * 0.03
        spacing: root.width * 0.015
        z: 10

        // Suspend
        Rectangle {
            width: root.height * 0.045
            height: width
            radius: width / 2
            color: suspendMouse.containsMouse
                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.6)

            Text {
                anchors.centerIn: parent
                // moon icon
                text: "\uf186"
                color: suspendMouse.containsMouse ? root.peach : root.subtext0
                font.family: root.fontFamily
                font.pixelSize: root.height * 0.02
            }

            MouseArea {
                id: suspendMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.suspend()
            }
        }

        // Reboot
        Rectangle {
            width: root.height * 0.045
            height: width
            radius: width / 2
            color: rebootMouse.containsMouse
                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.6)

            Text {
                anchors.centerIn: parent
                // refresh/reboot icon
                text: "\uf021"
                color: rebootMouse.containsMouse ? root.blue : root.subtext0
                font.family: root.fontFamily
                font.pixelSize: root.height * 0.02
            }

            MouseArea {
                id: rebootMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.reboot()
            }
        }

        // Shutdown
        Rectangle {
            width: root.height * 0.045
            height: width
            radius: width / 2
            color: shutdownMouse.containsMouse
                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.6)

            Text {
                anchors.centerIn: parent
                // power icon
                text: "\uf011"
                color: shutdownMouse.containsMouse ? root.red : root.subtext0
                font.family: root.fontFamily
                font.pixelSize: root.height * 0.02
            }

            MouseArea {
                id: shutdownMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.powerOff()
            }
        }
    }

    // -- Username display (bottom left) --
    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.height * 0.03
        anchors.leftMargin: root.width * 0.03
        text: root.currentUser
        color: root.subtext0
        font.family: root.fontFamily
        font.pixelSize: root.height * 0.018
        font.letterSpacing: 1
    }

    // -- Close session dropdown when clicking elsewhere --
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            sessionDropdown.visible = false
            password.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        password.forceActiveFocus()
    }
}
