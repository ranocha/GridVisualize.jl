global default_backend=nothing

"""
    default_plotter()

Return default plotter backend. By default, this is set to one of `PlutoVista`,`GLMakie`,`PyPlot` and `Plots`
if one of these packages is imported.
"""
function default_plotter()
    global default_backend
    default_backend
end

"""
    default_plotter!(Module)

Set plotter module or `nothing` as the default plotter backend.
"""
function default_plotter!(Plotter)
    global default_backend=Plotter
end

"""
$(SIGNATURES)

Heuristically check if Plotter is VTKView
"""
isvtkview(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:StaticFrame)

"""
$(SIGNATURES)

Heuristically check if Plotter is PyPlot
"""
ispyplot(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:Gcf)

"""
$(SIGNATURES)

Heuristically check if  Plotter is Plots
"""
isplots(Plotter)= (typeof(Plotter)==Module) && isdefined(Plotter,:gr)


"""
$(SIGNATURES)

Heuristically check if Plotter is Makie/WGLMakie
"""
ismakie(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:Makie)

"""
$(SIGNATURES)

Heuristically check if Plotter is MeshCat
"""
ismeshcat(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:Visualizer)

"""
$(SIGNATURES)

Heuristically check if Plotter is PlutoVista
"""
isplutovista(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:PlutoVistaPlot)

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type PyPlotType  end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type MakieType   end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type PlotsType   end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter. Experimental.
"""
abstract type VTKViewType end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter. Experimental.
"""
abstract type MeshCatType end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type PlutoVistaType end

"""
$(SIGNATURES)
    
Heuristically detect type of plotter, returns the corresponding abstract type for plotting.
"""
function plottertype(Plotter::Union{Module,Nothing})
    if ismakie(Plotter)
        return MakieType
    elseif isplots(Plotter)
        return PlotsType
    elseif ispyplot(Plotter)
        return PyPlotType
    elseif isvtkview(Plotter)
        return VTKViewType
    elseif ismeshcat(Plotter)
        return MeshCatType
    elseif isplutovista(Plotter)
        return PlutoVistaType
    end
    Nothing
end

plottername(::Type{MakieType})="Makie"
plottername(::Type{PlotsType})="Plots"
plottername(::Type{PyPlotType})="PyPlot"
plottername(::Type{PlutoVistaType})="PlutoVista"
plottername(::Type{VTKViewType})="VTKView"
plottername(::Type{MeshCatType})="MeshCat"
plottername(::Type{Nothing})="nothing"
plottername(p::Union{Module,Nothing}) = plottertype(p) |> plottername


"""
$(TYPEDEF)

A SubVisualizer is just a dictionary which contains plotting information,
including the type of the plotter and its position in the plot.
"""
const SubVisualizer=Union{Dict{Symbol,Any},Nothing}

#
# Update subplot context from dict 
# and provide some backward compatibilitiy switches.
function _update_context!(ctx::SubVisualizer,kwargs)

    for (k,v) in kwargs
        ctx[Symbol(k)]=v
    end
    
    haskey(ctx,:resolution) ?  ctx[:size] = ctx[:resolution] : nothing
    haskey(ctx,:flevel) ?  ctx[:levels] = [ctx[:flevel]] : nothing
    haskey(ctx,:flimits) ? ctx[:limits] = ctx[:flimits] : nothing
    haskey(ctx,:xplane) ? ctx[:xplanes] = [ctx[:xplane]] : nothing
    haskey(ctx,:yplane) ? ctx[:yplanes] = [ctx[:yplane]] : nothing
    haskey(ctx,:zplane) ? ctx[:zplanes] = [ctx[:zplane]] : nothing
    haskey(ctx,:alpha) ? ctx[:outlinealpha] = ctx[:alpha] : nothing

    ctx
end

