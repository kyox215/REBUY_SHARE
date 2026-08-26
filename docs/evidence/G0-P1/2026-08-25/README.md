# G0/P1 候选证据：首页移动浅色中文

证据状态：候选，待 Owner 验收；本记录不表示 G0/P1 通过、UI 冻结、WCAG 认证、Staging 或生产验收。

## 截图文件

- 截图：[01-home-mobile-light-zh.png](./01-home-mobile-light-zh.png)
- 页面：Rebuy 买家端 Prototype 首页
- URL：`http://127.0.0.1:3000/`
- 视口：`390×844`；`innerWidth=390`、`innerHeight=844`
- 页面尺寸：`clientWidth=390`、`scrollWidth=390`、`bodyScrollWidth=390`
- 滚动位置：`scrollY=0`
- 语言：`<html lang="zh-CN">`
- 主题：浅色；根节点 class 为 `prototype-root theme-light`
- PNG：`390×844`，8-bit RGB，`167466` bytes
- SHA-256：`3b4de8c25d97e2de986cbdff660174521c631e37c253c30add750f2415dd1169`（本批唯一一次完整性检查）
- 控制台与页面错误/警告：本次检查结果均为空（`[]`）

## 数据与边界

页面只使用本地 Prototype 的合成商品、商家和状态数据，不包含客户 PII、真实订单、凭据、token 或外部服务内容。本批没有读取 cookies、localStorage、浏览器 profile、密码、会话存储或 `.env`。截图是机器辅助候选视觉基线，不替代 Owner 对配色、层级、密度、可读性、焦点和交互的主观判断。

它对应 [G0/P1 Owner 视觉验收清单](../../../stages/G0-P1-Owner视觉验收清单.md) 的 checkpoint 1，仅为 Owner 提供可复核的首页首屏参考；决定栏仍必须由 Owner 填写，G0/P1 仍保持“待 Owner 验收”。

## 失效、修订与维护

如果影响首页的源码、配色 token、字体、图片、合成数据、依赖版本或浏览器/渲染环境发生变化，本截图应视为失效并重新生成。不得覆盖本历史文件；修订请新建日期/批次目录和文件，并在对应 manifest 中记录新的元数据与 hash。若本地服务不可达，应记录暂停，不以旧截图代替当前预览。

本批没有修改 prototype 源码、依赖、服务器、数据库、部署或生产数据；回退只需移除本批候选证据文件及其文档链接，不影响产品代码或业务状态。

## 2026-08-25 候选视觉评审画廊

本节追加 checkpoint 2、3、4、5、6、7、9、11、12 的机器辅助候选画面；所有画面仍为“候选/待 Owner 验收”，不表示 G0/P1 通过、UI 冻结、WCAG、Staging 或生产验收。原有 01 记录保留不变；本批未重新计算 01 的 hash，沿用原记录。

页面均来自 `http://127.0.0.1:3000/` 本地 Prototype 和合成数据，未读取 cookies、localStorage、profile、密码、会话存储或 `.env`，没有输入真实邮箱或其他个人资料。每张新增/修订图均记录一次与最终文件对应的 SHA-256；所有本批浏览器 console/page error/warn 摘要均为 `[]`。

### 画廊 manifest

