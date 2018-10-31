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
local OFFSET = Vector3.new(0, 0.1, 0)

local seedPool = {}

--[[
	clusterStructure
	{
		[cluster_id] = {
			[instanceReference1] = {x = 0, y = 0},
			[instanceReference1] = {x = 20, y = 1},
			...	
		}	
	}
]]
local clusters = {}

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

local gridState = {
	Empty = 0,
	PathOrObstacle = 1,
	UnconnectedNode = 2,
	ConnectedNode = 3,
}

local function addToCluster(x, y ,_id)
	-- Add node to the cluster[_id]
	if not clusters[_id] then
		clusters[_id] = {}
	end
	local instanceRef = gridGenerator:getInstance(x, y)
	-- it is a valid node in grid
	if instanceRef then
		clusters[_id][instanceRef] = {x = x, y = y}
	end
end

local function generateNode(x, y ,parent)
	
	if not workspace:FindFirstChild("Nodes") then
		local unclusteredNodes = Instance.new("Folder")
		unclusteredNodes.Name = "Nodes"
		unclusteredNodes.Parent = workspace
	end
	local Nodes = workspace.Nodes
	
	local refInstance = gridGenerator:markOccupied(x, y, gridState.UnconnectedNode)
	if refInstance then
		local node = rs.Node:Clone()
		node.Parent = parent or Nodes
		node.Position = refInstance.Position + OFFSET
		node.Size = Vector3.new(0.1, NODE_SIZE, NODE_SIZE)
	end
end

local function createCentralUnit(x, y, l)
	--[[
	 (x,y)* * * *
		* * * * * *
		* * * * * *
		* * * * * *
		* * * * * *
		  * * * *
		Four edges will be the clusters for path-finding
		(x,y) will be the topLeft Conner
		Add edges to different clusters
	--]]
	if l < 3 then
		-- if l less than 3 then it is impossible to generate a shape like this	
		return
	end
	
	local cpu = Instance.new("Folder")
	cpu.Name = "CenteralUnit"
	cpu.Parent = workspace	
	
	local clusterIdPrefix = "CPU"..tostring(x)..tostring(y)
	for i = x + 1, x + l - 2 do
		generateNode(i, y, cpu)
		addToCluster(i, y, clusterIdPrefix.."U")
		generateNode(i, y + l - 1, cpu)
		addToCluster(i, y + l - 1, clusterIdPrefix.."D")
	end
	
	for j = y + 1, y + l - 2 do
		generateNode(x, j, cpu)
		addToCluster(x, j, clusterIdPrefix.."L")
		generateNode(x + l - 1, j, cpu)
		addToCluster(x + l - 1, j, clusterIdPrefix.."R")
	end
	 
	for i = x + 1, x + l - 2 do
		for j = y + 1, y + l - 2 do
			gridGenerator:markOccupied(i, j)
		end
	end
	local corner00 = gridGenerator:markOccupied(x + 1, y + 1)
	local corner11 = gridGenerator:markOccupied(x + l - 2, y + l - 2)
	local centerInstance = rs.Line:Clone()
	local centerLen = (corner11.Position - corner00.Position).magnitude * SQRT_2 / 2
	centerInstance.Parent = cpu
	centerInstance.Size = Vector3.new(centerLen, 0.1, centerLen)
	centerInstance.Position = (corner00.Position + corner11.Position) / 2 + OFFSET
end

local function generateCircuit(instancePath, moves, circuitWidth)
	local w = circuitWidth or CIRCUIT_WIDTH
	local size = #instancePath
	local circuitUnit = Instance.new("Folder")
	circuitUnit.Name = "circuitUnit"
	circuitUnit.Parent = workspace

	if size == 1 then
		return
	end

	for i = 1, size - 1 do
		local line = rs.Line:Clone()
		line.Parent = circuitUnit
		line.Position = (instancePath[i].Position + instancePath[i + 1].Position)/2 + OFFSET
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
		for i = 2, #result.instancePath - 1 do
			result.instancePath[i].CollisionGroupId = _id or 1
			if _debugColor then
				result.instancePath[i].Color = Color3.new(_debugColor.r/#result.instancePath * i,
									  _debugColor.g/#result.instancePath * i,
				  					  _debugColor.b/#result.instancePath * i)
			end
		end
		gridGenerator:markOccupied(startX, startY, gridState.ConnectedNode)
		gridGenerator:markOccupied(endX, endY, gridState.ConnectedNode)	
		generateCircuit(result.instancePath, result.moves, width)		
	end
	return result
end

-- return a specific position on the path with seed
local function interpolate(instancePath, seed, interpolationNumber)
	local size = #instancePath
	local i = math.ceil(seed / interpolationNumber)
	local j = seed - (i - 1) * interpolationNumber
	local t = j / interpolationNumber
	return instancePath[i].Position * (1 - t) + instancePath[i + 1].Position * t
end

local function connectClusters(startId, endId)
	if not clusters[startId] or not clusters[endId] then
		return
	end

	-- iterate through start and end clusters and connecting them as circuit units
	for instanceRefStart, startNode in pairs(clusters[startId]) do
		if instanceRefStart.CollisionGroupId == gridState.UnconnectedNode then
			local candidatePending = false
			for instanceRefEnd, endNode in pairs(clusters[endId]) do
				if instanceRefEnd.CollisionGroupId == gridState.UnconnectedNode then
					candidatePending = true
					createCircuitUnit(startNode.x, startNode.y, endNode.x, endNode.y)
					break
				end
			end
			if not candidatePending then
				break
			end
		end
	end
end
createCentralUnit(24, 25, 6)
createCentralUnit(35, 20, 8)
generateNode(2, 2)
generateNode(5, 3)
generateNode(5, 6)
generateNode(16, 15)
generateNode(16, 16)
generateNode(16, 17)
generateNode(16, 18)
generateNode(35, 35)
generateNode(16, 35)
generateNode(16, 36)
generateNode(35, 36)
generateNode(35, 37)
generateNode(35, 38)
generateNode(36, 35)
generateNode(10, 16)
generateNode(9, 16)
generateNode(7, 16)
generateNode(8, 15)
generateNode(8, 16)
generateNode(16, 18)

generateNode(3,7)
generateNode(3,6)
generateNode(3,5)
generateNode(3,4)
generateNode(7,14)
generateNode(8,15)
generateNode(8,16)
generateNode(6,18)

createCircuitUnit(3, 7, 25, 25)
createCircuitUnit(3, 6, 26, 25, 1.2)
createCircuitUnit(3, 5, 27, 25, 0.4)
createCircuitUnit(3, 4, 28, 25, 0.6)
createCircuitUnit(7, 14, 24, 26)
createCircuitUnit(8, 15, 24, 27, 1)
createCircuitUnit(24, 28, 24, 28)
createCircuitUnit(8, 16, 24, 29, 0.4)
createCircuitUnit(6, 18, 25, 30, 1.4)
connectClusters("CPU2425R", "CPU3520L")

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