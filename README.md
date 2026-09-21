# local.pgybox — 蒲公英 WAN 速率（Omarchy bar widget）

用户级、只读的 Omarchy 顶栏插件。watcher 观察浏览器中已打开的 PgyBox 云管理页；失败不会覆盖最后一次成功快照。

## 状态语义

- 新鲜成功（10 秒内）：`正常`，显示 WAN ↑/↓。
- 已有成功但超过 10 秒：`数据已过期`，保留最后成功数据但不显示为新鲜速率。
- 从未成功，或最近一次获取失败：`状态暂不可用`。

单次失败只记录为最近错误；QML 保留 `lastGoodSnap`，不会把错误快照当作远端不可用或本地离线。图标、工具提示和面板不作离线断言。

## 交互

- 左键：打开明细面板。
- 中键：立即重启 watcher，等待下一次页面轮询响应。
- 右键：用已认证的 `ma-browser` 打开蒲公英云管理页。
- 面板按 `r`：刷新；`Enter`：打开云管理页；`Esc`：关闭。
- 展开时左键速率文字折叠为 Oray 图标；折叠后左键图标打开明细。展开时左键图标也打开明细面板。
- 速率单位为字节每秒：`B/s`、`KB/s`、`MB/s`、`GB/s`。

云页面约每 5 秒产生一次流量响应；watcher 成功退出后由 QML 每 1 秒重试，正常情况下约 5–6 秒更新一次，10 秒内视为新鲜，不声称超过云页面源频率。`wan_up`/`wan_down` 为 0 仍是在线状态。

## watcher 契约

watcher 通过 CDP `Network`：

1. 选择已打开的 `pgybox.com` 页面；
2. `Network.enable` 后只观察该页面下一次 **GET** `/api/flowrate_wan_get`；
3. 仅对 HTTP 200 响应调用 `Network.getResponseBody`；
4. 仅当 JSON `code == 0` 且 `wan_up`、`wan_down` 为有限数值时成功。

成功只输出一行：

```json
{"ok":true,"reachable":true,"up":0,"down":0,"ts":0}
```

其中 `ts` 是本地收到响应正文的时间。缺页、超时、非 200、非零 `code`、无效正文或 CDP 错误只输出 `{"error":"..."}`。

认证由浏览器自动发送；插件绝不提取、输出、保存或重放 Bearer、`X-Auth-Verification`，也不调用 `Network.getAllCookies`。不会导航页面、发起云端直连请求或主动触发页面请求。

顶栏图标使用蒲公英控制台官方资产 `assets/oray.png`（276×60），通过 `sourceClipRect` 只裁剪左侧 60×60 的粉色贝锐 Oray 圆形标记，再用 `MultiEffect` 默认着色为 `root.fg`，非 fresh 时使用 `root.dim`；不显示带中文文字的全宽 Logo。Oray/蒲公英为其各自权利人的商标。

面板仍兼容未来可靠快照中的网络/设备名、SN、WAN IP、LAN IP、智能组网字段；首版 watcher 不请求这些详情端点。

## 自检

```sh
python3 bin/pgybox-watch --selfcheck
python3 -m py_compile bin/pgybox-watch
omarchy plugin validate ~/.config/omarchy/plugins/local.pgybox
```
