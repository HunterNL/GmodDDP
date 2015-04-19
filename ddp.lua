-- see bottom of file for useage
if CLIENT then return end

print("DDP loaded")



if not DDP then
	DDP = {}
	DDP.__index = DDP
end

DDP.methodId = 1

function DDP.Create(url,port)
	local self = setmetatable({},DDP)

	self.socket = WS.Create(url.."/websocket",port)
	self.socket:Connect()
	self.state="CONNECTING"

	self.collections = {}
	self.session = ""

	self.socket:SetCallbackReceive(function(data)
		self:OnMessage(data)
	end)

	self.socket:SetCallbackConnected(function()
		self:OnOpen()
	end)

	self.socket:SetCallbackClose(function(byclient)
		self:OnClose(byclient)
	end)

	return self
end

function DDP:OnOpen()
	self.state="OPEN"
	self:Connect()
end

function DDP:OnMessage(data)
	print("Incoming message "..data)
	local data = util.JSONToTable(data)

	if(data.msg=="ping") then
		self:Write("{\"msg\":\"pong\"}")
	end

	if(data.msg=="added") then
		local collection = data.collection
		local id = data.id
		local fields = data.fields

		if(self.collections[collection]!=nil) then
			self.collections[collection][id] = fields
		else
			self.collections[collection]={id=fields}
		end
	end

	if(data.msg=="connected") then
		self.session=data.session
	end
end

function DDP:OnClose()

end

function DDP:Close()
	self.socket:Close()
end

function DDP:Write(data)
	if (type(data) == "table") then
		data = util.TableToJSON(data)
	end
	--[[local msg = util.TableToJSON({
		msg = "connect",
		version =  "1",
		support = {1}
	})--]]

	print("Outdoing message"..data)
	self.socket:Send(data)
end

function DDP:PrintCollections()
	PrintTable(self.collections)
end

function DDP:Call(name,params)
	local pstring --params string

	if params == nil then
		pstring = "[]"
	else
		pstring= "["
		for k,v in pairs(params) do
			pstring = pstring.."\""..v.."\""

			if(k!=#params) then
				pstring = pstring..","
			end
		end
		pstring = pstring.."]"
	end



	local msg = "{\"msg\":\"method\",\"method\":\""..name.."\",\"id\":\""..self:getMethodId().."\", \"params\" :"..pstring.."}"
	self:Write(msg)
end

function DDP:getMethodId()
	local id = DDP.methodId
	DDP.methodId = DDP.methodId + 1
	return id
end

function DDP:Connect()
	local session
	if(self.session !="") then
		session = ",\"session\":\"..session..\""
	else
		session = ""
	end

	local msg = "{\"msg\":\"connect\",\"version\":\"1\",\"support\":[\"1\"]"..session.."}" --Manual JSON because lua cannot into arrays
	self:Write(msg)
end
