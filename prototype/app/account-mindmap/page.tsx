import type { Metadata } from "next";
import Link from "next/link";
import {
  BadgeCheck,
  BriefcaseBusiness,
  Building2,
  FileLock2,
  FileText,
  Fingerprint,
  KeyRound,
  LockKeyhole,
  LogIn,
  Milestone,
  Route,
  Scale,
  ShieldCheck,
  ShoppingBag,
  Store,
  Users,
} from "lucide-react";
import styles from "./mindmap.module.css";

export const metadata: Metadata = {
  title: "账号系统思维导图 | Rebuy",
  description: "Rebuy V1 账号系统的只读本地规划视图。",
};

const coreBranches = [
  {
    id: "identity",
    icon: Fingerprint,
    eyebrow: "Identity",
    title: "认证",
    summary: "证明登录主体是谁，不代表任何经营或组织权限。",
    facts: [
      "Apple、Google、邮箱 OTP",
      "Magic Link 兼容后备",
      "identity linking 需安全校验",
      "AAL1 / AAL2 与会话状态",
    ],
  },
  {
    id: "membership",
    icon: Building2,
    eyebrow: "Membership",
    title: "组织 / 店铺",
    summary: "明确用户属于哪个组织，以及可进入哪些店铺。",
    facts: [
      "organizations 与 stores",
      "memberships 与 store scopes",
      "用户不直接挂 store_id",
      "同一用户可切换多个组织",
    ],
  },
  {
    id: "authorization",
    icon: ShieldCheck,
    eyebrow: "Authorization",
    title: "角色权限",
    summary: "角色是权限点集合，实际动作始终按当前上下文判断。",
    facts: [
      "平台 / 商家 / 批发角色分离",
      "permission point 默认拒绝",
      "Next.js 服务端实时授权",
      "Postgres RLS 最终边界",
    ],
  },
  {
    id: "verification",
    icon: BadgeCheck,
    eyebrow: "Verification",
    title: "经营资格",
    summary: "商家入驻与批发采购分别审核，资格不等于角色。",
    facts: [
      "商家申请审批后原子开店",
      "批发公司资格独立审批",
      "资格暂停 / 到期立即失效",
      "批发价格由有效资格决定",
    ],
  },
] as const;

const accountPaths = [
  { icon: ShoppingBag, title: "访客", detail: "公开浏览 · 临时购物车" },
  { icon: Users, title: "零售买家", detail: "自助注册 · 本人订单与售后" },
  { icon: BriefcaseBusiness, title: "批发公司", detail: "资格审批 · 采购与账务角色" },
  { icon: Store, title: "商家", detail: "入驻审批 · 组织与店铺" },
  { icon: Users, title: "商家员工", detail: "仅邀请 · 角色与店铺 scope" },
  { icon: ShieldCheck, title: "平台员工", detail: "仅邀请 · 职责分离" },
] as const;

const roadmap = [
  ["A0", "ADR / 威胁模型"],
  ["A1", "Auth spike"],
  ["A2", "买家账号"],
  ["A3", "组织邀请"],
  ["A4", "商家 / 批发审核"],
  ["A5", "MFA / 审计 / 隐私"],
  ["A6", "小范围试运行"],
] as const;

