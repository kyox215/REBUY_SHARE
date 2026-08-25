export type Locale = "zh" | "it" | "en";
export type Role = "guest" | "retail" | "wholesale";
export type ProductKind = "new" | "used";
export type SpriteVariant = "phone" | "charger" | "headphones" | "laptop";
export type StockState = "in-stock" | "low-stock" | "out-of-stock";
export type OrderStatus = "submitted" | "processing" | "shipping" | "completed";
export type PrimaryView = "home" | "catalog" | "orders" | "cart" | "profile";
export type DetailView = "detail" | "checkout" | "order-detail";
export type AppView = PrimaryView | DetailView;
export type Localized = Record<Locale, string>;
export type HtmlLocale = "zh-CN" | "it" | "en";

const htmlLocaleByLocale: Record<Locale, HtmlLocale> = {
  zh: "zh-CN",
  it: "it",
  en: "en",
};

export function localeToHtmlLang(locale: Locale): HtmlLocale {
  return htmlLocaleByLocale[locale];
}

export type WholesaleLadder = {
  minimum: number;
  price: number;
};

export type UsedFacts = {
  condition: Localized;
  defect: Localized;
  battery: Localized;
  warranty: Localized;
};

export type Product = {
  id: string;
  kind: ProductKind;
  sprite: SpriteVariant;
  merchant: string;
  name: Localized;
  summary: Localized;
  retailPrice: number;
  wholesalePrice: number;
  wholesaleMinimum: number;
  wholesaleLadders: WholesaleLadder[];
  inventory: number;
  lowStockThreshold: number;
  unit: Localized;
  usedFacts?: UsedFacts;
};

export type CartItem = {
  productId: string;
  quantity: number;
};

export type OrderItemSnapshot = {
  productId: string;
  quantity: number;
  unitPrice: number;
};

export type MerchantOrder = {
  id: string;
  merchant: string;
  status: OrderStatus;
  delivery: Localized;
  items: OrderItemSnapshot[];
  subtotal: number;
};

export type OrderBatch = {
  id: string;
  createdAt: Localized;
  status: OrderStatus;
  role: Exclude<Role, "guest">;
  merchantOrders: MerchantOrder[];
};

const local = (zh: string, it: string, en: string): Localized => ({ zh, it, en });

