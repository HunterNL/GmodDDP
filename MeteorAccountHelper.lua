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
function MAH.Create(ddp)
	if(getmetatable(ddp)!=DDP) then
		error("MeteorAccountHelper needs a DPP client as constructor argument")
	end

	local self = setmetatable({},MAH)
	self.ddp = ddp
	self.userId = nil
	self.user = nil

	return self
end

--Calls the server, wich should reply with a dummy account if artwells:accounts-guest is installed
function MAH:LoginAsGuest()
	self.ddp:Call("createGuest",nil,function(...)
		self:CBGuestCreated(...)
	end)
end

--Takes username and unencrypted password, tried logging into Meteor
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

	print("Logged in as user "..self.userId)

	if(isfunction(self.onLoginCallback)) then
		self.onLoginCallback(self.user)
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
