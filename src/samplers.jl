export apply!, pointcrop!, linecrop!, linepool!, heatmappool!, aggregate!

function apply!(f::Function, buf::AbstractMatrix, c::Canvas)
  for j ∈ 1:size(buf,2)
    for i ∈ 1:size(buf,1)
      x, y = ij2xy(i, j, c)
      buf[i,j] = f(x, y)
    end
  end
end

function apply!(f::Function, buf::AbstractVector{Point2f0}, c::Canvas)
  xyrect = c.xyrect[]
  n = width(c.ijhome)
  p = 0
  for x ∈ range(left(xyrect), right(xyrect); length=n+1)
    y = f(x)
    if y isa AbstractVector
      for k ∈ 1:length(y)
        ij = xy2ij(Point2f0(x, y[k]), c)
        p = set!(buf, p, ij)
      end
    else
      ij = xy2ij(Point2f0(x, y), c)
      p = set!(buf, p, ij)
    end
  end
  truncate!(buf, p)
  length(buf) < 1 && push!(buf, Point2f0(Inf32, Inf32))  # needed because Makie does not like 0-point lines
end

function pointcrop!(buf::AbstractVector{Point2f0}, c::Canvas)
  data = c.datasrc.data
  data === missing && return
  xyrect = c.xyrect[]
  p = 0
  for k in 1:size(data,1)
    if left(xyrect) <= data[k,1] <= right(xyrect) && bottom(xyrect) <= data[k,2] <= top(xyrect)
      ij = xy2ij(Point2f0(data[k,1], data[k,2]), c)
      p = set!(buf, p, ij)
    end
  end
  truncate!(buf, p)
  length(buf) < 1 && push!(buf, Point2f0(Inf32, Inf32))  # needed because Makie does not like 0-point lines
end

function linecrop!(buf::AbstractVector{Point2f0}, c::Canvas)
  data = c.datasrc.data
  data === missing && return
  p = 0
  n = size(data,1)
  if n > 0
    xyrect = c.xyrect[]
    lastpt = data[1,:]
    for k in 1:n
      nextpt = data[k < n ? k + 1 : n, :]
      lastpt[1] < left(xyrect) && data[k,1] < left(xyrect) && nextpt[1] < left(xyrect) && continue
      lastpt[1] > right(xyrect) && data[k,1] > right(xyrect) && nextpt[1] > right(xyrect) && continue
      lastpt[2] < bottom(xyrect) && data[k,2] < bottom(xyrect) && nextpt[2] < bottom(xyrect) && continue
      lastpt[2] > top(xyrect) && data[k,2] > top(xyrect) && nextpt[2] > top(xyrect) && continue
      lastpt = data[k,:]
      ij = xy2ij(Point2f0(data[k,1], data[k,2]), c)
      p = set!(buf, p, ij)
    end
  end
  truncate!(buf, p)
  length(buf) < 1 && push!(buf, Point2f0(Inf32, Inf32))  # needed because Makie does not like 0-point lines
end

# TODO: check if average time of pooling is correct
function linepool!(buf::AbstractVector{Point2f0}, c::Canvas; pooling=orderedextrema)
  data = c.datasrc.data
  data === missing && return
  n = size(data,1)
  n < 2 && return linecrop!(buf, c)
  x0 = data[1,1]
  dx = data[2,1] - x0
  x2ndx(x) = round(Int, (x - x0) / dx)
  xyrect = c.xyrect[]
  n1 = x2ndx(left(xyrect))
  n1 < 1 && (n1 = 1)
  n2 = x2ndx(right(xyrect))
  n2 > n && (n2 = n)
  p = 0
  if n1 <= n && n2 >= 1
    m = width(c.ijrect)
    b = fld(n2 - n1, m)
    if b <= 1
      for k ∈ n1:n2
        ij = xy2ij(Point2f0(data[k,1], data[k,2]), c)
        p = set!(buf, p, ij)
      end
    else
      for k ∈ n1:b:n2
        k2 = k + b - 1
        k2 > n && (k2 = n)
        blk = @view data[k:k2,2]
        x = (data[k,1] + data[k2,1]) / 2
        for y ∈ pooling(blk)
          ij = xy2ij(Point2f0(x, y), c)
          p = set!(buf, p, ij)
        end
      end
    end
  end
  truncate!(buf, p)
  length(buf) < 1 && push!(buf, Point2f0(Inf32, Inf32))  # needed because Makie does not like 0-point lines
end

# TODO: check if sizes need to be adjusted by 1 for pixels vs data coordinates
function heatmappool!(buf::AbstractMatrix, c::Canvas; pooling=mean)
  data = c.datasrc.data
  data === missing && return
  xsize, ysize = size(data)
  xpd = (c.datasrc.xmax - c.datasrc.xmin) / xsize
  ypd = (c.datasrc.ymax - c.datasrc.ymin) / ysize
  isize, jsize = size(buf)
  xyrect = c.xyrect[]
  xpi = width(xyrect) / isize
  ypj = height(xyrect) / jsize
  dpi = round(Int, xpi / xpd)
  dpj = round(Int, ypj / ypd)
  dpi < 1 && (dpi = 1)
  dpj < 1 && (dpj = 1)
  for j ∈ 1:jsize
    for i ∈ 1:isize
      x = round(Int, ((i-1)*xpi + left(xyrect) - c.datasrc.xmin) / xpd)
      y = round(Int, ((j-1)*ypj + bottom(xyrect) - c.datasrc.ymin) / ypd)
      x1 = x - fld(dpi, 2)
      x2 = x + cld(dpi, 2)
      y1 = y - fld(dpj, 2)
      y2 = y + cld(dpj, 2)
      if x1 > xsize || x2 < 1 || y1 > ysize || y2 < 1
        buf[i,j] = 0
      else
        x1 < 1 && (x1 = 1)
        x2 > xsize && (x2 = xsize)
        y1 < 1 && (y1 = 1)
        y2 > xsize && (y2 = xsize)
        blk = @view data[x1:x2,y1:y2]
        buf[i,j] = pooling(blk)
      end
    end
  end
end

function aggregate!(buf::AbstractMatrix, c::Canvas)
  m, n = size(buf)
  buf .= zero(buf[1,1])
  data = c.datasrc.data
  for k ∈ 1:size(data,1)
    i, j = xy2ij(Int, data[k,1], data[k,2], c)
    0 <= i < m && 0 <= j < n && (buf[i+1, j+1] += 1)
  end
  # TODO: add support for spreading?
end

### helpers

function set!(buf, p, pt)
  if p < length(buf)
    p += 1
    buf[p] = pt
  else
    push!(buf, pt)
    p = length(buf)
  end
  p
end

function truncate!(buf, p)
  p < length(buf) && splice!(buf, p+1:length(buf))
end

orderedextrema(x) = argmin(x) < argmax(x) ? (minimum(x), maximum(x)) : (maximum(x), minimum(x))
