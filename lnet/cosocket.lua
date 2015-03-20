--
-- Written by xphh 2015 with 'MIT License'
--
local core = require "lnet.core"
local Socket = core.socket
local Poll = core.poll

local p = Poll:new(_G["_POLL"])

-- key:fd, vlaue:coroutine
local COMAP = {}

-- co fd list
local FDLIST = {}

-- timeout (sec) for all socket
local TIMEOUT = 3.0

-- object extends from Socket
local CoSocket = Socket:new(-1)

function CoSocket:setevent(bread, bwrite)
	local co = coroutine.running()
	COMAP[self.fd] = co
	table.insert(FDLIST, {fd = self.fd, t = os.clock(), co = co})
	p:control(self.fd, bread, bwrite, true)
end

function CoSocket:setread()
	self:setevent(true, false)
end

function CoSocket:setwrite()
	self:setevent(false, true)
end

-- override wait/connect/send/recv

function CoSocket:wait()
	local begin = os.clock()
	coroutine.yield()
	if os.clock() - begin >= TIMEOUT then
		return -1, "timeout"
	else
		return 0
	end
end

function CoSocket:connect(ip, port)
	local ret, err = Socket.connect(self, ip, port)
	if ret < 0 then
		return ret, err
	end
	self:setwrite()
	return self:wait()
end

function CoSocket:send(data, ip, port)
	local remain_data = data
	local remain_len = #data
	while true do
		local sndlen, err = Socket.send(self, remain_data, ip, port)
		if sndlen < 0 then
			return -1, err
		else
			remain_data = string.sub(remain_data, sndlen + 1)
			remain_len = remain_len - sndlen
			if remain_len <= 0 then
				return #data
			else
				self:setwrite()
				local ret, err = self:wait()
				if ret < 0 then
					return #data - remain_len, err
				end
			end
		end
	end
end

-- if size == nil, recv until disconnected
function CoSocket:recv(size)
	size = size or 0
	local total_data = ""
	local total_len = 0
	local peer_ip = ""
	local peer_port = 0
	while true do
		self:setread()
		local ret, err = self:wait()
		if ret < 0 then
			break
		end
		local rcvlen, data
		rcvlen, data, peer_ip, peer_port = Socket.recv(self, math.max(size, 1024))
		if rcvlen < 0 then
			break
		end
		total_len = total_len + rcvlen
		total_data = total_data..data
		if size > 0 and total_len >= size then
			break
		end
	end
	return total_len, total_data, peer_ip, peer_port
end

-- set timeout
function CoSocket.settimeout(to)
	TIMEOUT = to
end

-- get coroutine by fd, and delete it
function CoSocket.getco(fd)
	local co = COMAP[fd]
	COMAP[fd] = nil
	return co
end

-- return next timeout (sec)
function CoSocket.getnext()
	local now = os.clock()
	while FDLIST[1] ~=nil do
		local to = FDLIST[1].t + TIMEOUT
		if now >= to then
			coroutine.resume(FDLIST[1].co)
			table.remove(FDLIST, 1)
		else
			return to - now
		end
	end
	return -1
end

---------------
return CoSocket