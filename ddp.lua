-- see bottom of file for useage
if CLIENT then return end

print("DDP loaded")



if not DDP then
	DDP = {}
	DDP.__index = DDP
end

DDP.uid = 1

function DDP.Create(url,port)
	local self = setmetatable({},DDP)

	self.messageHandlers = {}

	self.socket = WS(url.."/websocket",port)
	self.socket:Connect()
	self.state="CONNECTING"

	self.collections = {}
	self.collectionEventQueue = {}
	self.session = ""

	self.socket:SetCallbackReceive(function(data)
		self:OnMessage(data)
	end)

	self.socket:SetCallbackConnected(function()
		self:OnWSOpen()
	end)

	self.socket:SetCallbackClose(function(byclient)
		self:OnWSClose(byclient)
	end)

	return self
end

function DDP:OnWSOpen() --fires when websocket is connected
	self:Connect()
end

function DDP:OnConnected() --fires when ddp is connected

end

function DDP:AddEventToQueue(event)
	local collectionqueue = self.collectionEventQueue[event.collection]

	if(!collectionEventQueue) then
		collectionqueue = {}
		self.collectionEventQueue[event.collection] = collectionEventQueue
	end
	table.insert(collectionqueue,event)
end

function DDP:ProcessEventQueue(collection)
	if(self.collectionEventQueue[collection.name]!=nil) then
		local queue = self.collectionEventQueue[collection.name]
		for k,v in ipairs(queue) do
			self:OnMessage(v)
		end
		queue = nil
		print(self.collectionEventQueue[collection.name])
	end
	collection.populated = true
	collection:OnPopulated()
end

function DDP:LinkCollection(collection)
	if(self.collections[collection.name]!=nil) then
		Error("Colletion with this name already linked")
	else
		self.collections[collection.name]=collection
		self:ProcessEventQueue(collection)
	end
end

function DDP:OnMessage(message)
	print("Incoming message "..message)
	local event = util.JSONToTable(message)
	local collectionName = event.collection
	local collection = self.collections[collectionName]
	local eventType = event.msg

	if(eventType=="added") then
		if(collection) then
			self:DataAdded(event)
			return
		end
	end

	if(eventType=="changed") then
		if(collection) then
			self:DataChanged(event)
			return
		end
	end

	if(eventType=="removed") then
		if(collection) then
			self:DataRemoved(event)
			return
		end
	end

	if(eventType=="connected") then
		self.state="OPEN"
		self.session=event.session

		self:OnConnected()
		return
	end

	if(event.msg=="ping") then
		self:Write("{\"msg\":\"pong\"}")
		return
	end

	if(eventType =="added" or eventType == "changed" or eventType=="remove") then
		self:AddEventToQueue(event) --If unhandled, add to que
		return
	end

	if(event.server_id) then
		return --Ignore this eventType, is ment for outdated meteor clients
	end

	print("Unhandled DDP message "..(eventType or "NONE"))
	PrintTable(event)
end

function DDP:DataAdded(event)
	local collection = self.collections[event.collection]
	if(collection) then
		collection:Add(event.id,event.fields or nil)
	end
end

function DDP:DataChanged(event)
	local collection = self.collections[event.collection]
	if(collection) then
		collection:Change(event.id,event.fields or nil,event.cleared or nil)
	end
end

function DDP:DataRemoved(event)
	local collection = self.collections[event.collection]
	if(collection) then
		collection:remove(event.id)
	end
end

function DDP:OnWSClose()

end

function DDP:Close()
	self.socket:Close()
end

function DDP:Write(data)
	if (type(data) == "table") then
		data = util.TableToJSON(data)
	end

	print("Outdoing message"..data)
	self.socket:Send(data)
end

function DDP:PrintCollections()
	PrintTable(self.collections)
end

local function arrayToJSON(array)
	local rstring --aRray string

	if (array == nil) then
		rstring = "[]"
	else
		rstring= "["
		for k,v in ipairs(params) do
			rstring = rstring.."\""..v.."\""

			if(k!=#params) then
				rstring = rstring..","
			end
		end
		rstring = rstring.."]"
	end

	return rstring
end

function DDP:Call(name,params,callback) --todo implement callback
	local msg = "{\"msg\":\"method\",\"method\":\""..name.."\",\"id\":\""..self:getUid().."\", \"params\" :"..arrayToJSON(params).."}"
	self:Write(msg)
end

function DDP:Subscribe(collectionName,params)
	local subid = self:getUid()
	local msg = "{\"msg\":\"sub\",\"id\":\""..self:getUid().."\",\"name\":\""..collectionName.."\",\"params\":"..arrayToJSON(params).."}"
	self:Write(msg)
	return subid
end

function DDP:getUid()
	local id = DDP.uid
	DDP.uid = DDP.uid + 1
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
