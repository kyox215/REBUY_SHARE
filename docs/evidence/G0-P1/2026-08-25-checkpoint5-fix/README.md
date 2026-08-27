# G0/P1 checkpoint 5 二手详情首屏修订证据

证据状态：修订后机器候选，待 Owner 验收；不表示 G0/P1 通过、UI 冻结、WCAG、Staging 或生产验收。

## 文件与浏览器状态

- 修订后截图：[05-product-used-mobile-light-zh-after.png](./05-product-used-mobile-light-zh-after.png)
- 修订前截图：[05-product-used-mobile-light-zh.png](../2026-08-25/05-product-used-mobile-light-zh.png)
- 原候选画廊 manifest：[2026-08-25/README.md](../2026-08-25/README.md)
- 页面：Rebuy 买家端 Prototype 二手商品详情（Nova X4 翻新手机 128GB）
- URL：`http://127.0.0.1:3000/`
- 视口：`390×844`；`innerWidth=390`、`innerHeight=844`
- 语言：`zh-CN`；主题：浅色；根节点 `prototype-root theme-light`
- 页面尺寸：`clientWidth=390`、`scrollWidth=390`、`bodyScrollWidth=390`
- `scrollY=0`
- PNG：`390×844`，8-bit RGB，`132766` bytes
- SHA-256：`a247bee92c0137e0f8498bbecd92fbaf85f7c1a73a230b7412a0f03d044c6597`（本文件一次完整性检查）
- console/page error/warn：`[]`

## 修订后 DOM 矩形摘要

以下为浏览器实际测量的 `.detail-page--used .used-facts .fact dt/dd`；每个值的 `bottom` 均在 `844` 内，四项事实先于购买按钮。三语均为 390×844、浅色、无横向溢出，并显示对应的固定单件文案。

| 语言 | 固定单件文案 | 四项 `dt/dd` bottom（px） | 最底事实 bottom |
|---|---|---|---:|
| 中文 `zh-CN` | `二手设备固定 1 件` | 成色 `622.57/645.12`；已披露缺陷 `622.57/662.66`；电池健康 `705.66/728.21`；保修 `705.66/745.76` | 755.76 |
| 意大利语 `it` | `L'usato è fisso a 1 pezzo` | Condizioni `688.79/728.88`；Difetti dichiarati `688.79/746.43`；Salute batteria `789.43/811.98`；Garanzia `789.43/829.52` | 839.52 |
| 英语 `en` | `Used items stay at 1 unit` | Condition `655.18/677.73`；Disclosed issue `655.18/695.27`；Battery health `738.27/760.82`；Warranty `738.27/795.91` | 805.91 |

三语测量均记录 `scrollWidth=390`、`bodyScrollWidth=390`，console/page error/warn 均为 `[]`。中文修订后截图只作为本批视觉文件；意大利语和英语为同一修订代码状态下的浏览器矩形证据。

## 关联页面与边界

- 1440×900 中文二手详情：事实网格实际为 2×2，`gridTemplateColumns=269.398px 269.406px`，四张事实卡均无横向溢出。
- 390×844 中文普通商品详情：`UsedFacts` 数量为 `0`；价格、数量 `1`、加入购物车和立即购买仍存在。
- 修订只扩展二手详情的信息顺序与移动媒体高度；未改变循环翡翠青、普通商品语义、业务数据、库存规则、路由、依赖、后端或认证。
- 证据使用本地 Prototype 合成数据；未读取 cookies、localStorage、profile、密码、会话存储或 `.env`，未输入真实邮箱、客户资料或订单信息。

## 失效、回退与 Owner Gate

若相关源码、token、字体、图片、合成数据、依赖、浏览器或渲染环境变化，本证据失效，应新建批次重新截图；不得覆盖修订前历史。回退只需回退本批 `PrototypeApp.tsx`/`globals.css` 的局部 UI 改动并移除本目录证据和文档链接，不影响业务或生产数据。该截图是机器修复候选，不能预填 Owner 通过；checkpoint 5 仍需 Owner 判断“通过/修订/暂停”。
