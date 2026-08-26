# G0/P1 阶段记录：视觉验收与 UI 冻结

阶段 ID：G0/P1  
阶段名称：买家端本地视觉原型与 UI 冻结  
当前状态：已通过并冻结  
当前证据级别：本地交互  
记录日期：2026-08-25（Europe/Rome）  
记录性质：本地原型事实记录，不是生产验收、后台授权或后端完成声明。

## 1. 元数据

- Owner：Rebuy Owner（2026-08-25 23:06:57 CEST 原话 `分类目录IA通过，G0重新冻结，未覆盖项进入后续专项，恢复G1授权`）
- 执行代理/负责人：本地视觉原型执行代理；本批记录由 `luna_worker` 整理
- 审查者：主代理/Owner（分类目录 IA 实时浏览器复验完成；Owner 已通过并冻结本批）
- 起始时间：N/A
- 结束时间：2026-08-25 23:06:57 CEST（Owner 决定记录）
- 记录版本：v1（2026-08-25）
- commit 或提交引用：`N/A`（当前工作区无可用提交引用）
- deploy/environment ref：`N/A`
- 环境：本地 `prototype/`、合成数据、`http://127.0.0.1:3000` 本地预览；不是 Staging/生产

## 2. 目标、范围与排除

### 目标

在已有本地买家端原型上记录可复核的 G0/P1 事实：已批准的统一 UI 方向与配色 D「循环翡翠青」已同步；本批落实 Owner 新的分类目录信息架构要求并完成主代理本地浏览器复验；Owner 已于 2026-08-25 23:06:57 CEST 决定 G0/P1 通过并冻结，未覆盖项转入后续专项。

### 范围

- 买家首页、分类/搜索、普通商品详情、二手商品详情、购物车/结算、订单、我的和登录演示。
- 五项买家导航、搜索/筛选、零售/批发身份样本的自动价格展示、多商家购物车/订单分组、普通/二手商品差异、zh/it/en、浅色/深色和响应式布局。
- 配色 D 的浅/深色 token、受控循环翡翠青渐变和既有 `BrandMark` 视觉同步。
- 本地验证证据：typecheck、lint、build、HTTP 200、指定视口的交互/视觉检查。

### 排除与停止边界

- 不实现 MerchantShell/商家后台；未来后台只是 [13 映射](../13-买家端与商家后台页面及组件映射.md) 中的设计规划。
- 不连接真实登录、Supabase、数据库、RLS、Storage、支付、物流、税务、微信接口、外部 API 或生产环境。
- 不产生真实订单、库存写入、客户记录、商家记录或任何生产数据。
- 所有商品、商家、订单、地址和身份均为虚构合成数据；不记录密码、token、客户 PII、原始敏感附件或生产凭据。

## 3. 依赖与前置

| 依赖/前置 | 当前证据 | 结果 |
|---|---|---|
| 00 范围与 01/02 买家端规范/线框 | 文档基线 | 已满足，仍受 Owner 后续决定约束 |
| 06 本地原型执行合同 | 合同已更新为已有本地原型证据、待 Owner 全流程验收 | 已满足 |
| 12/13 统一 UI 与页面/组件映射 | Owner 已批准并选定 D，已同步 P1 | 已满足设计输入；不等于代码/后台授权 |
| 本地 prototype 可运行 | typecheck/lint/build、HTTP 200 证据 | 已有本地证据 |
| Owner 全流程视觉验收/UI 冻结 | 20:14:15 CEST 曾有“通过并冻结”记录；随后提出分类页修订 | 当前冻结重新打开，执行修订并等待新的通过/冻结决定 |

## 4. 决策与假设

| 日期 | 决策/事实 | 影响 |
|---|---|---|
| 2026-08-25 | Owner 选择配色 D「循环翡翠青」并批准同步到既有 P1 原型 | 当前 prototype 使用 D token；不改变布局、业务范围或后台授权 |
| 2026-08-25 | 买家五项导航、多商家按商家分组、批发身份自动定价、二手关键事实和三语保持不变 | G0 验收必须逐项检查；不能改成手动批发模式或隐藏二手事实 |
| 2026-08-25 | 本地证据只能证明本地视觉/交互状态 | 不得写成独立测试、Staging、受控生产或生产验收 |
| 2026-08-25 | 最近配色 token 批次只改变品牌色/文档同步，不改变业务数据规则 | 桌面明/暗与 390 首页做定向复核；其他业务/布局证据注明复用前序边界 |

## 5. 批次与复用分类

| 分类 | 对象 | 事实 |
|---|---|---|
| 复用 | 既有 Buyer `AppShell`、`ProductCard`、`UsedFacts`、`PriceBlock`、`SellerGroup`、`StatusBanner`、`FilterSheet`、`QuantityStepper`、`SpriteImage` | 保持买家端结构和业务演示交互；本阶段不创建后台 Shell |
| 扩展 | `globals.css` 主题 token、浅/深色 D 配色、受控渐变、既有 `BrandMark` | 只同步视觉 token 和可访问性/状态表达，不改变业务规则 |
| 新建 | 本阶段记录与治理索引 | 只新增 Markdown 证据文件，不新增产品代码或外部服务 |

## 6. 文件、组件、路由与数据影响

| 影响域 | 记录 |
|---|---|
| 文档 | [01](../01-客户端苹果风格设计规范.md)、[06](../06-本地视觉原型执行合同.md)、[12](../12-Rebuy统一UI设计系统.md)、[13](../13-买家端与商家后台页面及组件映射.md) 提供基线；本记录补充 G0 事实 |
| Prototype 视觉 | 已有 `prototype/app/globals.css`、`prototype/components/BrandMark.tsx` 配色 D 同步证据；本记录不再修改代码 |
| 组件 | 复用/扩展上述 Buyer 组件；`MerchantShell` 仍未实现 |
| 路由 | 仅检查已有买家原型页面；本阶段不新增路由 |
| API/类型/schema | 无；本地原型无后端连接 |
| 数据 | 无持久化；仅合成商品、商家、订单、地址和身份样本 |

## 7. 安全、隐私与租户影响

- 认证/授权：本地身份样本只用于展示自动定价语义，不构成登录、组织、成员或服务端授权。
- PII：不使用真实客户/商家资料；文档和日志不记录密码、token、邮箱、电话、地址或原始附件。
- 租户：多商家分组是本地演示结构，不证明真实租户隔离、RLS 或跨组织负向测试。
- 外部服务/生产写入：无；不连接 Supabase、支付、物流、税务、微信、生产或外部 API。
- 结论：证据等级保持本地静态/本地交互；G0 不能替代 G1 工程底座、G2-A0/G2-A1 账号专项、P2 或生产专项审查。

## 8. 验证证据

| 验证命令/检查 | 环境/视口 | 结果 | 证据级别 |
|---|---|---|---|
| `pnpm typecheck` | `prototype/` 本地 | 已有通过记录；沿用前序有效证据 | 本地静态 |
| `pnpm lint` | `prototype/` 本地 | 已有通过记录；沿用前序有效证据 | 本地静态 |
| `pnpm build` | `prototype/` 本地 | 已有通过记录；沿用前序有效证据 | 本地静态 |
| HTTP 200 检查 | `http://127.0.0.1:3000` 本地 | 已有返回 200 记录；不是部署证明 | 本地交互 |
| 浏览器页面/交互检查 | 390、430、1440 等本地视口 | 前序已检查首页、关键页面/响应式证据；仍待 Owner 全流程复核 | 本地交互 |
| 配色 D 定向复核 | 桌面浅色、桌面深色、390 首页 | 最近配色 token 批次已完成定向检查；确认本地颜色层级与首页布局未出现明显阻塞 | 本地交互 |

### 8.1 证据复用边界

前序本地 typecheck/lint/build、HTTP 和 390/430/1440 等检查可覆盖未变化的原型结构和业务演示边界。最近配色 token 改动后只重新做了桌面明/暗与 390 首页定向检查，因此不能把复用证据扩大解释为所有视口、所有语言、所有订单/结算状态或 Owner 全流程视觉验收已经重新通过。

待 Owner 全流程验收至少需要重新确认：五项导航、分类/筛选、普通/二手详情、购物车/结算、订单/我的、登录、深色、zh/it/en、零售/批发样本、390/430/768/1024/1440 无溢出/遮挡，以及二手关键事实和多商家分组。

## 9. 回退与恢复

- 触发条件：Owner 发现品牌对比度、布局、语言、二手事实、导航、交互或响应式不符合批准方向。
- 最后可验证状态：配色 D 已同步的本地 P1 原型及其前序本地验证记录；不宣称冻结。
- 回退方式：只回退/修订本地视觉 token、组件样式或文档记录；保留合成数据，不触及后端或生产。
- 恢复后复验：针对改变的视口/模式/组件定向检查，并更新本记录追加条目和 15 台账。
- 历史和安全证据：保留旧验证摘要和纠正理由，不删除订单/审计（本阶段没有真实持久化）。

## 10. 风险与债务

