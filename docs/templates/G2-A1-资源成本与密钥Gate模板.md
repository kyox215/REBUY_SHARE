# G2-A1 资源、成本与密钥 Gate 模板

用途：在 G2-A1 Auth 技术阶段打开前，记录独立 non-production 资源、费用和密钥责任。
状态：模板，不是授权、不代表资源已创建，也不是技术验证证据。
填写原则：任何未知字段写“待确认”，不得用默认值或通用价格补全；任何 secret/PII 原值禁止进入本文件。

## 1. Gate 元数据与决定

| 字段 | 填写值 |
|---|---|
| Gate ID | `G2-A1-resource-cost-secret` |
| 记录日期（Europe/Rome） | `YYYY-MM-DD HH:MM` |
| 申请阶段/批次 | `G2-A1 / A1-B1…B4` |
| 当前 Gate 状态 | `关闭 / 待审 / 已批准 / 已拒绝 / 已过期` |
| 申请范围 | `仅独立 non-production Auth spike；synthetic-only` |
| Owner 决定人 | `待指定` |
| 安全审查人 | `待指定` |
| 成本责任人 | `待指定` |
| secret/key owner | `待指定` |
| stop contact | `待指定` |
| 生效时间 / expiry | `待确认` |
| 证据位置 | `待填写脱敏路径；不得写原值` |
| 回退记录位置 | `待填写脱敏路径` |

**Gate 规则：** Owner 明确批准前，Gate 保持关闭；A0 Exit 或“下次无需重复批准”不能代替本 Gate。任何需要创建项目、启用 provider、配置 OAuth/SMTP/Storage、读取 secret 或产生费用的动作都必须在本 Gate 通过后执行。

## 2. Provider / project / plan / region / environment

| 字段 | 填写值 | 证明方式/限制 |
|---|---|---|
| provider | `Supabase / Clerk / Auth0 / 其他（待比较）` | 记录选定事实和日期；未选定写 proposal |
| organization | `待指定` | 只记录经批准的最小标识；不在模板中写无关组织名 |
| project | `待指定` | 必须是独立 Rebuy non-production；禁止复用无关项目 |
| project ref / internal ID | `待指定；仅在授权证据允许时填写` | 不记录 host、连接串或 key |
| plan | `待确认` | 记录实际套餐，不从价格页推断 |
| region | `待确认（proposal 可为 eu-central-1 / Frankfurt）` | region 是位置选择，不等于 GDPR 合规 |
| environment | `local / preview-staging；禁止 production` | 记录隔离证明、域名和访问边界 |
| deployment target | `N/A；A1 不打开 Production` | 不写 deploy URL、cookie 或 token |
| isolation proof | `待填写` | 项目、client、redirect、SMTP、Storage、日志与 Production 分离 |
| existing resources checked | `待填写` | 不得复用与 Rebuy 无关的项目 |

## 3. Cost quote、recurrence、tax 与 spend cap

| 字段 | 填写值 | 强制说明 |
|---|---|---|
| provider exact cost quote | `待获取` | 只能在指定组织后由 provider `get_cost` 获取；不得从通用价格推断 |
| quote timestamp / currency | `待获取` | 与 provider 返回结果绑定；记录日期和币种 |
| quote scope | `项目/组织/资源清单待填写` | 明确是否包含 compute、Auth、Storage、SMTP、OAuth 等 |
| recurrence | `一次性 / 月度 / 年度 / 按用量 / 待确认` | 记录周期与计费触发，不得遗漏按量费用 |
| tax / VAT / billing address effect | `待确认` | 由账单和专业顾问核对；不把税务判断写成本模板结论 |
| included quota | `待获取` | 记录 provider 返回摘要，不记录支付凭据 |
| overage unit / cap coverage | `待获取` | 记录哪些 usage item 被覆盖，哪些不覆盖 |
| spend cap | `开启 / 关闭 / 不适用 / 待确认` | 推荐 proposal 为开启；Pro 才可用且不是细粒度预算 |
| spend cap stop behavior | `待确认` | 记录超 quota 的限制与人工处置，不自动扩大预算 |
| maximum authorized spend | `待填写` | Owner 明确金额、币种、周期和触发人 |
| alert / invoice owner | `待指定` | 负责 usage、invoice、超额和停用沟通 |
| cost approval evidence | `待填写` | 必须有 Owner 对 exact quote/recurrence/tax 的明确确认 |

精确费用的唯一流程：先指定组织和 resource scope → 调用 provider `get_cost` → 记录 exact quote、recurrence、tax、Spend Cap 与最大上限 → Owner 确认 → 才能创建/启用资源。若 provider 无法返回可核验报价，Gate 继续关闭。

## 4. Secrets / keys / access responsibility

