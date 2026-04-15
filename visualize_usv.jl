using JLD2
using CairoMakie 

file = jldopen("chennai_surge_results.jld2")

iterations = parse.(Int, keys(file["timeseries/t"]))
times = [file["timeseries/t/$i"] for i in iterations]

sample_η = file["timeseries/η/$(iterations[1])"][:, :, 1]
nx, ny = size(sample_η)
x = range(0, 100, length=nx)
y = range(0, 100, length=ny)

# Calculating dynamic scaling based on the exaggerated heights
final_η = file["timeseries/η/$(iterations[end])"][:, :, 1]
max_wave = maximum(abs, final_η)
z_exaggeration = 5.0 # VERTICAL EXAGGERATION: Stretch the waves 5x!
plot_scale = (max_wave > 0.001 ? max_wave : 0.1) * z_exaggeration

fig = Figure(size = (1200, 800))

# Force the 3D aspect ratio to display the Z-axis prominently
ax = Axis3(fig[1, 1], 
    title = "Chennai Coast USV Station-Keeping",
    xlabel = "Longitude (m)", ylabel = "Latitude (m)", zlabel = "Exaggerated Wave Height",
    elevation = pi/8, azimuth = pi/4,
    aspect = (1, 1, 0.5) # Force the Z-axis box to be exactly half as tall as the X/Y axes
)

# Raw data observable
raw_η_obs = Observable(sample_η)

# Mapping the raw data to visually stretched data on the fly
η_surface = @lift($raw_η_obs .* z_exaggeration)

surface!(ax, x, y, η_surface, colormap = :ocean, colorrange = (-plot_scale, plot_scale))
scatter!(ax, [5.0], [5.0], [plot_scale], color = :red, markersize = 25)

# Keeping the camera tightly cropped around the USV
xlims!(ax, 35, 65)
ylims!(ax, 35, 65)
zlims!(ax, -plot_scale * 1.5, plot_scale * 1.5) 

@info "Compiling 60-second high-definition video..."

# We now have 1800 frames (saved every 2s for an hour). 
# 1800 frames / 30 fps = exactly 60 seconds of buttery smooth video!
record(fig, "usv_surge_animation.mp4", 1:length(iterations), framerate = 30) do i
    raw_η_obs[] = file["timeseries/η/$(iterations[i])"][:, :, 1]
    ax.title = "Time: $(round(times[i]/60, digits=1)) minutes"
end

close(file)
@info "Hollywood render complete! Check your new mp4 file."