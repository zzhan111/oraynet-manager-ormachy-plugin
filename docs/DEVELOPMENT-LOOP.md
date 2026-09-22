# PgyBox Plugin 开发循环

本循环由两个 Herdr Codex agent 独立设计与审查后合并。每轮只交付一个纵向切片；默认顺序：设备摘要 → 流量用量 → DHCP 健康 → 版本健康 → 按需诊断。

## 0. 先清基础阻塞

新增业务字段前先修正：

1. watcher 与 opener 使用同一精确 hostname、同一 claimed tab，不能用宽泛的 `"pgybox.com" in url`。
2. `reachable` 不能表示“历史上成功过”；连接状态、区块新鲜度和最后成功数据分离。
3. CDP 读取必须覆盖响应正文尚未完成与命令期间事件交错，不能静默丢事件。
4. 每个面板区块拥有独立数据、时间戳、错误和过期状态。
5. stderr、IPC、fixture 和错误文案不得输出 Token、Cookie、请求头或真实设备标识。

未满足以上条件，不开始设备摘要。

## 每轮循环

### 1. 选择一个纵向切片

写清：

- 用户能看到什么。
- 所需输入字段与单位。
- `ok / stale / no-page / unauthorized / error` 行为。
- 明确不做什么。

**门槛：**一个切片必须能从浏览器响应贯通到面板；不得顺手实现下一阶段。

### 2. 建立只读接口契约

使用已登录、已 claim 的 PgyBox tab，被动观察页面自然产生的响应。记录：

- 精确 origin、path、method。
- 成功、空数据、未授权、错误响应形状。
- 字段类型、单位、分页、刷新周期。
- 当前页面与设备版本。

禁止提取、重放或记录认证信息；禁止触发保存、重启、升级或配置请求。

**门槛：**目标响应能在需求刷新窗口内自然出现，字段语义无歧义。否则停止该切片。

### 3. 制作脱敏 fixture

只保留允许字段，并在写盘前替换：

- 设备名、MAC、IP、SN → 合成值。
- Cookie、Token、Authorization、daemon token → 完全删除。

最少包含：正常、零值、空列表、缺字段、类型错误、未授权、超时和 API 漂移。

**门槛：**fixture 保持字段关系和类型；人工检查与 secret-canary 扫描均无敏感信息。

### 4. 实现纯解析与离线回放

先写纯解析/归一化逻辑，再接 CDP：

- 严格校验类型、非负数和有限数值。
- 零速率是合法值。
- Top 3 排序必须确定且可复现。
- 某区块失败不能刷新或覆盖其他区块。
- 路由器身份变化时不得沿用上一台设备的数据。

**门槛：**fixture 回放得到预期快照；失败用例产生明确状态，而非仅“不崩溃”。

### 5. 接入 QML 区块

每个区块独立维护：

```text
data + lastSuccessTs + status + error
```

要求：

- 旧数据可保留，但必须明确标记 stale。
- 不把超时猜成未登录，也不把历史成功显示为当前在线。
- 长名称截断，设备标识掩码。
- 顶栏宽度和现有折叠/恢复交互不变。

**门槛：**正常、空、过期、错误、恢复五种状态均可用合成数据复现。

### 6. 运行最小检查集

```sh
python3 bin/pgybox-watch --selfcheck
python3 -m py_compile bin/pgybox-watch bin/pgybox-open
omarchy plugin validate .
git diff --check
git diff --stat
git diff
```

新增解析逻辑必须有一个无需真实账号即可运行的 fixture/selfcheck。

**停止条件：**检查失败、QML 日志出现未解释错误、出现敏感信息或无关文件改动。

### 7. 真实生命周期验收

在实际 Omarchy shell 与目标浏览器中验证：

- 前台/后台 tab。
- tab 关闭、导航、重开和 claim。
- 登录失效与重新登录。
- 浏览器断开与恢复。
- 零流量、无后续事件、刚好过期和恢复。
- 单区块失败、其他区块继续更新。
- 横向/纵向 bar、面板滚动、长名称。
- 左键折叠/恢复、中键刷新、右键复用页面、键盘操作。

保留脱敏的时间记录、命令摘要和合成数据截图，不保留 HAR 或原始 CDP dump。

**门槛：**无需重启 shell 即可恢复；插件未触发契约外路由器动作。

### 8. 提交并决定是否进入下一轮

提交前检查 staged diff：

- 仅包含本切片实现、脱敏 fixture、契约说明和检查证据。
- 所有验收项通过；未通过项写成明确 blocker。
- 不以“真实页面偶尔成功”替代离线回放，也不以 fixture 通过替代真实生命周期测试。

通过后提交一个可回滚 commit；再决定是否开始下一阶段。

## 首个循环

第一轮不是直接增加 Top 3，而是先完成“基础阻塞”并留下回归检查。第二轮再实现设备摘要：在线数、活跃数、Top 3 实时流量设备。

