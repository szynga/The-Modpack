dofile "../Libs/Debugger.lua"

-- the following code prevents re-load of this file, except if in '-dev' mode.  -- fixes broken sh*t by devs.
if WASDThruster and not sm.isDev then -- increases performance for non '-dev' users.
	return
end 

mpPrint("loading WASDThruster.lua")

WASDThruster = class( nil )
WASDThruster.maxParentCount = -1
WASDThruster.maxChildCount = 0
WASDThruster.connectionInput = sm.interactable.connectionType.power + sm.interactable.connectionType.logic
WASDThruster.connectionOutput = sm.interactable.connectionType.none
WASDThruster.colorNormal = sm.color.new( 0x009999ff  )
WASDThruster.colorHighlight = sm.color.new( 0x11B2B2ff  )
WASDThruster.poseWeightCount = 2

WASDThruster.stepSize = 0.05


function WASDThruster.server_onCreate( self ) 
	self:server_init()
end

function WASDThruster.server_init( self ) 
	self.power = 0
	self.direction = sm.vec3.new(0,0,1)
	self.smode = 0
	
	local stored = self.storage:load()
	if stored and type(stored)=="number" then
		self.smode = stored - 1
	end
end

function WASDThruster.server_onRefresh( self )
	self:server_init()
end

function WASDThruster.server_onFixedUpdate( self, dt )
	if self.interactable.power ~= self.power then 
		self.interactable:setPower(self.power)
	end
	if self.power > 0 and math.abs(self.power) ~= math.huge then
		sm.physics.applyImpulse(self.shape, self.direction*self.power*-1)
		--print(self.direction)
	end
end


function WASDThruster.client_onCreate(self)
	self.shootEffect = sm.effect.createEffect( "Thruster", self.interactable )
	self.parentHPose = 0.5
	self.prevparentHPose = 0.5
	self.parentVPose = 0.5
	
	self.currentHPose = 0.5
	self.currentVPose = 0.5
	self.mode = 0
	self.network:sendToServer("server_requestmode")
	self.modes = {"wasd", "ws reversed", "only WS", "only AD"}
	
	self.interactable:setAnimEnabled( "animY", true )
	self.interactable:setAnimEnabled( "animX", true )
end


function WASDThruster.client_onDestroy(self)
	self.shootEffect:stop()
end

function WASDThruster.client_onInteract(self)
	local crouching = sm.localPlayer.getPlayer().character:isCrouching()
	self.network:sendToServer("server_changemode", crouching)
end
function WASDThruster.server_changemode(self, crouch)
	self.smode = (self.smode + (crouch and -1 or 1))%4
	self.storage:save(self.smode+1)
	self.network:sendToClients("client_mode", self.smode)
end
function WASDThruster.server_requestmode(self)
	self.network:sendToClients("client_mode", self.smode)
end
function WASDThruster.client_mode(self, mode)
	sm.audio.play("ConnectTool - Rotate", self.shape:getWorldPosition())
	if mode ~= self.mode then print("mode: ", self.modes[mode+1]) end
	self.mode = mode
end