"""
$(TYPEDEF)

GridVisualizer struct
"""
struct GridVisualizer
    Plotter::Union{Module,Nothing}
    subplots::Array{SubVisualizer,2}
    context::SubVisualizer
    GridVisualizer(Plotter::Union{Module,Nothing}, layout::Tuple, default::SubVisualizer)=new(Plotter,
                                                                                            [copy(default) for I in CartesianIndices(layout)],
                                                                                              copy(default))
end


"""
$(TYPEDSIGNATURES)

Create a  grid visualizer

Plotter: defaults to `default_plotter()` and can be `PyPlot`, `Plots`, `VTKView`, `Makie` or `PlutoVista´.
This pattern allows  to pass the backend as a module to a plot function without heavy default package dependencies.


Depending on the `layout` keyword argument, a 2D grid of subplots is created.
Further `...plot!` commands then plot into one of these subplots:

```julia
vis=GridVisualizer(Plotter=PyPlot, layout=(2,2)
...plot!(vis[1,2], ...)
```

A `...plot`  command just implicitely creates a plot context:

```julia
gridplot(grid, Plotter=PyPlot) 
```

is equivalent to

```julia
vis=GridVisualizer(Plotter=PyPlot, layout=(1,1))
gridplot!(vis,grid) 
reveal(vis)
```

Please note that the return values of all plot commands are specific to the Plotter.

An interactive mode switch key   for GLMakie (`,`)  and  VTKView (`*`) allows to
toggle between "gallery view" showing all plots at once and "focused view" showing only one plot.


Keyword arguments: see [`available_kwargs`](@ref)

"""
function GridVisualizer(;Plotter::Union{Module,Nothing}=default_plotter(), kwargs...)
    default_ctx=Dict{Symbol,Any}( k => v[1] for (k,v) in default_plot_kwargs())
    _update_context!(default_ctx,kwargs)
    layout=default_ctx[:layout]
    if isnothing(Plotter)
        default_ctx=nothing
    end
    p=GridVisualizer(Plotter,layout,default_ctx)
    if !isnothing(Plotter)
        p.context[:Plotter]=Plotter
        for I in CartesianIndices(layout)
            ctx=p.subplots[I]
            i=Tuple(I)
            ctx[:subplot]=i
            ctx[:iplot]=layout[2]*(i[1]-1)+i[2]
            ctx[:Plotter]=Plotter
            ctx[:GridVisualizer]=p
        end
        initialize!(p,plottertype(Plotter))
    end
    p
end

function Base.show(io::IO, mime::MIME"text/html", p::GridVisualizer)
    if isplutovista(p.Plotter)
        show(io,mime,p.subplots[1][:figure])
    else
        output="""<code>GridVisualizer(Plotter=$(p.Plotter))</code>"""
        write(io,output)
    end
end

"""
$(SIGNATURES)

Return the layout of a GridVisualizer
"""
Base.size(p::GridVisualizer)=size(p.subplots)

"""
$(SIGNATURES)

Return a SubVisualizer
"""
Base.getindex(p::GridVisualizer,i,j)=p.subplots[i,j]


"""
$(SIGNATURES)

Return the type of a plotter.
"""
plottertype(p::GridVisualizer)=plottertype(p.Plotter)

