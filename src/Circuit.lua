--[[
<Circuit Generator>
	[x] Stack (DFS)
	[x] Direction Constraint 
	[x] Obstacles (not perfectly work as we have direction restrictions and do not have A*)
	[x] Greedy
	[ ] Cluster PathFinding
	[ ] UnitDeploy
	[x] Scalable
	[x] Circuit Generation
	[x] Electricity
	[ ] Random interpolation number for different path
--]]

local rs = game:GetService("ReplicatedStorage")
local GridGenerator = require(rs.GridGenerator)

local gridGenerator = GridGenerator.new(50, 50, 3, true)
local CIRCUIT_WIDTH = 0.8
local NODE_SIZE = 1.6
local SQRT_2 = math.sqrt(2)
local INTERPOLATION_NUMBER = 30

local seedPool = {}

local lineOrientation = {
	["U"]  = Vector3.new(0, 90, 0),
	["UL"] = Vector3.new(0, 135, 0),
	["UR"] = Vector3.new(0, 45, 0),
	["L"]  = Vector3.new(0, 0, 0),
	["R"]  = Vector3.new(0, 0, 0),
	["D"]  = Vector3.new(0, 90, 0),
	["DL"] = Vector3.new(0, 45, 0),
	["DR"] = Vector3.new(0, 135, 0),
}

local function createCentralUnit(x, y, l)
	--[[
		  * * * *
		* * * * * *
		* * * * * *
		* * * * * *
		* * * * * *
		  * * * *
		Four edges will be the clusters for path-finding
		x,y will be the topLeft Conner
	--]]
	
end

local function generateCircuit(instancePath, moves, circuitWidth)
	local w = circuitWidth or CIRCUIT_WIDTH
	local size = #instancePath
	local circuitUnit = Instance.new("Folder")
	circuitUnit.Name = "circuitUnit"
	circuitUnit.Parent = workspace

	-- create start & end node
	local startNode = rs.Node:Clone()
	startNode.Parent = circuitUnit
	startNode.Position = instancePath[1].Position + Vector3.new(0, 0.1, 0)
	startNode.Size = Vector3.new(0.1, NODE_SIZE, NODE_SIZE)
	if size == 1 then
		return
	end
	
	local endNode = rs.Node:Clone()
	endNode.Parent = circuitUnit
	endNode.Position = instancePath[size].Position + Vector3.new(0, 0.1, 0)
	endNode.Size = Vector3.new(0.1, NODE_SIZE, NODE_SIZE)
	for i = 1, size - 1 do
		local line = rs.Line:Clone()
		line.Parent = circuitUnit
		line.Position = (instancePath[i].Position + instancePath[i + 1].Position)/2 + Vector3.new(0, 0.1, 0)
		line.Orientation = lineOrientation[moves[i]]
		local len = (instancePath[i].Position - instancePath[i + 1].Position).magnitude + w * SQRT_2 / 4
		line.Size =Vector3.new(len, 0.1, w)
	end

	-- create a electricity and throw a seed to the pool
	local electricity = rs.Electricity:Clone()
	electricity.Parent = circuitUnit
	electricity.Emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, w * 0.9),
		NumberSequenceKeypoint.new(1, w * 0.85),
	})
	seedPool[electricity] = {
		seed = 1,
		seedConstraint = INTERPOLATION_NUMBER * (size - 1),
		instancePath = instancePath
	}
end

local function createCircuitUnit(startX, startY, endX, endY, width, _id, _debugColor)
	local result = gridGenerator:path(startX, startY, endX, endY)
	if result then
		for i = 1, #result.instancePath do
			result.instancePath[i].CollisionGroupId = _id or 1
			if _debugColor then
				result.instancePath[i].Color = Color3.new(_debugColor.r/#result.instancePath * i,
									  _debugColor.g/#result.instancePath * i,
				  					  _debugColor.b/#result.instancePath * i)
			end
		end
		generateCircuit(result.instancePath, result.moves, width)		
	end
	return result
end

-- return a specific position on the path with the specific seed
local function interpolate(instancePath, seed, interpolationNumber)
	local size = #instancePath
	local i = math.ceil(seed / interpolationNumber)
	local j = seed - (i - 1) * interpolationNumber
	local t = j / interpolationNumber
	return instancePath[i].Position * (1 - t) + instancePath[i + 1].Position * t
end

gridGenerator:markOccupied(2, 2)
gridGenerator:markOccupied(5, 3)
gridGenerator:markOccupied(5, 6)
gridGenerator:markOccupied(16, 15)
gridGenerator:markOccupied(16, 16)
gridGenerator:markOccupied(16, 17)
gridGenerator:markOccupied(16, 18)
gridGenerator:markOccupied(35, 35)
gridGenerator:markOccupied(16, 35)
gridGenerator:markOccupied(16, 36)
gridGenerator:markOccupied(35, 36)
gridGenerator:markOccupied(35, 37)
gridGenerator:markOccupied(35, 38)
gridGenerator:markOccupied(36, 35)
gridGenerator:markOccupied(10, 16)
gridGenerator:markOccupied(9, 16)
gridGenerator:markOccupied(24, 28)
gridGenerator:markOccupied(24, 29)
gridGenerator:markOccupied(7, 16)
gridGenerator:markOccupied(8, 15)
gridGenerator:markOccupied(8, 16)
gridGenerator:markOccupied(16, 18)
gridGenerator:markOccupied(26, 29)
gridGenerator:markOccupied(25, 29)
gridGenerator:markOccupied(25, 28)

createCircuitUnit(3, 7, 25, 25)
createCircuitUnit(3, 6, 26, 25, 1.2)
createCircuitUnit(3, 5, 27, 25, 0.4)
createCircuitUnit(3, 4, 28, 25, 0.6)
createCircuitUnit(7, 14, 24, 26)
createCircuitUnit(8, 15, 24, 27, 1)
createCircuitUnit(24, 28, 24, 28)
createCircuitUnit(6, 18, 6, 18)
createCircuitUnit(16, 18, 24, 29, 0.4)
createCircuitUnit(8, 16, 25, 30, 1.4)


local RunService = game:GetService("RunService")

RunService.Heartbeat:connect(function()
	for electricity, seedObj in pairs(seedPool) do
		-- update seed
		seedObj.seed = seedObj.seed + 1
		if seedObj.seed == seedObj.seedConstraint then
			seedObj.seed = 1
		end
		electricity.Position =  interpolate(seedObj.instancePath, seedObj.seed, INTERPOLATION_NUMBER)+ Vector3.new(0,0.15,0)
	end
end)