| 风险/债务 | 严重度 | 当前控制 | 解除条件 |
|---|---|---|---|
| Owner 全流程视觉验收尚未完成 | 中 | 台账保持待 Owner 验收；不打开后续阶段 | Owner 明确冻结或修订决定 |
| 最近配色批次仅定向复核部分视口/页面 | 中 | 标明复用边界，不扩大证据等级 | Owner 完成全矩阵检查或批准补验范围 |
| 本地身份样本可能被误解为真实权限/批发模式 | 高 | 文档与原型保持自动定价/无后端边界 | G1、G2-A0、G2-A1、P2 通过独立授权证据 |
| Merchant Shell 仅有设计映射 | 高 | 13 与 14 明确未授权实现 | P6 Owner Gate 与权限专项审查 |

## 11. 维护与运维

- 服务器、依赖、数据库和部署：本阶段不管理；环境 ref 为 `N/A`，不把本地进程写成部署。
- 记录维护：状态变化先更新 [15 台账](../15-项目状态与阶段台账.md)，事实/纠正追加在本记录末尾。
- 证据保存：只保留命令结果摘要、视口和合成数据边界；不得保存真实敏感截图或未脱敏日志。
- 后续维护：Owner 冻结后，任何 UI 变化需新批次记录并重新判断是否影响 G0 Gate。

## 12. Owner Gate

- Gate：G0/P1 全流程视觉验收与 UI 冻结
- 已具备：既有本地原型、配色 D 同步、typecheck/lint/build/HTTP 和部分本地浏览器证据
- 当前决定：已通过并冻结（Owner 原话 `分类目录IA通过，G0重新冻结，未覆盖项进入后续专项，恢复G1授权`，2026-08-25 23:06:57 CEST）
- 历史决定：Owner 原话 `G0视觉通过并冻结，授权进入G1`；该历史记录不删除，但不再作为当前 G1 可执行授权。
- 当前修订原话：`整个项目当中不要出现类似这样的目录，我要的是移动端app的那种体验`；证据指向分类页 `REBUY / CATALOG`。
- 决策时间：历史决定为 2026-08-25 20:14:15 CEST；当前修订精确时刻未提供
- 决策记录：[15 台账](../15-项目状态与阶段台账.md)、[Owner 验收清单](./G0-P1-Owner视觉验收清单.md)
- 下一动作：进入 G1 Entry 准备；G1.1 先由 Owner 确认 Git 根选择，再建立本地 Node 22/pnpm 10.33.3 基线。直接 Enter 键盘提交未验证成功，已转入后续键盘/无障碍专项，不阻塞本次冻结或 Entry；G1 Exit Gate 前不打开 G2-A0。

## 13. 追加记录

### 2026-08-25｜初始事实记录

- 已确认既有买家端本地 Prototype 存在，配色 D「循环翡翠青」已同步。
- 前序 typecheck/lint/build、HTTP、390/430/1440 等本地检查作为本地证据保留；最近配色 token 批次已完成桌面浅/深与 390 首页定向检查。
- G0/P1 保持“待 Owner 验收”，本记录不宣称 UI 已冻结、不打开 G1、G2-A0、G2-A1 或 P2。

### 2026-08-25｜机器辅助全流程预验收

#### 元数据与证据边界

- 环境：通过 Browser skill 的 `node_repl js + browser-client` 连接现有本地 `http://127.0.0.1:3000/`；未启动、停止或修改服务器，未检查 cookies、localStorage、profile、密码或 session store。
- 本轮视口：`390×844`、`430×900`、`768×900`、`1024×900`、`1440×900`。页面均使用实际交互/DOM 状态检查，不以截图替代交互证据。
- 本轮只读预验收不等于 Owner 主观视觉验收、UI 冻结、独立测试、Staging 或生产验收；G0/P1 状态仍为“待 Owner 验收”。
- 页面数据、商家、订单、身份和登录输入均为本地合成演示；不记录密码、token、客户 PII、原始敏感附件或真实凭据。

#### 本轮实际覆盖矩阵

| 页面/流程 | 实际检查 | 结果与证据 |
|---|---|---|
| 首页 | 390、430、768、1024、1440；导航、商品流、响应式宽度 | 通过机器检查；各视口 `document.scrollWidth` 与 `body.scrollWidth` 均等于视口宽度。390/430 的两个普通商品同排，二手卡下一行占满可用宽度；1024/1440 显示买家侧栏，移动端显示五项底栏。 |
| 分类/搜索/筛选 | 390 搜索 `Nova`、打开筛选、清除条件并恢复结果；430/768/1024/1440 分类页宽度 | 通过实际交互；筛选 Sheet 打开、清除后恢复 4 个结果，再关闭；未见横向溢出或页面错误。 |
| 普通商品详情 | 390；Voltix 详情、数量从 1 增至 2、加入购物车 | 通过本地演示交互；数量调整和加入状态可见。未在每个宽度重做完整普通详情内容矩阵。 |
| 二手商品详情 | 390 完整内容；430/768/1024/1440 做页面路由与宽度复核 | 通过已观察内容：成色、已披露缺陷、电池健康、保修均在详情首屏；显示“二手设备固定 1 件”。二级详情页不显示底部五项导航。 |
| 购物车/结算 | 390 加入 Voltix×2、Nova×1、Aster×1；按商家分组并进入结算；430/768/1024/1440 宽度复核 | 通过本地演示；Northline Lab、Riva Devices、Blue Harbor Tech 三组独立显示，合计 `€378.70`；结算继续按三商家摘要，明确不触发支付、库存写入或外部通知。宽视口本轮只复核空购物车状态和宽度，未伪造已填充数据。 |
| 订单/商家子订单 | 390 订单列表、Northline Lab 子订单详情；1440 订单列表；430/768/1024 宽度复核 | 通过本地演示；`RB-DEMO-001` 含多商家子订单，状态时间线和商家小计可见。未点击“提交演示订单”，未创建真实订单。 |
| 我的/身份样本 | 390 完整检查；430/768/1024/1440 宽度复核；零售与已认证批发样本切换 | 通过演示语义检查；批发样本显示自动批发价、MOQ 和阶梯价，未出现手动批发模式；页面明确本地原型、不连接外部服务。 |
| 登录演示 | 390 表单、主题切换、合成邮箱进入 6 位 OTP 演示；1440 桌面分栏；无真实提交 | 通过本地演示；390 intro 为无边框/无阴影紧凑区，1440 intro 与表单分栏；状态明确“未发送邮件”。未覆盖 430/768/1024 登录矩阵，也未完成真实认证。 |

#### 主题、三语、无障碍与错误观察

- 在 390 的“我的”页面切换浅/深色：原型根节点浅色表面为 `rgb(244, 245, 250)`、surface 为 `#fff`；深色表面为 `rgb(15, 16, 32)`、surface 为 `#17182a`；切换后宽度仍为 390，无页面错误。登录页 390 也实际切换了浅/深色。
- 在 390 实际切换 `中文`、`Italiano`、`English`，界面标题、搜索、导航和身份长文案均更新，未发生横向溢出；同时观察到 `document.documentElement.lang` 在三种界面语言下仍返回 `zh-CN`，建议作为 Owner/后续可访问性与国际化修订项复核（中等严重度，不在本批次修复）。
- 本轮结束时浏览器错误/警告日志为 `[]`，未见 error overlay 或页面恢复失败。一次加入购物车过程中，自动化 locator 因 DOM 更新后数量变化失效；按 Browser skill 先重读页面状态后重新定位并完成交互，判定为检查脚本时序问题，不是页面错误。
- 所有已检查页面的 `scrollWidth`/`bodyScrollWidth` 均未超过对应视口；未观察到底栏覆盖、关键事实隐藏或明显文字裁切。Owner 仍需主观确认视觉层级、对比度、意大利语/英语极端长文案、动效与键盘焦点。

#### 未覆盖项与下一 Gate

- 本轮没有在每个视口重复每个流程的完整内容快照：普通详情完整内容主要在 390，结算填充态主要在 390，订单子订单详情主要在 390，登录主要在 390/1440；这些限制已明确记录，不能由宽度复核推导为全矩阵通过。
- 未运行源码命令、独立安全审查、E2E、Staging/生产检查，也未提交订单、认证、支付或外部服务请求；相关阶段仍由 G1、G2-A0、G2-A1 与后续 Owner Gate 管理。
- 下一动作仍是 Owner 全流程视觉验收与 UI 冻结/修订决定；未获明确决定前不打开 G1，不把本轮机器辅助结果写成 Owner 已通过。

### 2026-08-25｜HTML 语言标记修复与复验

#### 修复范围与分类

- 复用：现有 `Locale` 类型、AppShell 的 `lang` 属性、PrototypeApp 的 `locale` 状态和既有 `useEffect` 生命周期；不新增业务状态、存储或外部连接。
- 扩展：在 `prototype/lib/data.ts` 增加集中且纯的 `localeToHtmlLang` 映射函数，返回 `zh-CN`、`it`、`en`；AppShell 与根文档同步共用该映射，避免散落 ternary。
- 新建：无新组件、路由、API、schema 或数据；只增加根 `<html lang>` 的客户端同步 effect。

#### 实际文件与影响