export default function AccountMindmapPage() {
  return (
    <main className={`theme-light ${styles.page}`}>
      <div className={styles.shell}>
        <header className={styles.header}>
          <div className={styles.headerMeta}>
            <span className={styles.kicker}>账号系统 · 内部规划视图</span>
            <span className={styles.status}>
              <BadgeCheck aria-hidden="true" size={15} strokeWidth={2} />
              A0 执行中 · 待验收
            </span>
          </div>
          <h1>账号系统思维导图</h1>
          <p>
            多商家、批发与零售共用一套身份入口，组织关系、权限与经营资格分别核验。
          </p>
          <div className={styles.headerCommands}>
            <span className={styles.revision}>原型视图 v1.1 · 2026-08-25</span>
            <Link className={styles.prototypeLink} href="/account/login">
              <LogIn aria-hidden="true" size={16} strokeWidth={1.9} />
              查看登录原型
            </Link>
          </div>
        </header>

        <section className={styles.coreSection} aria-labelledby="core-map-title">
          <div className={styles.sectionHeading}>
            <div>
              <span className={styles.kicker}>核心四层</span>
              <h2 id="core-map-title">登录账号不等于业务权限</h2>
            </div>
            <p>Identity → Membership → Authorization → Verification</p>
          </div>

          <div className={styles.coreMap}>
            <div className={styles.rootNode}>
              <span className={styles.rootIcon} aria-hidden="true">
                <KeyRound size={22} strokeWidth={1.9} />
              </span>
              <span>
                <small>中心根节点</small>
                <strong>Rebuy 账号系统 V1</strong>
              </span>
            </div>

            <div className={styles.coreBranches}>
              {coreBranches.map((branch) => {
                const Icon = branch.icon;

                return (
                  <article className={styles.coreNode} data-tone={branch.id} key={branch.id}>
                    <div className={styles.nodeHeader}>
                      <span className={styles.nodeIcon} aria-hidden="true">
                        <Icon size={21} strokeWidth={1.9} />
                      </span>
                      <span>
                        <small>{branch.eyebrow}</small>
                        <h3>{branch.title}</h3>
                      </span>
                    </div>
                    <p>{branch.summary}</p>
                    <ul>
                      {branch.facts.map((fact) => (
                        <li key={fact}>{fact}</li>
                      ))}
                    </ul>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section className={styles.pathsSection} aria-labelledby="paths-title">
          <div className={styles.sectionHeading}>
            <div>
              <span className={styles.kicker}>Account paths</span>
              <h2 id="paths-title">账号路径</h2>
            </div>
            <Route aria-hidden="true" size={22} strokeWidth={1.8} />
          </div>
          <div className={styles.pathGrid}>
            {accountPaths.map((path) => {
              const Icon = path.icon;

              return (
                <div className={styles.pathNode} key={path.title}>
                  <Icon aria-hidden="true" size={18} strokeWidth={1.8} />
                  <span>
                    <strong>{path.title}</strong>
                    <small>{path.detail}</small>
                  </span>
                </div>
              );
            })}
          </div>
        </section>

        <div className={styles.supportGrid}>
          <section className={styles.supportSection} aria-labelledby="login-title">
            <div className={styles.supportTitle}>
              <LogIn aria-hidden="true" size={20} strokeWidth={1.9} />
              <div>
                <span className={styles.kicker}>V1 Identity</span>
                <h2 id="login-title">登录入口</h2>
              </div>
            </div>
            <div className={styles.loginMethods}>
              <span>Apple</span>
              <span>Google</span>
              <span>邮箱 OTP</span>
            </div>
            <p className={styles.redline}>
              OAuth 只建立 identity，不授予 membership、商家资格或批发权限。
            </p>
          </section>

          <section className={styles.supportSection} aria-labelledby="security-title">
            <div className={styles.supportTitle}>
              <LockKeyhole aria-hidden="true" size={20} strokeWidth={1.9} />
              <div>
                <span className={styles.kicker}>Security boundaries</span>
                <h2 id="security-title">安全红线</h2>
              </div>
            </div>
            <ul className={styles.compactList}>
              <li>PKCE / state / nonce 与精确 redirect allowlist</li>
              <li>高风险动作实时校验 membership、AAL 与重新认证</li>
              <li>浏览器无 service role，JWT 陈旧时默认拒绝</li>
              <li>Apple relay 规划支持，待 A1 验证；identity 合并受审计</li>
            </ul>
          </section>

          <section className={styles.supportSection} aria-labelledby="gdpr-title">
            <div className={styles.supportTitle}>
              <Scale aria-hidden="true" size={20} strokeWidth={1.9} />
              <div>
                <span className={styles.kicker}>Privacy</span>
                <h2 id="gdpr-title">GDPR</h2>
              </div>
            </div>
            <ul className={styles.compactList}>
              <li>数据最小化与目的限制</li>
              <li>证明文件私有存储，使用短时签名 URL</li>
              <li>支持导出、更正、删除与限制处理请求</li>
              <li>账号删除与订单、财务法定留存分离</li>
            </ul>
          </section>

          <section className={styles.supportSection} aria-labelledby="facts-title">
            <div className={styles.supportTitle}>
              <FileLock2 aria-hidden="true" size={20} strokeWidth={1.9} />
              <div>
                <span className={styles.kicker}>Business facts</span>
                <h2 id="facts-title">商家与批发事实</h2>
              </div>
            </div>
            <ul className={styles.compactList}>
              <li>商家批准原子创建组织、店铺、owner membership 与 scope</li>
              <li>批发资格独立审批，不能由登录方式或角色名推断</li>
              <li>员工仅邀请，撤销后高风险动作实时校验；旧 access token 可能到 exp 才失效</li>
              <li>批发价格同时受资格、组织、商品与库存规则约束</li>
            </ul>
          </section>
        </div>

        <section className={styles.roadmapSection} aria-labelledby="roadmap-title">
          <div className={styles.sectionHeading}>
            <div>
              <span className={styles.kicker}>Owner gates</span>
              <h2 id="roadmap-title">A0–A6 路线</h2>
            </div>
            <Milestone aria-hidden="true" size={22} strokeWidth={1.8} />
          </div>
          <ol className={styles.roadmap}>
            {roadmap.map(([phase, title]) => (
              <li key={phase}>
                <span>{phase}</span>
                <strong>{title}</strong>
              </li>
            ))}
          </ol>
        </section>

        <footer className={styles.footer}>
          <FileText aria-hidden="true" size={17} strokeWidth={1.8} />
          <span>查看完整规划文档</span>
          <code>docs/08-账号系统思维导图.md</code>
        </footer>
      </div>
    </main>
  );
}
