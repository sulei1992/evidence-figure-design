# Run with Rscript plot_pressure.R. Outputs go beside this script.
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
outdir <- dirname(normalizePath(sub("^--file=", "", script_arg)))
source_data <- datasets::pressure
stopifnot(
  nrow(source_data) == 19,
  identical(source_data$temperature, seq(0, 360, 20)),
  all(source_data$pressure > 0),
  all(source_data$pressure[c(1, 10, 19)] == c(0.0002, 8.8, 806))
)

draw_figure <- function() {
  par(mai = c(0.46, 0.68, 0.11, 0.12), family = "Arial", ps = 8,
      fg = "#303637", col.axis = "#303637", col.lab = "#303637",
      tcl = -0.22, mgp = c(1.8, 0.43, 0), xaxs = "i", yaxs = "i")
  plot.new()
  plot.window(xlim = c(-9, 369), ylim = c(0.00008, 1450), log = "y")
  pressure_ticks <- 10^(-4:3)
  segments(-9, pressure_ticks, 369, pressure_ticks, col = "#DDE2E3", lwd = 0.6)
  box(bty = "l", lwd = 0.7)
  axis(1, at = seq(0, 360, 60), cex.axis = 7/8, lwd = 0, lwd.ticks = 0.7)
  axis(2, at = pressure_ticks,
       labels = c("0.0001", "0.001", "0.01", "0.1", "1", "10", "100", "1000"),
       las = 1, cex.axis = 7/8, lwd = 0, lwd.ticks = 0.7)
  mtext("Temperature (\u00b0C)", side = 1, line = 1.9)
  mtext("Mercury vapor pressure (mmHg)", side = 2, line = 3.25)
  points(source_data$temperature, source_data$pressure,
         pch = 16, cex = 0.80, col = "#176473")
}

size_inches <- c(89, 68) / 25.4
# Cairo uses an integer-point page. Choose the nearest printable page size.
pdf_inches <- round(size_inches * 72) / 72
cairo_pdf(file.path(outdir, "pressure.pdf"), width = pdf_inches[1],
          height = pdf_inches[2], family = "Arial", pointsize = 8, bg = "white")
draw_figure()
invisible(dev.off())

png(file.path(outdir, "pressure.png"), width = 89, height = 68,
    units = "mm", res = 300, pointsize = 8, type = "cairo", bg = "white")
draw_figure()
invisible(dev.off())
