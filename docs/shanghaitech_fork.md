# 上海科技大学适配分支说明（非官方）

> 本文件是本分支**新增**的说明文档，用于记录相对上游的全部修改，便于原作者与使用者核对。
> 依据：上游 `docs/faq.md` 中作者关于"将该软件适配到您学校"的说明，以及 MPL-2.0 §3.1/§3.2 的分发义务。

---

## 一、这是什么

- **上游项目**：[BenderBlog/traintime_pda](https://github.com/BenderBlog/traintime_pda)（XDYou / Traintime PDA，作者 **BenderBlog Rodriguez** 及贡献者）
- **本分支**：把该 App 的数据来源从**西安电子科技大学**换成**上海科技大学**的**个人自用**适配分支
- **基准版本**：上游 tag **`v1.6.6`**（`pubspec.yaml` 中 `version: 1.6.6+50`）
  - 已验证：上游 `v1.6.6` 标签与 `main` 分支在该时点内容完全一致
- **非官方声明**：本分支与上海科技大学官方**无任何关系**，不是学校发布的软件

## 二、授权

- 上游代码按 **Mozilla Public License 2.0** 授权（见 `LICENSE`）。部分文件另有 MIT / Apache-2.0 授权，标注在各文件头部的 `SPDX-License-Identifier`。
- **本分支对文件的修改，同样以 MPL-2.0 公开**（符合 MPL-2.0 §3.1/§3.2 对分发修改版的要求）。
- **未删除或修改任何留存文件原有的 `SPDX-License-Identifier` 许可头**（可逐文件核对）。
- 被删除的文件（见 3.6）连同其许可声明一并从本分支移除；如需上游原件请查阅上游仓库。
- 未使用上游 `assets/README.MD` 中标注"版权所有，作者保留一切权利"的素材来标识本分支的编译产物；本分支**不发布任何二进制版本**。
- 上游 `docs/xdyou_eula.md` 明确"仅对 iOS 或 Mac **签名**版本有效"且"从代码编译而**没有签名**的产物不受该协议约束"，故本分支（Windows 未签名构建）不涉及该 EULA。

## 三、改动清单（相对 `v1.6.6`）

| 类别 | 数量 | 内容 |
|---|---|---|
| **新增文件** | 13 个 dart + 本文件 | 「学术活动 / 听报告登记」模块（3.7）、上科大图书馆 Primo 实现（3.11）、校园卡模块（3.13） |
| **修改文件** | 41 个 | 认证层、三大功能数据源、本校规则、图书馆与校园卡接线、模块清理、主页卡片精简（见 3.1–3.13） |
| **删除文件** | **473 个** | 西电独有模块及其素材（3.6）、西电超星 / 图星图书馆模块（3.11） |
| **改名** | 1 个 | — |

> 核对方式：`git log`、`git diff <上游基线> --stat`（本仓库保留了上游历史）。
> 上表为 **`v1.6.6..HEAD`（`f9d2229e`）** 的实测值：`529 files changed, 3515 insertions(+), 14454 deletions(-)`。
> 另有 **11 个文件的安全加固尚未提交**（见 3.14，`+179 / −27`），**未计入**上表。

### 3.1 认证层（统一认证 / IDS）

| 文件 | 改动 |
|---|---|
| `lib/repository/ids_session/ids_session.dart` | ① 统一认证域名 `ids.xidian.edu.cn` → `ids.shanghaitech.edu.cn`；② **登录密码加密改用金智通用方案**（`network_client.dart` 的 `aesEncrypt`）——原实现是西电私有变体（固定 IV `xidianscriptsxdu` + 固定 64 字节前缀），对本校无效；③ `checkWhetherPostgraduate()` 的目标改为上科大研究生门户 |
| `lib/repository/ids_session/ids_auth_protocol.dart` | SSO origin 与 host 判断 |
| `lib/repository/ids_session/ids_reauth_client.dart` | 二次认证相关 URL 的 host |
| `lib/repository/ids_session/slider_captcha_client.dart` | ① host；② **滑块验证码几何参数**：`280×155 / 44×155` → `500×332 / 85×331`（本校实测） |
| `lib/repository/logger.dart` | 敏感 host 白名单（否则新校 SSO 的 ticket 会写入日志） |

### 3.2 登录后功能可用性的关键修复

| 文件 | 改动 |
|---|---|
| `lib/controller/homepage_controller.dart` | `_comboLogin()` 的 CAS `service` 由西电 ehall（`ehall.xidian.edu.cn`）改为上科大研究生门户地址。**原代码会导致**：拿不到 ticket → `loginState` 被置为 `fail` → 全局离线守卫拦截所有请求，表现为"课表/成绩/考试全部无法查看且不发出任何请求" |

### 3.3 三大功能（课表 / 成绩 / 考试）数据源

| 文件 | 改动 |
|---|---|
| `lib/repository/ids_session/semester_session.dart` | 学期信息接口 host；CAS target 改用本校已注册的门户地址 |
| `lib/repository/ids_session/classtable_session.dart` | 课表模块 `sys/wdkbapp/` → `sys/wdkbappshtech/`（本校定制模块名）；其余 host |
| `lib/repository/ids_session/score_session.dart` | 成绩接口 host |
| `lib/repository/ids_session/exam_session.dart` | 考试接口 host |

### 3.4 本校规则替换

| 文件 | 改动 |
|---|---|
| `lib/model/time_list.dart` | 作息表：西电 **11 节**（08:30–21:25）→ 上科大 **13 节**（08:15–09:00 … 20:45–21:30） |
| `lib/model/xidian_ids/score.dart` | 绩点换算：西电规则 → **上科大 4.0 等级制**（A+/A=4.0、A-=3.7、B+=3.3、B=3.0、B-=2.7、C+=2.3、C=2.0、C-=1.7、F=0），并新增 `isPassFailCourse` 识别通过制（P/NP） |
| `lib/page/score/score_state.dart` | 均分/GPA 统计排除通过制（P/NP）课程（落实"采用通过制的课程不计入 GPA"） |

### 3.5 其它

| 文件 | 改动 |
|---|---|
| `lib/model/xidian_ids/classtable.dart` | 移除多余的 `package:flutter/foundation.dart` 依赖（该文件仅用到 `listEquals`，已本地实现），使课表模型可在纯 Dart 下做离线解析测试。语义不变 |
| `lib/repository/notification/notification_service.dart` | 补上 `WindowsInitializationSettings`：上游在 Windows 上初始化通知会抛 `Windows settings must be set when targeting Windows platform` |
| `README.md` | 顶部新增"非官方分支"声明 |
| `docs/shanghaitech_fork.md` | 本文件（新增） |

### 3.6 删除西电独有模块（435 个文件）

以下模块连接西电专有系统或社区，在本校无对应物，故**整块删除**（而非隐藏）：

| 模块 | 删除内容 | 理由 |
|---|---|---|
| **睿思论坛** | `lib/external/ruisi_flutter/`（35 个 dart）+ `assets/ruisi_flutter/`（389 个素材，其中表情 386 个）+ `pubspec.yaml` 中 4 行素材声明 | 西电独有社区（`rs.xidian.edu.cn`）。顺带消除了该内嵌模块自身的许可矛盾（其 `LICENSE` 为 BSD-3-Clause，而 `README.md` 头部标注 MPL-2.0） |
| **XDU Planet** | `lib/page/xdu_planet/`（3 个文件）+ `lib/model/xdu_planet/`（2 个文件） | 西电博客聚合。上游代码中已是整块 `/* */` 注释的死代码，外部零引用 |
| **空调** | `aircon_session.dart`、`aircon_controller.dart`、`aircon_energy_card.dart`、`aircon_imei_dialog.dart`、`model/aircon_energy.dart`(+`.g.dart`) | 第三方空调平台；上游代码整块被注释，属死代码 |

随之清理的接线：

| 文件 | 改动 |
|---|---|
| `lib/page/homepage/home.dart` | 移除睿思标签：底部导航 **5 → 4** 个标签（主页 / 工具箱 / 猪图 / 设置），`index` 重排为 0–3，`PageView` 子项同步；顺带清掉 3 个变为未使用的导入与已死的 `changePage` 回调 |
| `lib/page/setting/groups/core_section.dart` | 移除睿思登出调用 + 未使用的 `get_it` 导入 |
| `lib/page/toolbox/toolbox_page.dart` | 移除「校园发现」（`nav.xdruisi.cn`）入口 |
| `lib/page/setting/groups/account_section.dart` | 移除空调 IMEI 的整段注释块 |
| `lib/page/energy/electricity_window.dart`、`lib/page/energy/energy_ready_view.dart` | 移除 `AirconEnergyCard` 的注释残留 |
| `lib/repository/preference.dart` | 移除 `airconImei` 枚举项 |
| `pubspec.yaml` | 移除 4 行睿思素材声明 |

### 3.7 新增「学术活动 / 听报告登记」模块（6 个文件）

本校研究生系统（金智 gsapp，应用 `jzxxtjapp`，菜单 `tbgdj`）提供「听报告登记」，上游无对应功能，故新增。结构照搬上游「考试安排」模块，**不引入新样式**：

| 文件 | 说明 |
|---|---|
| `lib/model/jzxxtj/activity_report.dart` | 数据模型与解析（纯 Dart、不依赖 Flutter、不使用代码生成，便于离线断言） |
| `lib/repository/ids_session/activity_session.dart` | `ActivitySession extends IDSSession`：统一认证 → CAS 重定向 → `POST …/jzxxtjapp/modules/tbgdj/tbgdj_lbcx.do` → `FetchResult` |
| `lib/controller/activity_controller.dart` | 与 `ExamController` 同构（signals + `AsyncState`） |
| `lib/page/activity/activity_window.dart` | 列表页面 |
| `lib/page/activity/activity_report_card.dart` | 单条记录卡片 |
| `lib/page/homepage/toolbox/activity_card.dart` | 首页入口小卡片 |

接线：`lib/routing/routes.dart`（新增 `Routes.activity`）、`lib/page/homepage/homepage_widget_registry.dart`（注册卡片并加入 `defaultAllOrder`）、`assets/flutter_i18n/{zh_CN,zh_TW,en_US}.yaml`（新增 `activity.*` 与 `homepage.toolbox.activity`）。

接口与字段依据本校系统的实测抓包；字段（`XNXQ` 学年学期 / `BGMC` 报告名称 / `BGSJ` 时间 / `BGDD` 地点 / `ZJR` 主讲人 / `SHZT` 审核状态 / `SFSYYY` 是否英语 / `FJ` 附件）取自系统的列元数据接口。

**当前仅实现只读查看**；新建 / 编辑 / 删除尚未实现。

### 3.8 移除物理实验 / 实验报告的西电网络依赖（24 个文件）

物理实验（原西电 PhyEws 实验报告系统）与「其他实验」（原西电实验室预约系统）在本校**均无对应系统**。
但实验数据是课表的**一等公民**——`ExperimentData` 作为日程条目参与课表渲染、系统日历导出、
课程提醒与 iOS/Android 小组件，直接整块删除会造成大量 UI 编译错误。

因此采用**「只删网络层、保留模型与界面」**的最小改动方案：把两个 session 降级为
「永远返回空 `FetchResult` 的本地空壳」，控制器在构造时直接进入空数据终态。
这样模型、信号、UI、课表渲染、系统日历、课程提醒、小组件**全部零改动**，
只是永远不会再被喂到实验数据，界面表现为正常的空态文案。

| 类别 | 内容 |
|---|---|
| **整删（24 个文件）** | `experiment_report_session.dart`；代码生成链 `lib/generated/score_hashes.g.dart` + `tool/generators/score_hashes_generator.dart` + `build.yaml` 中对应 builder；素材 `assets/experiment_score/**`（19 个）与 2 个 `captcha-solver-*.tflite` |
| **改为空实现（3 个）** | `image_recognition.dart`（只保留 `ExperimentData` 序列化所需的 `RecognitionResult`）、`physics_experiment_session.dart`、`sysj_session.dart` |
| **小改（2 个控制器）** | 构造时清历史缓存 + seed 空态；删除学期变更 effect（该 effect 会把 `_lastValid` 置 `null` 而不 reload，改空实现后会导致实验页**永久转圈**） |
| **未改动** | `model/xidian_ids/experiment.dart`(+`.g.dart`)、全部 `page/classtable/**` 与 `page/experiment/**`、`android/**`、`ios/**`、三语 i18n |

顺带修正：`deleteCache()` 现在同时清理 iOS App Group 中的历史缓存副本；
`assets/README.MD` 中 3 条已失效的资产授权条目同步移除。

> 说明：**移掉实验功能不等于全仓「零西电域名」**。电费/校园卡/图书馆/校园网/体育等模块仍保留
> 指向西电的代码路径，属尚未适配范围（见第四节）。本次验收口径是「**实验链路**零西电域名」。

### 3.9 移除「宿舍水机」模块（4 个文件）

宿舍水机（原接第三方直饮水平台 `i.ilife798.com`）在本校无对应服务，且其依赖的第三方平台
与学校系统无关，故**整块删除**。

| 类别 | 内容 |
|---|---|
| **整删（4 个文件 / 1 293 行）** | `lib/model/dorm_water.dart`、`lib/page/dorm_water/dorm_water_window.dart`、`lib/repository/miscellaneous_session/dorm_water_session.dart`、`lib/page/homepage/toolbox/dorm_water_card.dart`（`page/dorm_water/` 目录随之移除） |
| **摘除接线** | `homepage_widget_registry.dart`（`defaultAllOrder` 条目 + `HomepageWidgetEntry` 块 + import）、`routing/routes.dart`（import + `dormWater` 常量 + 路由分支）、`repository/preference.dart`（`dormWaterToken`/`dormWaterUid`/`dormWaterEid` 三个枚举项） |
| **同步 i18n** | 三语各移除 41 行：顶级 `dorm_water:` 块（40 行）+ `homepage.toolbox.dorm_water` 键 |

> 主页注册表条目由 12 项减为 **11 项**（后续第 3.12 节又精简为 **6 项**）。

### 3.10 工具箱新增「研究生系统」直达入口（`0a668924`，4 个文件）

| 文件 | 改动 |
|---|---|
| `lib/page/toolbox/toolbox_page.dart` | 新增一条外链入口：上科大研究生门户首页（`https://graduate.shanghaitech.edu.cn/gsapp/sys/yjsemaphome/portal/index.do`），交由系统浏览器打开 |
| `assets/flutter_i18n/{zh_CN,zh_TW,en_US}.yaml` | 新增对应标题与说明键 |

### 3.11 图书馆：改用上科大 Ex Libris Primo，删除西电超星 / 图星模块（`26d71ea6`，19 个文件）

上科大图书馆是 **Ex Libris（Alma / Primo + SFX）**，与上游所对的西电超星 / 图星协议
（`mfindxidian.libsp.cn`、馆代码 200755）**毫无关系**，故这一块是**重写**而非改造。

| 类别 | 内容 |
|---|---|
| **新增（4 个 dart）** | `model/shanghaitech/library.dart`、`repository/shanghaitech/library_primo_parser.dart`、`repository/shanghaitech/primo_library_session.dart`、`page/library/primo_search_window.dart` |
| **删除（11 个文件 / 1699 行）** | 西电图书馆 UI 层：`book_cover`、`book_detail_card`、`book_info_card`、`book_place_card`、`borrow_info_card`、`borrow_list_view`、`borrow_list_window`、`ebook_place_card`、`search_book_constant`、`search_book_window`、`search_fields`（**绝大多数是 UI 卡片**，而非会话层） |
| **接线 / 改造（4 个文件）** | `page/library/library_window.dart`（改为 Primo 检索界面）、`assets/flutter_i18n/{zh_CN,zh_TW,en_US}.yaml`。主页注册表与路由无需改动 —— `library` 条目与路由早已存在，只是换了数据源与界面 |

接口契约（实测，勿凭猜测改动）：

- 检索：`GET /primo_library/libweb/webservices/rest/primo-explore/v1/pnxs?…`，`institution=SHTECH`、`viewId=shtech`
- **鉴权：必须带 `Authorization: Bearer <访客 JWT>`**。JWT 取自
  `/rest/v1/guestJwt/SHTECH?isGuest=true&lang=zh_CN&viewId=shtech`，剩余寿命不足 5 分钟时提前刷新，401/403 重试一次
- 馆藏地与可借状态**不在独立接口**里，而是编码在记录的 `rtaResultsLink` 字段中
  （`$$1` 馆藏地 / `$$2` 索书号 / `$$S` 状态；含 `$$T` 的段是类型标记，须忽略）
- **`馆藏地` 不是服务端分面**（实际分面为 `library`、`rsrctype`、`language`、`topic`、`genre`、`toplevel` 等），
  故「按馆藏地筛选」只能在**已加载的页**内做客户端过滤 —— 已知局限，非缺陷

未适配：**借阅记录**（现有抓包为访客态，JWT 中 `userGroup: GUEST`），界面优雅降级为说明 + 打开图书馆网站。

> 服务端行为实测（2026-09-14，四个变体 + 阴性对照）：无认证头 / 仅 `X-Requested-With` / 仅 Cookie 一律 **403**，
> 裸 token（无 `Bearer` 前缀）返回 **500**，`Authorization: Bearer <jwt>` 返回 **200 且带真实结果**。
> 注意：该站对不存在的路径同样返回 403，故「无认证 = 403」本身不构成鉴权证据，真正的证据是裸 token 500 与 Bearer 200 的对比。

### 3.12 主页卡片精简为 6 项（`080c04b7`，1 个文件）

| 文件 | 改动 |
|---|---|
| `lib/page/homepage/homepage_widget_registry.dart` | 注册表与 `defaultAllOrder` 由 11 项精简为 **6 项**：`library`、`schoolcard`、`score`、`exam`、`activity`、`empty_classroom`；`getOrderedEntries()` 以注册表 `containsKey` 过滤，老用户的历史顺序不会复活已移除条目 |

> 被移除条目的**代码全部保留**（按用户指示：发布前统一清理），只是入口不再存在。
> 注意：`energy`（西电电费）虽已移出入口，其调用当时仍留在首页刷新路径上 —— 见 3.14 第 11 项。

### 3.13 校园卡：上科大新开普服务大厅（`f9d2229e`，11 个文件）

上科大校园卡由**新开普（NewCapec）**提供（**不是**金智），入口 `card.shanghaitech.edu.cn/servicehall`。

| 类别 | 内容 |
|---|---|
| **新增（4 个 dart）** | `model/shanghaitech/card.dart`、`repository/shanghaitech/card_parser.dart`、`repository/shanghaitech/card_session.dart`、`controller/card_controller.dart` |
| **改造（7 个文件）** | `page/schoolcard/school_card_window.dart`、`page/schoolcard/qr_code_view.dart`、`controller/school_card_controller.dart`、`repository/logger.dart`、三语 i18n |

关键实现（均已实测确认）：

- **加密**：业务响应形如 `{"data":"<base64 密文>"}`，而 **`data` 的前 16 个字符（UTF-8）就是 AES 密钥**，
  其余是密文；算法为 **AES-128-ECB + Pkcs7**。依据是本校前端源码：
  `my-encryption.js` 中 `CryptoJS.AES.decrypt(ciphertext, CryptoJS.enc.Utf8.parse(key), {mode: ECB, padding: Pkcs7})`，
  以及 `dkywwachat.js` 里唯一的一处调用 `aesUtil.decrypt(data.substr(16), data.substr(0, 16))`
- **会话**：校园卡没有自己的账号，必须经统一认证进入；业务接口以**查询参数 `openid`**（入口页隐藏字段）作会话凭据
- **金额单位是「分」**：接口返回 `balance: 850` 对应界面 **8.5 元**，故模型字段一律带 `Cents` 后缀，
  并提供 `balanceYuan` / `amountText` 换算 getter，让「误当元」在命名层面就刺眼
- 未适配：**支付码**（`qrcodeinfo` 不是二维码图片，真正的 `/servicehall/virtualcard/openQrcodeQuotaModify` 未抓到），已优雅降级
- 西电校园卡 `repository/ids_session/school_card_session.dart` 至此成为**孤儿文件**，待发布前清理

**同期加固日志脱敏**（同一提交）：`logger.dart` 的敏感 host 增为 2 个（+ `card.shanghaitech.edu.cn`）、
敏感查询键 + `openid`（等价密码）、敏感头 + `referer` / `referrer`（其值里带 openid）；
四个模型类覆写 `toString()` —— **`CardEnvelope` 最关键**，否则整份解密响应会被打进可导出的日志。

### 3.14 独立安全审查后的加固（**尚未提交**，11 个文件 `+179 / −27`）

由一个**独立审查会话**（无开发上下文，只读源码 + 读依赖包源码 + 独立复算）出具审查报告后，
对其中**已确证**的缺陷直接落修，**不改动功能与界面**：

| # | 文件 | 修的是什么 |
|---|---|---|
| 1 | `lib/repository/logger.dart` | 敏感 host 由 2 个扩到 **14 个**；补 `jwtopacauth` / `jwt` / `token` / `x-csrf-token` 头名；**关闭响应头打印**（`talker_dio_logger 5.1.20` 只对**请求**头脱敏，响应头是直接照抄的，`set-cookie` 会整条入库） |
| 2 | `lib/repository/ids_session/ids_session.dart` | 新增公开脱敏入口 `redactLocationForLog()`（原 `_redirectLogUri` 改为静态并被复用） |
| 3 | `lib/repository/ids_session/semester_session.dart` | 打印 CAS 跳转地址改走脱敏入口（**原实现裸打 `$location`，其中含一次性 `ticket`**） |
| 4 | `lib/repository/ids_session/classtable_session.dart` | 同上；并把「整份响应 Map」的日志降级为行数 |
| 5 | `lib/repository/ids_session/activity_session.dart` | 异常消息不再携带响应体前 160 字符（该异常会进日志、进界面、并进「错误页邮件」） |
| 6 | `lib/repository/ids_session/energy_session.dart` | 请求体日志（含 `UserID` = 学号、OAuth `code`）降级为方法 + URL |
| 7 | `lib/repository/ids_session/slider_captcha_client.dart` | 滑块验证码 payload 与原始响应体不再进日志 |
| 8 | `lib/repository/shanghaitech/card_parser.dart` | `jsonDecode` 失败不再抛出携带源片段 / 明文片段的 `FormatException` |
| 9 | `lib/repository/shanghaitech/primo_library_session.dart` | 同上（403 时返回的 Primo HTML 错误页不再随异常外流） |
| 10 | `lib/repository/shanghaitech/card_session.dart` | 一次性 ticket 用后即弃；**把 3xx 判定为会话失效**；并发初始化合并（不再同时解两次滑块）；解析失败包装为 `CardSessionException` |
| 11 | `lib/controller/homepage_controller.dart` | 首页刷新不再调用已下线、且指向西电电控的 `EnergyController.refreshElectricityInfo` |

> 验证：类型检查全量 **252 文件 0 error 0 warning**（带**阳性对照**，确认工具不是假绿）；
> 一卡通 80/80、图书馆 60/60、学术活动 44/44、课表 43/43 等离线断言脚本全绿。
> **这 11 个文件尚未提交** —— 按本项目约定，提交前需用户逐次批准。

## 四、当前可用范围

**已适配并验证可用：**

- 统一认证登录（`ids.shanghaitech.edu.cn`）
- 我的课表（`wdkbappshtech`）
- 我的成绩（`wdcjapp`，含上科大 4.0 绩点换算）
- 我的考试（`wdksapp`）
- **学术活动 / 听报告登记**（`jzxxtjapp` · `tbgdj`，目前仅查看）
- **图书馆检索（Ex Libris Primo）**：检索 + 馆藏地 / 可借状态（**访客态**，借阅记录未适配，见 3.11）
- **校园卡（新开普服务大厅）**：余额 + 交易流水（支付码未适配，见 3.13）
- 课程提醒与系统日历导出（依赖课表数据，不依赖学校系统）

**仍不可用：**

- **电费、空教室、校园网、考勤、体育**：数据源均为西电专有系统，本校无对应物。
  **实测结论（2026-09-14）**：本校统一认证对发往西电 / 超星的 `service` **一律返回「应用未注册」页面并拒绝签发 ticket**
  （对照组为本校研究生门户，正常放行），故这些功能**无法通过本校 SSO 打通** —— 属「无对应系统」，而非「待适配」。
  其中 `empty_classroom` 卡片**目前仍在主页注册表内**（见 3.12），点击必然失败。
- **图书馆借阅记录**：现有抓包为访客态（JWT 中 `userGroup: GUEST`），界面上优雅降级为说明 + 打开图书馆网站。
- **校园卡支付码**：接口与数据均未抓到，优雅降级为「打开校园卡网页」。

> ⚠️ **另一处已知限制**：登录流程按 `checkWhetherPostgraduate()` 分流，**非研究生会走 `getSemesterInfoEhall()`
> （西电 ehall，已被本校统一认证拒绝）**，因此**本科路径在当前实现下必然失败**，研究生路径正常。
> 将来若需支持本科生，须把这条分支改为本校自己的接口。

> 其中**睿思论坛、XDU Planet、空调已从代码中删除**（见 3.6），界面上相应入口也不再存在；底部导航由 5 个标签变为 4 个。
> **宿舍水机已整块删除**（见 3.9），主页不再有该入口。
> **物理实验 / 实验报告的西电网络依赖已移除**（见 3.8）：界面保留，但不再请求西电系统，表现为空态；
> 课表空态文案相应地从 `with_experiment` 回退到 `with_exam` / `no_course`（属预期变化）。

## 五、构建说明

- Flutter：**stable 3.47.x**（本分支实测 3.47.4 / Dart 3.13.3）
- **Windows 桌面**额外需要：
  - Visual Studio（**不是** VS Code）的「使用 C++ 的桌面开发」工作负载，含 Windows SDK 与 C++ CMake 工具；
  - **C++ ATL** 组件（`flutter_local_notifications_windows` 需要 `atlbase.h`）；
  - 系统「开发人员模式」已开启（插件符号链接需要）。
- 常用命令：`flutter pub get` → `flutter analyze` → `flutter run -d windows`

## 六、致谢

- 上游作者 **BenderBlog Rodriguez** 及全部贡献者（名单见 `lib/page/setting/about_page/about_page.dart` 的 `getDevelopers`）。
- 本分支的适配工作基于上游代码完成，未改变上游的授权方式。

> 如原作者对本分支的任何改动有异议，请通过 Issue 联系，我会立即调整或撤下。