#
# Default context information with help info.
#
default_plot_kwargs()=OrderedDict{Symbol,Pair{Any,String}}(
    :show => Pair(false,"Show plot immediately"),
    :reveal => Pair(false,"Show plot immediately (same as :show)"),
    :clear => Pair(true,"Clear plot before adding new content"),
    :layout => Pair((1,1),"Layout of plots in window"),
    :size => Pair((500,500),"Plot window resolution"),
    :legend => Pair(:none,"Legend (position): one of [:none, :best, :lt, :ct, :rt, :lc, :rc, :lb, :cb, :rb]"),    
    :title => Pair("","Plot title"),
    :xlabel => Pair("x","x axis label"),
    :ylabel => Pair("y","y axis label"),
    :zlabel => Pair("z","z axis label"),
    :xlimits => Pair((1,-1),"x axis limits"),
    :ylimits => Pair((1,-1),"y axis limits"),
    :zlimits => Pair((1,-1),"z axis limits"),
    :limits => Pair((1,-1),"function limits"),
    :xscale => Pair(:identity,"x axis  scale: one of [:log, :identity]"),
    :yscale => Pair(:identity,"y axis  scale: one of [:log, :identity]"),
    :aspect => Pair(1.0,"XY Aspect ratio modification"),
    :fontsize => Pair(20,"Fontsize of titles. All others are relative to it"),
    :linewidth => Pair(2,"linewidth for isolines or 1D plots"),
    :linestyle => Pair(:solid,"1D Plot linestyle: one of [:solid, :dash, :dot, :dashdot, :dashdotdot]"),
    :markevery => Pair(5,"1D plot marker stride"),
    :markersize => Pair(5,"1D plot marker size"),
    :markershape => Pair(:none,"1D plot marker shape: one of [:none, :circle, :star5, :diamond, :hexagon, :cross, :xcross, :utriangle, :dtriangle, :rtriangle, :ltriangle, :pentagon, :+, :x]"),
    :color => Pair((0.0,0.0,0.0),"1D plot line color"),
    :cellwise => Pair(false,"1D plots cellwise; unmaintained and can be slow)"),
    :label => Pair("","1D plot label"),
    :levels => Pair(5,"array of isolevels or number of isolevels for comtour plots"),
    :elevation => Pair(0.0,"2D plot height factor for elevation"),
    :colorlevels => Pair(51,"2D/3D contour plot: number of color levels"),
    :colormap => Pair(:viridis,"2D/3D contour plot color map (any from [ColorSchemes.jl](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes))"),
    :colorbar => Pair(:vertical,"2D/3D plot colorbar. One of [:none, :vertical, :horizontal]"),
    :colorbarticks => Pair(:default,"number of ticks in colorbar (:default sets it equal to levels)"),
    :outlinealpha => Pair(0.05,"3D outline surface alpha value"),
    :levelalpha => Pair(0.25,"3D isolevel alpha"),
    :planealpha => Pair(1.0,"3D plane section alpha"),
    :spacing => Pair(:default,"Spacing of quiver points in vector plot"),
    :offset => Pair(:default,"Offset of quiver grid"),
    :vscale => Pair(1.0,"Vector field scale for quiver grid"),
    :vnormalize => Pair(true,"Normalize vector field befor scaling"),
    :interior => Pair(true,"3D plot interior of grid"),
    :xplanes => Pair([prevfloat(Inf)],"3D x plane positions or number thereof"),
    :yplanes => Pair([prevfloat(Inf)],"3D y plane positions or number thereof"),
    :zplanes => Pair([prevfloat(Inf)],"3D z plane positions or number thereof"),
    :zoom => Pair(1.0,"Zoom level"),
    :gridscale => Pair(1.0,"grid scale factor"),
    :azim => Pair(-60,"3D azimuth angle  (in degrees)"),
    :elev => Pair(30,"3D elevation angle  (in degrees)"),
    :perspectiveness => Pair(0.25,"3D perspective A number between 0 and 1, where 0 is orthographic, and 1 full perspective"),
    :scene3d  => Pair("Axis3","3D plot type of Makie scene. Alternaitve to `Axis3` is `LScene`"),
    :fignumber => Pair(1,"Figure number (PyPlot)"),
    :framepos => Pair(1,"Subplot position in frame (VTKView)"),
    :subplot => Pair((1,1),"Private: Actual subplot"),
    :backend => Pair(:default,"Backend for PlutoVista plot"),
    :dim     => Pair(1,"Data dimension for PlutoVista plot"),
    :regions => Pair(:all,"List of regions to plot"),
    :species => Pair(1,"Number of species to plot or number of species in regions"),
)