- `prototype/lib/data.ts`：新增 Locale 到 HTML 语言值的集中映射。
- `prototype/components/AppShell.tsx`：复用映射函数设置内层 `.app-shell` 的 `lang`。
- `prototype/components/PrototypeApp.tsx`：随 `locale` 更新同步 `document.documentElement.lang`；不接 localStorage、cookie、外部服务，不改变主题、导航、业务规则或合成数据。
- `docs/stages/G0-P1-视觉验收与UI冻结.md`：追加本批次事实记录。
- RootLayout 的初始 `zh-CN` 保留作为 SSR 初值；本修复不改变 `prototype/app/layout.tsx`。

#### 验证

- `prototype/ pnpm typecheck`：通过。
- `prototype/ pnpm lint`：通过。
- 运行环境证据：实际 `node --version` 为 `v20.20.2`，而 `prototype/package.json` 的 engines 要求 `22.x`；`pnpm --version` 为 `10.33.3`，与项目声明一致。typecheck/lint 虽通过，但均出现 Node engine warning；这不能证明 Node 22 或 G1 工程底座已满足。
- Browser skill 复验：在 `http://127.0.0.1:3000/` 的 390px 视口依次切换中文、Italiano、English，确认 `document.documentElement.lang` 与 `.app-shell` `lang` 分别为 `zh-CN`、`it`、`en`；三语文案更新，无横向溢出，console/page error 无新增。随后恢复中文、浅色、首页和默认视口。
- 本批未运行 build：仅修改低风险语言映射与客户端属性同步，现有 dev server 正在提供 HMR，避免与 dev 同时写 `.next`；后续里程碑可按风险重新运行 build。

#### 回退、风险与 Owner Gate

- 回退方式：恢复上述三个 prototype 文件中的映射和 effect 即可；不涉及持久化、数据库、认证、生产或外部服务。
- 剩余风险：语言切换后的完整键盘/屏幕阅读器体验、长文案视觉验收和浏览器语言行为仍需 Owner 主观确认；本批不修复其他国际化问题。G1 首要待办是将实际 Node `20.20.2` 对齐项目要求的 Node `22.x`，并在工程底座门中固定版本和 CI 证据。
- G0/P1 仍为“待 Owner 验收”；本批不宣称 Owner 通过或 UI 冻结。下一动作仍是 Owner 全流程视觉验收与 UI 冻结/修订决定。

### 2026-08-25｜第二轮机器辅助无障碍与响应式审计

#### 元数据与边界

- 环境：复用 Browser skill 的 `node_repl js + browser-client` 会话，目标为现有 `http://127.0.0.1:3000/`；未启动/停止服务器，未检查 cookies、localStorage、profile、密码或 session store。
- 实际视口：`390×844` 与 `1440×900` 用于键盘/焦点；`390×844` 用于触控目标、减少动效、三语页面和对比度。所有检查都是本地合成数据下的机器辅助预验收，不是完整 WCAG 认证或 Owner 主观视觉验收。
- 浏览器能力仅暴露 viewport；页面 `evaluate` 为只读 DOM 观察，无法安全注入根字体或替换 `window.scrollTo`。因此 200% 文本放大和程序滚动参数的直接观察标为未覆盖，不以正常字号结果推导放大结果。

#### 键盘与焦点矩阵

| 路径 | 实际操作与观察 | 结果/边界 |
|---|---|---|
| 首页 390 | 从品牌按钮开始实际 `Tab`：搜索、主题、购物车、快速分类、普通商品图片/标题/加入购物车、二手卡、底部首页/分类/订单/购物车/我的；商品卡用 `Enter` 打开详情 | Tab 顺序可走通，主要按钮 `:focus-visible` 可见，按钮焦点环为 `#087F72` 2px；商品卡 Enter 可导航，但路由切换后 active element 回到 `body`，未自动聚焦详情标题或主要操作。 |
| 首页 1440 | `Tab` 经过搜索、语言 select、主题、购物车、侧栏首页/分类/订单/购物车/我的及分类入口；`Shift+Tab` 实际回退经过购物车→主题→语言 | 侧栏五项顺序和焦点环可见；搜索输入本身无 outline，但其 `.global-search` 父容器显示翡翠青边框/光晕。 |
| 分类筛选 Sheet 390/1440 | 对“筛选”使用 `Enter` 打开，再对当前焦点使用 `Escape`，最后用筛选按钮 `Enter` 关闭 | 打开可用且触发按钮保持焦点；两种视口中 `Escape` 均未关闭 Sheet，也未把焦点移入 Sheet。再次对触发按钮按 `Enter` 可关闭并恢复触发按钮焦点。 |
| 我的 390 | 底栏“我的”用 `Enter`；语言按钮用 `Space` 切到 Italiano；主题按钮用 `Space` 切换明/暗；“减少动态效果” checkbox 用 `Space` 开/关 | 文案、根 lang、主题和 checkbox 状态更新；焦点保持在操作控件。 |
| 登录 390/1440 | 主题按钮后 `Tab` 到 Apple 登录按钮；邮箱填入合成值并对 textbox 按 `Enter` 进入 OTP | Enter 路径可用、无页面错误且无溢出；进入 OTP 后 active element 回到 `body`，未自动聚焦 6 位验证码输入框。未提交真实认证。 |

#### 44px 触控目标实测

以下是当前可见或实际聚焦路径中测得的小于 `44×44` 的直接元素；父级 44px 触控壳与隐藏原生 checkbox 另行注明，不把它们静默当作合格直接控件。

| 视口/页面 | 元素与实际 rect | 影响判断 |
|---|---|---|
| 390 首页 | 搜索 `input` `51×23`；两个普通商品标题按钮各 `152×35`；二手标题按钮实际 `332×18`（可通过 Tab 到达） | 搜索位于约 44px 的 `.global-search` 容器内，风险较低但直接 input 未达到 44px；商品标题是直接导航按钮，低于合同目标，建议补齐最小高度。 |
| 390 分类/筛选 | 搜索 `input` `51×23`；Nova 二手标题按钮 `332×18` | Sheet 的主要按钮/选项本身为可用大控件；商品标题仍是低于 44px 的直接按钮。 |
| 390 购物车/结算 | 购物车搜索 `input` `105×23`；购物车商品标题按钮 `256×19`；结算返回按钮 `.topbar__back` `20×44`；“修改”文字按钮 `32×44` | 返回和修改的宽度不足 44px，是中等触控可达性问题；购物车商品标题和搜索 input 需确认是否应扩大直接点击面。 |
| 390 我的/主题 | 两个 checkbox 原生 input 为 `1×1`，但外层 `.setting-row` 为 `358×58`，键盘/标签操作可用 | 原生 input 是视觉隐藏实现，标签触控面足够；仍需 Owner 确认读屏和触控语义。 |
| 390 登录 | 可见登录按钮、邮箱输入框、主题切换和返回链接均达到或超过 44px；邮箱字段上方文本 label 为 `324×20`，不是独立操作控件 | 未把普通文本 label 当作触控失败。 |
| 1440 首页 | 搜索 `input` `690×25`；Nova 二手商品标题按钮 `232×22`；侧栏五项导航均 `190×44` | 桌面布局侧栏满足 44px 高度；搜索 input 与商品标题直接 rect 仍小于 44px，主要依赖父级/卡片点击面。 |

#### Reduced motion 实测

- 浏览器 `matchMedia("(prefers-reduced-motion: reduce)")` 本轮为 `false`；未改变操作系统级媒体偏好，因此系统 `true` 分支未覆盖。
- 应用“减少动态效果”用 Space 开启后，根节点实际 class 为 `prototype-root theme-light reduce-motion`；首页 `.home-intro`、分类 tile、商品卡和 bottom nav 的 computed `animation` 为 `none`，`animationDuration`/`transitionDuration` 为 `1e-05s`。关闭后恢复普通 class。
- computed `html` `scroll-behavior` 仍为 `smooth`；由于 evaluate 只读，未能捕获 JS `window.scrollTo` 的实际参数。不能据此宣称所有滚动动画均已完整验证，需在 Owner/后续浏览器专项中复核系统 reduce 分支和程序滚动。

#### 三语正常字号矩阵与文本放大边界

在 `390×844` 正常字号下，逐一切换中文、Italiano、English，并实际访问首页、分类、二手详情、购物车、结算、订单、我的；每个页面的 `scrollWidth` 与 `bodyScrollWidth` 均为 `390`，根 `<html lang>` 与 `.app-shell lang` 分别正确为 `zh-CN`、`it`、`en`，标题和长文案随语言更新。登录演示在 390 下也为 `390` 宽且无 error/page overlay。

200% 根字体/浏览器缩放本轮未覆盖：当前 Browser skill 没有 zoom/text-scale 能力，viewport 改变不等价于字体放大，且只读 evaluate 阻止了可逆的 DOM 根字体注入。Owner 仍需用真实浏览器缩放或等效辅助技术复核三语长文案、固定底栏、Sheet、详情事实和登录表单的裁切/遮挡。

#### 基础对比度预检查

以下值来自本轮页面 computed style，并按 WCAG 常用相对亮度公式计算；`4.5:1` 仅作为普通文字 AA 预检查门槛，不构成正式认证。

