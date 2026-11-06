import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Connect.js" as Connect

Panel {
  id: root
  moduleName: "knoguchi.hidden-network"
  ipcTarget: "knoguchi.hidden-network"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property var securities: ["wpa-psk", "sae", "open"]
  property int securityIndex: 0
  readonly property string security: securities[Math.max(0, Math.min(securities.length - 1, securityIndex))]
  property string statusKey: ""
  property string statusDetail: ""
  property bool failed: false
  readonly property bool busy: connectProc.running
  readonly property string statusText: statusDetail !== "" ? statusDetail : (statusKey !== "" ? strings.t(statusKey) : "")
  readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("scripts/connect-hidden").toString().replace(/^file:\/\//, ""))

  function selectSecurityByDelta(delta) {
    if (busy) return
    var count = securities.length
    securityIndex = (securityIndex + delta + count) % count
  }

  function clearStatus() {
    statusKey = ""
    statusDetail = ""
    failed = false
  }

  function submit() {
    if (busy) return
    var page = panel.loadedContent
    if (!page) return
    var check = Connect.validate(page.ssidField.text, page.passwordField.text, security)
    if (!check.ok) {
      failed = true
      statusDetail = ""
      statusKey = check.reason
      return
    }
    failed = false
    statusDetail = ""
    statusKey = "hidden.connecting"
    connectProc.secret = check.security === "open" ? "" : page.passwordField.text
    connectProc.command = ["bash", scriptPath, check.ssid, check.security]
    connectProc.running = true
  }

  function finish(exitCode, stderr, stdout) {
    connectProc.secret = ""
    var result = Connect.outcome(exitCode, stderr, stdout)
    failed = !result.ok
    statusDetail = result.detail
    statusKey = result.key
    if (result.ok && panel.loadedContent) panel.loadedContent.passwordField.text = ""
  }

  onOpenedChanged: {
    if (opened) {
      Qt.callLater(function() {
        if (panel.loadedContent) panel.loadedContent.ssidField.forceActiveFocus()
      })
    } else if (panel.loadedContent) {
      panel.loadedContent.passwordField.text = ""
    }
  }

  Process {
    id: connectProc
    property string secret: ""
    stdinEnabled: true
    stdout: StdioCollector { id: connectStdout; waitForEnd: true }
    stderr: StdioCollector { id: connectStderr; waitForEnd: true }
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
    onExited: function(exitCode) {
      root.finish(exitCode, connectStderr.text, connectStdout.text)
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\udb81\udda9"
    tooltipText: strings.t("hidden.tooltip")
    onPressed: function(b) {
      if (root.opened) root.close()
      else root.open()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias ssidField: ssidField
      property alias passwordField: passwordField
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      blocked: ssidField.activeFocus || (passwordField.visible && passwordField.activeFocus)

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.selectSecurityByDelta(dx)
      }
      onActivateRequested: root.submit()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: strings.t("hidden.title")
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: strings.t("hidden.hint")
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        TextField {
          id: ssidField
          width: parent.width
          enabled: !root.busy
          placeholderText: strings.t("hidden.ssid")
          font.family: root.bar.fontFamily
          foreground: root.bar.foreground
          onAccepted: root.security === "open" ? root.submit() : passwordField.forceActiveFocus()
          Keys.onEscapePressed: root.close()
        }

        PanelSectionHeader {
          text: strings.t("hidden.security")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Row {
          id: securityRow
          width: parent.width
          spacing: Style.space(6)
          readonly property real cellWidth: (width - spacing * (root.securities.length - 1)) / root.securities.length

          Repeater {
            model: root.securities
            delegate: Button {
              required property string modelData
              required property int index
              width: securityRow.cellWidth
              enabled: !root.busy
              bordered: true
              active: root.security === modelData
              text: {
                if (modelData === "sae") return strings.t("hidden.wpa3")
                if (modelData === "open") return strings.t("hidden.open")
                return strings.t("hidden.wpa")
              }
              fontSize: Style.font.bodySmall
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.securityIndex = index
            }
          }
        }

        TextField {
          id: passwordField
          visible: root.security !== "open"
          width: parent.width
          enabled: !root.busy
          password: true
          placeholderText: strings.t("hidden.password")
          font.family: root.bar.fontFamily
          foreground: root.bar.foreground
          onAccepted: root.submit()
          Keys.onEscapePressed: root.close()
        }

        Button {
          width: parent.width
          enabled: !root.busy
          bordered: true
          text: root.busy ? strings.t("hidden.connecting") : strings.t("hidden.connect")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: root.submit()
        }

        Text {
          id: statusText
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          visible: text !== ""
          text: root.statusText
          color: root.failed ? root.bar.urgent : root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          opacity: visible ? 1 : 0
          Behavior on opacity {
            NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
