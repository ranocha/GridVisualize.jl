module GridVisualize

using Printf
using LinearAlgebra

using DocStringExtensions
using OrderedCollections
using ElasticArrays
using StaticArrays
using Colors
using ColorSchemes
using GeometryBasics
using PkgVersion

using ExtendableGrids



include("dispatch.jl")
include("common.jl")
include("pyplot.jl")
include("makie.jl")
include("vtkview.jl")
include("meshcat.jl")
include("plots.jl")
include("plutovista.jl")


export scalarplot,scalarplot!
export gridplot,gridplot!
export vectorplot,vectorplot!
export streamplot,streamplot!
export save,reveal,backend!
export isplots,isvtkview,ispyplot,ismakie,isplutovista
export GridVisualizer, SubVisualizer
export plottertype, available_kwargs
export default_plotter!, default_plotter
export PyPlotType,MakieType,PlotsType,VTKViewType, PlutoVistaType, MeshCatType

end
