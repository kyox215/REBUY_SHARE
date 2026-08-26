# G0/P1 移动 App 标题层级修订证据

文档状态：源码门禁与主代理本地交互候选，待 Owner 复验；不表示 G0/UI 冻结、WCAG、Staging 或生产通过。  
日期：2026-08-25（Europe/Rome）  
环境：`http://127.0.0.1:3000/`，local-only，合成数据  
commit ref：N/A；deploy ref：N/A

## 1. 修订目标

Owner 原话：`整个项目当中不要出现类似这样的目录，我要的是移动端app的那种体验`。

本批移除买家端路径/面包屑式 `REBUY / CATALOG`、`Rebuy / cart`、`Rebuy / orders`、`Rebuy / local sample`，以及首页、详情、结账、订单详情、个人页 section heading 的纯装饰 `01`/`02`/`03`。商品分类、五项底部导航、订单批次/商家子订单和身份语义分支保留。

## 2. 候选二进制（不替代本批交互证据）

- 文件：[分类页移动端浅色中文 after](./01-category-mobile-light-zh-after.png)
- 页面：分类与搜索
- 视口：`390×844`
- 语言：`zh-CN`
- 主题：浅色
- `scrollY`：`0`
- `clientWidth/scrollWidth`：`390/390`
- PNG：`390×844`，`118251` bytes，SHA-256 `c06ba6a4f277680889ec97a0d2b57c35c30768ef99394720c21a81b566f6d9e6`
- 观察摘要：文件对应分类页移动浅色中文候选画面；本 manifest 不把该 PNG 作为主代理本次交互复验的完整截图证据。

本批不将 before 截图作为归档证据；before 只用于确认修订前的 `REBUY / CATALOG` 现场状态。历史画廊和前序截图不覆盖，仍由各自 manifest 管理。截图工具未能为本批主代理复验写入新的归档截图，因此截图证据仍待 Owner 当前可见预览或后续补存；不得把上述候选 PNG 当作 G0 通过或 UI 冻结证明。

## 3. 源码与机器门禁

- 代码扫描确认 `prototype/components/PrototypeApp.tsx` 不再出现 `Rebuy /`、`REBUY /` 或 `01`/`02`/`03` 装饰 eyebrow；详情标题/数量、购物车总计、订单批次/订单号等业务语义 eyebrow 保留。
- Node 22.12.0 PATH 下 `prototype/pnpm typecheck` 与 `prototype/pnpm lint` 均通过；本批未运行 build，未做独立审查或生产检查。
- 本地交互复验只使用 `http://127.0.0.1:3000/` 和合成数据；没有读取 cookies、localStorage、profile、密码、会话存储或 `.env`，没有外部连接或真实提交。
- 源码、token、字体、图片、合成数据、依赖、浏览器或渲染环境变化时，本证据失效；后续修订使用新日期/批次，不覆盖本文件。

## 4. 主代理真实浏览器交互复验（无截图文件）

以下结果由主代理在现有本地预览中实际完成；这是本地交互证据，不是 Owner 主观结论，也不等于截图证据、G0/UI 冻结、WCAG、Staging 或生产验收。console/page error/warn 均为 `[]`。

| 视口/语言 | 实际检查 | 结果 |
|---|---|---|
| 390×844，zh-CN，浅色 | 首页、分类、订单、空购物车、我的；五项底部导航；pathLabels=[]、numericSectionLabels=[]、overflowX=false | 主标题分别为“今天想找什么？”、“分类与搜索”、“订单”、“购物车还是空的”、“我的”；五项导航正常 |
| 390×844，zh-CN，浅色 | 分类、商品详情、购物车、结算、订单详情、登录 | 分类 h1 top=95px、首卡 top=218px；商品详情显示“商品详情”返回顶栏和 h1 商品名；购物车 h1 为“购物车”；结算顶栏为“结算确认”，h2 为“演示配送资料/商家订单摘要”；订单详情顶栏为“商家子订单”，h2 为“状态时间线/商家子订单”；登录 `/account/login` h1 为“登录 Rebuy”，无路径标签，overflowX=false |
| 390×844，it | 分类与五项导航 | `document` lang=it；h1 为“Categorie e ricerca”；五项导航正常 |
| 390×844，en | 分类与五项导航 | `document` lang=en；h1 为“Categories and search”；五项导航正常 |
| 1440×900，zh-CN，浅色 | 分类、购物车 | 分类 h1 正常、pathLabels=[]、桌面 sidebar grid 可见、bottom nav none、overflowX=false；购物车 h1 正常、2 栏布局、overflowX=false |

浏览器检查未保存 cookies/localStorage/profile/password/session 内容；未提交真实订单、认证或外部请求。截图工具未能写入新的本地归档 PNG，因此 Owner 如需截图判断仍应以当前可见预览或后续新批次为准。

#### Owner Gate

- G0/P1 仍为“待 Owner 验收”。本 manifest 的源码、机器和主代理本地交互结果不预填 Owner 决定、不冻结 UI、不打开 G1；下一动作是 Owner 按清单选择通过、修订或暂停。