| 模式 | 实际组合 | 对比度 |
|---|---|---:|
| 浅色 | 正文 `#171725` / 画布 `#F4F5FA` | 16.27:1 |
| 浅色 | 主按钮文字 `#FFFFFF` / action `#087F72` | 4.90:1 |
| 浅色 | 次要正文 `#626278` / surface `#FFFFFF` | 5.94:1 |
| 浅色 | 标签文字 `#066A60` / soft `#E5F7F3` | 5.85:1 |
| 浅色 | 焦点环 `#087F72` / 白色控件面 | 4.90:1 |
| 深色 | 正文 `#F6F5FF` / 画布 `#0F1020` | 17.42:1 |
| 深色 | 主按钮文字 `#171725` / action `#53D1BE` | 9.47:1 |
| 深色 | 次要正文 `#B9B8CD` / surface `#17182A` | 9.00:1 |
| 深色 | 标签/焦点环 `#53D1BE` / soft `#183F39` | 6.21:1 |
| 浅色状态面 | computed `color(srgb 0.919608 0.954902 1)` 上的 `#171725` | 15.89:1 |
| 深色状态面 | computed `color(srgb 0.127059 0.156078 0.248235)` 上的 `#F6F5FF` | 13.53:1 |

透明内容面和多色渐变没有做猜测式对比度计算；它们仍需按实际停靠点和最终文案做 Owner 复核。

#### 本轮问题分级与下一 Gate

- **中｜筛选 Sheet 键盘关闭/焦点管理**：390/1440 复现“分类→筛选→Enter→Escape”，Sheet 保持打开且焦点留在触发按钮；建议实现 Escape 关闭、打开时聚焦首个 Sheet 控件、关闭后恢复触发按钮焦点。
- **中｜二级结算触控宽度**：390 结算中返回按钮为 `20×44`、“修改”为 `32×44`；建议将直接操作区域扩为至少 `44×44`。
- **中｜路由切换后的焦点落点**：商品卡 Enter 进入详情、登录邮箱 Enter 进入 OTP 后 active element 均回到 `body`；建议将焦点转移到详情标题/主操作或 OTP 输入框。
- **低至中｜直接文本控件尺寸**：390 商品标题按钮 `18–35px` 高、搜索 input `23px` 高，1440 商品标题 `22px` 高；部分位于较大父级点击面内，但仍应由 Owner 决定是否补齐 44px 直接操作目标。
- **未覆盖**：真实 200% 文本放大、系统 `prefers-reduced-motion: reduce=true`、完整 WCAG 键盘/读屏认证、渐变/透明面全停靠点对比度、所有页面每个视口的逐项焦点复核。
- 本轮最后检查 console/page logs 为 `[]`，未见 error overlay；已恢复中文、浅色、普通字号、首页和默认视口。G0/P1 继续保持“待 Owner 验收”，本记录不宣称 UI 冻结或 Owner 通过。

### 2026-08-25｜键盘焦点与触控目标修复/复验

#### 批次范围与分类

- 复用：现有 `FilterSheet`、`AppShell`、`PrototypeApp`、登录演示、全局 token 和既有买家端导航/路由；不新增组件、路由、API、schema、数据或外部连接。
- 扩展：`FilterSheet` 使用稳定 `onOpenChange(open)`、触发按钮 ref/ARIA、稳定 dialog id/标题关系、局部 Escape 处理和打开/关闭焦点同步；`AppShell` 使用返回按钮 ref，并仅以原始 `showBack` 布尔值驱动详情页聚焦；登录 OTP 输入在 OTP 视图挂载时自动聚焦；全局 CSS 将指定直接控件补齐至少 `44×44`。
- 新建：无。`ProductCard.tsx` 未修改，因为现有标题按钮结构已可由共享 CSS 直接扩展。

#### 实际文件与影响边界

- `prototype/components/FilterSheet.tsx`：`onToggle` 改为稳定 `onOpenChange`；触发器添加 `aria-controls`、`aria-expanded`、`aria-haspopup="dialog"`；Sheet 添加稳定 `id`、`role="dialog"`、`aria-labelledby`；打开后焦点进入“清除条件”按钮，Sheet 内任意控件冒泡的 Escape 关闭并将焦点恢复到触发器，Apply 同样恢复焦点；未声明 `aria-modal`，未伪造完整 modal/inert/trap。
- `prototype/components/AppShell.tsx`：返回按钮 ref 与 `[showBack]` effect；只在二级 shell 从隐藏返回按钮状态进入显示状态时聚焦，不因标题或语言变化重复抢焦点。
- `prototype/components/PrototypeApp.tsx`：FilterSheet 直接传递稳定的 `setFilterOpen`，不再创建内联 toggle 回调。
- `prototype/app/account/login/LoginPrototype.tsx`：仅在 OTP 视图的输入框使用 `autoFocus`；首次邮箱视图仍先显示 Apple/Google/邮箱入口，不改变演示认证边界。
- `prototype/app/globals.css`：`.topbar__back`、`.text-button` 补足最小宽高，`.product-card__title`/`.cart-row__title` 与 `.global-search input` 补足最小高度；配色 D、减少动效 token 和业务布局不变。
- `docs/stages/G0-P1-视觉验收与UI冻结.md`：本追加记录；不改变 G0/P1 状态。

#### 命令验证

- `prototype/ pnpm typecheck`：通过。
- `prototype/ pnpm lint`：通过。
- 两条命令均出现运行环境提示：实际 Node `v20.20.2`，而 `prototype/package.json` engines 要求 `22.x`；pnpm `10.33.3` 与声明一致。该 warning 已记录，不能把 G1 工程底座或 Node 22 对齐写成已满足。
- 本批未运行 build：当前任务仅涉及低风险焦点/ARIA/CSS 修复，现有 dev server 正在提供 HMR；为避免 dev 与 build 同时写 `.next`，将 build 留给后续里程碑，不以未运行 build 声称更高证据级别。

#### Browser skill 定向复验

- 环境：复用 Browser skill 的 `node_repl js + browser-client`，连接现有 `http://127.0.0.1:3000/`；未启动/停止服务器，未检查 cookies、localStorage、profile、密码或 session store。
- `390×844`：分类页打开筛选后 active element 为 `.filter-sheet .text-button`；对 Sheet 控件按 Escape 后 Sheet 消失，触发器恢复焦点且 `aria-expanded="false"`；重新打开并按 Apply 后同样恢复。首页商品标题按 Enter 进入普通详情，active element 为 `.topbar__back`；登录合成邮箱按 Enter 后 active element 为 `#login-otp`。筛选、详情和登录页面 `scrollWidth/bodyScrollWidth` 均为 `390`，未见横向溢出。
- `1440×900`：商品标题按 Enter 进入详情后返回按钮获焦；分类筛选打开时焦点进入 Sheet，Escape 关闭并返回触发器；首页、分类和购物车样本未见宽度溢出。生成一条本地购物车样本后，`.cart-row__title` 测得 `372×44`。
- 触控目标实测：390 的 `.topbar__back` 为 `44×44`；筛选 `.text-button` 为 `60×44`；普通商品标题为 `152×44`，二手扩展标题为 `332×44`；`.global-search input` 为 `104.84×44`。1440 的普通/二手商品标题均为 `44px` 高，搜索 input 为 `690×44`。所有数值为当前可见 DOM rect，不把普通文本链接当作操作控件。
- 日志：复验结束 `g0tab.dev.logs()` 过滤 `error`/`pageerror`/`warn` 结果为 `[]`；未见 error overlay。最后恢复中文、浅色、首页和默认视口。

#### React 与无障碍定向自审

- 没有新增组件、重复业务逻辑或全局事件监听；Escape 使用 Sheet 局部 `onKeyDown` 冒泡，避免重复 listener。
- 焦点 effect 只处理必要 DOM 同步，依赖分别为原始 `open` 与 `showBack` 布尔值；关闭/Apply/触发器切换在事件处理器中完成，避免派生状态 effect。
- `FilterSheet` 的 dialog 语义仅包含稳定标题关系和实际实现的焦点行为；未声称 modal、inert、focus trap 或完整 WCAG 认证。

#### 回退、未覆盖与 Owner Gate

- 回退方式：仅回退本批六个允许范围内的局部 CSS/焦点/ARIA 改动及本追加记录；不触及配色 D、业务数据、服务器、依赖、认证或生产。
- 未覆盖：本批未运行 build；未重新执行 430/768/1024 全视口业务矩阵、真实 200% 文本放大、系统 `prefers-reduced-motion: reduce=true`、完整读屏/WCAG 认证、生产/Staging 或真实认证；这些限制不能由本批 390/1440 定向结果推导消除。
- 已保留上一轮“Sheet Escape/焦点未管理、OTP/body 焦点、直接控件低于 44px”的历史发现，没有静默改写。修复后的机器证据仍属于本地交互证据，不替代 Owner 主观视觉验收。
- Owner Gate：G0/P1 继续为“待 Owner 验收”，不宣称 UI 冻结或 Owner 通过。下一动作仍是 Owner 全流程视觉验收与 UI 冻结/修订决定；通过后才按路线进入 G1。

### 2026-08-25｜Owner 验收清单已准备

