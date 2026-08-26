# G0/P1 统一选择器实时验收证据

文档状态：G0 本轮统一选择器修订待 Owner 验收；不表示 UI 已冻结、G0 已通过、G1 已打开、WCAG、Staging 或生产通过。  
日期：2026-08-25（Europe/Rome）  
环境：`http://127.0.0.1:3000/`，local-only，合成数据  
commit ref：N/A；deploy ref：N/A  
截图：本轮没有落盘 PNG；以下是主代理在实时本地预览中的交互与 DOM/CSS 检查结果，不伪造截图文件或 hash。

## 1. 范围与 Owner 决定

Owner 原话：`这个点击打开的选项卡不统一 帮我为项目制作统一风格的`。

具体触发证据为分类页排序展开后显示浏览器原生蓝色菜单。本轮只验证共享 `SelectMenu<T extends string>` 对排序和语言入口的统一视觉、语义、键盘和焦点行为；不改变真实商品筛选、分类入口、五项导航、排序值、语言同步、商品/订单数据或业务规则。

## 2. 视觉与布局结果

| 视口/主题 | 页面状态 | 实际结果 |
|---|---|---|
| 499×862，浅色 | 分类页排序菜单打开 | 原生 select=0；菜单 3 项、单选 1 项；矩形 `L272/T231/R483/B381`，尺寸 `212×150`，完全位于视口内；圆角 14px；每项 44px；`scrollWidth=clientWidth=499`；白色 surface、循环翡翠青选中态，无系统蓝色 |
| 390×844，深色 | 分类页排序菜单打开 | 菜单矩形 `L204/T231/R374/B381`，完全位于视口内；`scrollWidth=clientWidth=390`；背景 `rgb(34,35,58)`、边框 `rgb(80,81,112)`；无横向溢出 |
| 1440×900，浅色 | 顶部语言菜单打开 | 菜单矩形 `L1101/T68/R1212/B218`，3 项；右对齐入口未越出视口；最终恢复中文 |

## 3. 键盘、焦点与状态结果

| 路径 | 实际操作与结果 |
|---|---|
| 499×862 排序 | `ArrowDown` + `Enter` 选择“价格从低到高”；商品卡顺序为 `Voltix → Aster → Nova → Orbit`；`End` 可到“价格从高到低” |
| 排序关闭 | `Escape` 关闭菜单并回到排序触发器 |
| 筛选联动 | 点击“筛选”会先关闭排序菜单，再打开 Filter Sheet；Sheet 首焦点为“清除条件”；`Escape` 关闭 Sheet 并回到“筛选”触发器 |
| 390×844 Tab | 排序菜单当前 option 按 `Tab`：一次按键关闭菜单并移动到“Voltix 查看”按钮；`document.activeElement` 不为 BODY |
| 390×844 Shift+Tab | 排序菜单按 `Shift+Tab`：一次按键关闭菜单并移动到“筛选”触发器；不困住焦点 |
| 1440×900 语言 | 方向键与 `End`/`Home` 完成 `zh-CN → it → en → zh-CN`，页面标题同步；`Tab` 移到深色模式按钮，`Shift+Tab` 移到搜索输入；菜单一次按键关闭且不落 BODY |

菜单使用 button、`aria-haspopup="menu"`、`aria-expanded`、`aria-controls`，弹层 `role="menu"`，选项 `role="menuitemradio"` + `aria-checked`。选择、Escape 和外部点击的焦点回归保持有效。

## 4. 控制台与代码验证

- 控制台仅有 React DevTools/HMR info/log；没有 warning 或 error。
- `prototype/ pnpm typecheck`：通过。
- `prototype/ pnpm lint`：通过。
- `prototype/`（排除 `node_modules/.next`）原生 `<select>` 扫描：`0`；旧 `.sort-control select` 与 `.topbar__locale select`：`0`。
- 未运行 build/E2E：本轮风险由类型、lint、实时浏览器矩阵覆盖；未启动额外独立审查代理，原因是普通共享 UI 调整，主代理已完成源码与浏览器综合审查。

## 5. 边界、风险与回滚

- 本证据只覆盖本地预览、合成数据和本轮排序/语言选择器；不证明真实筛选后端、权限、库存、Auth、数据库、部署或生产行为。
- 本轮没有确定性生成物或落盘截图，因此不做 hash；后续若保存截图，应使用新的证据批次，不覆盖本记录。
- 若视觉或键盘验收发现问题，可回滚 `SelectMenu` 及排序/语言调用点和相关 CSS；不触及业务数据、后端、数据库、Auth、部署或生产。
- 源码、token、字体、浏览器、视口或依赖变化后，本证据需重新验证。

## 6. Owner Gate

- 当前决定：`G0 本轮统一选择器修订待 Owner 验收`。
- 本地实时浏览器结果不等于 Owner 通过，不等于 UI 冻结。
- G1 仍为“未开始/暂停”；历史 G0 冻结与 G1 Entry 授权不因本轮选择器证据恢复。
- 下一动作：Owner 在当前本地预览中确认统一视觉、明暗主题、移动边界和键盘焦点后，选择通过、修订或暂停。
