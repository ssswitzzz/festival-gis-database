# 2026-06-23 Defqon.1 与 Awakenings 抓包阶段记录

## 本阶段目标

沿用 Tomorrowland 票价抓包的工作方式，继续尝试为 Defqon.1 2025 与 Awakenings Festival 2025 收集官方业务数据，重点关注：

- 官方页面是否能确认届次、日期、地点、票种入口；
- 是否能从页面或动态 API 中提取票价/套餐价格；
- 明确哪些数据已经抓到，哪些数据没有出现在当前抓包响应中。

## Defqon.1 2025

已从 Wayback Machine 抓取到 Q-dance 官方页面快照，主要有效页面包括：

- `https://www.q-dance.com/l/defqon-1-2025-weekend-tickets`
- `https://www.q-dance.com/l/defqon1-2025-day-tickets`

解析结果输出到：

- `data/processed/defqon_2025_wayback_page_facts.csv`

当前能确认的官方事实：

- 活动为 `Defqon.1 2025`；
- 页面描述包含 `June 26 - 29`；
- 页面包含 Weekend / Day / Premium / Regular / Friday / Saturday / Sunday 等票种或票务术语；
- 页面跳转到 `shop.q-dance.com/defqon-1-2025-where-legends-rise` 等官方购票入口。

当前限制：

- 抓到的 Q-dance 页面正文没有明确的欧元票价字段；
- 票价很可能位于外部 shop / Paylogic 购票流程内；
- 一个 `defqon-1-ayntk-tickets` 页面虽然在 2025 年被 Wayback 抓到，但页面内容指向 2023 届，因此标记为 `legacy_or_year_mismatch`，不能当作 2025 票价证据。

## Awakenings Festival 2025

Awakenings 官方站点的当前 sitemap 中未找到对应 2025 shop URL 的 Wayback 快照，因此本阶段抓取的是当前官方站点和其动态接口，置信标记为 `current_official_shop_json`。

解析结果输出到：

- `data/processed/awakenings_2025_event_facts_current_official.csv`
- `data/processed/awakenings_2025_package_prices_current_official.csv`
- `data/processed/awakenings_2025_shop_products_current_official.csv`

当前能确认的官方事实：

- 活动标题：`Awakenings Festival 2025`；
- 地点：`Beekse Bergen [NL]`；
- 日期：`2025-07-11` 到 `2025-07-13`；
- 最低年龄：`18`；
- 状态字段：`available`；
- 货币：`EUR`。

价格方面，目前可靠抓到的是 accommodation / camping / hotel 等 travel package 的 `basicSalePrice`。这些是住宿/旅行套餐价格，不等同于普通入场门票价格，因此暂时只进入 staging 表，不提升到 `ticket_price_offers`。

当前限制：

- `shopapi.id-t.com/api/v2/products` 当前抓到的产品列表只包含 `Booking Protection`；
- 普通 day/weekend ticket 产品可能需要进入更深的店铺路由或人工点击具体分类后才会加载；
- 住宿套餐说明中多次出现 `€150 deposit`，该金额已记录为押金/附加费用提示，不能当作套餐基础价格或门票价格。

补充尝试：

- 已进一步抓取 `weekend-tickets` 与 `day-tickets` 深层路由；
- 深层路由仍然只返回 `Booking Protection` 产品，未返回普通门票产品；
- `weekend-tickets` 页面可见 `WEEKEND TICKETS`、`ACCOMMODATION`、`LOCKERS` 等步骤，购物车总额保持为 `€ 0,00`；
- `day-tickets` 页面只显示较空的票务步骤和 `CONTINUE TO OVERVIEW`，购物车总额同样保持为 `€ 0,00`；
- 抓包候选中的价格主要来自 `en/packages` 的住宿/酒店套餐 JSON，而不是普通门票 API；
- 深层抓包诊断汇总已整理到 `data/processed/deep_capture_2025_findings.csv`，用于保留结论而不提交大量可再生成的 DOM、截图和响应缓存。

## 深层抓包结论

本轮新增 `scripts/deep_capture_festival_network.py`，用于在动态票务页面中滚动、记录可见控件、保存请求/响应摘要，并尝试点击安全的票务/套餐导航按钮。脚本不填写表单、不登录、不提交支付。

实际执行结果：

- Awakenings weekend route：请求 17 条、响应 37 条、候选事实 138 条、点击控件 7 个；
- Awakenings day route：请求 11 条、响应 31 条、候选事实 138 条、点击控件 1 个；
- Defqon current shop route：请求 21 条、响应 27 条、候选事实 22 条、点击控件 0 个。

