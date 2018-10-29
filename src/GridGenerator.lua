local rs = game:GetService("ReplicatedStorage")
local stack = require(rs.Stack)

local GridGenerator = {}
GridGenerator.__index = GridGenerator

local directionTable = {
	["U"]  = {x = 0, y = -1},
	["UL"] = {x = -1, y = -1},
	["UR"] = {x = 1, y = -1},
	["L"]  = {x = -1, y = 0},
	["R"]  = {x = 1, y = 0},
	["D"]  = {x = 0, y = 1},
	["DL"] = {x = -1, y = 1},
	["DR"] = {x = 1, y = 1},
}

function estimate(currentInstance, targetInstance)
	return (targetInstance.Position - currentInstance.Position).magnitude
end

function GridGenerator.new(width, height, gridScale, _debug)
	local self = setmetatable({}, GridGenerator)
	self._gridTable = {}
	self._clusters = {}
	self._width = width
	self._height = height
	self._gridScale = gridScale or 1
	self._debug = _debug or false
	
	-- create grid as intances
	self:generateEmptyGrid()
	return self
end

function GridGenerator:setDebugEnabled(value)
	self._debug = value
end

function GridGenerator:generateEmptyGrid()
	local grids = Instance.new("Folder")
	grids.Name = "grids"
	grids.Parent = workspace
	for y = 1, self._height do
		for x = 1, self._width do
			local gridInstance = rs.Grid:Clone()
			gridInstance.Parent = workspace.grids
			gridInstance.Position = Vector3.new(x * self._gridScale, 0.1, y * self._gridScale)
			self._gridTable[self:coordToIndex(x, y)] = gridInstance
		end
	end
end

function GridGenerator:getInstance(x, y)
	return self._gridTable[self:coordToIndex(x, y)]
end

function GridGenerator:markOccupied(x, y)
	local idx = self:coordToIndex(x, y)
	self._gridTable[idx].CollisionGroupId = 1

	if self._debug then
		self._gridTable[idx].Transparency = 1
	end
end

function GridGenerator:markClusters(id, nodeList)
	if not nodeList then return end
	if id < 2 then 
		warn("Id invalid for clusters.")
		return
	end

	for _, node in pairs(nodeList) do
		local idx = self:coordToIndex(node.x, node.y)
		if idx then
			self._gridTable[idx].CollisionGroupId = id

			if self._debug then
				self._gridTable[idx].Color = Color3.new(0.1 * id, 0, 0)
			end
		end
	end
end

function GridGenerator:coordToIndex(x, y)
	if x < 1 or y < 1  or x > self._width or y > self._height then 
		return
	end
	return (y - 1) * self._width + x
end

function GridGenerator.filterNeighbours(neighbours, incomingDir)
	local validNextMove = {}
	if string.len(incomingDir) == 1 then
		-- horizontal or vertical directions
		for dir, nb in pairs(neighbours) do
			if string.find(dir, incomingDir) then
				validNextMove[dir] = nb
			end
		end
	elseif string.len(incomingDir) == 2 then
		-- diagonal directions
		validNextMove[incomingDir] = neighbours[incomingDir]
		local dir = string.sub(incomingDir, 1, 1)
		validNextMove[dir] = neighbours[dir]
		dir = string.sub(incomingDir, 2, 2)
		validNextMove[dir] = neighbours[dir]
	end
	return validNextMove
end

-- Using index contains directions so that we could filter using string
function GridGenerator:getNeighbours(x, y, incomingDir)
	local neighbours = {}
	if not self:coordToIndex(x, y) then return neighbours end
	for dirName, dir in pairs(directionTable) do
		neighbours[dirName] = self._gridTable[self:coordToIndex(x + dir.x, y + dir.y)]
	end
	return incomingDir and self.filterNeighbours(neighbours, incomingDir) or neighbours
end

function GridGenerator:sortNeighbours(neighbours, target)
	local tmpTable = {}
	for dir, n in pairs(neighbours) do
		tmpTable[#tmpTable + 1] = {
			direction = dir,
			instance = n,
			est = estimate(n, target),
		}
	end
	table.sort(tmpTable, function(a, b)
		return a.est > b.est
	end)
	return tmpTable
end

function GridGenerator:path(startX, startY, endX, endY)
	local visited = {}
	local nodes = stack.new()
	local success = false
	local moves = {}
	local instancePath = {}

	nodes:push({
		x = startX, 
		y = startY, 
		direction = false,
		depth = 0
	})
	local startInstance = self:getInstance(startX, startY)
	local targetInstance = self:getInstance(endX, endY)
	instancePath[1] = startInstance

	while true do
		local currentNode = nodes:pop()
		if not currentNode then
			break
		end

		local currentInstance = self:getInstance(currentNode.x, currentNode.y)
		local continue = false

		-- if node already in the path should ignore
		for i = 1, #instancePath - 1 do
			if instancePath[i] == currentInstance then
				continue = true
			end
		end
			
		if not continue then
			-- process current node
			if not visited[currentInstance] or not visited[currentInstance][currentNode.direction] then
				if self._debug then
					local color = currentInstance.Color
					currentInstance.Color = Color3.new(1, 1, 0)
					-- wait()
					currentInstance.Color = color
				end
	
				if not visited[currentInstance] then
					visited[currentInstance] = {
						[currentNode.direction] = true
					}
				else
					visited[currentInstance][currentNode.direction] = true
				end
				
				if currentNode.depth > 0 then
					for i = currentNode.depth + 1, #moves do
						moves[i] = nil
						instancePath[i + 1] = nil
					end
					moves[currentNode.depth] = currentNode.direction
					instancePath[currentNode.depth + 1] = currentInstance
				end
				
				-- path found
				if currentNode.x == endX and currentNode.y == endY then
					success = true
					break
				end
	
				local neighbours = self:getNeighbours(currentNode.x, currentNode.y, currentNode.direction)
				
				-- push neighbours
				neighbours = self:sortNeighbours(neighbours, targetInstance)
				for i = 1, #neighbours do
					local nextNode = neighbours[i]
					if nextNode.instance.CollisionGroupId == 0 or nextNode.instance == targetInstance then
						nodes:push({
							x = currentNode.x + directionTable[nextNode.direction].x,
							y = currentNode.y + directionTable[nextNode.direction].y,
							direction = nextNode.direction,
							depth = currentNode.depth + 1
						})
					end
				end
			end -- end process current node
		end -- if continue, directly jmp here
	end

	if success then
		return {
			moves = moves,
			instancePath = instancePath,	
		}
	end
end

return GridGenerator