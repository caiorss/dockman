import PyPlot; plt = PyPlot;

x = 0:2:10
y = @. x^2 - 4x + 10

println(" x = ", collect(x)')
println(" y = ", y')

plt.plot(x, y)
 