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
  pwidth, qwidth = size(data)
  xylims = c.datasrc.xyrect
  xpp = width(xylims) / pwidth
  ypq = height(xylims) / qwidth
  iwidth, jwidth = size(buf)
  xyrect = c.xyrect[]
  xpi = width(xyrect) / iwidth
  ypj = height(xyrect) / jwidth
  ppi = xpi / xpp
  qpj = ypj / ypq
  for j ∈ 1:jwidth
    for i ∈ 1:iwidth
      p = ((i - 1) * xpi + left(xyrect) - left(xylims)) / xpp
      q = ((j - 1) * ypj + bottom(xyrect) - bottom(xylims)) / ypq
      p1 = round(Int, p - ppi/2) + 1
      p2 = round(Int, p + ppi/2) + 1
      q1 = round(Int, q - qpj/2) + 1
      q2 = round(Int, q + qpj/2) + 1
      if p1 > pwidth || p2 < 1 || q1 > qwidth || q2 < 1
        buf[i,j] = 0
      else
        p1 < 1 && (p1 = 1)
        p2 > pwidth && (p2 = pwidth)
        q1 < 1 && (q1 = 1)
        q2 > qwidth && (q2 = qwidth)
        blk = @view data[p1:p2,q1:q2]
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
