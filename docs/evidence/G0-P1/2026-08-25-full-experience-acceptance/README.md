# G0/P1 全流程实时本地验收证据

文档状态：G0 总体验收机器证据已完成；等待 Owner 最终冻结/修订决定。不表示 G0 已通过、UI 已冻结、G1 已打开、WCAG、Staging 或生产通过。  
日期：2026-08-25（Europe/Rome）  
环境：本地 `http://127.0.0.1:3000/`、合成数据；无真实邮箱、订单、客户资料或外部服务  
执行角色：主代理实时本地浏览器验收；本记录由执行代理整理  
commit ref：N/A；deploy ref：N/A  
截图：本轮没有落盘新 PNG，因此不生成或声称 hash；以下是实时 DOM/CSS/交互结果。

## 1. Owner 决定与证据边界

Owner 原话：`统一选择器通过，继续G0总体验收`（2026-08-25；具体时刻未提供）。该决定只覆盖 G0/P1 Owner 清单 checkpoint 15 的统一选择器，不等于整个 G0 通过、UI 冻结、G1 Entry、生产或后端授权。

本轮复用此前统一选择器的实时证据，并记录主代理对买家端全流程的实时检查。没有提交演示订单、真实登录、支付或外部请求；登录仅使用合成 `owner-preview@example.com`，未发送邮件。

## 2. 移动端 390×844

### 首页、分类与筛选

- 中文浅色首页：普通商品卡为 `174px + 174px` 双列，二手卡 `358px` 满行；五项底部导航准确，`overflowX=false`。
- 中文深色首页：body `rgb(15,16,32)`，商品卡 `rgb(23,24,42)`，激活循环翡翠青 `rgb(83,209,190)`；无横向溢出。
- 分类/搜索：对合成词 `Nova` 使用真实 DOM 键盘 `Enter` 后得到 1 个结果；筛选二手后得到 2 个结果。Filter Sheet 打开后首焦点为“清除条件”，`Escape` 关闭并回到“筛选”；无横向溢出。

### 商品详情

- 普通商品：数量 `1→2`、加入购物车成功；进入二级页后底部导航隐藏。
- 二手商品：无数量按钮，固定 `1 件`；成色/缺陷矩形 `top=595,bottom=671`，电池/保修矩形 `top=678,bottom=754`，四项事实均在 390×844 首屏可见且可读；无横向溢出。

### 购物车、结算与订单

- 购物车：Northline Lab 2 件、Riva Devices 1 件，按商家分组，总计 `€298.80`。
- 结算：显示两家商家摘要，底部导航隐藏；未点击“提交演示订单”。
- 订单：存在 2 个演示批次；`RB-DEMO-001` 的 Northline Lab 时间线中“已提交/处理中”已完成，“配送中/已完成”未完成；订单详情底部导航隐藏且无溢出。

### 我的与登录

- “我的”三语检查：意大利语 `h1=Profilo`、`lang=it`；英语 `h1=Profile`、`lang=en`；最后恢复 `zh-CN`。已认证批发身份自动显示批发价、MOQ、阶梯价；二手仍为 MOQ 1。
- 应用内“减少动态效果” checkbox 可开启；系统 `prefers-reduced-motion:true` 本轮未模拟。
- 登录 390：浅色/深色均无溢出，Apple/Google/邮箱入口存在；只使用合成邮箱 `owner-preview@example.com`，进入 OTP 后验证码 input 自动获焦；没有发送邮件或真实认证。

## 3. 桌面端 1440×900

- 首页：Buyer sidebar `224px`；普通卡 `224px×2`，二手卡 `461px`；底部导航实际 rect 为 `0`；原生 select=0；无 KPI/仪表盘、无横向溢出。
- 分类：toolbar `936px`，网格无溢出；普通/二手详情进入二级 shell 后隐藏 sidebar/bottom nav，二手事实为 2×2。
- 购物车：主区 `568px` + summary `340px`；结算：主区 `824px` + summary `340px`；两家商家分组且无溢出。
- 订单：批次区 `936px`，订单详情 section `1192px`，无溢出。
- 登录：frame `1120px`，intro `460px`、panel `440px`，无溢出。

## 4. 三语、主题与响应式