- 新建 [G0/P1 Owner 视觉验收清单](./G0-P1-Owner视觉验收清单.md)，供 Owner 在现有 `http://127.0.0.1:3000/` 本地原型按 390/1440、明暗、zh/it/en、买家流程和登录演示逐项判断。
- 清单明确 GOV-1 前置、机器证据不等于 Owner 决定、真实 200% 缩放与系统减少动效的手动检查、敏感信息边界、通过/修订/暂停三种最终 Gate，以及修订后的追加记录方式。
- 本条只登记资料准备，不改变 G0/P1“待 Owner 验收”、GOV-1、G1 或任何后续阶段状态；未运行 build/lint/browser/独立审查/哈希，原因是本批纯 Markdown 资料整理。

### 2026-08-25 18:58:57 CEST｜GOV-1 已通过，Owner 视觉验收已打开

- Owner 原话：`批准`；上下文为主代理请求“批准 GOV-1 治理体系，进入 G0/P1 Owner 视觉验收”。
- 当前影响：GOV-1 已通过，Owner 现在可以按 [G0/P1 Owner 视觉验收清单](./G0-P1-Owner视觉验收清单.md) 执行本阶段全流程验收。
- 严格边界：G0/P1 当前状态仍为“待 Owner 验收”，不等于 UI 冻结或 G0 通过；G1、G2-A0、G2-A1、P2–P8 仍未开始；不授权代码之外的数据库、Auth、部署、生产、支付或隐私实施。

### 2026-08-25｜Owner checkpoint 1 候选视觉基线截图

#### 批次目标与实际操作

- 目标：为 [G0/P1 Owner 视觉验收清单](./G0-P1-Owner视觉验收清单.md) checkpoint 1 提供一份可复核的首页移动浅色中文候选基线。
- 实际页面：`http://127.0.0.1:3000/` 首页；视口 `390×844`；中文 `zh-CN`；浅色；`scrollY=0`。
- 实际测量：`innerWidth=390`、`innerHeight=844`、`clientWidth=390`、`scrollWidth=390`、`bodyScrollWidth=390`；根节点为 `prototype-root theme-light`。
- 页面使用本地 Prototype 合成数据；未读取 cookies、localStorage、profile、密码、会话存储或 `.env`。

#### 浏览器证据与文件

- [候选截图](../evidence/G0-P1/2026-08-25/01-home-mobile-light-zh.png)：PNG，`390×844`，8-bit RGB，`167466` bytes。
- [截图 manifest](../evidence/G0-P1/2026-08-25/README.md)：记录截图元数据、边界、失效条件和 hash；SHA-256 为 `3b4de8c25d97e2de986cbdff660174521c631e37c253c30add750f2415dd1169`。
- 本次截图后的 console/page error/warn 检查结果均为空（`[]`）；未见页面错误覆盖层。
- 截图完成后恢复并保持同一首页、中文、浅色、顶部状态，便于 Owner 继续检查。

#### 风险、回退与维护

- 证据等级：本地交互/机器辅助候选证据；不表示 Owner 通过、G0/P1 已冻结、WCAG 认证、Staging 或生产验收。
- 若影响首页的源码、token、字体、图片、合成数据、依赖或浏览器/渲染环境变化，截图失效；历史文件不得覆盖，修订须使用新日期/批次文件并重新记录元数据与 hash。
- 本批只新增证据 PNG/manifest 和两处文档链接，未修改 prototype、依赖、服务器、数据库、部署或生产数据。回退为移除本批文件及对应链接，不影响代码或业务状态。

#### 验证与跳过项

- 已验证 PNG 存在、可由系统图像工具识别并解码为 `390×844`，文件为 PNG；manifest 中 hash 与本批唯一一次完整 SHA-256 检查结果一致。
- 已检查证据相对链接、状态边界和敏感信息边界；未运行 build/lint/E2E、未做独立安全审查或生产/Staging 检查，原因是本批仅生成本地候选截图与 Markdown 证据。

#### Owner Gate

- G0/P1 仍为“待 Owner 验收”。候选截图仅辅助 checkpoint 1，不填写 Owner 决定，不宣称 UI 冻结；下一动作仍是 Owner 按清单完成全流程视觉验收并选择通过、修订或暂停。

### 2026-08-25｜Owner checkpoint 2–12 候选视觉评审画廊

#### 批次目标、范围与实际文件

- 目标：为 Owner 清单 checkpoint 2、3、4、5、6、7、9、11、12 提供本地候选视觉画面；不替代 Owner 全流程判断。
- 新增/保留文件：[画廊 manifest](../evidence/G0-P1/2026-08-25/README.md)、`02-home-mobile-dark-zh.png`、`03-category-filter-mobile-light-zh.png`、`04-product-new-mobile-light-zh.png`、`05-product-used-mobile-light-zh.png`、`06-cart-mobile-light-zh.png`、`07-order-detail-mobile-light-zh.png`、`08-home-desktop-light-zh.png`、`08-home-desktop-dark-zh.png`、`09-login-desktop-light-zh.png`。
- `08-home-desktop-light-zh.png` 首轮截图实际为深色；未丢弃该证据，已改名保留为 `08-home-desktop-dark-zh.png`，随后在 DOM 确认 `theme-light`、浅色画布、中文、1440×900、`scrollY=0` 后重新生成正确的浅色 08。
- 本批仅操作本地 `http://127.0.0.1:3000/` 和合成数据；未读取 cookies、localStorage、profile、密码、会话存储或 `.env`，未连接外部服务、未提交真实订单或认证。

#### 浏览器状态与实际结果

| 文件 / checkpoint | 实际状态 | 机器可见结果 | console/page error/warn |
|---|---|---|---|
| 02 / checkpoint 2 | 390×844，中文，深色首页，`scrollY=0`，`scrollWidth=390` | 深色根主题、搜索、分类、普通商品流与二手卡 | `[]` |
| 03 / checkpoint 3 | 390×844，中文，浅色分类，筛选 Sheet 打开，`scrollY=0`，`scrollWidth=390` | Sheet 层级、筛选选项和应用按钮可见 | `[]` |
| 04 / checkpoint 4 | 390×844，中文，浅色普通商品详情，`scrollY=0`，`scrollWidth=390` | Voltix 价格、库存、购买数量、加入购物车和立即购买可见 | `[]` |
| 05 / checkpoint 5 | 390×844，中文，浅色二手详情，`scrollY=0`，`scrollWidth=390` | 固定 1 件、商品标题、价格与“二手购买事实”标题可见 | `[]` |
| 06 / checkpoint 6 | 390×844，中文，浅色购物车，`scrollY=0`，`scrollWidth=390` | Northline Lab 与 Riva Devices 两个合成商家分组可见；未提交结算 | `[]` |
| 07 / checkpoint 7 | 390×844，中文，浅色 `RB-DEMO-001` Northline Lab 商家子订单，`scrollY=0`，`scrollWidth=390` | 处理中状态、状态时间线、商家小计可见 | `[]` |
| 08-dark / checkpoint 11 抽查 | 1440×900，中文，深色首页，`scrollY=0`，`scrollWidth=1440` | 错误命名纠正后保留为桌面深色候选，不代表完整三语审查 | `[]` |
| 08-light / checkpoint 9 | 1440×900，中文，浅色首页，`scrollY=0`，`scrollWidth=1440` | DOM 确认 `prototype-root theme-light`；约 224px 分类侧栏、顶部工具栏和商品流可见 | `[]` |
| 09 / checkpoint 12 | 1440×900，中文，浅色 `/account/login` 初始表单，`scrollY=0`，`scrollWidth=1440` | 邮箱为空；Apple/Google 占位入口和本地认证边界可见 | `[]` |

#### 主审发现与风险

- **中｜checkpoint 5 二手关键事实首屏不足**：`05-product-used-mobile-light-zh.png` 是修订前证据；在实际 390×844 首屏中只能看到“二手购买事实”标题，成色、已披露缺陷、电池健康、保修具体内容未进入视口。该项影响已批准的二手关键事实不可隐藏规则，不能标为机器通过；Owner 需决定修订方向，修订后用新批次截图复验。
- **低｜checkpoint 9 首轮颜色状态误标**：首轮 08 文件名与实际深色不符，已保留为 `08-home-desktop-dark-zh.png` 并重新生成浅色 08；manifest 与清单链接已按最终文件名记录。
- 其余本批只记录画面状态和可见结构，不对品牌满意度、三语完整性、真实 200% 缩放、WCAG、生产或 Staging 作结论。

#### 验证、回退与维护

- 已用系统图像工具确认本批 PNG 可解码；移动图为 `390×844`，桌面图为 `1440×900`。manifest 记录每张最终文件的 bytes 与 SHA-256；修订后的 03–08 浅色文件按最终字节重新计算，保留的错误深色 08 沿用原字节 hash。
- 已完成本地浏览器状态、语言、主题、滚动位置、横向尺寸和 console/page error/warn 检查；未运行 build/lint/E2E，原因是本批仅生成证据和 Markdown；未做独立审查或外部连接。
- 回退：移除本批 PNG、manifest 及清单/阶段记录中的对应链接；不触及 prototype 源码、业务数据、服务器、依赖、数据库、部署或生产。
- 失效：相关源码、token、字体、图片、合成数据、依赖、浏览器或渲染环境变化后，旧画廊不得视为当前证据；修订必须新增日期/批次文件，不覆盖历史。

