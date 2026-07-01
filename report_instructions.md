# 论文文献检索与修改规范指南 (Report Modification & Literature Retrieval Guidelines)

为了方便后续自动/手动调用或为大语言模型（LLM）提供指令，本指南梳理了该期末地理论文的编写、文献检索、插图制作和 LaTeX 整合的一系列严格规范。

## 作业要求:
#### **设计一个数据库，包括：名称、设计理念、画ER图、范式检查、设计主键及约束、录入数据；设计并实现几道SQL查询.**
---

## 1. 文献检索与内容充实要求 (Literature Search & Content Enrichment)

*   **文献来源渠道**：
    *   如果需要检索文献，优先使用学术数据库（如 arXiv、Europe PMC、OpenAlex 等）检索最新的学术论文。
*   **内容编写风格**：
    *   要求学术性强、用词严谨、逻辑清晰，内容综合且全面，避免大白话和口语化表达。
    *   **排版与用语规范（新增）**：
        *   **严禁在中文名词后面加上由括号包裹的英文**（例如，不要在写完中文名词后直接紧随括号加注英文）。
        *   **降低“（如...）”或“（例如...）”此类括号举例的使用频率**，尽量使用流畅的叙述性语言进行阐述，避免频繁打断阅读。
        *   **降低双引号的使用频率**，非必要情况（如非特定的专有名词定义、非直接引用等）避免使用双引号，以保持学术写作的规范性与连贯性。


---

## 2. 引用与参考文献管理规范 (Citations & Bibliography Management)

*   **禁止正文行内引用 (`\cite`)**：
    *   在正文新增的文本中，**绝对不要**使用 `\cite{...}` 或 `\citeauthor{...}` 等行内引用标签。
*   **自动参考文献生成 (`\nocite{*}`)**：
    *   本论文在正文开头已配置 `\nocite{*}`，这意味着所有写入到 `.bib` 参考文献数据库中的文献都会自动显示在论文末尾的“参考文献”列表中。
*   **参考文献数据库管理**：
    *   查找到的文献信息必须转换成标准 BibTeX 格式，直接追加写入到 `references.bib` 文件尾部。
    *   每一个 `@article` 或 `@report` 必须字段完整（包含 `author`, `title`, `year`, `journal`/`institution`, `url`/`doi` 等）。

---

## 3. 论文插图设计规范 (Figure Design & LaTeX Embedding Guidelines)

如果需要为论文生成并插入新图表或地图，须遵循以下原则：

### 3.1 图表生成设计规范 (Matplotlib Charts)
*   **背景色**：图表背景必须为浅灰色（推荐使用颜色代码 `#f5f5f5`，与论文内页协调），使用 `fig.patch.set_facecolor('#f5f5f5')` 和 `plt.savefig(..., facecolor='#f5f5f5')` 设置。
*   **无内置标题**：不要在图表内部使用 `plt.title()`。图表的标题由 LaTeX 中的 `\caption` 提供。
*   **语言本土化**：图表中的所有标签、图例、坐标轴刻度等文本必须翻译为**纯中文**，不得包含任何英文或多余的括号（除非是数据单位）。
*   **字体规范**：
    *   思源宋体 (Source Han Serif CN)：`SourceHanSerifCN-SemiBold.otf`。
    *   字体需在 Python 代码中通过绝对路径加载，并确保 fallback 逻辑。
*   **输出格式**：保存为矢量 PDF 格式（如 `.pdf`）以获得最佳印刷画质。如果是高密度底图/夜光图，可以采用高分辨率 `.jpg`。

### 3.2 LaTeX 插图排版与数据来源标注
所有插图在 LaTeX 中的排版必须符合规范。

*   **标准单图格式**：
    ```latex
    \begin{figure}[H]
        \centering
        \includegraphics[width=0.8\textwidth]{figs/sweden_riksdag.pdf}
        \caption{\textcolor{red}{瑞典议会2022年大选席位分布}}
        \label{fig:sweden_riksdag}
        \par\vspace{2pt}
        {\footnotesize\textcolor{red}{注：数据来源 Valmyndigheten (\url{https://www.val.se/})}}
    \end{figure}
    ```

*   **双图并排格式 (使用 minipage)**：
    ```latex
    \begin{figure}[H]
        \centering
        \begin{minipage}[b]{0.48\textwidth}
            \centering
            \includegraphics[width=\linewidth]{figs/img_a.jpg}
            \caption{左侧图标题}
            \label{fig:img_a}
        \end{minipage}
        \hfill
        \begin{minipage}[b]{0.48\textwidth}
            \centering
            \includegraphics[width=\linewidth]{figs/img_b.jpg}
            \caption{右侧图标题}
            \label{fig:img_b}
        \end{minipage}
    \end{figure}
    ```

---

## 4. LaTeX 语法安全防护 (LaTeX Syntax Safety)

*   在 LaTeX 插入文本时，必须对保留字符（如 `%`, `_`, `&`, `$`, `#`, `{`, `}` 等）进行正确的转义处理（例如 `\%`、`\_`），避免编译失败。
*   对于新增内容中的专有名词，注意其首字母或翻译的准确性。
