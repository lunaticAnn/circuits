local Stack = {}
Stack.__index = Stack

function Stack.new()
	local self = {}
	setmetatable(self, Stack)
	self.data = {}
	self._size = 0
	return self
end

function Stack:push(obj)
	self._size = self._size + 1
	self.data[self._size] = obj
end

function Stack:pop()
	if self._size == 0 then return end
	local item = self.data[self._size]
	self.data[self._size] = nil
	self._size = self._size - 1
	return item
end

return Stack