#### Owner Gate

- G0/P1 继续保持“待 Owner 验收”，本批候选画廊不等于 UI 冻结或 Owner 通过。checkpoint 5 已有明确待修订视觉发现；下一动作是 Owner 按清单逐项判断并决定通过、修订或暂停，不能因截图存在而打开 G1。

### 2026-08-25｜checkpoint 5 二手详情首屏纠正与修订

#### 目标与历史纠正

- 目标：在 390×844 二手详情首屏同时呈现价格、库存中的固定 1 件、成色、已披露缺陷、电池健康、保修，并保持四项事实先于购买按钮和次要规格。
- 历史事实保留：前序记录曾写“二手关键事实首屏可见”，但修订前截图实际只露出“二手购买事实”标题；该当前结论已被本条纠正，不删除历史记录。
- 新证据：[修订后截图](../evidence/G0-P1/2026-08-25-checkpoint5-fix/05-product-used-mobile-light-zh-after.png) 与 [修订 manifest](../evidence/G0-P1/2026-08-25-checkpoint5-fix/README.md) 仅证明机器修复候选，不是 Owner 通过。

#### 代码批次与复用边界

- `prototype/components/PrototypeApp.tsx`：复用既有 `UsedFacts`，将非 compact 二手事实从 detail layout 后移至 detail copy 的价格/库存之后、购买区之前；二手库存行明确复用 `tr(locale, "cart.singleItem")`；普通商品继续显示库存数量和既有数量步进器；UsedFacts 只渲染一次。
- `prototype/app/globals.css`：新增 `detail-page--used` 局部规则，事实网格固定为清晰 2×2；移动端收紧二手媒体高度与事实间距，但保持事实 label 至少 12px、value 至少 13px、按钮触控区规则和可换行长文案。桌面/普通商品规则未改变。
- 未新增组件、依赖、路由、API、数据或后端；未改变二手固定 1 件、价格/库存语义、循环翡翠青或商家业务事实。

#### 浏览器实际验证

环境：复用 Browser skill 的 `node_repl js + browser-client`，本地 `http://127.0.0.1:3000/`；未读取 cookies、localStorage、profile、密码、会话存储或 `.env`。

| 页面/语言 | 视口与横向尺寸 | 固定单件文案 | 四项事实最底 bottom | 结果 |
|---|---|---|---:|---|
| 二手详情 / 中文 `zh-CN` | 390×844；`scrollY=0`；`scrollWidth/bodyScrollWidth=390` | `二手设备固定 1 件` | 755.76px | 4 个 `dt/dd` 均在视口内；console/page error/warn `[]` |
| 二手详情 / 意大利语 `it` | 390×844；`scrollY=0`；`scrollWidth/bodyScrollWidth=390` | `L'usato è fisso a 1 pezzo` | 839.52px | 4 个 `dt/dd` 均在视口内；console/page error/warn `[]` |
| 二手详情 / 英语 `en` | 390×844；`scrollY=0`；`scrollWidth/bodyScrollWidth=390` | `Used items stay at 1 unit` | 805.91px | 4 个 `dt/dd` 均在视口内；console/page error/warn `[]` |
| 二手详情 / 中文 `zh-CN` | 1440×900；`scrollY=0`；`scrollWidth/bodyScrollWidth=1440` | `二手设备固定 1 件` | 2×2，事实卡 bottom 470.45/543.00px | 事实网格为 2×2，无横向溢出；console/page error/warn `[]` |
| 普通详情 / 中文 `zh-CN` | 390×844；`scrollWidth/bodyScrollWidth=390` | 数量步进器 `1` | UsedFacts 数量 `0` | 价格、数量、加入购物车、立即购买正常；console/page error/warn `[]` |

#### 命令、证据与边界

- `prototype/ pnpm typecheck`：通过；`prototype/ pnpm lint`：通过。两条命令均提示实际 Node `v20.20.2` 不满足 `engines 22.x`，pnpm `10.33.3` 与声明一致；该 warning 不等于 Node 22/G1 已满足。
- 未运行 build：本批为单个 TSX/CSS 的低风险局部 UI 修订，且现有 dev server 正在提供 HMR；未启动独立审查，未运行哈希以外的生成校验。修订后 PNG 可解码为 `390×844`，bytes `132766`，SHA-256 `a247bee92c0137e0f8498bbecd92fbaf85f7c1a73a230b7412a0f03d044c6597`。
- 维护/失效：相关源码、token、字体、图片、合成数据、依赖、浏览器或渲染环境变化时，本修订截图失效；后续修订使用新日期/批次，不覆盖修订前证据。
- 回退：仅回退 `PrototypeApp.tsx`/`globals.css` 本批局部改动并移除 checkpoint5-fix 证据及链接；不触及业务数据、服务器、数据库、部署、认证或生产。

#### Owner Gate

- G0/P1 仍为“待 Owner 验收”。本条机器验证修正了“事实未进入首屏”的当前问题，但不预填 Owner 决定、不冻结 UI、不打开 G1；下一动作仍是 Owner 检查三语长文案、层级、密度、对比度和二手事实可读性后选择通过、修订或暂停。

### 2026-08-25｜Owner 新修订请求：分类页目录式 eyebrow，G0 冻结重新打开

- Owner 原话：`整个项目当中不要出现类似这样的目录，我要的是移动端app的那种体验`。
- 具体证据：分类页出现 `REBUY / CATALOG` 目录/路径式 eyebrow；Owner 要求整个项目采用移动端 App 体验，不保留这类目录式表达。
- 历史决定：Owner 于 20:14:15 CEST 原话 `G0视觉通过并冻结，授权进入G1`；本条不删除该历史，但记录其后的修订请求已使当前冻结重新打开。
- 当前状态：G0/P1 改为“执行中”，证据级别仍为本地交互；下一批需要修订受影响 UI、复验移动端体验并重新取得 Owner 的 G0“通过并冻结”决定。
- G1 边界：G1 仍为“未开始”；20:14:15 的 Entry 授权保留为历史，但因当前 G0 前置不再满足而暂停进入，绝不继续 Git、Node、CI、环境或外部工程工作。
- 本批影响与回退：本条只追加 Markdown 事实，未修改 prototype；未来修订可局部移除该 eyebrow 并重做受影响证据，保留历史截图和本条记录，不触碰业务、后端、数据库、Auth、部署或生产。
- Owner Gate：G0/P1 当前不通过、不冻结；等待修订后新的 Owner 决定。

### 2026-08-25｜移动 App 标题层级修订完成，提交 G0 复验

- 目标：响应 Owner 对分类页 `REBUY / CATALOG` 目录/路径式表达的反馈，使买家端主页面直接呈现本地化标题和原生移动 App 分区。
- 代码范围：仅修改 `prototype/components/PrototypeApp.tsx` 与 `prototype/app/globals.css`；删除买家路径式 eyebrow 和首页/详情/结账/订单详情/个人页的纯装饰 `01`/`02`/`03`，保留详情标题/数量、购物车总计、订单批次/订单号等业务语义；不改变配色 D、五项导航、分类或业务数据。
- 机器验证：源码 `rg` 门禁无 `Rebuy /`、`REBUY /` 或数字装饰 eyebrow；Node 22.12.0 下 `pnpm typecheck`、`pnpm lint` 通过。无 build、独立审查或生产验证。
- 证据边界：[移动 App 标题层级 manifest](../evidence/G0-P1/2026-08-25-mobile-app-titles/README.md)只记录本批真实源码/机器检查；浏览器交互和截图复验由主代理补充，不预填 Owner 通过。
- 回退/维护：可局部恢复本批标题和间距改动，不触及后端、数据库、Auth、Git、CI、环境或生产；源码、字体、token、浏览器或布局变化时相关候选证据失效。
- 当前状态：G0/P1 为“待 Owner 验收”，冻结尚未重新通过；G1 为“未开始”，历史 Entry 授权暂停。下一动作是 Owner/主代理复验后选择通过、修订或暂停。

### 2026-08-25｜主代理全流程标题层级浏览器复验（无截图归档）

