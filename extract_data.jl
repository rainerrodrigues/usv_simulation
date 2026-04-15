using JLD2
using CairoMakie

@info "Extracting performance data..."
file = jldopen("chennai_surge_results.jld2")

# Extracting time steps
iterations = parse.(Int, keys(file["timeseries/t"]))
times = [file["timeseries/t/$i"] for i in iterations]

# Grid Math: 64 cells over 100 meters. 
# Index 32 is exactly at 50 meters (The center of the USV)
# Index 10 is at ~15 meters (Out in the unprotected storm)
# Index 16 is the very top surface of the Z-axis
ix_usv = 32
ix_storm = 10
iy_center = 32
z_surface = 16

# Looping through every saved frame and extract the velocity (u) at those exact coordinates
u_usv = [file["timeseries/u/$i"][ix_usv, iy_center, z_surface] for i in iterations]
u_storm = [file["timeseries/u/$i"][ix_storm, iy_center, z_surface] for i in iterations]

close(file)

# --------------------------------------------------------
# Plotting the Dashboard Graph
# --------------------------------------------------------
@info "Generating performance graph..."
fig = Figure(size = (1000, 500))
ax = Axis(fig[1, 1], 
    title = "USV Station-Keeping Performance vs. Storm Surge", 
    xlabel = "Simulation Time (seconds)", 
    ylabel = "Water Velocity (m/s)"
)

# Ploting the wild storm surge in red
lines!(ax, times, u_storm, label = "Wild Surge Velocity (Outside USV)", color = :red, linewidth = 2)

# Plotting the dampened water inside the USV in blue
lines!(ax, times, u_usv, label = "Dampened Velocity (Inside USV Hull)", color = :blue, linewidth = 2)

axislegend(ax, position = :rt) # Place legend in the top right

# Saving the graph as a high-res image
save("usv_performance_graph.png", fig)
@info "Graph saved as usv_performance_graph.png!"