function WASDThruster.client_onFixedUpdate(self, dt)
	local parents = self.interactable:getParents()
	local power = #parents>0 and 100 or 0
	local hasnumber = false
	local logicinput = 1
	local canfire = 0
	
	local ad = nil
	local ws = nil
	for k,v in pairs(parents) do
		local typeparent = v:getType()
		if tostring(v:getShape():getShapeUuid()) == "289e08ef-e3d8-4f1b-bc10-a0bcf36fa0ce" and v:getUvFrameIndex()%128 == 30 then
			ad = v.power
		elseif tostring(v:getShape():getShapeUuid()) == "289e08ef-e3d8-4f1b-bc10-a0bcf36fa0ce" and v:getUvFrameIndex()%128 == 31 then
			ws = v.power
		elseif  v:getType() == "scripted" and tostring(v:getShape():getShapeUuid()) ~= "6f2dd83e-bc0d-43f3-8ba5-d5209eb03d07" --[[tickbutton]] 
			and tostring(v:getShape():getShapeUuid()) ~= "ccaa33b6-e5bb-4edc-9329-b40f6efe2c9e" --[[orient block]] then
			-- number
			if v.power ~= math.huge and v.power ~= 0-math.huge and math.abs(v.power) >= 0 then
				if not hasnumber then power = 1 end
				power = power * v.power
				hasnumber = true
			end
			canfire = 1
		elseif v:getType() == "steering" then
			if self.mode == 0 then
				self.parentVPose = (v.power * -1/2)+0.5
				self.parentHPose = v:getPoseWeight(0)
			elseif self.mode == 1 then
				self.parentVPose = (v.power * 1/2)+0.5
				self.parentHPose = v:getPoseWeight(0)
			elseif self.mode == 2 then
				self.parentVPose = (v.power * 1/2)+0.5
				self.parentHPose = 0.5
			elseif self.mode == 3 then
				self.parentVPose = 0.5
				self.parentHPose = v:getPoseWeight(0)
			end
			
			if self.parentHPose > 0.5 and not (self.parentHPose < self.prevparentHPose) and self.currentHPose < 1 then -- D
				self.currentHPose = self.currentHPose + self.stepSize
			elseif self.parentHPose < 0.5 and not (self.parentHPose > self.prevparentHPose) and self.currentHPose > 0 then -- A
				self.currentHPose = self.currentHPose - self.stepSize
			elseif self.parentHPose > 0 and self.parentHPose < 1 then 
				if self.currentHPose < 0.4999 then self.currentHPose = self.currentHPose + self.stepSize end
				if self.currentHPose > 0.5001 then self.currentHPose = self.currentHPose - self.stepSize end
			end
			
			if self.parentVPose > 0.5 and self.currentVPose < 1 then -- W
				self.currentVPose = self.currentVPose + self.stepSize
			elseif self.parentVPose < 0.5 and self.currentVPose > 0 then -- S
				self.currentVPose = self.currentVPose - self.stepSize
			elseif self.parentVPose > 0 and self.parentVPose < 1 then
				if self.currentVPose < 0.4999 then self.currentVPose = self.currentVPose + self.stepSize end
				if self.currentVPose > 0.5001 then self.currentVPose = self.currentVPose - self.stepSize end
			end
	
		elseif tostring(v:getShape():getShapeUuid()) == "ccaa33b6-e5bb-4edc-9329-b40f6efe2c9e" then
			if self.mode == 0 then
				self.parentVPose = (v.power *6 * -1/2)+0.5
				self.parentHPose = (v:getPoseWeight(0)-0.5)*6+0.5
			elseif self.mode == 1 then
				self.parentVPose = (v.power *6 * 1/2)+0.5
				self.parentHPose = (v:getPoseWeight(0)-0.5)*6+0.5
			elseif self.mode == 2 then
				self.parentVPose = (v.power *6 * 1/2)+0.5
				self.parentHPose = 0.5
			elseif self.mode == 3 then
				self.parentVPose = 0.5
				self.parentHPose = (v:getPoseWeight(0)-0.5)*6+0.5
			end
			
			self.currentHPose = math.min(1,math.max(0,self.parentHPose))
			self.currentVPose = math.min(1,math.max(0,self.parentVPose))
			--print(self.currentHPose, self.currentVPose)
		else
			-- logic
			logicinput = logicinput * v.power
			canfire = 1
		end
	end
	
	if self.mode == 0 then
		if ws then self.currentVPose = (ws+1)/2 end -- -1 to 1 => 0 to 1
		if ad then self.currentHPose = (ad+1)/2 end -- -1 to 1 => 0 to 1
	elseif self.mode == 1 then
		if ws then self.currentVPose = (ws+1)/2 end -- -1 to 1 => 0 to 1
		if ad then self.currentHPose = (ad+1)/2 end -- -1 to 1 => 0 to 1
	elseif self.mode == 2 then
		if ws then self.currentVPose = (ws+1)/2 end -- -1 to 1 => 0 to 1
		if ad or ws then self.currentHPose = 0.5 end
	elseif self.mode == 3 then
		if ws or ad then self.currentVPose = 0.5 end -- -1 to 1 => 0 to 1
		if ad then self.currentHPose = (ad+1)/2 end -- -1 to 1 => 0 to 1
	end
	self.power = power * logicinput * canfire
	if math.abs(self.power) == math.huge or self.power ~= self.power then self.power = 0 end
	
	
	self.interactable:setUvFrameIndex(self.mode)
    self.interactable:setAnimProgress( "animY", self.currentVPose )
    self.interactable:setAnimProgress( "animX", self.currentHPose )
	local localX = sm.vec3.new(1,0,0)
	local localY = sm.vec3.new(0,-1,0)
	local localZ = sm.vec3.new(0,0,1)
	self.direction = localZ + (localY * ((self.currentVPose - 0.5)))
	self.direction = self.direction + (localX * ((self.currentHPose - 0.5)))
	self.direction = self.direction:normalize()
	--print(self.direction)
	
	--rotation particle(next patch):
	local worldRot = sm.vec3.getRotation( getLocal(self.shape,sm.shape.getUp(self.shape)),self.direction)
	self.shootEffect:setOffsetRotation(worldRot)
	self.shootEffect:setOffsetPosition((-sm.vec3.new(0,0,1.25)+self.direction)*0.36)
	if self.power > 0 then
		if not self.shootEffect:isPlaying() then
		self.shootEffect:start() end
	else
		if self.shootEffect:isPlaying() then
		self.shootEffect:stop() end
	end
	
	
	self.prevparentHPose = self.parentHPose
	self.prevparentVPose = self.parentVPose
end
function getLocal(shape, vec)
    return sm.vec3.new(sm.shape.getRight(shape):dot(vec), sm.shape.getAt(shape):dot(vec), sm.shape.getUp(shape):dot(vec))
end