| 文件 | checkpoint / 页面状态 | 视口、主题、语言、滚动 | 关键合成状态 | PNG / bytes | SHA-256 | console/page |
|---|---|---|---|---:|---|---|
| [01-home-mobile-light-zh.png](./01-home-mobile-light-zh.png) | 1：首页首屏 | 390×844，浅色，zh-CN，`scrollY=0` | 原有首页基线；沿用前批记录 | 390×844 / 167466 | `3b4de8c25d97e2de986cbdff660174521c631e37c253c30add750f2415dd1169` | `[]` |
| [02-home-mobile-dark-zh.png](./02-home-mobile-dark-zh.png) | 2：首页深色 | 390×844，深色，zh-CN，`scrollY=0`；`scrollWidth=390` | 首页搜索、分类、普通双列与二手卡 | 390×844 / 173432 | `96f532adc3b281f4c04f50545db288da27c91076e7811f9994fa0e3849b90f5b` | `[]` |
| [03-category-filter-mobile-light-zh.png](./03-category-filter-mobile-light-zh.png) | 3：分类筛选 Sheet 打开 | 390×844，浅色，zh-CN，`scrollY=0`；`scrollWidth=390` | 分类 4 个结果；筛选 Sheet 可见，包含全部/全新/二手/有货与应用筛选 | 390×844 / 133115 | `b20510bd4fae1cf3d8c9c0c9fae96f991a98255bb4ece0ecbc7865893bcabdc6` | `[]` |
| [04-product-new-mobile-light-zh.png](./04-product-new-mobile-light-zh.png) | 4：普通商品详情 | 390×844，浅色，zh-CN，`scrollY=0`；`scrollWidth=390` | Voltix 充电器；价格、库存、数量、加入购物车/立即购买 | 390×844 / 137882 | `f749d960f60a813d2a6e19c3855af78ecd1ec3cf5e0e0ef2daf5030385fefc06` | `[]` |
| [05-product-used-mobile-light-zh.png](./05-product-used-mobile-light-zh.png) | 5：二手商品详情，**修订前证据** | 390×844，浅色，zh-CN，`scrollY=0`；`scrollWidth=390` | Nova X4；固定 1 件，成色/缺陷/电池/保修区域位于标题下方 | 390×844 / 114637 | `23cf6ac5708d03db2fb626d2df466b0b243c1e4fdacb4f03d76d8f4a6cc23074` | `[]` |
| [06-cart-mobile-light-zh.png](./06-cart-mobile-light-zh.png) | 6：购物车多商家分组 | 390×844，浅色，zh-CN，`scrollY=0`；`scrollWidth=390` | Northline Lab 与 Riva Devices 两个合成商家分组；未提交结算 | 390×844 / 132465 | `611f159ce3b61d7521524c68d845520c0998eac3335a822edafb7babf004e899` | `[]` |
| [07-order-detail-mobile-light-zh.png](./07-order-detail-mobile-light-zh.png) | 7：订单商家子订单详情 | 390×844，浅色，zh-CN，`scrollY=0`；`scrollWidth=390` | `RB-DEMO-001`、Northline Lab、处理中、状态时间线与商家小计 | 390×844 / 91355 | `40ac7d24a36df9a5d0247ef5df53dcc60698e060502059c66ce19da47b06132b` | `[]` |
| [08-home-desktop-light-zh.png](./08-home-desktop-light-zh.png) | 9：首页桌面顶部 | 1440×900，浅色，zh-CN，`scrollY=0`；`scrollWidth=1440` | 约 224px 分类侧栏、顶部搜索/语言/主题/购物车、首页商品流 | 1440×900 / 353053 | `3cb8c46aae66c3979a01fc8e8ed2c731cbbbda02ed269cfb74209615184efde2` | `[]` |
| [08-home-desktop-dark-zh.png](./08-home-desktop-dark-zh.png) | 11：桌面深色抽查；原 08 浅色命名错误，已保留并改名 | 1440×900，深色，zh-CN，`scrollY=0`；`scrollWidth=1440` | 同一桌面首页结构；仅作为深色候选证据，不替代三语完整检查 | 1440×900 / 356265 | `671a170641e573aec46c2a15889901e688e88520e79c60f6e03167ad04021220` | `[]` |
| [09-login-desktop-light-zh.png](./09-login-desktop-light-zh.png) | 12：登录演示桌面初始表单 | 1440×900，浅色，zh-CN，`scrollY=0`；`scrollWidth=1440` | `/account/login`；邮箱为空，Apple/Google 占位入口可见，未输入真实资料 | 1440×900 / 137002 | `6f16200c7c7854b12849cf41ef2a5b75acfcecd9e2a50ee7dfdba50b75700f2b` | `[]` |

### 05 二手首屏修订发现

图 05 是实际修订前画面：在 390×844 首屏中只能看到“二手购买事实”标题，成色、已披露缺陷、电池健康、保修具体内容没有进入视口。该项是 checkpoint 5 的明确视觉修订发现，不得写成机器通过；Owner 仍需决定修订方向，修订后应新建批次截图，不覆盖本文件。

### 失效与维护

若影响这些页面的源码、配色 token、字体、图片、合成数据、依赖、浏览器或渲染环境发生变化，相关截图全部或部分失效，应重新生成。错误命名的 08 深色图已改名保留，历史证据不得覆盖；任何修订使用新的日期/批次文件并记录新的元数据与 hash。回退只涉及本批证据文件、manifest 与文档链接，不触及 prototype 源码、业务数据、服务器、数据库、部署或生产。
