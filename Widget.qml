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
  // Section-ready state: current connectivity is independent of retained data.
  property var wanState: ({
    data: null, lastSuccessTs: 0, status: "no-page", error: "no-page",
    reachable: false
  })
  property var devicesState: ({ data: null, lastSuccessTs: 0, status: "no-data", error: "", reachable: false })
  property var trafficState: ({ data: null, lastSuccessTs: 0, status: "no-data", error: "", reachable: false })
  property var dhcpState: ({ data: null, lastSuccessTs: 0, status: "no-data", error: "", reachable: false })
  property var updatesState: ({ data: null, lastSuccessTs: 0, status: "no-data", error: "", reachable: false })
  property bool ratesCollapsed: false
  property double nowSec: Date.now() / 1000
  property bool demoMode: false
  readonly property var demoSnap: ({
    ok: true, reachable: true, gateway: "—",
    name: "PgyBox Gateway", sn: "—", wanIp: "—", lanIp: "—",
    joined: true, up: 0, down: 0, ts: Date.now() / 1000
  })
  readonly property var snap: demoMode ? demoSnap : wanState.data
  readonly property int watcherRetrySec: 1
  readonly property int freshWindowSec: 10
  readonly property bool hasSuccess: !!wanState.data || demoMode
  readonly property bool reachable: demoMode || wanState.reachable
  readonly property var rateUp: snap ? snap.up : 0
  readonly property var rateDown: snap ? snap.down : 0
  readonly property double snapTs: demoMode ? Number(snap.ts || 0) : Number(wanState.lastSuccessTs || 0)
  readonly property bool hasRate: !!snap && snap.up !== undefined && snap.down !== undefined
  readonly property bool fresh: !!snap && hasRate && reachable
    && (nowSec - snapTs < freshWindowSec)
  readonly property bool devicesFresh: !!devicesState.data && devicesState.status === "ok" && (nowSec - Number(devicesState.lastSuccessTs || 0) < freshWindowSec)
  readonly property var trafficData: trafficState.data || ({})
  readonly property bool trafficFresh: !!trafficState.data && trafficState.status === "ok" && (nowSec - Number(trafficState.lastSuccessTs || 0) < freshWindowSec)
  readonly property bool dhcpFresh: !!dhcpState.data && dhcpState.status === "ok" && (nowSec - Number(dhcpState.lastSuccessTs || 0) < freshWindowSec)
  readonly property bool updatesFresh: !!updatesState.data && updatesState.status === "ok" && (nowSec - Number(updatesState.lastSuccessTs || 0) < freshWindowSec)
  readonly property bool available: ["no-claimed-tab", "no-pgybox-page", "no-browser", "unauthorized"].indexOf(wanState.status) < 0
    && (fresh || devicesFresh || trafficFresh || dhcpFresh || updatesFresh)
  readonly property string statusText: {
    if (demoMode) return "正常"
    if (wanState.status === "no-claimed-tab" || wanState.status === "no-pgybox-page") return "页面未打开"
    if (wanState.status === "no-browser") return "浏览器未运行"
    if (!reachable && wanState.status === "unauthorized") return "登录已失效"
    if (!reachable && wanState.status === "timeout") return "页面无新数据"
    if (!reachable) return "状态暂不可用"
    if (!snap) return "页面已连接"
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
  function fmtBytes(value) {
    var n = Number(value)
    if (!isFinite(n) || n < 0) return "—"
    if (n < 1000 * 1000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "KB"
    if (n < 1000 * 1000 * 1000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "MB"
    return (n / 1000000000).toFixed(1).replace(/\.0$/, "") + "GB"
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
    var opener = Qt.resolvedUrl("bin/pgybox-open").toString().replace(/^file:\/\//, "")
    Quickshell.execDetached([opener])
    root.close()
  }
  function markPageReachable() {
    if (!root.wanState.reachable) root.wanState = ({
      data: root.wanState.data, lastSuccessTs: root.wanState.lastSuccessTs,
      status: "page-ok", error: "", reachable: true
    })
  }
  function parseState(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      var sectionError = function(value) {
        var allowed = ["timeout", "unauthorized", "invalid-json", "devices-api-error", "devices-invalid", "traffic-invalid", "dhcp-api-error", "dhcp-invalid", "updates-api-error", "updates-invalid", "firmware-invalid", "body-unavailable", "http-error", "cdp-error"]
        return allowed.indexOf(String(value || "")) >= 0 ? String(value) : "error"
      }
      if (parsed && parsed.section === "devices") {
        root.devicesState = parsed.ok === true
          ? ({data: parsed.data, lastSuccessTs: Number(parsed.ts || Date.now() / 1000), status: "ok", error: "", reachable: true})
          : ({data: root.devicesState.data, lastSuccessTs: root.devicesState.lastSuccessTs, status: sectionError(parsed.status), error: sectionError(parsed.error || parsed.status), reachable: false})
        if (parsed.ok === true) root.markPageReachable()
        return
      }
      if (parsed && parsed.section === "traffic") {
        root.trafficState = parsed.ok === true
          ? ({data: Object.assign({}, root.trafficState.data || {}, parsed.data || {}), lastSuccessTs: Number(parsed.ts || Date.now() / 1000), status: "ok", error: "", reachable: true})
          : ({data: root.trafficState.data, lastSuccessTs: root.trafficState.lastSuccessTs, status: sectionError(parsed.status), error: sectionError(parsed.error || parsed.status), reachable: false})
        if (parsed.ok === true) root.markPageReachable()
        return
      }
      if (parsed && parsed.section === "dhcp") {
        root.dhcpState = parsed.ok === true
          ? ({data: parsed.data, lastSuccessTs: Number(parsed.ts || Date.now() / 1000), status: "ok", error: "", reachable: true})
          : ({data: root.dhcpState.data, lastSuccessTs: root.dhcpState.lastSuccessTs, status: sectionError(parsed.status), error: sectionError(parsed.error || parsed.status), reachable: false})
        if (parsed.ok === true) root.markPageReachable()
        return
      }
      if (parsed && parsed.section === "updates") {
        root.updatesState = parsed.ok === true
          ? ({data: Object.assign({}, root.updatesState.data || {}, parsed.data || {}), lastSuccessTs: Number(parsed.ts || Date.now() / 1000), status: "ok", error: "", reachable: true})
          : ({data: root.updatesState.data, lastSuccessTs: root.updatesState.lastSuccessTs, status: sectionError(parsed.status), error: sectionError(parsed.error || parsed.status), reachable: false})
        if (parsed.ok === true) root.markPageReachable()
        return
      }
      if (parsed && parsed.ok === true && parsed.reachable === true
          && parsed.up !== undefined && parsed.down !== undefined) {
        var normalized = {
          ok: true, reachable: true, status: "ok",
          up: Number(parsed.up), down: Number(parsed.down),
          ts: Number(parsed.ts || Date.now() / 1000)
        }
        root.wanState = ({
          data: normalized, lastSuccessTs: normalized.ts,
          status: "ok", error: "", reachable: true
        })
      } else if (parsed && parsed.error) {
        var allowed = ["no-claimed-tab", "no-pgybox-page", "no-page", "no-browser", "timeout", "unauthorized", "invalid-json",
                       "api-code-not-zero", "invalid-wan-rate", "body-unavailable",
                       "invalid-body", "http-error", "cdp-error"]
        var status = allowed.indexOf(String(parsed.status || parsed.error)) >= 0
          ? String(parsed.status || parsed.error) : "cdp-error"
        root.wanState = ({
          data: root.wanState.data, lastSuccessTs: root.wanState.lastSuccessTs,
          status: status, error: status, reachable: false
        })
      } else {
        root.wanState = ({
          data: root.wanState.data, lastSuccessTs: root.wanState.lastSuccessTs,
          status: "invalid-json", error: "invalid-json", reachable: false
        })
      }
    } catch (e) {
      root.wanState = ({
        data: root.wanState.data, lastSuccessTs: root.wanState.lastSuccessTs,
        status: "invalid-json", error: "invalid-json", reachable: false
      })
      console.warn("pgybox", "invalid watcher state")
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
        if (String(data).trim() !== "") console.warn("pgybox", "watcher reported an error")
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
            colorizationColor: root.available ? "#ffffff" : root.dim
          }
        }
      }
      foreground: root.available ? "#ffffff" : root.dim
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
        if (root.ratesCollapsed) root.ratesCollapsed = false
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
    if (buttonCode === Qt.LeftButton && root.ratesCollapsed) {
      root.ratesCollapsed = false
      return
    }
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
        Rectangle { width: parent.width; height: 1; color: root.faint }
        Column {
          width: parent.width
          spacing: Style.space(3)
          Text { text: "设备"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          DetailRow { label: "在线"; value: root.devicesState.data ? String(root.devicesState.data.online) : "—" }
          DetailRow { label: "活跃"; value: root.devicesState.data ? String(root.devicesState.data.active) : "—" }
          Repeater {
            model: root.devicesState.data ? root.devicesState.data.top : []
            delegate: DetailRow { label: modelData.name; value: "↑" + root.fmtRate(modelData.up) + " ↓" + root.fmtRate(modelData.down) }
          }
          Text { visible: !root.devicesState.data; text: root.devicesState.status === "no-data" ? "暂无设备数据" : "设备数据暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          Text { visible: !!root.devicesState.data && !root.devicesFresh; text: "设备数据已过期或暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        }
        Rectangle { width: parent.width; height: 1; color: root.faint }
        Column {
          width: parent.width
          spacing: Style.space(3)
          Text { text: "流量用量"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          DetailRow { label: "近 7 天"; value: root.trafficData.days7 !== undefined ? root.fmtBytes(root.trafficData.days7) : "—" }
          DetailRow { label: "近 30 天"; value: root.trafficData.days30 !== undefined ? root.fmtBytes(root.trafficData.days30) : "—" }
          DetailRow { label: "本月已用"; value: root.trafficData.used !== undefined && root.trafficData.used !== null ? root.fmtBytes(root.trafficData.used) : "—" }
          DetailRow { label: "月度限额"; value: root.trafficData.limit !== undefined && root.trafficData.limit !== null ? root.fmtBytes(root.trafficData.limit) : "未设置"; alert: !!root.trafficData.warning }
          Rectangle {
            visible: root.trafficData.limit > 0
            width: parent.width; height: Style.space(2); color: root.faint
            Rectangle {
              width: parent.width * Math.min(1, Math.max(0, Number(root.trafficData.used || 0) / Number(root.trafficData.limit || 1)))
              height: parent.height; color: root.trafficData.warning ? root.urgent : root.fg
            }
          }
          Text { visible: !root.trafficState.data; text: root.trafficState.status === "no-data" ? "暂无流量数据" : "流量数据暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          Text { visible: !!root.trafficState.data && !root.trafficFresh; text: "流量数据已过期或暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        }
        Rectangle { width: parent.width; height: 1; color: root.faint }
        Column {
          width: parent.width
          spacing: Style.space(3)
          Text { text: "DHCP"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          DetailRow { label: "状态"; value: root.dhcpState.data ? (root.dhcpState.data.enabled ? "已启用" : "未启用") : "—" }
          DetailRow { label: "活跃租约"; value: root.dhcpState.data ? String(root.dhcpState.data.active) : "—" }
          DetailRow { label: "地址池占用（估）"; value: root.dhcpState.data ? Math.round(Number(root.dhcpState.data.utilization || 0) * 100) + "%" : "—" }
          Text { visible: !root.dhcpState.data; text: root.dhcpState.status === "no-data" ? "暂无 DHCP 数据" : "DHCP 数据暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          Text { visible: !!root.dhcpState.data && !root.dhcpFresh; text: "DHCP 数据已过期或暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        }
        Rectangle { width: parent.width; height: 1; color: root.faint }
        Column {
          width: parent.width
          spacing: Style.space(3)
          Text { text: "版本健康"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          DetailRow { label: "组件总数"; value: root.updatesState.data && root.updatesState.data.total !== undefined ? String(root.updatesState.data.total) : "—" }
          DetailRow { label: "待更新"; value: root.updatesState.data && root.updatesState.data.pending !== undefined ? String(root.updatesState.data.pending) : "—" }
          Repeater { model: root.updatesState.data && root.updatesState.data.pendingNames ? root.updatesState.data.pendingNames : []; delegate: DetailRow { label: "待更新"; value: modelData } }
          DetailRow { label: "当前固件"; value: root.updatesState.data && root.updatesState.data.firmwareCurrent ? root.updatesState.data.firmwareCurrent : "—" }
          DetailRow { label: "固件更新"; value: root.updatesState.data && root.updatesState.data.firmwareUpdate !== undefined ? (root.updatesState.data.firmwareUpdate ? (root.updatesState.data.firmwareAvailable || "有更新") : "最新") : "—"; alert: !!(root.updatesState.data && root.updatesState.data.firmwareUpdate) }
          Text { visible: !root.updatesState.data; text: root.updatesState.status === "no-data" ? "暂无版本数据" : "版本数据暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          Text { visible: !!root.updatesState.data && !root.updatesFresh; text: "版本数据已过期或暂不可用"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
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
    function state(): string { return JSON.stringify({wan: root.wanState, devices: root.devicesState, traffic: root.trafficState, dhcp: root.dhcpState, updates: root.updatesState, display: root.display, demo: root.demoMode}) }
  }
}
