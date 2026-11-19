# Reproduce figures from R's public datasets package.
# Run from this directory with Rscript --vanilla render.R baseline|redesign [output-directory]
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) %in% c(1L, 2L), args[1] %in% c("baseline", "redesign"))
mode <- args[1]
redesign <- mode == "redesign"
destination <- if (length(args) == 2L) args[2] else file.path("figures", mode)
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})
library(grid)
base_size <- 7.5
ink <- "#24383F"
teal <- "#006A67"
base_theme <- function() {
  theme_bw(base_size = base_size, base_family = "Arial") +
    theme(text = element_text(colour = ink), axis.text = element_text(colour = ink),
          plot.margin = margin(7, 7, 7, 7), plot.background = element_rect(fill = "white"))
}
reader_theme <- function() {
  theme_classic(base_size = base_size, base_family = "Arial") +
    theme(text = element_text(colour = ink), axis.text = element_text(colour = ink),
          axis.line = element_line(colour = "#859399", linewidth = .26),
          axis.ticks = element_line(colour = "#859399", linewidth = .26),
          axis.ticks.length = unit(2, "pt"), axis.title = element_text(size = 8),
          plot.title = element_text(size = 8.5, face = "bold", margin = margin(b = 6)),
          plot.margin = margin(7, 7, 7, 7), plot.background = element_rect(fill = "white", colour = NA))
}
export_plot <- function(plot, name, w, h) {
  # SVG, PDF, and PNG all use the full original plotting page.
  path <- file.path(destination, name)
  svglite::svglite(paste0(path, ".svg"), width = w / 25.4, height = h / 25.4,
                   bg = "white", standalone = TRUE)
  print(plot)
  dev.off()
  # Cairo's PDF page box uses whole points on some platforms. Target the
  # nearest point, with a small allowance for the device's integer truncation.
  pdf_inches <- function(mm) (round(mm * 72 / 25.4) + .01) / 72
  grDevices::cairo_pdf(paste0(path, ".pdf"), width = pdf_inches(w), height = pdf_inches(h),
                       family = "Arial", bg = "white", onefile = TRUE)
  print(plot)
  dev.off()
  ragg::agg_png(paste0(path, ".png"), width = w, height = h, units = "mm", res = 200,
                background = "white")
  print(plot)
  dev.off()
}

# 1. Dried plant weight: show every plant and the mean with a t interval.
plants <- datasets::PlantGrowth
codes <- levels(plants$group)
names_pretty <- c("Control", "Treatment 1", "Treatment 2")
plants$row <- as.integer(plants$group)
plant_stats <- do.call(rbind, lapply(split(plants$weight, plants$group), function(x) {
  estimate <- mean(x)
  margin <- qt(.975, length(x) - 1) * sd(x) / sqrt(length(x))
  data.frame(n = length(x), estimate = estimate, low = estimate - margin, high = estimate + margin)
}))
plant_stats$row <- seq_len(nrow(plant_stats))
stopifnot(all(plant_stats$n == 10), all.equal(plant_stats$estimate, c(5.032, 4.661, 5.526)))
set.seed(1129)
plants$offset <- runif(nrow(plants), -.085, .085)
weight_axis <- scale_y_continuous(breaks = seq(3.5, 6.5, by = .5), limits = c(3.3, 6.6),
                                  expand = expansion(mult = c(.01, .035)))