## 里程碑计分与 M1 证据

将“基础加固、设备摘要、流量用量、DHCP 健康、版本健康、按需诊断”视为 6 个等权里程碑：

```text
完成度 = 已完成里程碑数 / 6
50% = 3 / 6
```

本轮已完成 M1、M2、M3 的实现与离线检查，因此实现进度为 `3 / 6 = 50%`；真实生命周期验收仍未宣称通过。

M1 证据：

- `bin/pgybox-open` 与 `bin/pgybox-watch` 均按 `www.pgybox.com` 精确 hostname 选择页面；opener 先 claim 并写入完整 `tabId`，watcher 将其映射到 CDP full target id 后才观察该页面。
- watcher 等待 `Network.loadingFinished` 后读取正文，并缓存命令期间交错到达的事件；错误输出使用固定、无凭据的状态词。
- `Widget.qml` 将 WAN 区块拆为 `data + lastSuccessTs + status + error + reachable`，历史数据保留但 confirmed loss 会立即让图标变灰。
- stale 只保留旧数据作说明，速率文字隐藏且图标使用灰色；仅 fresh 状态使用白色在线视觉。
- `fixtures/pgybox-watch/flow-ok.json`、`flow-invalid.json` 与 `claim-tabs.json` 支持无账号离线回归；fixture 不含真实设备标识或认证字段。
- 离线检查命令：`python3 bin/pgybox-watch --selfcheck`、`python3 bin/pgybox-open --selfcheck`、`python3 -m py_compile bin/pgybox-watch bin/pgybox-open`、`git diff --check`。

真实浏览器生命周期、Omarchy shell 加载、tab 关闭/重开/claim、登录失效恢复和横纵向面板仍须 live validation；本轮不以离线检查替代该验收。

M2/M3 contract notes: device data is observed from `/en/deviceList` (`/api/lan_device_get` and `/api/flowrate_ip_get`); traffic data is observed from `/en/networkSettings/flowManage` (`/devices/-/cpe/flows` and `/api/flow_warn_get`). These remain passive GET observations only.

Collector evidence: WAN success cuts off immediately; device summaries require both device-list and IP-flow bodies; traffic emits field-preserving patches within a short settle window. Body and parser failures carry their section name, and offline replay covers route matching, dependency order, prompt cutoff, patch merging, isolated failures, empty data, invalid numeric values, and `enabled` normalization.

## 50% 验收记录

2026-09-22 完成 M1–M3，进度为 `3 / 6 = 50%`。

离线证据：

- `python3 bin/pgybox-watch --selfcheck`：通过。
- `python3 bin/pgybox-open --selfcheck`：通过。
- `python3 -m py_compile bin/pgybox-watch bin/pgybox-open`：通过。
- `omarchy plugin validate .`：通过。
- `git diff --check`：通过。
- 独立 reviewer 最终 code gate：PASS，无剩余代码正确性阻塞。

真实生命周期证据：

- opener 写入的 full `tabId` 与 CDP `/json` target id 一致，精确 host 为 `www.pgybox.com`。
- 首页 WAN 响应约 5 秒产出成功快照，满足 10 秒更新门槛。
- 登录过期页立即产出 `unauthorized`，重新登录后无需重启 shell 即恢复。
- 设备页约 9 秒合并真实设备列表与 IP 流速；QML 保留在线数、活跃数和确定排序的 Top 3。
- 流量页先合并 7 天和本月字段，再在选择 30 天后补入 30 天字段；设备区块未被覆盖。
- 关闭 claimed tab 后状态变为 `no-pgybox-page`；opener 重开、claim 并刷新后设备区块恢复。
- 实际 Omarchy shell 可加载、打开、刷新和关闭面板；修复空流量状态后无新的 PgyBox QML 错误。

## 剩余 50%

未完成里程碑：

1. M4 DHCP 健康：启用状态、活跃租约数、地址池利用率。
2. M5 版本健康：组件待更新数与固件更新提示。
3. M6 按需诊断：仅在用户明确触发后运行 ping/traceroute。

已知风险与限制：

- 被动观察不会主动请求数据；用户须访问或刷新设备页，7/30 天数据须分别选择对应页面选项。
- 页面 API 字段或 origin 漂移时，严格校验会保留旧数据并显示过期/错误，而不会猜测新格式。
- `limit_warning == 0` 按“未设置限额”处理；非零限额语义仍需在真实启用限额的账号上复核。
- 已验证当前实际 bar 布局；另一方向 bar 的视觉布局尚未做真实截图验收。
- 登录、设备名与流量值仅在本机内存/IPC 中使用；fixture 和仓库未保存真实标识或认证信息。

当前无阻塞 M1–M3 使用的问题；以上项目属于剩余范围或后续兼容性风险。
