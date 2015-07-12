if CLIENT then return end
MeteorAccountHelper = MeteorAccountHelper or {}


print("Loaded MeteorAccountHelper")

if not MAH then
    MAH = {}
    MAH.__index = MAH
    setmetatable(MAH,{
        __call = function(self,...) --Set constructor
            return MAH.Create(...)
		end
    })
	MeteorAccountHelper = MAH
end

--Constructor
function MAH.Create(ddp,dontmakeusercollection)
	if(getmetatable(ddp)!=DDP) then
		error("MeteorAccountHelper needs a DPP client as constructor argument")
	end

	local self = setmetatable({},MAH)
	self.ddp = ddp

    self.users = self.ddp.collections.users
    print("MAH - self users",self.users)
    if(self.users==nil and dontmakeusercollection==nil and not dontmakeusercollection) then
        self.users = DDPCollection(self.ddp,"users")
    end

	self.userId = nil
	self.user = {}

	return self
end

--Calls the server, wich should reply with a dummy account if artwells:accounts-guest is installed
function MAH:LoginAsGuest()
	self.ddp:Call("createGuest",nil,function(...)
		self:CBGuestCreated(...)
	end)
end

--Takes username and unencrypted password, tries logging into Meteor
function MAH:LoginWithPassword(username,password)
	self.ddp:Call("login",{{ --Nested table is intentional, all of this is 1 argument to login method
		user = {username = username},
		password = {digest=hash256(password),algorithm="sha-256"}
	}},function(...)
		self:OnLogin(...)
	end)
end

function MAH:Logout()
	--TODO code me
end

--Callback for common login
function MAH:OnLogin(err,result)
	if(err) then
		PrintTable(err)
		error("Error loggin in")
	end

	self.userId = result.id
	self.token = result.token
	--Todo handle token expiration

    if(self.users!=nil) then
        print(self.users.data[self.userId],self.user)
        table.CopyFromTo(self.users.data[self.userId],self.user)
    end

    self.users:ObserveId(self.userId,{
        OnAdd = function(id,doc) self:OnCollectionChange(id,doc) end,
        OnChange = function(id,newdoc,olddoc) self:OnCollectionChange(id,newdoc,olddoc) end,
        OnRemove = function(id) self:OnCollectionChange(id,nil) end --empty user field
    })

	print("Logged in as user "..self.userId)--.." with following user data")
    --PrintTable(self.user)

	if(isfunction(self.onLoginCallback)) then
		self.onLoginCallback(self.user)
	end
end

function MAH:SetLoginCallback(func)
    self.onLoginCallback = func
end

function MAH:SetUserDataCallback(func)
    self.onUserDataChangeCallback = func
end

function MAH:OnCollectionChange(id,newdoc,olddoc)
    --[[print("MAH - ")
        PrintTable(newdoc)
        print("split")
        PrintTable(olddoc)
    print("end mah")
    table.CopyFromTo(newdoc,self.user)
    ]]

    table.CopyFromTo(newdoc,self.user)
    --PrintTable(self.user)

    if(isfunction(self.onUserDataChangeCallback)) then
        self.onUserDataChangeCallback(newdoc,olddoc)
    end
end

--Callback for guest account creation
function MAH:CBGuestCreated(error,result)
	if(error) then
		print("Error in connection call")
		PrintTable(error)
		return
	end

	self:LoginWithPassword(result.username,result.password)
end
