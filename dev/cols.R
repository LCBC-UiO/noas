cols <- c(NULL
,"#C5DA84"
,"#94C11F"
,"#009FE3"
,"#66BFDD"
)

layout(1:length(cols))
for (colstr in cols) {
  .add_h <- function(hsv, c) {
    hsv['v',] <- hsv['v',] + c
    hsv <- pmax(hsv, 0)
    hsv <- pmin(hsv, 1)
    return(hsv)
  }
  .hsv2col <- function(col_hsv) {
    return(hsv(h=col_hsv['h',],s=col_hsv['s',],v=col_hsv['v',]))
  }
  col_hsv <- rgb2hsv(col2rgb(colstr))
  diff <- 0.2
  c_light <- .hsv2col(.add_h(col_hsv,  diff))
  c_dark  <- .hsv2col(.add_h(col_hsv, -diff))
  barplot(c(1,1,1), col=c(c_light, colstr, c_dark) )
  str <- sprintf("light: %s dark: %s  (org: %s; +- %.2fv) ", c_light, c_dark, colstr, diff)
  write(str, "")
}
