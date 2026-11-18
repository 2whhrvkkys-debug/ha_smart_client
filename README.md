# Smart Home — SmartThings 风格的 Home Assistant 客户端

一个生产级结构的 Flutter 手机客户端（iOS + Android），直接对接 Home Assistant 的 **REST + WebSocket API**，
把 HA 中「有用的实体」以 **家 → 楼层 → 房间 → 设备 → 实体卡片** 的方式组织展示。

> 不依赖官方 HA App，不使用任何私有协议；实体控制走标准 `POST /api/services/<domain>/<service>`。

---

## 1. 功能概览

| 能力 | 实现 |
|---|---|
| 登录 | URL + Long-Lived Token，凭证存于 Keychain / EncryptedSharedPreferences |
| 全量实体 | `GET /api/states` + 四类 registry（entity/device/area/floor） |
| 实时状态 | WebSocket `auth` → `subscribe_events(state_changed)`，指数退避重连 + 心跳 |
| 可控域 | light / switch / cover / climate / lock / media_player / scene / script / button / automation |
| 只读域 | sensor / binary_sensor / person / device_tracker 等，不提供控制入口 |
| 组织方式 | 楼层 → 房间 → 设备 → 实体卡片；诊断实体聚合到设备详情 |
| 过滤规则 | 隐藏 `hidden_by` / `disabled_by` / 用户隐藏；保留离线实体（需可见告警） |
| UI | Material 3、自适应 iOS 转场、深色模式、圆角卡片、mdi 图标 |
| 交互 | 下拉刷新、实时状态动画、收藏、搜索、隐藏管理、连接横幅、空状态 |

---

## 2. 快速开始

### 2.1 补齐平台脚手架

本仓库包含完整的 Dart 代码与配置，但不含 Flutter 自动生成的 `android/` `ios/` 原生目录。
在项目根目录执行（不会覆盖已有的 `lib/` 与 `pubspec.yaml` 依赖）：

```bash
cd ha_smart_client
flutter create --org com.example --project-name ha_smart_client .
flutter pub get
flutter run
```

> 若 `flutter create` 重写了 `pubspec.yaml`，请把 `dependencies` 段恢复为仓库中的版本。

### 2.2 准备 HA 凭证

1. 打开 Home Assistant 网页版 → 左下角 **个人资料**
2. 滚动到 **安全** → **Long-Lived Access Tokens**
3. 点击 **创建令牌** 并复制（只显示一次）
4. 远程访问建议使用 HTTPS 与反向代理；局域网可填 `http://192.168.x.x:8123`

App 会自动补全 `https://` 前缀并去掉末尾 `/api`。

---

## 3. 目录结构与分层

```
lib/
├── main.dart                     # 入口：初始化、恢复会话、注入 HaProvider
├── app/                          # MaterialApp、主题、路由分发
├── core/
│   ├── ha_api/                   # 通信层
│   │   ├── ha_auth.dart          # URL 规范化 + /api/config 凭证校验
│   │   ├── ha_rest_client.dart   # states / config / services 调用
│   │   ├── ha_ws_client.dart     # auth、事件订阅、命令请求、重连、心跳
│   │   └── ha_registry.dart      # 四张注册表拉取（WS 命令）
│   ├── storage/                  # 安全存储（凭证、主题、收藏、隐藏项）
│   ├── models/                   # HaArea / HaFloor / HaDevice / HaEntity / HaControlCapability
│   ├── grouping/                 # 实体聚合算法（纯函数）
│   ├── errors/                   # 统一异常类型
│   └── utils/                    # 状态格式化、mdi 图标映射
├── state/ha_provider.dart        # 全局单一数据源 + 所有控制入口
├── features/                     # 登录 / 首页 / 设备 / 房间 / 场景 / 设置 / 外壳
└── widgets/
    ├── cards/                    # 各 domain 卡片 + 自动分发工厂 + 统一外壳
    └── common/                   # 连接横幅、空状态、分区标题、设备详情面板
```

**依赖方向**：`features/ + widgets/` → `state/` → `core/`，core 内部不反向依赖 UI。

---

## 4. 核心机制

### 4.1 聚合算法（`entity_aggregator.dart`）

纯函数 `aggregate(states, registry, userHiddenIds)`，输出 `AggregatedHome`：

1. 建立 entity / device / area / floor 四张索引；
2. 每个 state 与 registry 合并 → 过滤 hidden/disabled → 判定区域归属
   （实体 `area_id` > 设备 `area_id` > 虚拟「未分配区域」）；
3. 诊断类实体（`entity_category=diagnostic`、last_seen、linkquality…）单独收集，
   按 `device_id` 聚合到设备详情，不进入主网格；
4. 只保留拥有可见实体的设备；按楼层 `level` 排序生成 `HaFloor` 列表；
5. 离线或告警类实体进入 `problemEntities` 供首页提醒。

### 4.2 实时刷新

- WS 收到 `state_changed` → `HaProvider._onEntityUpdated` 
  → 用 `copyWithState` **保留 registry 元数据**（WS 的 `new_state` 不含这些信息）
  → 80ms 合并后一次性重聚合并通知 UI。
- 每次 WS 重连成功后自动刷新注册表，新增设备/区域无需重启 App。

### 4.3 控制流

卡片只调用 `HaProvider` 的语义化方法（如 `setBrightness`、`openCover`、`setClimateTemperature`），
由 Provider 统一转成 `callService`。成功响应中的 state 会合并回缓存，
失败通过 `runHaAction` 显示 SnackBar，并记录 `lastError` 供顶部横幅展示。

---

## 5. 扩展指南

### 新增一个可控 domain

1. `core/models/ha_entity.dart` 的 `capability` getter 增加分支，返回对应 `HaControlType`；
2. 在 `widgets/cards/` 新增卡片，继承 `EntityCardShell` 的布局约定；
3. `widgets/cards/entity_card.dart` 工厂中增加分发；
4. `HaProvider` 中增加对应 service 方法（若现有方法不适用）；
5. `ha_icons.dart` 增加图标映射。

无需修改页面代码：Devices / Rooms / Home 均通过工厂渲染。

### 新增快捷指令 / 场景分组

`ScenesPage` 已按 `domain` 分组，可直接新增筛选条件；
路由集中在 `app/router.dart`，新增页面只需在此注册。

---

## 6. 已做的生产级处理

- 认证失败（401/403）自动清除凭证并回到登录页；网络失败保留缓存并显示重连横幅；
- WS 指数退避重连（1→32 秒）+ 30 秒心跳 + 未决命令超时；
- 认证失败为致命错误，不进入重连循环；
- 注册表旧版本兼容（无 floor_registry、旧版 `hidden` 布尔字段）；
- `Selector` 精确订阅，实时刷新不会重建 `MaterialApp` 整棵树；
- 所有列表使用 `unmodifiable` 包装，避免 UI 误改缓存；
- 依赖保持轻量：仅 http / web_socket_channel / secure_storage / provider / mdi / collection。

---

## 7. MVP 之外的可选演进

- 设备详情页独立路由（当前为底部面板）；
- 本地通知与自动化触发记录；
- 图表化历史数据（需接 HA Recorder / history API）；
- 平板 / 折叠屏分栏导航；
- 单元测试：聚合算法与 capability 推导是纯函数，最易覆盖。
