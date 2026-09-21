import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// PgyBox：只显示浏览器已打开页面收到的 WAN 实时响应；0 B/s 仍是在线。
Panel {
  id: root
  moduleName: "local.pgybox"
  ipcTarget: "local.pgybox"
  manageIpc: false

  property string display: {
    var v = String(setting("display", "rate"))
    return ["rate", "up", "down"].indexOf(v) >= 0 ? v : "rate"
  }
  property var lastGoodSnap: null
  property string recentError: ""
  property bool ratesCollapsed: false
  property double nowSec: Date.now() / 1000
  property bool demoMode: false
  readonly property var demoSnap: ({
    ok: true, reachable: true, gateway: "—",
    name: "PgyBox Gateway", sn: "—", wanIp: "—", lanIp: "—",
    joined: true, up: 0, down: 0, ts: Date.now() / 1000
  })
  readonly property var snap: demoMode ? demoSnap : lastGoodSnap
  readonly property int watcherRetrySec: 1
  readonly property int freshWindowSec: 10
  readonly property bool hasSuccess: !!lastGoodSnap || demoMode
  readonly property bool reachable: hasSuccess
  readonly property var rateUp: snap ? snap.up : 0
  readonly property var rateDown: snap ? snap.down : 0
  readonly property double snapTs: snap ? Number(snap.ts || 0) : 0
  readonly property bool hasRate: !!snap && snap.up !== undefined && snap.down !== undefined
  readonly property bool fresh: !!snap && hasRate && hasSuccess && !recentError
    && (nowSec - snapTs < freshWindowSec)
  readonly property string statusText: {
    if (demoMode) return "正常"
    if (recentError !== "" || !hasSuccess) return "状态暂不可用"
    return fresh ? "正常" : "数据已过期"
  }
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
  readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.20)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string barLabel: {
    if (ratesCollapsed || !fresh) return ""
    if (display === "up") return "↑" + fmtRate(rateUp)
    if (display === "down") return "↓" + fmtRate(rateDown)
    return "↑" + fmtRate(rateUp) + " ↓" + fmtRate(rateDown)
  }
  readonly property string barTooltip: {
    if (ratesCollapsed) return "PgyBox · 左键打开明细"
    if (!fresh) return "PgyBox · " + statusText + " · 左键详情"
    return "PgyBox · 左键折叠速率 · WAN ↑" + fmtRate(rateUp) + " ↓" + fmtRate(rateDown)
  }

  function fmtRate(value) {
    var n = Number(value)
    if (!isFinite(n) || n < 0) return "—"
    if (n < 1000) return Math.round(n) + "B/s"
    if (n < 1000 * 1000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "KB/s"
    if (n < 1000 * 1000 * 1000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "MB/s"
    return (n / 1000000000).toFixed(1).replace(/\.0$/, "") + "GB/s"
  }
  function fmtAgo() {
    if (!snap || !snapTs) return "—"
    var s = Math.max(0, Math.floor(nowSec - snapTs))
    return s < freshWindowSec ? "刚刚" : Math.floor(s / 60) + " 分钟前"
  }
  function refresh() {
    restartTimer.stop()
    watcherProc.running = false
    watcherProc.running = true
  }
  function openCloud() {
    Quickshell.execDetached(["ma-browser", "open", "https://www.pgybox.com/zh/introduction?model=R300A-3151G"])
    root.close()
  }
  function parseState(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && parsed.ok === true && parsed.reachable === true
          && parsed.up !== undefined && parsed.down !== undefined) {
        root.lastGoodSnap = parsed
        root.recentError = ""
      } else if (parsed && parsed.error) {
        root.recentError = String(parsed.error)
      } else {
        root.recentError = "invalid-response"
      }
    } catch (e) {
      root.recentError = "invalid-json"
      console.warn("pgybox", "bad state line", e)
    }
  }

  readonly property string watcher: Qt.resolvedUrl("bin/pgybox-watch").toString().replace(/^file:\/\//, "")
  Process {
    id: watcherProc
    command: [root.watcher]
    running: true
    stdout: SplitParser { onRead: function(data) { root.parseState(data) } }
    stderr: SplitParser {
      onRead: function(data) {
        if (String(data).trim() !== "") console.warn("pgybox", String(data).trim())
      }
    }
    onExited: restartTimer.start()
  }
  Timer {
    id: restartTimer
    interval: root.watcherRetrySec * 1000
    onTriggered: watcherProc.running = true
  }
  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: root.nowSec = Date.now() / 1000
  }
  implicitWidth: (bar && bar.vertical) ? bar.barSize : row.implicitWidth
  implicitHeight: (bar && !bar.vertical) ? bar.barSize : row.implicitHeight
  Grid {
    id: row
    anchors.centerIn: parent
    columns: bar && bar.vertical ? 1 : 3
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    spacing: -Style.space(3)
    BarIconButton {
      id: button
      bar: root.bar
      text: ""
      iconComponent: Component {
        Item {
          anchors.fill: parent
          Image {
            id: oraySource
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/oray.png")
            sourceClipRect: Qt.rect(0, 0, 60, 60)
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            visible: false
            layer.enabled: true
          }
          MultiEffect {
            anchors.fill: oraySource
            source: oraySource
            colorization: 1.0
            colorizationColor: root.fresh ? root.fg : root.dim
          }
        }
      }
      foreground: root.fresh ? root.fg : root.dim
      onPressed: function(buttonCode) { root.barPressed(buttonCode) }
    }
    Item {
      id: rateItem
      implicitWidth: root.barLabel === "" ? 0 : label.implicitWidth + Style.space(2)
      implicitHeight: root.barLabel === "" ? 0 : label.implicitHeight
      visible: root.barLabel !== ""
      Text {
        id: label
        anchors.centerIn: parent
        text: root.barLabel
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    Item {
      width: root.barLabel === "" ? 0 : Style.space(2)
      height: 1
    }
  }
  MouseArea {
    anchors.fill: row
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) {
        if (root.ratesCollapsed) root.barPressed(mouse.button)
        else if (root.barLabel !== "" && mouse.x >= rateItem.x
                 && mouse.x < rateItem.x + rateItem.width) root.ratesCollapsed = true
        else root.barPressed(mouse.button)
      } else {
        root.barPressed(mouse.button)
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(row, root.barTooltip)
    onExited: if (root.bar) root.bar.hideTooltip(row)
  }
  function barPressed(buttonCode) {
    if (buttonCode === Qt.RightButton) root.openCloud()
    else if (buttonCode === Qt.MiddleButton) root.refresh()
    else root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: row
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(310))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + Style.space(16), Style.space(560))
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.openCloud()
      onCloseRequested: root.close()
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }
    }
    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight + Style.space(8)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      Column {
        id: column
        x: Style.space(4)
        width: parent.width - Style.space(8)
        spacing: Style.space(6)
        Column {
          width: parent.width
          spacing: Style.space(2)
          Text {
            text: "PGYBOX · 远程网关"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            text: root.statusText
            color: root.statusText === "正常" ? root.fg : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
        Rectangle { width: parent.width; height: 1; color: root.faint }
        Text {
          visible: root.fresh
          text: "↑" + root.fmtRate(root.rateUp) + "  ↓" + root.fmtRate(root.rateDown)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
          font.bold: true
        }
        Text {
          visible: !root.fresh
          text: root.statusText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
          font.bold: true
        }
        Rectangle { width: parent.width; height: 1; color: root.faint }
        Column {
          width: parent.width
          spacing: Style.space(3)
          DetailRow { label: "网络"; value: root.reachable && root.snap ? (root.snap.network || "") : "" }
          DetailRow { label: "设备名称"; value: root.reachable && root.snap ? (root.snap.name || "") : "" }
          DetailRow { label: "SN"; value: root.reachable && root.snap ? (root.snap.sn || "") : "" }
          DetailRow { label: "WAN IP"; value: root.reachable && root.snap ? (root.snap.wanIp || "") : "" }
          DetailRow { label: "LAN IP"; value: root.reachable && root.snap ? (root.snap.lanIp || "") : "" }
          DetailRow { label: "智能组网"; value: root.reachable && root.snap ? (root.snap.joined !== undefined ? (root.snap.joined ? "已加入" : "未加入") : "") : "" }
          DetailRow { label: "上行"; value: root.fresh ? root.fmtRate(root.rateUp) : "" }
          DetailRow { label: "下行"; value: root.fresh ? root.fmtRate(root.rateDown) : "" }
          DetailRow { label: "上次更新"; value: root.fmtAgo() }
          DetailRow {
            label: "状态"
            value: root.statusText
            alert: root.statusText === "状态暂不可用"
          }
        }
      }
    }
  }
  component DetailRow: Item {
    property string label: ""
    property string value: ""
    property bool alert: false
    visible: value !== ""
    width: parent ? parent.width : 0
    height: Math.max(left.implicitHeight, right.implicitHeight)
    Text {
      id: left
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2)
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      id: right
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      text: parent.value
      color: parent.alert ? root.urgent : root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
  IpcHandler {
    enabled: root.bar !== null
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function demo(): string { root.demoMode = !root.demoMode; if (root.demoMode && !root.opened) root.open(); return root.demoMode ? "demo" : "live" }
    function state(): string { return JSON.stringify({snap: root.snap, display: root.display, demo: root.demoMode}) }
  }
}
