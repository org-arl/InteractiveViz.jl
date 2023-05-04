using GLMakie

x = randn(10_000)
lines(x)

x = Observable(randn(10_000))
lines(x)

x[] = randn(10_000)

let fig = Figure()
  lines(fig[1,1], x)
  lines(fig[1,2], x)
  fig
end

x[] = randn(10_000)

let fig = Figure()
  p1 = lines(fig[1,1], x)
  p2 = lines(fig[2,1], @lift(abs.($x)))
  linkxaxes!(p1.axis, p2.axis)
  fig
end

@async begin
  for i ∈ 1:1000
    x[] = 0.9 .* x[] .+ 0.1 .* randn(10_000)
    sleep(0.01)
  end
end

using InteractiveViz

x = randn(10_000_000)

lines(x)
ilines(x)

let x = range(0, 10; length=1500)
  lines(x, sin.(x))
end

ilines(sin, 0, 10)

iheatmap(InteractiveViz.Demo.mandelbrot; colorrange=(0,1), colormap=:jet, axis=(; limits=(-3, 1.5, -2, 2)))
Colorbar(ans.figure[:,end+1], ans.plot)

x = randn(100_000, 100)
x .+= range(-1.0, 1.0; length=100_000)

iheatmap(x; colorrange=(-5,5), colormap=:jet)
Colorbar(ans.figure[:,end+1], ans.plot)

x = [Point2f(randn(), randn()) for _ ∈ 1:10_000_000]
y = [Point2f(0.5 * randn() + 1, 0.5 * randn() + 1.5) for _ ∈ 1:10_000_000]

iscatter(x; markersize=2)
iscatter!(y; markersize=2, color=:red)

scatter(x; markersize=2)
scatter!(y; markersize=2, color=:red)