export const copy: Record<Locale, Record<string, string>> = {
  zh: {
    "nav.home": "首页",
    "nav.catalog": "分类",
    "nav.orders": "订单",
    "nav.cart": "购物车",
    "nav.profile": "我的",
    "home.greeting": "今天想找什么？",
    "home.subtitle": "在多个虚构商家之间，清楚比较电子产品与配件。",
    "home.categories": "快速分类",
    "home.recommended": "少量推荐",
    "home.viewAll": "查看全部",
    "search.placeholder": "搜索商品、品牌或型号",
    "search.submit": "搜索",
    "catalog.title": "分类与搜索",
    "catalog.directoryTitle": "分类目录",
    "catalog.directoryNote": "选择一个品类查看商品列表",
    "catalog.backToCategories": "返回全部分类",
    "catalog.results": "个结果",
    "catalog.filter": "筛选",
    "catalog.sort": "排序",
    "catalog.sortLow": "价格从低到高",
    "catalog.sortHigh": "价格从高到低",
    "catalog.noResults": "没有找到匹配商品",
    "catalog.noResultsNote": "保留当前关键词，试试清除筛选或换一个更短的词。",
    "catalog.clear": "清除条件",
    "catalog.filterTitle": "筛选商品",
    "catalog.filterApplied": "已应用筛选",
    "catalog.resultCount": "结果",
    "category.electronics": "电子产品",
    "category.accessories": "手机配件",
    "category.used": "二手交易",
    "category.computers": "电脑与配件",
    "filter.all": "全部",
    "filter.new": "全新",
    "filter.used": "二手",
    "filter.inStock": "有货",
    "product.new": "全新",
    "product.used": "二手",
    "product.single": "单件",
    "product.inStock": "有货",
    "product.lowStock": "库存紧张",
    "product.outOfStock": "暂时无货",
    "product.available": "可购",
    "price.retail": "零售价",
    "price.wholesale": "批发价",
    "price.minimum": "起订",
    "price.ladder": "阶梯价",
    "price.reference": "零售价参照",
    "buttons.add": "加入购物车",
    "buttons.buy": "立即购买",
    "buttons.back": "返回",
    "buttons.continue": "继续购物",
    "buttons.checkout": "继续结算",
    "buttons.submit": "提交演示订单",
    "buttons.submitting": "正在确认",
    "buttons.view": "查看",
    "buttons.change": "修改",
    "buttons.remove": "移除",
    "buttons.retry": "重试",
    "buttons.demoCart": "加入跨商家演示组合",
    "buttons.goOrders": "查看订单",
    "buttons.close": "关闭",
    "buttons.apply": "应用筛选",
    "buttons.clear": "清除",
    "buttons.decrease": "减少数量",
    "buttons.increase": "增加数量",
    "details.title": "商品详情",
    "details.specs": "规格与包装",
    "details.delivery": "配送与售后",
    "details.seller": "商家",
    "details.inventory": "库存事实",
    "details.quantity": "购买数量",
    "details.package": "包装单位",
    "details.policy": "虚构演示政策",
    "used.title": "二手购买事实",
    "used.condition": "成色",
    "used.defect": "已披露缺陷",
    "used.battery": "电池健康",
    "used.warranty": "保修",
    "cart.title": "购物车",
    "cart.empty": "购物车还是空的",
    "cart.emptyNote": "先去浏览一些虚构商品，再回来按商家核对。",
    "cart.shopNow": "去浏览商品",
    "cart.subtotal": "商品小计",
    "cart.total": "合计",
    "cart.sellerSubtotal": "商家小计",
    "cart.quantity": "数量",
    "cart.singleItem": "二手设备固定 1 件",
    "cart.loginRequired": "游客可以加购，但提交前需要进入演示身份。",
    "checkout.title": "结算确认",
    "checkout.demoAddress": "演示配送资料",
    "checkout.demoAddressPoint": "演示收货点",
    "checkout.demoAddressNote": "仅用于本地预览，不会产生真实配送或支付。",
    "checkout.shipping": "配送说明",
    "checkout.shippingNote": "各商家分别确认配送条件；本原型不连接承运商。",
    "checkout.payment": "支付说明",
    "checkout.paymentNote": "本地演示不会触发支付、库存写入或外部通知。",
    "checkout.summary": "商家订单摘要",
    "checkout.guestBlock": "游客不能提交订单，请在“我的”中选择一个演示身份。",
    "checkout.success": "订单批次已创建",
    "checkout.successNote": "这是本地内存演示，已按商家生成子订单。",
    "orders.title": "订单",
    "orders.empty": "还没有演示订单",
    "orders.emptyNote": "提交一次本地演示后，这里会显示订单批次和商家子订单。",
    "orders.batch": "订单批次",
    "orders.suborders": "个商家子订单",
    "orders.suborder": "商家子订单",
    "orders.timeline": "状态时间线",
    "orders.items": "件商品",
    "orders.openDetail": "查看子订单",
    "profile.title": "我的",
    "profile.identity": "演示身份样本",
    "profile.demoNote": "仅供本地原型测试；生产价格仍由认证身份自动决定。",
    "profile.retail": "零售客户",
    "profile.wholesale": "已认证批发客户",
    "profile.guest": "游客预览",
    "profile.retailStatus": "当前显示零售价",
    "profile.wholesaleStatus": "当前自动显示批发条件",
    "profile.guestStatus": "可浏览和加购，不能提交",
    "profile.language": "语言",
    "profile.appearance": "外观与无障碍",
    "profile.dark": "深色模式",
    "profile.light": "浅色模式",
    "profile.reduced": "减少动态效果",
    "profile.on": "已开启",
    "profile.off": "未开启",
    "profile.wholesaleCard": "批发身份样本",
    "profile.wholesaleCardNote": "打开后，商品价格、起订量和阶梯价会随身份自动更新。",
    "profile.demoOnly": "本地原型 · 不连接外部服务",
    "status.submitted": "已提交",
    "status.processing": "处理中",
    "status.shipping": "配送中",
    "status.completed": "已完成",
    "status.delivery": "演示配送条件",
    "status.available": "可购买",
    "toast.added": "已加入购物车",
    "toast.demoCart": "已加入两个虚构商家的演示商品",
    "toast.orderCreated": "本地订单批次已创建",
    "toast.removed": "商品已移除",
    "notice.demo": "这是 Rebuy 本地视觉原型；“Rebuy”是可替换的工作名。",
  },
  it: {
    "nav.home": "Home",
    "nav.catalog": "Categorie",
    "nav.orders": "Ordini",
    "nav.cart": "Carrello",
    "nav.profile": "Profilo",
    "home.greeting": "Cosa cerchi oggi?",
    "home.subtitle": "Confronta con chiarezza prodotti tech e accessori di negozi demo.",
    "home.categories": "Categorie rapide",
    "home.recommended": "Scelti per te",
    "home.viewAll": "Vedi tutto",
    "search.placeholder": "Cerca prodotto, marca o modello",
    "search.submit": "Cerca",
    "catalog.title": "Categorie e ricerca",
    "catalog.directoryTitle": "Catalogo categorie",
    "catalog.directoryNote": "Scegli una categoria per vedere i prodotti",
    "catalog.backToCategories": "Torna a tutte le categorie",
    "catalog.results": "risultati",
    "catalog.filter": "Filtra",
    "catalog.sort": "Ordina",
    "catalog.sortLow": "Prezzo crescente",
    "catalog.sortHigh": "Prezzo decrescente",
    "catalog.noResults": "Nessun prodotto trovato",
    "catalog.noResultsNote": "Mantieni la ricerca e prova a rimuovere un filtro o usa una parola più breve.",
    "catalog.clear": "Azzera condizioni",
    "catalog.filterTitle": "Filtra prodotti",
    "catalog.filterApplied": "Filtri applicati",
    "catalog.resultCount": "Risultati",
    "category.electronics": "Elettronica",
    "category.accessories": "Accessori telefono",
    "category.used": "Seconda mano",
    "category.computers": "Computer e accessori",
    "filter.all": "Tutti",
    "filter.new": "Nuovo",
    "filter.used": "Usato",
    "filter.inStock": "Disponibile",
    "product.new": "Nuovo",
    "product.used": "Usato",
    "product.single": "Pezzo singolo",
    "product.inStock": "Disponibile",
    "product.lowStock": "Scorte limitate",
    "product.outOfStock": "Non disponibile",
    "product.available": "Acquistabile",
    "price.retail": "Prezzo retail",
    "price.wholesale": "Prezzo ingrosso",
    "price.minimum": "Minimo",
    "price.ladder": "Prezzo a scaglioni",
    "price.reference": "Riferimento retail",
    "buttons.add": "Aggiungi al carrello",
    "buttons.buy": "Acquista ora",
    "buttons.back": "Indietro",
    "buttons.continue": "Continua lo shopping",
    "buttons.checkout": "Vai al pagamento",
    "buttons.submit": "Invia ordine demo",
    "buttons.submitting": "Conferma in corso",
    "buttons.view": "Apri",
    "buttons.change": "Modifica",
    "buttons.remove": "Rimuovi",
    "buttons.retry": "Riprova",
    "buttons.demoCart": "Aggiungi set demo multi-negozio",
    "buttons.goOrders": "Vedi ordini",
    "buttons.close": "Chiudi",
    "buttons.apply": "Applica filtri",
    "buttons.clear": "Azzera",
    "buttons.decrease": "Diminuisci quantità",
    "buttons.increase": "Aumenta quantità",
    "details.title": "Dettaglio prodotto",
    "details.specs": "Specifiche e confezione",
    "details.delivery": "Consegna e assistenza",
    "details.seller": "Negozio",
    "details.inventory": "Dati di disponibilità",
    "details.quantity": "Quantità",
    "details.package": "Unità di confezione",
    "details.policy": "Condizioni demo",
    "used.title": "Fatti dell'usato",
    "used.condition": "Condizioni",
    "used.defect": "Difetti dichiarati",
    "used.battery": "Salute batteria",
    "used.warranty": "Garanzia",
    "cart.title": "Carrello",
    "cart.empty": "Il carrello è vuoto",
    "cart.emptyNote": "Sfoglia alcuni prodotti demo e torna qui per controllarli per negozio.",
    "cart.shopNow": "Sfoglia prodotti",
    "cart.subtotal": "Subtotale prodotti",
    "cart.total": "Totale",
    "cart.sellerSubtotal": "Subtotale negozio",
    "cart.quantity": "Quantità",
    "cart.singleItem": "L'usato è fisso a 1 pezzo",
    "cart.loginRequired": "Un ospite può aggiungere prodotti, ma deve scegliere un'identità demo per inviare.",
    "checkout.title": "Conferma ordine",
    "checkout.demoAddress": "Dati di consegna demo",
    "checkout.demoAddressPoint": "Punto di consegna demo",
    "checkout.demoAddressNote": "Solo anteprima locale: nessuna consegna o pagamento reale.",
    "checkout.shipping": "Consegna",
    "checkout.shippingNote": "Ogni negozio conferma le proprie condizioni; nessun corriere è collegato.",
    "checkout.payment": "Pagamento",
    "checkout.paymentNote": "La demo non attiva pagamenti, scritture di stock o notifiche esterne.",
    "checkout.summary": "Riepilogo per negozio",
    "checkout.guestBlock": "Gli ospiti non possono inviare. Scegli un'identità demo in Profilo.",
    "checkout.success": "Batch ordine creato",
    "checkout.successNote": "Demo locale in memoria, divisa in ordini per negozio.",
    "orders.title": "Ordini",
    "orders.empty": "Nessun ordine demo",
    "orders.emptyNote": "Dopo un invio locale vedrai batch e ordini dei singoli negozi.",
    "orders.batch": "Batch ordine",
    "orders.suborders": "ordini negozio",
    "orders.suborder": "Ordine negozio",
    "orders.timeline": "Cronologia stato",
    "orders.items": "articoli",
    "orders.openDetail": "Apri ordine",
    "profile.title": "Profilo",
    "profile.identity": "Identità demo",
    "profile.demoNote": "Solo per test locale; in produzione il prezzo dipende automaticamente dall'autenticazione.",
    "profile.retail": "Cliente retail",
    "profile.wholesale": "Cliente ingrosso verificato",
    "profile.guest": "Visitatore",
    "profile.retailStatus": "Mostra il prezzo retail",
    "profile.wholesaleStatus": "Mostra automaticamente le condizioni wholesale",
    "profile.guestStatus": "Può sfogliare e aggiungere, non inviare",
    "profile.language": "Lingua",
    "profile.appearance": "Aspetto e accessibilità",
    "profile.dark": "Tema scuro",
    "profile.light": "Tema chiaro",
    "profile.reduced": "Riduci animazioni",
    "profile.on": "Attivo",
    "profile.off": "Non attivo",
    "profile.wholesaleCard": "Campione cliente ingrosso",
    "profile.wholesaleCardNote": "Prezzi, minimo e scaglioni seguono automaticamente l'identità.",
    "profile.demoOnly": "Prototipo locale · nessun servizio esterno",
    "status.submitted": "Inviato",
    "status.processing": "In lavorazione",
    "status.shipping": "In consegna",
    "status.completed": "Completato",
    "status.delivery": "Condizioni demo",
    "status.available": "Acquistabile",
    "toast.added": "Aggiunto al carrello",
    "toast.demoCart": "Aggiunti prodotti demo di due negozi",
    "toast.orderCreated": "Batch ordine locale creato",
    "toast.removed": "Prodotto rimosso",
    "notice.demo": "Questo è il prototipo visivo locale Rebuy; “Rebuy” è un nome di lavoro sostituibile.",
  },
  en: {
    "nav.home": "Home",
    "nav.catalog": "Categories",
    "nav.orders": "Orders",
    "nav.cart": "Cart",
    "nav.profile": "Profile",
    "home.greeting": "What are you looking for today?",
    "home.subtitle": "Compare tech and accessories clearly across fictional shops.",
    "home.categories": "Quick categories",
    "home.recommended": "A few picks",
    "home.viewAll": "View all",
    "search.placeholder": "Search products, brands or models",
    "search.submit": "Search",
    "catalog.title": "Categories and search",
    "catalog.directoryTitle": "Category directory",
    "catalog.directoryNote": "Choose a category to see its products",
    "catalog.backToCategories": "Back to all categories",
    "catalog.results": "results",
    "catalog.filter": "Filter",
    "catalog.sort": "Sort",
    "catalog.sortLow": "Price: low to high",
    "catalog.sortHigh": "Price: high to low",
    "catalog.noResults": "No matching products",
    "catalog.noResultsNote": "Keep your keyword and try clearing a filter or using a shorter phrase.",
    "catalog.clear": "Clear conditions",
    "catalog.filterTitle": "Filter products",
    "catalog.filterApplied": "Filters applied",
    "catalog.resultCount": "Results",
    "category.electronics": "Electronics",
    "category.accessories": "Phone accessories",
    "category.used": "Second-hand",
    "category.computers": "Computers and accessories",
    "filter.all": "All",
    "filter.new": "New",
    "filter.used": "Used",
    "filter.inStock": "In stock",
    "product.new": "New",
    "product.used": "Used",
    "product.single": "Single unit",
    "product.inStock": "In stock",
    "product.lowStock": "Low stock",
    "product.outOfStock": "Out of stock",
    "product.available": "Available",
    "price.retail": "Retail price",
    "price.wholesale": "Wholesale price",
    "price.minimum": "Minimum",
    "price.ladder": "Tiered price",
    "price.reference": "Retail reference",
    "buttons.add": "Add to cart",
    "buttons.buy": "Buy now",
    "buttons.back": "Back",
    "buttons.continue": "Continue shopping",
    "buttons.checkout": "Continue to checkout",
    "buttons.submit": "Submit demo order",
    "buttons.submitting": "Confirming",
    "buttons.view": "View",
    "buttons.change": "Change",
    "buttons.remove": "Remove",
    "buttons.retry": "Retry",
    "buttons.demoCart": "Add multi-shop demo set",
    "buttons.goOrders": "View orders",
    "buttons.close": "Close",
    "buttons.apply": "Apply filters",
    "buttons.clear": "Clear",
    "buttons.decrease": "Decrease quantity",
    "buttons.increase": "Increase quantity",
    "details.title": "Product details",
    "details.specs": "Specs and packaging",
    "details.delivery": "Delivery and support",
    "details.seller": "Shop",
    "details.inventory": "Stock facts",
    "details.quantity": "Quantity",
    "details.package": "Pack unit",
    "details.policy": "Demo policy",
    "used.title": "Used item facts",
    "used.condition": "Condition",
    "used.defect": "Disclosed issue",
    "used.battery": "Battery health",
    "used.warranty": "Warranty",
    "cart.title": "Cart",
    "cart.empty": "Your cart is empty",
    "cart.emptyNote": "Browse a few fictional products, then return to check them by shop.",
    "cart.shopNow": "Browse products",
    "cart.subtotal": "Items subtotal",
    "cart.total": "Total",
    "cart.sellerSubtotal": "Shop subtotal",
    "cart.quantity": "Quantity",
    "cart.singleItem": "Used items stay at 1 unit",
    "cart.loginRequired": "Guests can add items, but must choose a demo identity before submitting.",
    "checkout.title": "Checkout review",
    "checkout.demoAddress": "Demo delivery details",
    "checkout.demoAddressPoint": "Demo delivery point",
    "checkout.demoAddressNote": "Local preview only; no real delivery or payment is created.",
    "checkout.shipping": "Delivery",
    "checkout.shippingNote": "Each shop confirms its own terms; no carrier is connected.",
    "checkout.payment": "Payment",
    "checkout.paymentNote": "This demo does not trigger payment, stock writes or external notifications.",
    "checkout.summary": "Shop order summary",
    "checkout.guestBlock": "Guests cannot submit. Choose a demo identity in Profile.",
    "checkout.success": "Order batch created",
    "checkout.successNote": "Local in-memory demo, split into shop sub-orders.",
    "orders.title": "Orders",
    "orders.empty": "No demo orders yet",
    "orders.emptyNote": "After a local submission, order batches and shop sub-orders will appear here.",
    "orders.batch": "Order batch",
    "orders.suborders": "shop sub-orders",
    "orders.suborder": "Shop sub-order",
    "orders.timeline": "Status timeline",
    "orders.items": "items",
    "orders.openDetail": "View sub-order",
    "profile.title": "Profile",
    "profile.identity": "Demo identity sample",
    "profile.demoNote": "For local prototype testing only; production pricing follows verified identity automatically.",
    "profile.retail": "Retail customer",
    "profile.wholesale": "Verified wholesale customer",
    "profile.guest": "Guest preview",
    "profile.retailStatus": "Retail pricing is shown",
    "profile.wholesaleStatus": "Wholesale conditions are shown automatically",
    "profile.guestStatus": "Can browse and add, cannot submit",
    "profile.language": "Language",
    "profile.appearance": "Appearance and access",
    "profile.dark": "Dark mode",
    "profile.light": "Light mode",
    "profile.reduced": "Reduce motion",
    "profile.on": "On",
    "profile.off": "Off",
    "profile.wholesaleCard": "Wholesale identity sample",
    "profile.wholesaleCardNote": "Price, minimum and tiers update automatically with the identity sample.",
    "profile.demoOnly": "Local prototype · no external services",
    "status.submitted": "Submitted",
    "status.processing": "Processing",
    "status.shipping": "Shipping",
    "status.completed": "Completed",
    "status.delivery": "Demo delivery terms",
    "status.available": "Available to buy",
    "toast.added": "Added to cart",
    "toast.demoCart": "Demo items from two shops added",
    "toast.orderCreated": "Local order batch created",
    "toast.removed": "Item removed",
    "notice.demo": "This is the Rebuy local visual prototype; “Rebuy” is a replaceable working name.",
  },
};

