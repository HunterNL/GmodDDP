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

	self.ddp:LinkCollection(self)

	return self
end

function DDPCollection:Add(id,fields)
	self.data[id]=fields
end

function DDPCollection:Change(id,fields,cleared)
	self.data[id]=fields
end

function DDPCollection:Remove(id)
	self.data[id]=nil
end

function DDPCollection:OnPopulated()
	print("DB POPULATED")
end
