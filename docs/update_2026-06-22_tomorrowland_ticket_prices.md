# Tomorrowland 2025 票价抓取阶段记录

日期：2026-06-22

## 本次目标

继续沿用之前抓取 Tomorrowland 2025 lineup 的 Wayback 工作流，确认 Tomorrowland 2025 官方页面中是否能找到票价数据，并把可追溯的结构化价格导出为 CSV。

## 抓取结论

当前官网 `https://belgium.tomorrowland.com/en/passes-packages/` 是 Tomorrowland Belgium 2026 页面。该页面主要提供 Passes & Packages 的入口导航，没有直接公开具体票价。本次抓包中出现过的 `48eur` 是组件 ID（如 `m48eur16`）造成的误判，不是票价。

可用票价来自 Wayback Machine 保存的 Tomorrowland 2025 具体票种页面。关键快照如下：

| 页面 | Wayback 时间戳 | 内容 |
| --- | --- | --- |
| `/en/passes-packages/tomorrowland-tickets/day-pass/` | `20250117121930` | Day Pass / Day Pleasure Pass / Day Comfort Pass 价格 |
| `/en/passes-packages/tomorrowland-tickets/full-madness-pass/` | `20250117122523` | Full Madness Pass / Full Madness Comfort Pass 价格 |

## 输出文件

| 文件 | 说明 |
| --- | --- |
| `scripts/parse_tomorrowland_ticket_prices_capture.py` | 从 Wayback 抓包结果中解析 `__NEXT_DATA__` / JSON 的 `product_prices` 结构 |
| `data/processed/tomorrowland_2025_ticket_prices_official_wayback.csv` | 清洗后的官方票价 CSV，10 条 |
| `sql/15_import_tomorrowland_2025_ticket_prices.sql` | 建立 staging 表并导入官方票价 CSV |
| `sql/16_promote_tomorrowland_2025_ticket_price_offers.sql` | 新增/确认正式票价明细表，并将 staging 价格提升到正式表 |

## 已提取票价

| 票种 | 销售阶段 | 价格 |
| --- | --- | --- |
| Day Pass | WorldWide & Belgian Pre-Sale | EUR 129.00 |
| Day Pass | WorldWide Sale | EUR 143.00 |
| Day Pleasure Pass | WorldWide & Belgian Pre-Sale | EUR 177.00 |
| Day Pleasure Pass | WorldWide Sale | EUR 208.00 |
| Day Comfort Pass | WorldWide & Belgian Pre-Sale | EUR 232.00 |
| Day Comfort Pass | WorldWide Sale | EUR 250.00 |
| Full Madness Pass | WorldWide & Belgian Pre-Sale | EUR 304.00 |
| Full Madness Pass | WorldWide Sale | EUR 374.00 |
| Full Madness Comfort Pass | WorldWide & Belgian Pre-Sale | EUR 530.00 |
| Full Madness Comfort Pass | WorldWide Sale | EUR 640.00 |

以上价格来自页面内官方结构化数据，不是文本正则猜测。CSV 中保留了 `official_product_id`、`official_price_id`、`capture_timestamp`、`source_url_hint`，便于审计。

## 建模说明

原有正式表 `ticket_types` 只有 `name` 和单一 `price_eur`，不能完整表达同一票种在不同销售阶段的多个价格。因此本次先导入 `stg_tomorrowland_2025_ticket_prices` staging 表，再新增正式明细表 `ticket_price_offers` 保存不同销售阶段的官方价格。

新增正式明细表结构为：

```sql
ticket_price_offers(
    offer_id,
    ticket_type_id,
    sale_category,
    price_eur,
    currency,
    price_status,
    source_url,
    captured_at
)
```

这样可以保留 “Day Pass - Pre-Sale” 与 “Day Pass - WorldWide Sale” 两个价格，同时不破坏 `ticket_types` 对票种实体的表达。

当前数据库执行结果：

| 表 | 行数 | 说明 |
| --- | ---: | --- |
| `stg_tomorrowland_2025_ticket_prices` | 10 | Wayback 官方结构化票价 staging |
| `ticket_price_offers` | 10 | 已提升的正式销售阶段价格 |

## 未解决内容

1. 官方页面未给出票种 quota，`ticket_types.quota` 仍应标注为模拟或估计。
2. DreamVille / Global Journey / Hospitality 套餐可能存在更复杂的组合价格，需要继续沿具体子页面或 Paylogic 页面抓取。
3. 现有 `ticket_types.is_simulated` 只能整体标记一条票种记录，无法区分“价格真实、配额模拟”。本次将官方价格事实放入 `ticket_price_offers.confidence='official_wayback_structured'`，后续仍可增加统一 evidence 表。