if (!redesign) {
  plant_plot <- ggplot(plants, aes(row, weight)) +
    geom_point(aes(x = row + offset - .10), shape = 1, colour = "#575E66", size = 1.55,
               stroke = .35) +
    geom_linerange(data = plant_stats, aes(x = row + .12, ymin = low, ymax = high),
                   inherit.aes = FALSE, colour = "#235889", linewidth = .5) +
    geom_point(data = plant_stats, aes(x = row + .12, y = estimate), shape = 18, size = 2,
               colour = "#235889") +
    scale_x_continuous(breaks = 1:3, labels = names_pretty, limits = c(.65, 3.35)) +
    weight_axis + labs(x = NULL, y = "Dried plant weight") + base_theme()
} else {
  plant_plot <- ggplot(plants, aes(row, weight)) +
    geom_point(aes(x = row + offset + .13, shape = "Plant"), colour = "#737F87", size = 1.6,
               stroke = .38) +
    geom_linerange(data = plant_stats, aes(x = row - .14, ymin = low, ymax = high),
                   inherit.aes = FALSE, colour = teal, linewidth = .75) +
    geom_point(data = plant_stats, aes(x = row - .14, y = estimate, shape = "Mean (95% CI)"), size = 2.05,
               fill = teal, colour = teal, stroke = .35) +
    scale_shape_manual(name = NULL, breaks = c("Plant", "Mean (95% CI)"),
                       values = c("Plant" = 1, "Mean (95% CI)" = 23),
                       guide = guide_legend(override.aes = list(colour = c("#737F87", teal),
                                                                fill = c(NA, teal), size = c(1.6, 2.05)))) +
    scale_x_reverse(breaks = 1:3, labels = names_pretty, limits = c(3.48, .52),
                    expand = c(0, 0)) +
    weight_axis + coord_flip() + labs(x = NULL, y = "Dried plant weight") + reader_theme() +
    theme(legend.position = "top", legend.justification = "left",
          legend.key.size = unit(3, "mm"), legend.margin = margin(0, 0, 0, 0),
          legend.box.spacing = unit(1, "mm"), axis.line.y = element_blank(), axis.ticks.y = element_blank(),
          panel.grid.major.x = element_line(colour = "#E1E8E8", linewidth = .23),
          axis.text.y = element_text(size = 7.5, margin = margin(r = 4)))
}
plant_layers <- ggplot_build(plant_plot)$data
stopifnot(nrow(plant_layers[[1]]) == 30, all(is.finite(plant_layers[[1]]$y)),
          identical(sort(plant_layers[[1]]$y), sort(plants$weight)),
          all.equal(plant_layers[[2]]$ymin, plant_stats$low),
          all.equal(plant_layers[[2]]$ymax, plant_stats$high))
export_plot(plant_plot, "plant-growth", 89, 62)
write.csv(plant_stats, file.path(destination, "plant-summary.csv"), row.names = TRUE)

# 2. Mortality rates: separate residence and sex; each number is a source matrix cell.
rates <- as.data.frame(as.table(datasets::VADeaths), stringsAsFactors = FALSE)
names(rates) <- c("age", "population", "rate")
rates$age <- factor(rates$age, levels = rev(rownames(datasets::VADeaths)))
rates$population <- factor(rates$population, levels = colnames(datasets::VADeaths))
rates$residence <- sub(" .*", "", rates$population)
rates$sex <- factor(sub(".* ", "", rates$population), levels = c("Male", "Female"))
fmt <- function(x) sprintf("%.1f", x)
fill_limits <- c(0, 75)
legend_breaks <- c(0, 25, 50, 75)
palette <- if (redesign) c("#F3F7F6", "#12495B") else c("#EFF3FF", "#08519C")
fill_function <- scales::col_numeric(palette, domain = fill_limits)
luminance <- function(colours) {
  srgb <- grDevices::col2rgb(colours) / 255
  linear <- ifelse(srgb <= .04045, srgb / 12.92, ((srgb + .055) / 1.055)^2.4)
  drop(c(.2126, .7152, .0722) %*% linear)
}
fill_luminance <- luminance(fill_function(rates$rate))
dark_text <- "#142C35"
dark_contrast <- (fill_luminance + .05) / (luminance(dark_text) + .05)
white_contrast <- 1.05 / (fill_luminance + .05)
rates$label_colour <- ifelse(white_contrast > dark_contrast, "white", dark_text)
# Middle tones can support black better than the default dark ink.
rates$label_colour[pmax(white_contrast, dark_contrast) < 4.5] <- "#000000"
contrast <- ifelse(rates$label_colour == "white", white_contrast,
                   (fill_luminance + .05) / (luminance(rates$label_colour) + .05))
stopifnot(min(contrast) >= 4.5)
heat_plot <- ggplot(rates, aes(if (redesign) sex else population, age, fill = rate)) +
  geom_tile(colour = "white", linewidth = .35) +
  geom_text(aes(label = fmt(rate), colour = label_colour), size = 7.3 / .pt, family = "Arial") +
  scale_colour_identity() +
  scale_fill_gradient(low = palette[1], high = palette[2], limits = fill_limits,
                      breaks = legend_breaks, name = "Deaths per 1,000 per year") +
  labs(x = NULL, y = "Age (years)")