Awakenings 深层抓包已经进入 `weekend-tickets` / `day-tickets` 路由和步骤流，但 `shopapi.id-t.com/api/v2/products` 仍然只返回 `Booking Protection`，普通 day/weekend ticket 的产品行和价格没有出现在响应或 DOM 中。因此，本阶段不能把 `€ 0,00` 购物车总额或住宿套餐价格当作普通门票价格。

Defqon.1 当前 shop URL `https://shop.q-dance.com/defqon-1-2025-where-legends-rise` 已不再暴露 2025 票务产品。页面实际渲染为 `DEFQON.1 2026`，并提示 tickets sold out、进入 shop 仅用于 experiences / add-ons，因此该当前页面只能作为“2025 入口已失效/年份不匹配”的证据，不能作为 2025 票价证据。

## Awakenings Wayback 票价探测

由于 live shop 的 day/weekend route 均未显示普通票价，本阶段继续尝试用 Wayback Machine/CDX 查找历史快照。

CDX 查询结果：

- `www.awakenings.com/en/shop/awakenings-festival-2025-weekend/367651/weekend-tickets/*`：无快照；
- `www.awakenings.com/en/shop/awakenings-festival-2025-main/375194/day-tickets/*`：无快照；
- `www.awakenings.com/en/api/shop/config/*`：无快照；
- `d1tbov4skw93c6.cloudfront.net/*/en/packages*` 与 `*/en/settings*`：无快照；
- `shopapi.id-t.com/api/v2/products`：存在若干 2024 年 JSON 快照。

`shopapi.id-t.com/api/v2/products` 是通用店铺接口，URL 中不包含 event id、shop id、referrer 或 Awakenings 2025 页面路径，因此不能单独作为 Awakenings Festival 2025 的官方票价证据。为避免丢失线索，已将其中 ticket 类型产品整理到：

- `data/processed/awakenings_wayback_shopapi_ticket_candidates.csv`

其中 `20240416161001` 快照包含 Awakenings 周边商品和一组疑似 Awakenings 入口票产品，例如：

- `Weekend | Regular ticket`：`143 EUR`；
- `Saturday | Regular ticket`：`84 EUR`；
- `Sunday | Regular ticket`：`69 EUR`；
- `Weekend | Loyalty ticket`：`135.5 EUR`；
- `Saturday | Loyalty ticket`：`79 EUR`；
- `Sunday | Loyalty ticket`：`64 EUR`。

但是该快照时间为 2024-04-16，且没有可配套的 Awakenings 2025 官方页面快照；从时间上看，它更可能对应 2024 届或当时 live shop 的其他上下文。因此这些价格只能保留为 `unattributed_wayback_shopapi_candidate`，不能导入 `ticket_price_offers`，也不能在报告中写成 Awakenings Festival 2025 的确认票价。

## 数据入库

新增导入脚本：

- `sql/18_import_defqon_awakenings_capture.sql`

导入 staging 表：

- `stg_defqon_2025_page_facts`
- `stg_awakenings_2025_event_facts`
- `stg_awakenings_2025_package_prices`
- `stg_awakenings_2025_shop_products`

## 下一阶段建议

1. 对 Awakenings 执行更深层店铺路由抓包，例如 `weekend-tickets`、`day-tickets` 等页面。如果页面需要点击分类或等待队列，需要人工在浏览器中配合。
2. 对 Defqon.1 尝试抓取 `shop.q-dance.com/defqon-1-2025-where-legends-rise` 或其 Wayback / Paylogic 流程。如果页面需要登录、队列或过期活动状态，只记录“官方入口存在但价格不可访问”。本阶段已尝试当前 shop 入口，抓到的是 shop 初始化页面和静态资源，没有有效票价产品 JSON。
3. 如果后续能抓到明确普通门票产品价格，再将其规范化导入 `ticket_price_offers`；住宿、酒店、camping 等非门票价格建议保留在独立 package staging 表中。
4. 下一步若继续追票价，优先尝试 Wayback CDX 中的外部 shop / Paylogic 历史 URL，而不是当前 live shop；当前 live shop 对 Defqon 已切到 2026，对 Awakenings 普通门票已离线或隐藏。
5. 对 Awakenings，除非找到带 2025 官方页面路径、event id 或 shop id 的历史页面/接口快照，否则不要把通用 `shopapi.id-t.com/api/v2/products` 的候选价格提升为正式数据。