export function tr(locale: Locale, key: string): string {
  return copy[locale][key] ?? copy.en[key] ?? key;
}

export const products: Product[] = [
  {
    id: "charger",
    kind: "new",
    sprite: "charger",
    merchant: "Northline Lab",
    name: local("Voltix 30W USB-C 氮化镓充电器", "Caricatore Voltix 30W GaN USB-C", "Voltix 30W USB-C GaN charger"),
    summary: local("双口、轻量旅行款，适合日常补电。", "Doppia porta, compatto per i viaggi.", "Dual-port, compact power for daily travel."),
    retailPrice: 24.9,
    wholesalePrice: 17.9,
    wholesaleMinimum: 5,
    wholesaleLadders: [
      { minimum: 5, price: 17.9 },
      { minimum: 20, price: 15.9 },
    ],
    inventory: 18,
    lowStockThreshold: 6,
    unit: local("件", "pezzo", "unit"),
  },
  {
    id: "phone",
    kind: "used",
    sprite: "phone",
    merchant: "Riva Devices",
    name: local("Nova X4 翻新手机 128GB", "Smartphone ricondizionato Nova X4 128GB", "Nova X4 refurbished phone 128GB"),
    summary: local("外观有使用痕迹，关键状况在详情首屏披露。", "Segni d'uso visibili, fatti chiave dichiarati in alto.", "Visible wear with key facts disclosed up front."),
    retailPrice: 249,
    wholesalePrice: 221,
    wholesaleMinimum: 1,
    wholesaleLadders: [],
    inventory: 1,
    lowStockThreshold: 1,
    unit: local("件", "pezzo", "unit"),
    usedFacts: {
      condition: local("B：边框有可见磕碰", "B: piccoli urti visibili sul bordo", "B: visible frame marks"),
      defect: local("扬声器音量偏低，已测试并披露", "Altoparlante con volume ridotto, testato e dichiarato", "Speaker volume is low; tested and disclosed"),
      battery: local("88%", "88%", "88%"),
      warranty: local("30 天功能保修，不含外观磨损", "30 giorni sulle funzioni, usura estetica esclusa", "30-day functional cover; cosmetic wear excluded"),
    },
  },
  {
    id: "headphones",
    kind: "new",
    sprite: "headphones",
    merchant: "Blue Harbor Tech",
    name: local("Aster Loop 头戴式主动降噪耳机", "Cuffie Aster Loop con ANC", "Aster Loop ANC headphones"),
    summary: local("可折叠头戴设计、双麦克风和旅行收纳包。", "Design pieghevole, doppio microfono e custodia da viaggio.", "Foldable over-ear design, dual mics and a travel case."),
    retailPrice: 79.9,
    wholesalePrice: 56.9,
    wholesaleMinimum: 10,
    wholesaleLadders: [
      { minimum: 10, price: 56.9 },
      { minimum: 25, price: 52.9 },
    ],
    inventory: 4,
    lowStockThreshold: 5,
    unit: local("件", "pezzo", "unit"),
  },
  {
    id: "laptop",
    kind: "used",
    sprite: "laptop",
    merchant: "Orbit Works",
    name: local("Orbit 13 轻薄笔记本 256GB", "Notebook Orbit 13 ricondizionato 256GB", "Orbit 13 refurbished laptop 256GB"),
    summary: local("已售出示例，用于演示二手无货边界状态。", "Esempio venduto per mostrare lo stato usato non disponibile.", "Sold example showing the used-item unavailable state."),
    retailPrice: 329,
    wholesalePrice: 299,
    wholesaleMinimum: 1,
    wholesaleLadders: [],
    inventory: 0,
    lowStockThreshold: 1,
    unit: local("件", "pezzo", "unit"),
    usedFacts: {
      condition: local("C：上盖有明显划痕", "C: graffi visibili sul coperchio", "C: visible lid scratches"),
      defect: local("键盘背光不稳定，已披露", "Retroilluminazione tastiera instabile, dichiarata", "Keyboard backlight is intermittent; disclosed"),
      battery: local("76%", "76%", "76%"),
      warranty: local("已售出，当前不可购买", "Venduto, non acquistabile", "Sold and unavailable"),
    },
  },
];

