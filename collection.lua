if CLIENT then return end

print("Collections loaded")

if not DDPCollection then
	DDPCollection = {}
	DDPCollection.__index = DDPCollection
	setmetatable(DDPCollection,{__call = function(self,...)
		return DDPCollection.Create(...)
	end})
end

function DDPCollection.Create(ddp,name)
	local self = setmetatable({},DDPCollection)
	self.ddp = ddp
	self.name = name
	self.populated = false
	self.data = {}
	self.listeners = {}

	self.ddp:LinkCollection(self)

	return self
end

function DDPCollection:Observe(callbacks)
	table.insert(self.listeners,callbacks)
end
function DDPCollection:Add(id,fields)
	self.data[id]=fields

	for k,v in pairs(self.listeners) do
		if(isfunction(v.OnAdd)) then
			v.OnAdd(id,fields)
		end
	end
end

function DDPCollection:Change(id,fields,cleared)
	print("data changed",id,fields)
	local oldDoc = self.data[id]

	self.data[id]=fields

	for k,v in pairs(self.listeners) do
		if(isfunction(v.OnChange)) then
			v.OnChange(id,fields,olddoc)
		end
	end
end

function DDPCollection:Remove(id)
	local oldDoc = self.data[id]
	self.data[id]=nil

	for k,v in pairs(self.listeners) do
		if (isfunction(v.OnRemove)) then
			v.OnRemove(id,oldDoc)
		end
	end
end

function DDPCollection:OnPopulated()
	print("DB POPULATED")
end
