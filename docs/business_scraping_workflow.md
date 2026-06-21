# 官方业务数据抓取脚本说明

## 目标

本项目的空间数据已经基本真实化。业务数据下一步优先补：

1. 活动日期
2. 观众规模
3. 真实票价
4. lineup / timetable

官网页面经常动态变化，因此脚本不会直接改正式表，而是先保存原始网页和候选 CSV，人工复核后再入库。

## 新增文件

| 文件 | 作用 |
| :--- | :--- |
| `data/sources/festival_business_sources.json` | 官方网页抓取清单 |
| `scripts/scrape_festival_business_data.py` | Python 抓取与候选信息提取脚本 |
| `scripts/scrape_festival_business_data.ps1` | PowerShell 运行入口 |
| `scripts/capture_festival_network.py` | 浏览器网络响应抓包脚本，用于动态加载的票价和 lineup |
| `sql/10_business_scrape_staging.sql` | 抓取候选数据暂存表 |

## 运行方式

抓取全部配置网站：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\scrape_festival_business_data.ps1
```

只抓某一个音乐节：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\scrape_festival_business_data.ps1 -Festival "Tomorrowland"
```

## 输出文件

| 文件 | 内容 |
| :--- | :--- |
| `data/raw/festival_business_pages/*.html` | 原始官网页面 |
| `data/raw/festival_business_pages/*.json` | 每个页面的抓取元数据 |
| `data/processed/business_scrape_pages.csv` | 页面级抓取记录 |
| `data/processed/business_fact_candidates.csv` | 日期、观众规模等候选事实 |
| `data/processed/business_ticket_candidates.csv` | 票价候选值 |
| `data/processed/business_lineup_candidates.csv` | 艺人、舞台、时刻表候选值 |
| `data/processed/business_manual_review_template.csv` | 手动复核模板 |

## 动态页面抓包

如果普通抓取没有票价或 timetable，说明信息很可能由 JavaScript 接口加载。可以使用浏览器网络抓包脚本：

```powershell
python scripts\capture_festival_network.py --festival "Tomorrowland" --edition-year 2025 --url "https://belgium.tomorrowland.com/en/line-up/" --wait-ms 15000
```

首次使用需要安装 Playwright：

```powershell
python -m pip install playwright
python -m playwright install chromium
```

如果页面需要手动点 cookie、展开日期或打开票种，使用：

```powershell
python scripts\capture_festival_network.py --festival "Tomorrowland" --edition-year 2025 --url "https://belgium.tomorrowland.com/en/line-up/" --wait-ms 30000 --headed
```

该脚本会保存匹配 `ticket`、`price`、`lineup`、`artist`、`timetable`、`schedule` 等关键词的网络响应。

## 入库流程

先创建暂存表：

```powershell
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -v ON_ERROR_STOP=1 -f sql\10_business_scrape_staging.sql
```

然后在 `psql` 里按脚本注释执行 `\copy`，把 CSV 导入暂存表。

## 复核原则

- `confidence = structured`：来自 JSON-LD 等结构化网页数据，优先级最高。
- `confidence = candidate`：来自正文正则匹配，需要人工确认。
- `confidence = low_candidate`：lineup 附近的名字候选，只能作为线索。
- 日期候选中的 `year_matches_edition` 应优先为 `true`。如果官网已经跳到下一年，该值会帮助避免误入库。

票价、观众规模和 timetable 不建议自动写正式表，因为官网页面可能隐藏售罄票种、动态加载价格，或者只在 app 中显示完整时刻表。
