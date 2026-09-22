# PgyBox 面板功能研究

## 第一轮：控制台首页

观察到：首页提供实时上下行速率、WAN/LAN IP、本地设备数、WiFi 状态与 SSID、智能组网成员数、4G 套餐状态、设备型号与 SN。

TypeSafe Jev 判断：

1. 实时速率最适合顶栏（概率 0.90），现已实现。
2. 本地设备数适合面板，价值评分 2.66/4。
3. WAN IP 适合面板，重要度 2.59/4。
4. 4G 套餐余量适合低余量告警。
5. WiFi 与智能组网状态适合作为次要详情。
6. 顶栏下一项在设备数与套餐余量之间并列（各 0.46），信心较低；暂不增加顶栏信息。
7. 保持插件只读，不加入重启、密码、升级、防火墙等写操作。

## 第二轮：其他页面

只读导航了 Local Device、Smart Network Member List、System Info、WiFi、Traffic、Network Detection 与 Log Center。

### 页面观察

- Local Device：设备名、连接类型、MAC、IP、实时上下行、累计流量、连接数和联网状态。
- Smart Network：网络名、总速率、成员 IP、连接类型与成员速率；当前成员表数据不稳定。
- WiFi：SSID、2.4G/访客网络、认证/加密、定时开关和限速；以配置项为主且涉及密钥。
- Traffic：7/30 天 APN 流量、月结日、已用流量、流量限额与提醒。
- Network Detection、Log Center、System Info：当前 DOM 未得到稳定且有价值的只读摘要。

### TypeSafe Jev 判断

| 候选 | 适配度（0–4） | 结论 |
|---|---:|---|
| 本地设备摘要/高流量设备 | 3.64 | 最优下一项；Choice 概率 0.84 |
| 7/30 天流量与月度限额 | 3.10 | 第二优先，适合用量进度与低余量告警 |
| 智能组网成员健康 | 1.10 | 数据稳定后再考虑 |
| WiFi 只读状态 | 1.03 | 信息价值有限，且页面主要是配置 |
| 日志摘要 | 1.12 | 当前证据不足，不实施 |
| 网络检测 | 0.08 | 不适合当前面板 |

Jev 对排除 WiFi 密钥、重启、升级、防火墙、限速编辑等配置操作给出 0.97 的赞同概率。

### 推荐顺序

1. 面板增加在线设备总数、活跃设备数和 Top 3 实时流量设备。
2. 增加 7/30 天累计流量、月度限额进度及低余量告警。
3. 暂不加入智能组网、WiFi、日志和网络检测；先解决数据稳定性与读取契约。

## 第三轮：网络基础设施页面

只读导航了 WAN、LAN、DHCP、QoS、Hosts、VPN Client、ARP、SNMP Server 和 Network Tool。

### 页面观察

- WAN：云端不开放设置，要求转到本地管理；没有稳定的远程状态摘要。
- LAN、QoS、Hosts、SNMP：以配置为主，当前没有值得面板展示的稳定摘要。
- DHCP：包含启用状态、地址池、租期、活跃设备和静态租约表。
- ARP：设备名、IP、MAC、接口与绑定类型；主要用于配置绑定。
- VPN：页面主要提示传统 VPN 会使智能组网失效。
- Network Tool：提供 ping、traceroute、route，需要目标地址并主动执行。

### TypeSafe Jev 判断

| 候选 | 适配度（0–4） | 结论 |
|---|---:|---|
| DHCP 健康摘要 | 3.51 | 本轮最佳；Choice 概率 0.64 |
| 按需 ping/traceroute | 2.61 | 可做诊断入口，但不属于持续监测 |
| VPN/智能组网兼容状态 | 1.66 | 低优先级提示 |
| ARP 冲突告警 | 1.60 | 仅在能稳定检测冲突时考虑 |
| WAN/LAN/QoS/Hosts/SNMP 配置 | 0.13 | 不适合面板 |

Jev 再次以 0.97 概率建议面板保持只读，不加入网络配置写操作。

### 推荐

1. 在设备摘要之后增加 DHCP 启用状态、活跃租约数和地址池利用率。
2. ping/traceroute 可作为后续“诊断”按钮，必须由用户主动触发并明确目标。
3. 暂不展示 WAN/LAN/QoS/Hosts/SNMP 配置；ARP 仅做冲突告警，不展示绑定管理。

## 第四轮：安全、维护与版本健康

只读导航了 Access List、Forwarding、P2P Port、Remote Assistance、System Upgrade、Component Upgrade、UPnP、Firewall、Internet ACL 和 APP Center。

### 页面观察

- Component Upgrade：稳定显示组件名、当前版本、是否可升级和状态；多数为最新，但观察到一个组件可立即升级。
- System Upgrade：有升级页面，但当前 DOM 未得到稳定版本与更新状态。
- Firewall：有功能、说明和操作表头，但当前未得到稳定状态行。
- Remote Assistance、UPnP、Access List、Forwarding、P2P Port：页面存在，但当前未得到稳定只读状态。
- Internet ACL、APP Center：主要是配置或安装管理。

### TypeSafe Jev 判断

| 候选 | 适配度（0–4） | 结论 |
|---|---:|---|
| 组件版本健康/待更新数 | 3.10 | 本轮最佳；Choice 概率 0.89 |
| 固件版本与更新告警 | 3.02 | 数据稳定后值得加入 |
| 防火墙/UPnP/远程协助安全摘要 | 1.43 | 证据稳定后再评估 |
| P2P/转发健康 | 0.44 | 不适合当前面板 |
| APP Center 清单 | 0.11 | 不适合面板 |

Jev 对“升级信息只做被动告警、不提供升级按钮”的赞同概率为 0.70。

### 推荐

1. 增加组件健康摘要：总组件数、待更新数、异常组件名。
2. 能稳定获取固件版本后，增加“有更新”告警；不提供一键升级。
3. 暂缓安全姿态摘要，直到能可靠读取防火墙、UPnP 与远程协助开关状态。
