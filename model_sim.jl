using Oceananigans
using Oceananigans.Units
using Printf
using CUDA

# --------------------------------------------------------
# Environment Setup (The Chennai Coast)
# --------------------------------------------------------
# Using a moderate grid size so it runs reasonably fast on a standard CPU
grid = RectilinearGrid(GPU(),size=(64, 64, 16), 
                       extent=(100, 100, 5), 
                       topology=(Bounded, Bounded, Bounded))
@inline function storm_surge(x, y, t)
    base_stress = -5.0 # Base wind stress in N/m² (negative for wind blowing towards the shore)
    
    # A massive wind gust that travels across the water at 10 m/s.
    # The wind aggressively pulses, forcing the water to slosh and form deep gravity waves.
    variation = 2.0 * sin(2.0 * 3.141592653589793 * (x - 10.0 * t) / 30.0)
    
    return (base_stress * (1.0 + variation)) / 1024.0
end

u_top_bc = FluxBoundaryCondition(storm_surge)
u_bcs = FieldBoundaryConditions(top = u_top_bc)

# --------------------------------------------------------
# Mechatronics Setup (The Ghost USV)
# --------------------------------------------------------
const x_target = 50.0
const y_target = 50.0

thrust_field = Forcing(@inline (x, y, z, t) -> 
    (x > 48.0 && x < 52.0 && y > 48.0 && y < 52.0 && z > -2.0) ? 
    clamp(0.05 * (50.0 - x), -0.2, 0.2) : 0.0
)

# --------------------------------------------------------
# Model Initialization
# --------------------------------------------------------
@info "Building the Hydrostatic Free Surface Model..."
model = HydrostaticFreeSurfaceModel(grid; 
    momentum_advection = VectorInvariant(),
    free_surface = SplitExplicitFreeSurface(grid, substeps=30), # <-- Updated solver
    coriolis = FPlane(latitude=13.08), 
    boundary_conditions = (u=u_bcs,), 
    forcing = (u=thrust_field,),
    closure = SmagorinskyLilly()
)

# --------------------------------------------------------
# Simulation Configuration
# --------------------------------------------------------
# Creating a wizard that dynamically adjusts Δt based on velocity
wizard = TimeStepWizard(cfl=0.2, max_change=1.1, max_Δt=0.5)

simulation = Simulation(model, Δt=0.01, stop_time=1hour)

# Adding a progress message
function print_progress(sim)
    time_str = prettytime(sim.model.clock.time)
    # Printing the current Δt so you can watch it adapt to the waves
    @info "Simulation Time: $time_str | Current Δt: $(prettytime(sim.Δt)) | Max u: $(maximum(abs, sim.model.velocities.u))"
end
simulation.callbacks[:progress] = Callback(print_progress, IterationInterval(100))

# Also telling the wizard to update every iteration
simulation.callbacks[:wizard] = Callback(wizard, IterationInterval(10))
# --------------------------------------------------------
# Data Logging (Output Writer)
# --------------------------------------------------------
# We need to save the surface height (η) and the surface velocities (u)
@info "Configuring output writers..."

# Automatically extract all valid prognostic fields for your specific version
model_fields = fields(model) 

simulation.output_writers[:surface_data] = JLD2Writer(model,
    (; η = model_fields.η, u = u=model.velocities.u), 
    schedule = TimeInterval(2),
    filename = "chennai_surge_results.jld2",
    overwrite_existing = true
)

# --------------------------------------------------------
# Executing the simulation
# --------------------------------------------------------
@info "Starting the turbulent sea simulation. Hold on to your hats!"
run!(simulation)
@info "Simulation complete. Data saved to chennai_surge_results.jld2"