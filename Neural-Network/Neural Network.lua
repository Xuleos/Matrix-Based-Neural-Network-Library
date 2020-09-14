local module = {}

local matmath = require(script.MatrixMathematics)

local max = math.max
local exp = math.exp
local function Activator(x) --leaky relu
	return max(.01*x, x)
end

local function Sigmoid(x) --activator function for the final layer to add non-linearity
	return 1/(1+exp(-x))
end

function module.Create(Size) --creates a neural network
	local network = {}
	local biases = {}
	for i = 1,#Size-1 do
		local nextnum = i+1
		network[i] = matmath.CreateRandom({Size[i], Size[nextnum]}, -2, 2)
		biases[i] = matmath.CreateRandom({1, Size[nextnum]}, -2, 2)
	end
	return {network, biases}
end

function module.Run(Network, Inputs, BackProp) --input size: x by 1
	local compinp = {}
	for i = 1,#Inputs do
		compinp[i] = {Inputs[i]}
	end
	
	local activations = {}
	activations[1] = compinp
	
	local rawact = activations
	
	for i = 1,#Network[1]-1 do -- -1 because the output layer is done slightly differently
		local nextnum = i+1
		activations[nextnum] = matmath.Multiply(Network[1][i], activations[i])
		activations[nextnum] = matmath.Add(activations[nextnum], Network[2][i])
		rawact[nextnum] = activations[nextnum]
		activations[nextnum] = matmath.Map(activations[nextnum], Activator)
	end
	activations[#Network[1]+1] = matmath.Multiply(Network[1][#Network[1]], activations[#Network[1]])
	activations[#Network[1]+1] = matmath.Add(activations[#Network[1]+1], Network[2][#Network[1]])
	rawact[#Network[1]+1] = activations[#Network[1]+1]
	activations[#Network[1]+1] = matmath.Map(activations[#Network[1]+1], Sigmoid)
	
	if BackProp then
		return {activations, rawact}
	end
	
	for i = 1,#activations[#Network[1]+1] do --changes the output matrix into a simple table
		activations[#Network[1]+1][i] = activations[#Network[1]+1][i][1]
	end
	return activations[#Network[1]+1]
end


local function DAct(x)
	if x>=0 then
		return 1
	end
	return .01
end

local function DSig(x)
	local s = Sigmoid(x)
	return s*(1-s)
end


function module.BackPropagate(Network, TrainingData, LearningRate)
	--Training Data Structure: table of tables containing a table inputs and table of expected outputs
	local gradients = {}
	local bigrad = {}
	
	for i = 1,#Network[1] do --for the number of layers in the network [this is to create a set of empty matrices to do stochastic gradient descent]
		gradients[i] = matmath.Create({#Network[1][i][1], #Network[1][i]}, 0) --create an empty matrix the same size as the network
		bigrad[i] = matmath.Create({1, #Network[2][i]}, 0) --bias gradient matrix
	end
	for i = 1,#TrainingData do --backpropagate for all given pieces of training data
		local Inputs = TrainingData[i][1]
		local Targets = TrainingData[i][2]
		
		local outputs = module.Run(Network, TrainingData[i][1], true)
		local POut = outputs[1]--processed outputs
		local ROut = outputs[2]--raw outputs
		
		local err = matmath.Subtract(matmath.FromTable(Targets), POut[#POut]) --POut[#POut] is the outputs of the output layer of the network
		
		local errors = {}
		errors[#Network[1]+1] = err
		
		--error likely originates from between here and line 110
		
		for o = #Network[1]+1,2,-1 do --calculate the error for the number of weight matrices in this network
			errors[o-1] = matmath.Transpose(Network[1][o-1])
			errors[o-1] = matmath.Multiply(errors[o-1], errors[o])
		end
		
		--error almost guaranteed happens somewhere between here and line 110
		for o = 1,#Network[1]-1 do -- -1 because the final layer is done a little differently
			local gradient = matmath.Map(ROut[o], DAct)
			gradients[o] = matmath.Add(gradients[o], matmath.Multiply(errors[o+1], matmath.Transpose(gradient)))
			bigrad[o] = matmath.Add(bigrad[o], gradient)
		end
		local gradient = matmath.Map(ROut[#Network[1]], DSig)
		gradients[#Network[1]] = matmath.Add(gradients[#Network[1]], matmath.Multiply(errors[#Network[1]+1], matmath.Transpose(gradient)))
		
		
	end
	
	local deltas = {}
	for i = 1,#gradients do
		deltas[i] = matmath.ScalarMultiply(LearningRate/#TrainingData, gradients[i])
		bigrad[i] = matmath.ScalarMultiply(LearningRate/#TrainingData, bigrad[i])
	end
	local newnet = Network--make a new network to return
	for i = 1,#gradients do
		newnet[1][i] = matmath.Add(newnet[1][i], deltas[i])
		newnet[2][i] = matmath.Add(newnet[2][i], bigrad[i])
	end
	
	return newnet
end


return module