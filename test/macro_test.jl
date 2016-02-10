module Macro_Test

using FactCheck, GLAbstraction, Compat

dicta = @compat Dict(
	:a => 2332,
	:b => 777,
	:c => 999,
)

dictb = @compat Dict(
	:a => 2332,
	:b => 777,
	:c => 999,
)

@materialize a,b,c = dicta

facts() do
    @fact a --> dicta[:a]
    @fact b --> dicta[:b]
    @fact c --> dicta[:c]
end

@materialize! a,b,c = dictb

facts() do
    @fact a --> dicta[:a]
    @fact b --> dicta[:b]
    @fact c --> dicta[:c]
    @fact isempty(dictb) --> true
end

@materialize a,b,c = @compat Dict(
	:a => 2332,
	:b => 777,
	:c => 999,
    )

facts() do
    @fact a --> dicta[:a]
    @fact b --> dicta[:b]
    @fact c --> dicta[:c]
end

end
