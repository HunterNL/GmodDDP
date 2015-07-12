-- see bottom of file for useage
if CLIENT then return end

print("DDP loaded")



if not
 DDP then
	DDP = {}
	DDP.__index = DDP
	setmetatable(DDP,{
		__call = function(self,...)
			return DDP.Create(...)
		end
	})

end

DDP.uid = 1
DDP.verbose = false

function DDP.Create(url,port)
	local self = setmetatable({},DDP)

	self.messageHandlers = {}

	self.socket = WS.Client(url.."/websocket",port)

	self.state="CONNECTING"

	self.collections = {}
	self.collectionEventQueue = {}
	self.messageQueue = {}

    self.callbacksQuick = {}
    self.callbacksSlow = {}
    self.callbacksReady = {}

	self.session = ""

	self.socket:on("message",function(data)
        print("ddp message")
		self:OnMessage(data)
	end)

	self.socket:on("open",function()
        print("ddp open")
		self:OnWSOpen()
	end)

	self.socket:on("close",function()
        print("ddp close")
		self:OnWSClose()
	end)

    self.socket:Connect()

	return self
end

function DDP:OnWSOpen() --fires when websocket is connected
	self:Connect()
end

function DDP:OnConnected() --fires when ddp is connected
	local queue = self.messageQueue
	if(#queue>0) then
		for k,v in ipairs(queue) do
			self.socket:Send(v)
		end
	end
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
	if(DDP.verbose) then print("Incoming message "..message) end
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

    if(eventType =="result") then
        self:OnResult(event.id,event)
        return
    end

    if(eventType=="updated") then
        self:OnUpdated(event.methods)
        return
    end

    if(eventType=="ready") then
        self:OnSubReady(event.subs)
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
		collection:Remove(event.id)
	end
end

function DDP:OnWSClose()

end

function DDP:Close()
	self.socket:Close()
end

function DDP:QueueMessage(data)
	table.insert(self.messageQueue,data)
end

function DDP:Write(data,dontqueue)
	if (type(data) == "table") then
		data = util.TableToJSON(data)
	end

	if(DDP.verbose) then print("Outgoing message"..data) end
	if(self.state=="OPEN" or dontqueue) then
		self.socket:Send(data)
	elseif(self.state=="CONNECTING") then
		self:QueueMessage(data)
	end
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
		for k,v in ipairs(array) do
            if(type(v)=="table") then
                if (table.IsSequential(v)) then
                    v = arrayToJSON(v)
                else
                    v = util.TableToJSON(v)
                end
                rstring = rstring..v
            else
                rstring = rstring.."\""..v.."\""
			end

			if(k!=#array) then
				rstring = rstring..","
			end
		end
		rstring = rstring.."]"
	end

	return rstring
end

function DDP:Call(name,params,callbackquick,callbackslow)
    local id = tostring(self:getUid())
	local msg = "{\"msg\":\"method\",\"method\":\""..name.."\",\"id\":\""..id.."\", \"params\" :"..arrayToJSON(params).."}"

    if(isfunction(callbackquick)) then
        self.callbacksQuick[id] = callbackquick
    end

    if(isfunction(callbackslow)) then
        self.callbacksSlow[id] = callbackslow
    end


	self:Write(msg)
end

function DDP:OnResult(id,data)
    local func = self.callbacksQuick[id]
    if(isfunction(func)) then
        func(data.error,data.result)
    end
    self.callbacksQuick[id]=nil
end

function DDP:OnUpdated(idArray)
    for k,v in pairs(idArray) do
        local cb = self.callbacksSlow[v]
        if(isfunction(cb)) then
            cb()
            self.callbacksSlow[v]=nil
        end
    end
end

function DDP:OnSubReady(subs)
    for k,v in pairs(subs) do
        local cb = self.callbacksReady[v]
        if(isfunction(cb)) then
            cb()
            self.callbacksReady[v]=nil
        end
    end
end

function DDP:Subscribe(collectionName,params,callback)
	local subid = tostring(self:getUid())
	local msg = "{\"msg\":\"sub\",\"id\":\""..subid.."\",\"name\":\""..collectionName.."\",\"params\":"..arrayToJSON(params).."}"
    self.callbacksReady[subid]=callback

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
	self:Write(msg,true)
end