export function findProduct(productId: string): Product | undefined {
  return products.find((product) => product.id === productId);
}

export function formatCurrency(value: number, locale: Locale): string {
  const localeName = locale === "it" ? "it-IT" : locale === "zh" ? "zh-CN" : "en-IE";
  return new Intl.NumberFormat(localeName, {
    style: "currency",
    currency: "EUR",
    maximumFractionDigits: 2,
  }).format(value);
}

export function stockState(product: Product): StockState {
  if (product.inventory <= 0) return "out-of-stock";
  if (product.inventory <= product.lowStockThreshold) return "low-stock";
  return "in-stock";
}

export function minimumQuantity(product: Product, role: Role): number {
  if (product.kind === "used") return 1;
  return role === "wholesale" ? product.wholesaleMinimum : 1;
}

export function priceForProduct(product: Product, role: Role, quantity: number): number {
  if (role !== "wholesale") return product.retailPrice;
  const ladder = [...product.wholesaleLadders]
    .sort((a, b) => b.minimum - a.minimum)
    .find((tier) => quantity >= tier.minimum);
  return ladder?.price ?? product.wholesalePrice;
}

export function statusLabel(locale: Locale, status: OrderStatus): string {
  return tr(locale, `status.${status}`);
}

function demoOrder(
  role: Exclude<Role, "guest">,
  id: string,
  merchant: string,
  status: OrderStatus,
  productId: string,
  quantity: number,
  createdAt: Localized,
): MerchantOrder {
  const product = findProduct(productId);
  if (!product) throw new Error(`Unknown demo product: ${productId}`);
  const unitPrice = priceForProduct(product, role, quantity);
  return {
    id,
    merchant,
    status,
    delivery: local("演示配送：商家确认中", "Consegna demo: conferma negozio", "Demo delivery: shop confirming"),
    items: [{ productId, quantity, unitPrice }],
    subtotal: unitPrice * quantity,
  };
}

