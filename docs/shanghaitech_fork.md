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
| **新增文件** | 6 个 dart + 本文件 | 「学术活动 / 听报告登记」模块（见 3.7） |
| **修改文件** | 13 个 | 认证层、三大功能数据源、本校规则、模块接线与清理（见 3.1–3.5、3.6 的接线表、3.7 的接线说明） |
| **删除文件** | **435 个** | 西电独有模块及其素材（见 3.6） |

> 核对方式：`git log`、`git diff <上游基线> --stat`（本仓库保留了上游历史）。

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

## 四、当前可用范围

**已适配并验证可用：**

- 统一认证登录（`ids.shanghaitech.edu.cn`）
- 我的课表（`wdkbappshtech`）
- 我的成绩（`wdcjapp`，含上科大 4.0 绩点换算）
- 我的考试（`wdksapp`）
- **学术活动 / 听报告登记**（`jzxxtjapp` · `tbgdj`，目前仅查看）
- 课程提醒与系统日历导出（依赖课表数据，不依赖学校系统）

**仍不可用**（连接西电专有系统，界面上仍会显示并报错）：

电费、校园卡、图书馆、校园网、物理实验 / 实验报告、空教室、考勤、体育。

> 其中**睿思论坛、XDU Planet、空调已从代码中删除**（见 3.6），界面上相应入口也不再存在；底部导航由 5 个标签变为 4 个。
> 物理实验 / 实验报告尚未删除：它与课表 UI 深度耦合（实验数据作为日程条目参与渲染），计划按"只删网络层、保留模型与界面"的方式单独处理。

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