#
# Print default dict for interpolation into docstrings
#
function _myprint(dict)
    lines_out=IOBuffer()
    for (k,v) in dict
        println(lines_out,"  - `$(k)`: $(v[2]). Default: `$(v[1])`\n")
    end
    String(take!(lines_out))
end

"""
$(SIGNATURES)

Available kwargs for all methods of this package.

$(_myprint(default_plot_kwargs()))
"""
available_kwargs()=println(_myprint(default_plot_kwargs()))



###################################################################################
"""
$(TYPEDSIGNATURES)

Plot grid into subplot in the visualizer. If `[i,j]` is omitted, `[1,1]` is assumed.

Keyword arguments: see [`available_kwargs`](@ref)
"""
function gridplot!(ctx::SubVisualizer,grid::ExtendableGrid; kwargs...)
    _update_context!(ctx,kwargs)
    gridplot!(ctx,plottertype(ctx[:Plotter]),Val{dim_space(grid)},grid)
end

"$(TYPEDSIGNATURES)"
gridplot!(p::GridVisualizer,grid::ExtendableGrid; kwargs...)= gridplot!(p[1,1],grid; kwargs...)


"""
$(TYPEDSIGNATURES)

Create grid visualizer and plot grid

Keyword arguments: see [`available_kwargs`](@ref)
"""
gridplot(grid::ExtendableGrid; Plotter=default_plotter(), kwargs...)=gridplot!(GridVisualizer(Plotter=Plotter; show=true, kwargs...),grid)


###################################################################################
"""
$(TYPEDSIGNATURES)

Plot node vector on grid as P1 FEM function on the triangulation into subplot in the visualizer. If `[i,j]` is omitted, `[1,1]` is assumed.

If instead of the node vector,  a function is given, it will be evaluated on the grid.

If instead of the grid, coordinate vectors are given, a temporary grid is created.

Keyword arguments: see [`available_kwargs`](@ref)
"""
function scalarplot!(ctx::SubVisualizer,grid::ExtendableGrid,func; kwargs...)
    _update_context!(ctx,Dict(:clear=>true,:show=>false,:reveal=>false))
    _update_context!(ctx,kwargs)
    scalarplot!(ctx,plottertype(ctx[:Plotter]),Val{dim_space(grid)},grid,func)
end