- 执行边界：主代理在现有 `http://127.0.0.1:3000/` 本地预览中实际复验；只使用合成数据，未读取 cookies、localStorage、profile、密码、会话存储或 `.env`，未提交真实订单/认证或连接外部服务。截图工具未写入新的本地归档 PNG，因此本条不声称有截图证据。
- 390×844、中文、浅色：首页、分类、订单、空购物车、我的均为 `pathLabels=[]`、`numericSectionLabels=[]`、`bottomNav=5`、`overflowX=false`；主标题分别为“今天想找什么？”、“分类与搜索”、“订单”、“购物车还是空的”、“我的”。分类 h1 top=95px、首卡 top=218px；商品详情显示“商品详情”返回顶栏与商品名 h1；购物车 h1 为“购物车”；结算顶栏为“结算确认”，h2 为“演示配送资料/商家订单摘要”；订单详情顶栏为“商家子订单”，h2 为“状态时间线/商家子订单”；`/account/login` h1 为“登录 Rebuy”，无路径标签且 `overflowX=false`。
- 390×844 三语抽查：Italiano 的 `document` lang=`it`、h1 为“Categorie e ricerca”、五项导航正常；English 的 `document` lang=`en`、h1 为“Categories and search”、五项导航正常。
- 1440×900、中文、浅色：分类 h1 正常、`pathLabels=[]`、桌面 sidebar grid 可见、`bottomNav=none`、`overflowX=false`；购物车 h1 正常、2 栏布局、`overflowX=false`。
- 所有上述主代理交互检查的 console/page error/warn 均为 `[]`。结果是本地交互证据，不是 Owner 主观视觉通过、UI 冻结、WCAG、Staging 或生产验收。
- 复用/扩展/新建：复用既有 Prototype 路由、标题、五项导航和本地合成数据；本条只扩展阶段事实记录与证据 manifest，不新增组件、依赖、路由、API 或后台能力。
- 回退/失效：浏览器复验记录为追加事实，可由后续带日期纠正；源码、token、字体、图片、合成数据、依赖、浏览器或渲染环境改变时需重新复验。无截图文件可回退或删除，现有候选 PNG 仍不作为本条交互证明。
- Owner Gate：G0/P1 当前仍为“待 Owner 验收”；标题修订后的本地机器/主代理交互结果不预填决定。G1 仍“未开始”，20:14:15 的 Entry 授权仅为历史且暂停；下一动作是 Owner 按清单选择通过、修订或暂停。

### 2026-08-25｜统一选择器修订启动

- Owner 原话：`这个点击打开的选项卡不统一 帮我为项目制作统一风格的`；证据为分类页排序展开后显示浏览器原生蓝色菜单。
- 当前状态：G0/P1 暂记为“执行中（统一选择器修订）”；历史 G0 冻结和标题层级修订保留，但不构成当前通过。G1 继续“未开始/暂停”，不因本批 UI 修订打开工程工作。
- 目标：以共享 `SelectMenu<T extends string>` 替换排序/语言原生选择器，统一循环翡翠青、明暗主题、弹层边界、键盘和焦点语义；不改变排序/语言状态、筛选、分类、五项导航、商品数据或业务规则。
- 排除：不触碰后端、Auth、数据库、部署、Git、CI、外部服务或生产数据；浏览器交互验收由主代理另行完成。

### 2026-08-25｜统一选择器实时浏览器验收完成，提交 Owner Gate

- Owner 原话：`这个点击打开的选项卡不统一 帮我为项目制作统一风格的`；本条记录该修订请求完成后的事实，前一条启动记录保留。
- 证据：[统一选择器实时验收 manifest](../evidence/G0-P1/2026-08-25-unified-select/README.md)。本轮没有落盘 PNG 或 hash；manifest 只记录主代理实时本地浏览器与 DOM/CSS 结果。
- 499×862 浅色分类排序菜单：原生 select=0、3 项/1 项选中、`L272/T231/R483/B381`、`212×150`、圆角 14px、每项 44px、`scrollWidth=clientWidth=499`、白色面/循环翡翠青选中态、无系统蓝色。390×844 深色菜单：`L204/T231/R374/B381`，视口内，背景 `rgb(34,35,58)`、边框 `rgb(80,81,112)`，`scrollWidth=clientWidth=390`。
- 1440×900 语言菜单：`L1101/T68/R1212/B218`，3 项，右对齐未越界；方向键/End/Home 完成 zh-CN→it→en→zh-CN，标题同步并恢复中文。排序 ArrowDown+Enter/End、Sheet 联动、Escape、Tab/Shift+Tab 均实测；390 Tab 到 Voltix 查看、Shift+Tab 到筛选，1440 Tab 到深色模式、Shift+Tab 到搜索，不落 BODY。
- 控制台仅 React DevTools/HMR info/log，无 warning/error；`prototype/ pnpm typecheck` 和 `prototype/ pnpm lint` 通过；原生 `<select>` 扫描为 0。未运行 build/E2E、未做 hash（无确定性生成物/落盘截图），未启动额外独立审查代理；原因与本批风险边界见 manifest。
- 复用/扩展/新建：复用既有 FilterSheet/AppShell 与配色 D token，新增共享 `SelectMenu<T extends string>` 并扩展排序/语言调用点；不改变筛选、分类、五项导航、业务数据、后端、Auth、数据库、部署或生产。
- Owner Gate：G0/P1 当前为“待 Owner 验收”，准确描述为“G0 本轮统一选择器修订待 Owner 验收”；本地实时结果不等于 Owner 通过或 UI 冻结。G1 仍“未开始/暂停”，20:14:15 的历史冻结与 Entry 授权不恢复为当前工程授权；下一动作是 Owner 选择通过、修订或暂停。

### 2026-08-25｜全流程实时本地验收与隔离构建完成，提交最终 Owner Gate

- Owner 决定：`统一选择器通过，继续G0总体验收`（2026-08-25；具体时刻未提供）。该决定仅将 Owner 清单 checkpoint 15 标为“通过”，不等于 G0/P1 总体通过、UI 冻结或 G1 Entry。
- 证据：[G0/P1 全流程验收 manifest](../evidence/G0-P1/2026-08-25-full-experience-acceptance/README.md)。本轮没有落盘新 PNG，不生成 hash；manifest 记录主代理实时 DOM/CSS/交互结果和隔离 build。
- 实际覆盖：390×844 首页普通 `174+174` 双列/二手 `358` 满行、五项导航、明暗主题；分类 `Nova` 键盘 Enter 1 结果、二手筛选 2 结果、Sheet 首焦点/ Escape 回焦；普通数量 1→2、二手固定 1 件和四项事实首屏；两商家购物车/结算；两演示订单与子订单时间线；我的三语/批发语义/减少动态效果；登录 390 浅深色/OTP 自动聚焦及 1440 分栏。
- 1440 覆盖：Buyer sidebar `224px`、商品卡/二手卡、分类 toolbar `936px`、购物车主区 `568px`+summary `340px`、结算 `824px`+`340px`、订单 `936px`/详情 `1192px`、登录 frame `1120px`；详情二级 shell 隐藏 sidebar/bottom nav；无 KPI/仪表盘；原生 select=0。
- 三语/响应式：it/en 标题同步、430/768/1024 检查通过；320 精确视口未覆盖，浏览器实际 clamp 到 `innerWidth=413`，不伪称 320 通过；触控目标实测 `44px` 下限，console/page warning/error=0。
- 键盘/放大边界：全页 Tab 序列本轮因浏览器驱动限制未重复取得，复用此前同源码的定向 Tab/Shift+Tab 证据；200% 缩放、系统 `prefers-reduced-motion:true`、完整读屏/WCAG 未覆盖，留给 Owner/专项检查。
- 隔离 build：最终使用 `/tmp/rebuy-g0-build.RKda6l/prototype` 内部依赖复制、Node `v22.12.0`、pnpm `10.33.3` 执行 `pnpm build`，Next `16.3.2` 成功输出 5 个静态页面和 `/api/health/supabase` 动态路由；外部 symlink 与 `cp -a` 的失败尝试均作为构建准备阻塞记录，不影响源目录。未停止/替换服务器；执行代理隔离 shell 的 curl 返回 `000`，不作为用户侧预览通过或失败证据，主代理 in-app browser 构建前后持续可交互。
- 验证边界：typecheck/lint 复用统一选择器修复后有效证据，源码此后未变化；正式 E2E、hash 和额外独立审查未运行，原因与风险见 manifest；本轮不触碰业务、后端、Auth、数据库、部署或生产。
- 当前 Owner Gate：G0/P1 保持“待 Owner 验收（总体验收机器证据完成，等待最终冻结/修订决定）”；G1 仍“未开始/暂停”。下一动作是 Owner 对全流程视觉、长文案、200% 缩放、减少动态效果和最终 UI 冻结/修订作出决定。

### 2026-08-25｜分类目录信息架构修订启动