| 资产类别 | secret 名称/引用（非原值） | owner | 保存位置/访问角色 | 轮换与撤销 | 状态 |
|---|---|---|---|---|---|
| Supabase/Provider test key | `TEST_KEY_REF_<label>` | 待指定 | 受控 secret manager；服务端最小权限 | 泄露或到期立即撤销 | 待确认 |
| Apple client secret / `.p8` | `APPLE_SECRET_REF_<label>` | 待指定 | 受控密钥系统；不入仓库/截图/chat | 轮换、告警、紧急重签和回退 | 待确认 |
| Google test client secret | `GOOGLE_SECRET_REF_<label>` | 待指定 | 受控密钥系统；不复用 Production | 轮换与撤销 | 待确认 |
| SMTP test credential | `SMTP_SECRET_REF_<label>` | 待指定 | 独立测试 SMTP 或 local catcher | A1 结束撤销 | 待确认 |
| Storage/service role | `STORAGE_ROLE_REF_<label>` | 待指定 | 仅受信服务端；A1 默认关闭 | 访问审计与撤销 | 待确认 |
| Synthetic test accounts | `SYNTH_ACCOUNT_REF_<label>` | 待指定 | 专用测试设备/账号 | A1 结束清理或冻结 | 待确认 |
| TOTP factors | `TOTP_FACTOR_REF_<label>` | 待指定 | 不记录 seed/QR/OTP；只记录标签 | 清理/撤销 | 待确认 |

密钥规则：只写 secret 名称、不可逆摘要或受控引用；不得写 token、密码、cookie、OAuth code、PKCE verifier、`state`、`nonce`、TOTP seed、OTP、`.p8`、SMTP 密码或 service role 原值。`NEXT_PUBLIC_*` 等会进入客户端的变量不得承载服务端密钥。

## 5. Redirect / OAuth / SMTP / Storage

| 资源项 | 计划值/引用 | 必须证明 | 禁止项 |
|---|---|---|---|
| OAuth providers | `Apple / Google；测试 client 待指定` | client、scope、环境和 owner 独立 | 生产 client、额外 scope、provider token 落地 |
| redirect allowlist | `https://auth-test.invalid/callback`（示例） | 精确 allowlist、环境绑定、相对 `next` | 通配外域、open redirect、生产域名 |
| callback test host | `auth-test.invalid`（示例） | 仅用于文档/合成样例 | 真实域、真实 cookie、真实 callback |
| SMTP mode | `local catcher / 独立 test SMTP / 待指定` | 不发送真实客户邮件；记录 TTL/限流/模板版本 | 生产 SMTP、真实发件人/收件人、secret 原值 |
| SMTP sender/recipient | `no-reply@auth-test.invalid` / `buyer-01@demo.invalid`（示例） | 仅 `.invalid` 合成地址 | 真实 email、真实 PII、个人邮箱 |
| Storage | `关闭 / 独立 test bucket 待授权` | A1 不需要业务文件时保持关闭；若开启须隔离与清理 | 生产 bucket、真实证件/文件、公开对象 |
| data mode | `synthetic-only` | 账号、组织、邀请、订单和文件均为合成标签 | 真实客户、商家、地址、订单或证件 |

## 6. Evidence / rollback / expiry / cleanup

| 字段 | 填写值 |
|---|---|
| evidence repository/path | `docs/evidence/G2-A1/<date>-<batch>/` |
| evidence owner | `待指定` |
| evidence retention | `待确认；只保留脱敏摘要与审计结论` |
| rollback trigger | `隔离无法证明、成本超 cap、secret 泄露、callback/MFA/session 安全失败等` |
| rollback steps | `冻结入口 → 撤销/轮换测试 key → 停止 SMTP/Storage/OAuth → 保存脱敏时间线 → 通知 Owner` |
| rollback owner | `待指定` |
| expiry date/time | `待确认` |
| expiry action | `停止测试、禁用测试入口、撤销 test client/secret、冻结账号` |
| cleanup checklist | `项目/资源/SMTP/Storage/OAuth/test accounts 清理或冻结；不删除必要审计摘要` |
| cleanup evidence | `待填写脱敏路径` |
| unresolved risks | `待填写` |
| Owner final decision | `未决定；Gate 保持关闭` |

## 7. Gate 审批签名

| 检查 | 结果 | 签名/日期 |
|---|---|---|
| provider / organization / project 已明确且独立 | `待审` | `待指定` |
| plan / region / environment 已明确 | `待审` | `待指定` |
| exact cost、recurrence、tax 已由 provider `get_cost` 返回 | `待审` | `待指定` |
| spend cap、最大支出和 stop contact 已确认 | `待审` | `待指定` |
| secret/key owner、保存、轮换、撤销已确认 | `待审` | `待指定` |
| redirect / SMTP / Storage / synthetic-only 已确认 | `待审` | `待指定` |
| evidence / rollback / expiry-cleanup 已确认 | `待审` | `待指定` |
| Owner Gate 决定 | `关闭` | `待指定` |

在所有必要字段完成、审查人和 Owner 明确签名之前，任何空白、`待确认` 或 proposal 均按未授权处理。
