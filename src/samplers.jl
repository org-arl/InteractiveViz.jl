export apply!, pointcrop!, linecrop!, linepool!, aggregate!

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
  n = c.ijhome[].width
  p = 0
  for x ∈ range(xyrect.left, xyrect.left + xyrect.width; length=n+1)
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
    if xyrect.left <= data[k,1] < xyrect.left + xyrect.width && xyrect.bottom <= data[k,2] < xyrect.bottom + xyrect.height
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
    left = xyrect.left
    right = xyrect.left + xyrect.width
    bottom = xyrect.bottom
    top = xyrect.bottom + xyrect.height
    lastpt = data[1,:]
    for k in 1:n
      nextpt = data[k < n ? k + 1 : n, :]
      lastpt[1] < left && data[k,1] < left && nextpt[1] < left && continue
      lastpt[1] > right && data[k,1] > right && nextpt[1] > right && continue
      lastpt[2] < bottom && data[k,2] < bottom && nextpt[2] < bottom && continue
      lastpt[2] > top && data[k,2] > top && nextpt[2] > top && continue
      lastpt = data[k,:]
      ij = xy2ij(Point2f0(data[k,1], data[k,2]), c)
      p = set!(buf, p, ij)
    end
  end
  truncate!(buf, p)
  length(buf) < 1 && push!(buf, Point2f0(Inf32, Inf32))  # needed because Makie does not like 0-point lines
end

function linepool!(buf::AbstractVector{Point2f0}, c::Canvas)
  data = c.datasrc.data
  data === missing && return
  n = size(data,1)
  n < 2 && return linecrop!(buf, c)
  x0 = data[1,1]
  dx = data[2,1] - x0
  x2ndx(x) = round(Int, (x - x0) / dx)
  xyrect = c.xyrect[]
  n1 = x2ndx(xyrect.left)
  n1 < 1 && (n1 = 1)
  n2 = x2ndx(xyrect.left + xyrect.width)
  n2 > n && (n2 = n)
  p = 0
  if n1 <= n && n2 >= 1
    m = c.ijrect[].width
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
        y1, y2 = orderedextrema(blk)
        x = (data[k,1] + data[k2,1]) / 2
        ij = xy2ij(Point2f0(x, y1), c)
        p = set!(buf, p, ij)
        ij = xy2ij(Point2f0(x, y2), c)
        p = set!(buf, p, ij)
      end
    end
  end
  truncate!(buf, p)
  length(buf) < 1 && push!(buf, Point2f0(Inf32, Inf32))  # needed because Makie does not like 0-point lines
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