if (!redesign) {
  heat_plot <- heat_plot + scale_x_discrete(labels = function(x) sub(" ", "\n", x)) +
    base_theme() + theme(legend.position = "bottom")
} else {
  heat_plot <- heat_plot + facet_grid(~residence) + scale_x_discrete(position = "top", expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) + reader_theme() +
    theme(axis.line = element_blank(), axis.ticks = element_blank(), strip.background = element_blank(),
          strip.placement = "outside",
          strip.text = element_text(face = "bold", size = 8, margin = margin(t = 2, b = 3)),
          legend.position = "bottom", panel.spacing.x = unit(3, "mm"),
          legend.key.width = unit(5, "mm"), legend.key.height = unit(2, "mm"))
}
heat_layers <- ggplot_build(heat_plot)$data
stopifnot(nrow(heat_layers[[1]]) == 20, identical(sort(heat_layers[[2]]$label), sort(fmt(c(datasets::VADeaths)))),
          identical(toupper(heat_layers[[1]]$fill), toupper(fill_function(rates$rate))))
export_plot(heat_plot, "virginia-rates", 100, 76)
write.csv(rates[, c("age", "population", "rate")], file.path(destination, "virginia-rates.csv"), row.names = FALSE)

# 3. Eruption duration and next interval; fixed 5-minute bins in both layouts.
eruptions <- datasets::faithful
edges <- seq(40, 100, by = 5)
bins <- table(cut(eruptions$waiting, breaks = edges, include.lowest = TRUE, right = FALSE))
counts <- data.frame(low = head(edges, -1), high = tail(edges, -1), n = as.integer(bins))
stopifnot(nrow(eruptions) == 272, sum(counts$n) == nrow(eruptions))
wait_axis <- scale_y_continuous(limits = range(edges), breaks = seq(40,100,10),
                                expand = expansion(mult = c(0, .025)))
scatter <- ggplot(eruptions, aes(eruptions, waiting)) +
  geom_point(size = 1.35, alpha = .66, shape = 16, colour = if (redesign) "#167D78" else "#3B5973") +
  wait_axis + labs(x = "Eruption duration (min)", y = "Time to next eruption (min)")
if (!redesign) {
  scatter <- scatter + base_theme()
  distribution <- ggplot(counts) +
    geom_rect(aes(xmin = low, xmax = high, ymin = 0, ymax = n), colour = "white",
              fill = "#708FA6", linewidth = .24) +
    labs(x = "Time to next eruption (min)", y = "Eruptions") + base_theme()
  panel_layout <- c(1, 1)
} else {
  scatter <- scatter + reader_theme() +
    theme(panel.grid.major.y = element_line(colour = "#E2E8E8", linewidth = .22))
  distribution <- ggplot(counts) +
    geom_rect(aes(ymin = low, ymax = high, xmin = 0, xmax = n), fill = "#82A6B1",
              colour = "white", linewidth = .24) +
    wait_axis + scale_x_continuous(breaks = c(0, 25, 50), expand = expansion(mult = c(0, .035))) +
    labs(x = "Eruptions", y = NULL) + reader_theme() +
    theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank(),
          panel.grid.major.y = element_line(colour = "#E2E8E8", linewidth = .22))
  panel_layout <- c(2.8, 1)
}
paired <- (scatter + distribution) + plot_layout(widths = panel_layout) +
  plot_annotation(tag_levels = "a") & theme(plot.tag = element_text(family = "Arial", face = "bold", size = 8))
s <- ggplot_build(scatter)$data[[1]]
h <- ggplot_build(distribution)$data[[1]]
stopifnot(identical(s$x, eruptions$eruptions), identical(s$y, as.numeric(eruptions$waiting)),
          identical(as.integer(if (redesign) h$xmax else h$ymax), counts$n))
export_plot(paired, "old-faithful", 155, 80)
write.csv(counts, file.path(destination, "waiting-histogram.csv"), row.names = FALSE)
writeLines(c("PlantGrowth: 30 observations, group counts 10/10/10, 3 mean t intervals",
             sprintf("VADeaths: 20 verified labels, minimum cell text contrast %.2f:1", min(contrast)),
             sprintf("faithful: %d plotted pairs, histogram sum %d", nrow(eruptions), sum(counts$n))),
           file.path(destination, "checks.txt"))
print(sessionInfo())
quit(status = 0)
