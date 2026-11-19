# Evidence Figure Design

面向论文数据图的中文 Agent Skill。从一项读图任务出发，在写代码前确定版面与视觉编码，随后用源表和实际导出的文件验图。适用于分组比较、热图和多面板图。

## 使用

将整个目录以 `evidence-figure-design` 为名放入 Agent 的技能目录。在 Codex 中可将它放到 `~/.codex/skills/`，然后在新会话中调用。

> 用 $evidence-figure-design 改这张分组图。读者要比较三组的组内波动和均值。请保留所有观测，先给版面蓝图，输出单栏 PDF 和预览图，核对误差区间和 PDF 中的轴标签。

完整工作流见 [SKILL.md](SKILL.md)。绘图使用已有 R 或 Python 环境。可选的尺寸检查工具读取成品的绝对尺寸，SVG 使用 Python 标准库，PDF 需要 pypdf。下例的尺寸是一次工作的目标值。

```sh
python scripts/check_export.py figure.svg figure.pdf --width-mm 89 --height-mm 68
```

## 从 Opus 样图借鉴了什么

SciFigure2Code 的附图 S10 将参考图与 Opus 4.6、4.7 等模型的重建逐行列出。第一列的两行三列校准图用一致的面板布局支持横向比较。光谱示例中，4.7 保留了前景曲线与背景填色的层次，但部分谷形仍偏离参考图。我们据此把两件工作写进了流程：借鉴分面、标签或层级时说清具体决定，核对曲线或区间时回到原始数值。该研究评估有参考图的重建。 [论文与任务说明](https://arxiv.org/abs/2609.08155v2) · [附图 S10](https://arxiv.org/html/2609.08155v2/x1.png)

Anthropic 的公开 Graphing Skill 按阅读任务选择图型，并要求作者回看实际 PNG。它的应用场景包括报告和交互图。我们针对论文图增加了物理尺寸、可选中文字、统计口径和矢量文件复验。这份 Skill 及其尺寸检查器为独立编写。 [Anthropic Graphing](https://github.com/anthropics/claude-tag-plugins/blob/main/claude-tag-data-viz/skills/graphing/SKILL.md)

## 样图与验证

用 R 自带数据制作了三对图。每对共用数据、统计量、字体家族和目标页宽。基线为常规 ggplot2 版，改版按本 Skill 绘制。一名未参与制图的代理只看到匿名 A/B 图和读图问题，先给出读数，再选择更易读的版本，允许平局。分数是此次代理的主观评分。

| 数据与阅读任务 | 核对结果 | 代理评分，基线 → 改版 |
|---|---|---|
| [PlantGrowth 干重](examples/comparisons/plant-growth.png)，比较各组均值与个体分布 | 30 个观测，三组各 10 个，均值为 5.032、4.661、5.526。改版用符号键标明个体及均值的 95% t 置信区间。 | 7 → 10 |
| [VADeaths 死亡率](examples/comparisons/virginia-rates.png)，查指定年龄、居住地和性别 | 20 个格值全部核对。农村男性 50–54 岁为 11.7，城市女性 70–74 岁为 50.0，单位为每千人每年死亡数。 | 8 → 10 |
| [faithful 喷发与等待](examples/comparisons/old-faithful.png)，同时读散点和直方图 | 两版均保留 272 对观测，直方图总频数 272，最高组为 80 至不足 85 分钟的 57 次。改版共用等待时间轴，单独读直方图的组界仍需对照左侧刻度。 | 8 → 9 |

三对图的 12 份 PDF/SVG 均通过成品尺寸检查，每轴容差 0.25 mm。试用中补了干重图的符号图例、调整了热图分组标题位置，并修正了 Cairo PDF 页框取整。基线和改版都是为此次测试新绘制的公开数据示例。代理偏好不能代替真人读者评价。

另请一名独立代理仅凭 Skill 和读图任务，用 R 自带的 pressure 数据完成了单栏图。最终 PDF 实测 88.900 × 68.086 mm，两条轴名、单位和 15 个刻度均可提取。将最终 PDF 栅格化后按坐标轴标定，19 个点逐项匹配源表，最大偏差小于半个像素。

## 复现

在 `examples/` 目录中运行以下命令。R 示例需要 ggplot2、patchwork、scales、svglite、ragg、支持 Cairo 的 R 和 Arial 或本机可用的替代字体。拼接对照图需要 Python 的 Pillow 与 pypdfium2。独立的汞蒸气压示例使用基础 R。输入数据直接从 R 的 datasets 包读取。

```sh
Rscript --vanilla render.R baseline
Rscript --vanilla render.R redesign
python make_pairs.py
Rscript --vanilla plot_pressure.R
```

各版原图、摘要数值及核对记录写入 `figures/`，对照 PNG 与版本对应关系写入 `comparisons/`，蒸气压图写在其 R 脚本旁。数据定义与出处可查 R 帮助页。 [PlantGrowth](https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/PlantGrowth.html) · [VADeaths](https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/VADeaths.html) · [faithful](https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/faithful.html) · [pressure](https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/pressure.html)
