export apply!, subset!, aggregate!

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

function subset!(buf::AbstractVector{Point2f0}, c::Canvas)
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