- 历史决定：Owner 曾原话 `G0总体验收通过并冻结，未覆盖项进入后续专项，重新授权进入G1`；该冻结与 G1 Entry 历史保留，不被本条删除或改写。
- 新 Owner 要求：`然后网站整体的目录结构应该是跟淘宝类似，首页显示推荐内容，然后分类展示各个种类的列表，点进去后才是商品`。本批只借鉴“推荐→目录→品类列表→详情”的层级，不复制淘宝品牌、配色、拥挤营销或视觉。
- 当前状态：该新要求使 G0/P1 再次打开，当前为“执行中（分类目录信息架构修订）”；G1 仍“未开始/暂停”，历史 Entry 授权不构成当前工程开门。
- IA 合同：首页推荐区先于轻量快速分类；底部/桌面一级“分类”进入仅含品类列表的目录根页，不显示商品卡、结果数、筛选或排序；点击品类进入匹配商品列表，显示本地化品类标题、结果数、筛选/排序和明确的“返回全部分类”；搜索直接进入结果列表；详情返回保留来源品类结果；五项导航、桌面侧栏具体品类、二手事实、批发自动定价、多商家分组和三语不变。
- 复用/扩展/新建：复用 `categoryItems`、`productMatchesCategory`、`ProductCard`、`FilterSheet`、`AppShell` 和现有 D token；扩展 `catalogMode` directory/results、分类文案、电脑品类入口和目录返回操作；不新增组件、不新增路由/API/后端能力。
- 实际代码文件：`prototype/components/PrototypeApp.tsx`、`prototype/components/AppShell.tsx`、`prototype/lib/data.ts`、`prototype/app/globals.css`。`selectCategory` 同时清除旧筛选/排序，避免从另一品类带入陈旧条件。
- 本地验证：Node `v22.12.0`、pnpm `10.33.3` 下 `prototype/pnpm typecheck` 与 `prototype/pnpm lint` 通过；源码门禁确认目录根分支没有 `ProductCard`、`FilterSheet`、结果计数或排序结构，并确认买家实现无 `REBUY /`/装饰数字。未运行 build/E2E/hash；本批尚未由主代理完成浏览器复验，不写成 Owner 验收或 UI 冻结。
- 风险/回退/维护：主要风险是目录根与结果列表状态在移动/桌面返回、侧栏快捷入口和详情来源恢复中的交互回归；主代理需复验 390/430/768/1024/1440、三语、明暗主题、分类根纯目录和详情返回。若失败，局部回退 `catalogMode`/目录样式/分类文案并追加新记录；不触碰业务数据、后端、Auth、数据库、部署、CI 或生产。
- Owner Gate：G0/P1 保持“执行中（分类目录信息架构修订）”，不预填通过；下一动作是主代理浏览器复验后由 Owner 选择通过、修订或暂停。G1 继续暂停。

### 2026-08-25｜全局搜索提交按钮定向修正

- 发现：此前 `global-search` 只有装饰性 Search 图标、输入框和清除按钮，点击图标或用真实键盘 Enter 在主代理复验中未稳定触发 `handleSearchSubmit`，无法形成可见、可触控、可键盘验证的全局搜索直达结果证据。
- 修正：仅修改 `prototype/components/AppShell.tsx` 与 `prototype/app/globals.css`；将左侧 Search 图标改为现有 `search.submit` 三语文案的 `<button type="submit">`，保留现有 form `onSubmit`/`onSearchSubmit` 逻辑、输入和清除按钮；新增 44×44 命中区、hover 与 focus-visible 样式，不改变搜索状态、结果过滤、API 或路由。
- 复用/扩展/新建：复用既有 AppShell form、Search 图标、`search.submit` 翻译和现有 token；扩展 submit 语义与局部 CSS；未新增组件、依赖或业务逻辑。
- 验证：Node `v22.12.0`、pnpm `10.33.3` 下 `prototype/pnpm typecheck`、`prototype/pnpm lint` 均通过；源码门禁确认 submit 按钮存在、原生 select=0、目录 IA 与路径标签规则不回归。浏览器复验由主代理执行，当前不写成通过。
- 风险/回退：搜索栏在 390px 下新增 44px submit 命中区，需主代理复验输入空间、无横向溢出、Enter/点击均进入结果；如出现布局挤压，可局部调整该按钮/搜索布局或回退本条两文件改动，不触及数据、后端、Auth、数据库、部署、CI 或生产。
- Owner Gate：G0/P1 仍为“执行中（分类目录信息架构修订）”；Owner checkpoint 16 继续待验收，G1 仍“未开始/暂停”。

### 2026-08-25｜390px 搜索输入宽度定向修正

- 发现：主代理 390×844 实测在输入 `Voltix` 且清除按钮出现时，`.global-search input` 实际 rect 约 `24.8px` 宽；submit 与清除按钮各 44px，虽然无横向溢出，但输入可读区过窄。
- 修正：仅修改 `prototype/app/globals.css` 的 `max-width: 500px` 规则；搜索 form 改为相对定位，submit/clear 作为左右绝对定位的 44×44 控件，input 占满 form 并使用左右 `48px` 内边距避让控件。桌面布局、点击/焦点、清除按钮和 React 搜索逻辑不变。
- 验证：CSS 选择器/结构门禁确认移动断点包含 `position: relative`、input `width: 100%`/左右 48px 内边距、submit/clear 绝对定位及左右锚点；本批纯 CSS，复用前一条 Node 22 typecheck/lint 通过证据，未重复运行。浏览器需主代理复验输入 rect、点击/Enter 提交、清除和无横向溢出。
- Owner Gate：G0/P1 仍为“执行中（分类目录信息架构修订）”；checkpoint 16 继续待验收，搜索输入宽度修正不构成浏览器通过、G0 冻结或 G1 授权。

### 2026-08-25｜分类目录 IA 主代理本地浏览器复验完成

- 证据：[分类目录 IA 复验证据 manifest](../evidence/G0-P1/2026-08-25-category-directory-ia/README.md)。本条记录主代理在 `http://127.0.0.1:3000/` 的实时本地复验；本批没有落盘截图，不能伪造截图或 hash。
- 390×844 中文浅色：首页“少量推荐”先于“快速分类”，3 个推荐、4 个快捷品类，首个商品 `top=296.19`、首个快捷分类 `top=1383.95`，宽度 390，五项底栏正常。分类根 h1 为“分类目录”，4 个品类，`ProductCard=0`、`article=0`、筛选/排序/结果数均为 0，tile 最小高 88px，无溢出。
- 品类结果：手机配件 2（Voltix、Aster）、电子产品 3（Nova、Aster、Orbit）、二手交易 2（Nova、Orbit）、电脑与配件 1（Orbit）；结果页本地化标题、结果数、筛选、统一排序和返回全部分类均可见；高到低排序为 Orbit→Nova，筛选 dialog 可打开。
- 路径：推荐→详情→返回首页、快速分类→对应结果、手机配件结果→详情→返回原结果、返回全部分类→纯目录、1440 侧栏电脑与配件→Orbit 单品结果均通过；430/768/1024/1440 推荐顺序、4/0 目录、电脑 1 个结果、44px 返回和无溢出通过。
- 三语/主题：it 分类根为 `Catalogo categorie`、电脑结果 1 个 `Notebook Orbit...`；en 分类根为 `Category directory`；html/AppShell lang 同步；390 深色中文与 1440 深色意大利语分类根均 4 品类/0 商品，canvas `rgb(15,16,32)`，无溢出。
- 搜索：390 输入 Voltix 时 form `158.84px`、input `156.84px`、左右 padding `48px`、submit/clear 各 44px；点击 submit 进入“分类与搜索”并仅显示 Voltix，清除按钮清空并消失。自动化 `press("Enter")` 与 CUA Enter 本轮均未产生结果跳转；不写成键盘通过，留给后续键盘/无障碍专项和 Owner 手动复核。
- 控制台：所有最终浏览器路径 `console/page warning/error logs=[]`。静态 typecheck/lint、源码门禁、154 项 Markdown 链接/fragment、围栏和敏感模式扫描均通过；最后 CSS 修正复用前一状态 typecheck/lint 证据。未重跑 build/E2E/hash，未启动独立审查。
- 当前 Owner Gate：G0/P1 更新为“待 Owner 验收（分类目录 IA 修订及主代理本地浏览器复验完成）”，证据级别本地交互；checkpoint 16 机器证据完成但 Owner 决定仍为待验收。G1 为“未开始/暂停”，只有新的 G0“通过并冻结”后才可恢复。

### 2026-08-25 23:06:57 CEST｜分类目录 IA 通过，G0 重新冻结，恢复 G1 Entry

- Owner 最新正式决定原话：`分类目录IA通过，G0重新冻结，未覆盖项进入后续专项，恢复G1授权`。
- 当前 Gate：G0/P1 更新为“已通过并冻结”；Owner 清单 checkpoint 16 更新为“通过”。点击搜索已通过；直接 Enter 键盘提交未验证成功，转入后续键盘/无障碍专项，不阻塞本次 G0 冻结或 G1 Entry。
- G1 当前进入“准备中（Entry 已恢复授权）”，但只允许 Entry 基线准备。尚未初始化 Git、切换 Node、创建 CI/Preview、连接远端/Supabase/生产；G1 Exit Gate 未通过，G2-A0 不打开。
- 只读基线见[G1 Entry 基线证据](../evidence/G1/2026-08-25-entry-baseline/README.md)：项目根与 `prototype/` 均无 `.git`；当前 Node `v20.20.2`、pnpm `10.33.3`，`prototype/.node-version=22`，package engines/packageManager 与 lockfileVersion `9.0` 已记录；未发现 CI/部署配置；只观察 `.env.example` 两个变量名，未读值。
- G1.1 推荐项目根为唯一 Git 根、`prototype/` 为 app 目录，但该选择仍需 Owner 明确确认；确认后先建立本地 Git/ref 与 Node 22/pnpm `10.33.3` 基线，再另行决定远端/Preview。不得伪造 commit ref。
- 范围/回退：本条仅更新阶段事实和 Gate；不修改 prototype、依赖、服务器、数据库、Auth、部署或外部服务。若 G1.1 选择或版本对齐失败，停止晋级并保留本只读基线，追加纠正记录。
