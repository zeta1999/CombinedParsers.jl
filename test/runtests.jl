using CombinedParsers
using Test

@testset "CombinedParsers.jl" begin
    # Write your own tests here.
    include("test-parser.jl")
    include("test-re.jl")
end