- 1440 深色中文正常；意大利语首页 `Cosa cerchi oggi?`、分类 `Categorie e ricerca`、订单 `Ordini`；英语首页 `What are you looking for today?`、订单 `Orders`；均 `overflowX=false`，最后恢复中文浅色。
- 430 首页：普通 `194×2`、二手 `398` 满行、底部导航可见。
- 768 首页：普通 `353×2`、二手 `720` 满行、底部导航可见。
- 1024 首页：普通 `231×2`、二手 `475` 满行、sidebar 可见。
- 三个宽度的首页/分类均 `overflowX=false`。尝试设置 320 时浏览器将实际宽度 clamp 为 `innerWidth=413`；因此 320 精确视口未覆盖，不将 413 结果伪称为 320 通过；413 下 toolbar/menu 在实际视口内。

## 5. 触控、控制台与键盘证据边界

- 当前 390 主要触控目标：search input `105×44`；商品标题 `152/152/332×44`；底栏每项 `68×56`。
- 本轮 console/page warning/error 均为 0。
- 本轮没有重新取得全页 Tab 序列，因为浏览器驱动对 Tab 默认移动有限制；复用此前同源码状态下已验证的统一选择器 Tab/Shift+Tab 证据，并以本轮 Sheet、选择器、OTP、返回焦点定向路径补充。复用证据不写成新的全页 Tab 实测。
- 真实浏览器 200% 缩放未覆盖；系统减少动效 `true` 分支、完整读屏和正式 WCAG 认证未覆盖，留给 Owner/后续专项。

## 6. 隔离构建里程碑

- 实时预览未停止、未替换；本执行代理仅在 build 前只读检查 `curl http://127.0.0.1:3000/`，其隔离 shell 返回 `000`，没有启动或停止服务器。该结果不能用于判断用户侧预览，既不作通过也不作失败证据；主代理 in-app browser 在构建前后持续连接并可交互，前述浏览器矩阵是可达证据。
- 失败的隔离尝试 1：临时目录 `/tmp/rebuy-g0-build.UAapu9/prototype` 通过外部 `node_modules` symlink 复用依赖；因未切换 PATH 实际为 Node `v20.20.2`，出现 engines warning，Turbopack 报 `Symlink [project]/node_modules is invalid`，未形成 build 证据。
- 失败的隔离尝试 2：临时目录 `/tmp/rebuy-g0-build.SB761f/prototype` 使用 `cp -a` 复制 pnpm 虚拟存储，复制阶段出现 `Too many levels of symbolic links`，未运行 build。
- 最终隔离构建：临时目录 `/tmp/rebuy-g0-build.RKda6l/prototype` 排除 `.next`/`node_modules` 复制源码，再用 `rsync -a` 将现有依赖及相对链接复制到临时项目根内；命令为 `PATH=/Users/kyox215/.nvm/versions/node/v22.12.0/bin:$PATH pnpm build`。
- 最终环境：Node `v22.12.0`、pnpm `10.33.3`、Next `16.3.2`；构建完成并输出 5 个静态页面及 `/api/health/supabase` 动态路由，退出状态 `0`，成功构建无 warning/error。
- 该隔离构建只证明本地源码在临时根内可构建，不证明部署、Staging、生产、Auth、数据库、支付或真实数据通过。

## 7. 复用、跳过、回退与 Owner Gate

- 复用：既有买家路由、配色 D、五项导航、二手 `UsedFacts`、商家分组、统一 `SelectMenu` 和此前 typecheck/lint 证据；本轮没有新增业务代码。
- 跳过：正式 E2E 测试套件未运行，因为本轮无新增业务代码且主代理已完成真实浏览器业务矩阵；没有新截图/确定性生成物，不做 hash；普通 G0 视觉里程碑由主代理综合审查，不再启动额外独立审查代理。
- 回退：本轮为浏览器事实与文档追加；若 Owner 修订，追加新的修订记录和证据，不覆盖历史。构建临时目录可直接丢弃，不影响源 `prototype/` 或实时服务器。
- 当前 Owner Gate：统一选择器 checkpoint 15 为“通过”，记录了 Owner 原话 `统一选择器通过，继续G0总体验收`；G0 总体仍为“待 Owner 验收（总体验收机器证据完成，等待最终冻结/修订决定）”。G1 继续“未开始/暂停”，不得因本轮机器证据打开 G1。