"$(TYPEDSIGNATURES)"
scalarplot!(p::GridVisualizer,grid::ExtendableGrid, func; kwargs...) = scalarplot!(p[1,1],grid,func; kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot!(ctx::SubVisualizer,grid::ExtendableGrid,func::Function; kwargs...)=scalarplot!(ctx,grid,map(func,grid);kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot!(ctx::SubVisualizer,func::AbstractVector; kwargs...)=scalarplot!(ctx,simplexgrid(X),1:length(func),func;kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot!(ctx::SubVisualizer,X::AbstractVector,func; kwargs...)=scalarplot!(ctx,simplexgrid(X),func;kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot!(ctx::GridVisualizer,X::AbstractVector,func; kwargs...)=scalarplot!(ctx,simplexgrid(X),func;kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot!(ctx::GridVisualizer,X::AbstractVector,Y::AbstractVector,func; kwargs...)=scalarplot!(ctx,simplexgrid(X,Y),func;kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot!(ctx::GridVisualizer,X::AbstractVector,Y::AbstractVector,Z::AbstractVector, func; kwargs...)=scalarplot!(ctx,simplexgrid(X,Y,Z),func;kwargs...)



"""
$(TYPEDSIGNATURES)

Plot node vector on grid as P1 FEM function on the triangulation.

If instead of the node vector,  a function is given, it will be evaluated on the grid.
 
If instead of the grid,  vectors for coordinates are given, a grid is created automatically.

For keyword arguments, see [`available_kwargs`](@ref)
"""
scalarplot(grid::ExtendableGrid,func ;Plotter=default_plotter(),kwargs...) = scalarplot!(GridVisualizer(Plotter=Plotter; kwargs...),grid,func,show=true)


"$(TYPEDSIGNATURES)"
scalarplot(func::AbstractVector ;kwargs...)=scalarplot(1:length(func),func;kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot(X::AbstractVector,func ;kwargs...)=scalarplot(simplexgrid(X),func;kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot(X::AbstractVector,Y::AbstractVector,func ;kwargs...)=scalarplot(simplexgrid(X,Y),func;kwargs...)

"$(TYPEDSIGNATURES)"
scalarplot(X::AbstractVector,Y::AbstractVector,Z::AbstractVector, func ;kwargs...)=scalarplot(simplexgrid(X,Y,Z),func;kwargs...)

###################################################################################


"""
$(TYPEDSIGNATURES)

Plot piecewise linear vector field  as quiver plot.
"""
function vectorplot!(ctx::SubVisualizer,grid::ExtendableGrid,func; kwargs...)
    _update_context!(ctx,Dict(:clear=>true,:show=>false,:reveal=>false))
    _update_context!(ctx,kwargs)
    vectorplot!(ctx,plottertype(ctx[:Plotter]),Val{dim_space(grid)},grid,func)
end

vectorplot!(ctx,ptype,::Type{Val{1}},grid,func::Matrix)=scalarplot!(ctx,ptype,Val{1},grid,func[1,:])
vectorplot!(ctx,ptype,::Type{Val{1}},grid,func::Vector)=scalarplot!(ctx,ptype,Val{1},grid,func)



"$(TYPEDSIGNATURES)"
vectorplot!(p::GridVisualizer,grid::ExtendableGrid, func; kwargs...) = vectorplot!(p[1,1],grid,func; kwargs...)
"$(TYPEDSIGNATURES)"
vectorplot!(ctx::GridVisualizer,X::AbstractVector,Y::AbstractVector,func; kwargs...)=vectorplot!(ctx,simplexgrid(X,Y),func;kwargs...)
"$(TYPEDSIGNATURES)"
vectorplot!(ctx::GridVisualizer,X::AbstractVector,Y::AbstractVector,Z::AbstractVector, func; kwargs...)=vectorplot!(ctx,simplexgrid(X,Y,Z),func;kwargs...)


"""
$(TYPEDSIGNATURES)

Plot piecewise linear vector field  as quiver plot.
"""
vectorplot(grid::ExtendableGrid,func ;Plotter=default_plotter(),kwargs...) = vectorplot!(GridVisualizer(Plotter=Plotter; kwargs...),grid,func,show=true)
"$(TYPEDSIGNATURES)"
vectorplot(X::AbstractVector,Y::AbstractVector,func ;kwargs...)=vectorplot(simplexgrid(X,Y),func;kwargs...)
"$(TYPEDSIGNATURES)"
vectorplot(X::AbstractVector,Y::AbstractVector,Z::AbstractVector, func ;kwargs...)=vectorplot(simplexgrid(X,Y,Z),func;kwargs...)



###################################################################################


"""
$(TYPEDSIGNATURES)

Plot piecewise linear vector field  as stream plot.
(2D pyplot only)
"""
function streamplot!(ctx::SubVisualizer,grid::ExtendableGrid,func; kwargs...)
    _update_context!(ctx,Dict(:clear=>true,:show=>false,:reveal=>false))
    _update_context!(ctx,kwargs)
    streamplot!(ctx,plottertype(ctx[:Plotter]),Val{dim_space(grid)},grid,func)
end

"$(TYPEDSIGNATURES)"
streamplot!(p::GridVisualizer,grid::ExtendableGrid, func; kwargs...) = streamplot!(p[1,1],grid,func; kwargs...)
"$(TYPEDSIGNATURES)"
streamplot!(ctx::GridVisualizer,X::AbstractVector,Y::AbstractVector,func; kwargs...)=streamplot!(ctx,simplexgrid(X,Y),func;kwargs...)
"$(TYPEDSIGNATURES)"
streamplot!(ctx::GridVisualizer,X::AbstractVector,Y::AbstractVector,Z::AbstractVector, func; kwargs...)=streamplot!(ctx,simplexgrid(X,Y,Z),func;kwargs...)


"""
$(TYPEDSIGNATURES)

Plot piecewise linear vector field  as stream plot.
(2D pyplot only)
"""
streamplot(grid::ExtendableGrid,func ;Plotter=default_plotter(),kwargs...) = streamplot!(GridVisualizer(Plotter=Plotter; kwargs...),grid,func,show=true)
"$(TYPEDSIGNATURES)"
streamplot(X::AbstractVector,Y::AbstractVector,func ;kwargs...)=streamplot(simplexgrid(X,Y),func;kwargs...)
"$(TYPEDSIGNATURES)"
streamplot(X::AbstractVector,Y::AbstractVector,Z::AbstractVector, func ;kwargs...)=streamplot(simplexgrid(X,Y,Z),func;kwargs...)




"""
$(TYPEDSIGNATURES)

Finish and show plot. Same as setting `:reveal=true` or `:show=true` in last plot statment
for a context.
"""
reveal(visualizer::GridVisualizer)=reveal(visualizer, plottertype(visualizer.Plotter))

"""
$(TYPEDSIGNATURES)

Save last plotted figure from visualizer to disk.
"""
save(fname::String,visualizer::GridVisualizer)=save(fname,visualizer, plottertype(visualizer.Plotter))

"""
$(TYPEDSIGNATURES)

Save scene returned from [`reveal`](@ref), [`scalarplot`](@ref) or [`gridplot`](@ref)  to disk.
"""
save(fname::String,scene;Plotter = default_plotter() )=save(fname,scene,Plotter,plottertype(Plotter))



#
# Dummy methods to allow Plotter=nothing
#
_update_context!(::Nothing,kwargs)=nothing
Base.copy(::Nothing)=nothing

gridplot!(ctx::Nothing,grid::ExtendableGrid;kwargs...)=nothing
gridplot!(ctx, ::Type{Nothing}, ::Type{Val{1}}, grid)=nothing
gridplot!(ctx, ::Type{Nothing}, ::Type{Val{2}}, grid)=nothing
gridplot!(ctx, ::Type{Nothing}, ::Type{Val{3}}, grid)=nothing

scalarplot!(ctx::Nothing,grid::ExtendableGrid,func;kwargs...)=nothing
scalarplot!(ctx::Nothing,grid::ExtendableGrid,func::Function;kwargs...)=nothing
scalarplot!(ctx, ::Type{Nothing}, ::Type{Val{1}},grid,func)=nothing
scalarplot!(ctx, ::Type{Nothing}, ::Type{Val{2}},grid,func)=nothing
scalarplot!(ctx, ::Type{Nothing}, ::Type{Val{3}},grid,func)=nothing

vectorplot!(ctx::Nothing,grid::ExtendableGrid,func;kwargs...)=nothing
vectorplot!(ctx::Nothing,grid::ExtendableGrid,func::Function;kwargs...)=nothing
vectorplot!(ctx, ::Type{Nothing}, ::Type{Val{2}},grid,func)=nothing
vectorplot!(ctx, ::Type{Nothing}, ::Type{Val{3}},grid,func)=nothing

streamplot!(ctx::Nothing,grid::ExtendableGrid,func;kwargs...)=nothing
streamplot!(ctx::Nothing,grid::ExtendableGrid,func::Function;kwargs...)=nothing
streamplot!(ctx, ::Type{Nothing}, ::Type{Val{2}},grid,func)=nothing
streamplot!(ctx, ::Type{Nothing}, ::Type{Val{3}},grid,func)=nothing




save(fname,scene,Plotter::Nothing,::Type{Nothing})=nothing
displayable(ctx,Any)=nothing
reveal(p,::Type{Nothing})=nothing