export function buildDemoOrders(role: Role): OrderBatch[] {
  if (role === "guest") return [];
  return [
    {
      id: "RB-DEMO-001",
      createdAt: local("今天 10:20", "Oggi 10:20", "Today 10:20"),
      status: "processing",
      role,
      merchantOrders: [
        demoOrder(role, "RB-DEMO-001-N", "Northline Lab", "processing", "charger", 5, local("今天 10:20", "Oggi 10:20", "Today 10:20")),
        demoOrder(role, "RB-DEMO-001-R", "Riva Devices", "shipping", "phone", 1, local("今天 10:20", "Oggi 10:20", "Today 10:20")),
      ],
    },
    {
      id: "RB-DEMO-002",
      createdAt: local("昨天 16:40", "Ieri 16:40", "Yesterday 16:40"),
      status: "completed",
      role,
      merchantOrders: [
        demoOrder(role, "RB-DEMO-002-B", "Blue Harbor Tech", "completed", "headphones", 1, local("昨天 16:40", "Ieri 16:40", "Yesterday 16:40")),
      ],
    },
  ];
}

export function makeLocalOrder(cart: CartItem[], role: Exclude<Role, "guest">): OrderBatch {
  const grouped = new Map<string, CartItem[]>();
  cart.forEach((item) => {
    const product = findProduct(item.productId);
    if (!product) return;
    const current = grouped.get(product.merchant) ?? [];
    current.push(item);
    grouped.set(product.merchant, current);
  });

  const merchantOrders = [...grouped.entries()].map(([merchant, items], index) => {
    const snapshots = items.flatMap((item) => {
      const product = findProduct(item.productId);
      if (!product) return [];
      const unitPrice = priceForProduct(product, role, item.quantity);
      return [{ productId: product.id, quantity: item.quantity, unitPrice }];
    });
    return {
      id: `RB-LOCAL-${index + 1}`,
      merchant,
      status: "submitted" as OrderStatus,
      delivery: local("演示配送：等待商家确认", "Consegna demo: in attesa del negozio", "Demo delivery: waiting for shop"),
      items: snapshots,
      subtotal: snapshots.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0),
    };
  });

  return {
    id: `RB-LOCAL-${String(Date.now()).slice(-6)}`,
    createdAt: local("刚刚", "Adesso", "Just now"),
    status: "submitted",
    role,
    merchantOrders,
  };
}
