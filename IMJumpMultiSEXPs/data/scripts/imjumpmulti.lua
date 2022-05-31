-- COMMON CONFIGURATION CONSTANTS

-- The percentage of a ship's speed to use while it jumps.
local THROTTLE = 33

-- How long a ship warms up for before departing, in milliseconds.
local DRIVE_WARMUP_MS = 4000
-- The sound to play while the player's ship warms up.
local DRIVE_WARMUP_SOUND = 50

-- UNCOMMON CONFIGURATION CONSTANTS

-- Jump apertures this far from the player, in meters, won't be drawn.
local CULL_M = 40000
-- The minimum distance between ships in a wing, in meters. For small ships,
-- the normal separation calculation can generate dangerously close values.
local MINIMUM_SEPARATION_RADIUS_M = 40
-- Offset vectors for the various ships in a wing, as percentages of the
-- wing's separation, in local coordinates relative to the arrival position.
local WING_OFFSETS = {
  ba.createVector(0, 0, 0),
  ba.createVector(-math.sqrt(1), 0, -math.sqrt(1)),
  ba.createVector(math.sqrt(1), 0, -math.sqrt(1)),
  ba.createVector(0, 0, -1),
  ba.createVector(-1, 0, -1),
  ba.createVector(1, 0, -1)
}

-- INTERNAL CONSTANTS

-- The Y-coordinate of subspace, in meters.
local SUBSPACE_Y_M = -100000
local SUBSPACE_Y_M_FUDGE = -95000
-- The Y-coordinate of a temporary placeholder area, in meters.
local NOWHERE_Y_M = -120000

local FORWARD = ba.createOrientation(0, 0, 0)
local LEGAL_AREA_SIDE_M = 50000
local PLACEHOLDER_STEP_M = 5000

-- INCLUDES

local class = require('class')
local DockManager = require('dockmanager')

-- SCRIPT BEGINS HERE

local Place = class(function(self, position, orientation)
  self.position = position
  self.orientation = orientation
end)

function Place:move(ship)
  ship.Position = self.position
  ship.Orientation = self.orientation
  ship.Physics.RotationalVelocity = ba.createVector(0, 0, 0)
  ship.Physics.RotationalVelocityDesired = ba.createVector(0, 0, 0)
end

function Place:offset(vector, world)
  if not world then
    vector = self.orientation:unrotateVector(vector)
  end
  return Place(self.position + vector, self.orientation)
end

function Place.ofWaypointList(waypointList)
  if not waypointList:isValid() then
    ba.error('invalid waypoint list ' .. tostring(waypointList))
  end
  if #waypointList < 2 then
    ba.error('waypoint list ' .. waypointList.Name .. ' is too short')
  end
  local position = waypointList[1].Position
  local target = waypointList[2].Position
  local delta = target - position
  local orientation = delta:getOrientation()
  return Place(position, orientation)
end

function Place:toFactory(separationMeters)
  local i = 0
  return {
    next = function()
      i = i + 1
      return self:offset(WING_OFFSETS[i] * separationMeters, true)
    end
  }
end

local Placeholder = class(function(self, y)
  self._x = -LEGAL_AREA_SIDE_M
  self._y = y
  self._z = -LEGAL_AREA_SIDE_M
end)

function Placeholder:next()
  local result = Place(ba.createVector(self._x, self._y, self._z), FORWARD)
  -- Advance to the next position
  self._x = self._x + PLACEHOLDER_STEP_M
  -- Wrap around if needed
  if (self._x > LEGAL_AREA_SIDE_M) then
    self._x = -LEGAL_AREA_SIDE_M
    self._z = self._z + PLACEHOLDER_STEP_M
    if (self._z > LEGAL_AREA_SIDE_M) then
      self._z = -LEGAL_AREA_SIDE_M
    end
  end
  return result
end

local JumpCuller = class(function(self)
  self._distance2 = CULL_M * CULL_M
  self._playerJumpingTo = nil
end)

function JumpCuller:playerJumpingTo(place)
  self._playerJumpingTo = place
end

function JumpCuller:shouldDraw(position)
  return self:_shouldDraw(position, hv.Player.Position) or self:_shouldDraw(position, self._playerJumpingTo)
end

function JumpCuller:_shouldDraw(position, origin)
  return origin and position:getDistanceSquared(origin) < self._distance2
end

local Jump = class(function(self, ship, destination, nowhere, culler, dockManager)
  self._ship = ship
  self._destination = destination
  self._nowhere = nowhere
  self._culler = culler
  self._dockManager = dockManager
  self._stealth = ship.Stealthed
  self._hidden = ship.HiddenFromSensors
  self._friendlyStealth = mn.evaluateSEXP('( is-friendly-stealth-visible !' .. ship.Name ..'! )')
end)

function Jump:toSubspace()
  self._toSubspace = true
  return self
end

function Jump:doWarmup(hideGauge)
  self._doWarmup = true
  self._hideGauge = hideGauge
  return self
end

function Jump:doCleanup()
  self._doCleanup = true
  return self
end

function Jump:after(after)
  self._after = after
  return self
end

function Jump:driftForMs(milliseconds)
  self._driftTime = milliseconds
  return self
end

function Jump:start()
  local ship = self._ship
  return async.run(function()
    ship.Target = nil
    ship.TargetSubsystem = nil
    async.await(self:_warmup())
    self:_beginMovement()
    async.await(mn.waitAsync(2))
    self:_finishMovement()
    if self._driftTime then
      async.await(self:_drift(self._driftTime))
    end
    self:_cleanup()
    if self._after then
      async.await(self:_after())
    end
  end)
end

function Jump:_warmup()
  if self._doWarmup then
    if not self._hideGauge and self._ship == hv.Player then
      mn.runSEXP('( hud-display-gauge ' .. DRIVE_WARMUP_MS .. ' !warpout! )')
      ad.playGameSound(DRIVE_WARMUP_SOUND)
    end
    return self:_drift(DRIVE_WARMUP_MS)
  else
    return async.run(function() end)
  end
end

function Jump:_drift(milliseconds)
  local ship = self._ship
  if ship:isValid() then
    self:_lockdown()
    local name = ship.Name
    mn.runSEXP('( ship-maneuver !' .. name .. '! ' .. milliseconds .. ' 0 0 0 ( true ) 0 0 ' .. THROTTLE .. ' ( true ) )')
  end
  return mn.waitAsync(milliseconds / 1000)
end

function Jump:_beginMovement()
  if self._ship == hv.Player then
    self._culler:playerJumpingTo(self._destination.position)
    self:_beginPlayerMovement()
  else
    self:_beginNPCMovement()
  end
end

function Jump:_beginNPCMovement()
  local ship = self._ship
  if self._culler:shouldDraw(ship.Position) then
    local copy = self._dockManager:cloneWithCargo(ship)
    if copy then
      self._dockManager:visit(copy, function(s)
        s.Stealthed = true
        mn.runSEXP('( friendly-stealth-invisible !' .. s.Name .. '! )')
        mn.runSEXP('( ship-invulnerable !' .. s.Name .. '! )')
      end)
      copy:warpOut()
    end
  end
  self._dockManager:visit(ship, function(s)
    s.Stealthed = true
    mn.runSEXP('( friendly-stealth-invisible !' .. s.Name .. '! )')
  end)
  self._nowhere:next():move(ship)
end

function Jump:_beginPlayerMovement()
  local ship = self._ship
  local name = ship.Name
  local speed = ship.Physics.VelocityMax.z * THROTTLE / 100
  local distance = speed * 2.05 -- Two seconds plus a fudge factor
  local offset = ship.Orientation:unrotateVector(ba.createVector(0, 0, distance))
  local here = ship.Position
  local there = here + offset
  local size = ship.Class.Model.Radius * 2
  mn.runSEXP('( ship-maneuver !' .. name .. '! ' .. 2000 .. ' 0 0 0 ( true ) 0 0 ' .. THROTTLE .. ' ( true ) )')
  mn.runSEXP('( warp-effect ' .. there.x .. ' ' .. there.y .. ' ' .. there.z .. ' ' .. here.x .. ' ' .. here.y .. ' ' .. here.z .. ' ' .. size .. ' 6 45 46 0 1 )')
  mn.waitAsync(1.2):continueWith(function()
    mn.runSEXP('( fade-out 500 255 255 255 )')
  end)
end

function Jump:_warpPlayerIn()
  local ship = hv.Player
  local name = ship.Name
  local offset = ship.Orientation:unrotateVector(ba.createVector(0, 0, 50))
  local here = ship.Position
  local there = here + offset
  local size = ship.Class.Model.Radius * 2
  mn.runSEXP('( warp-effect ' .. here.x .. ' ' .. here.y .. ' ' .. here.z .. ' ' .. there.x .. ' ' .. there.y .. ' ' .. there.z .. ' ' .. size .. ' 6 45 46 0 1 )')
end

function Jump:_finishMovement()
  local ship = self._ship
  if ship:isValid() then
    local name = ship.Name
    local isPlayer = (ship == hv.Player)
    local toSubspace = self._toSubspace
    self._dockManager:visit(ship, function(s)
      self._destination:move(s)
    end)
    if self._culler:shouldDraw(ship.Position) then
      if isPlayer then
        self:_warpPlayerIn()
      else
        ship:warpIn()
      end
    end
    if toSubspace then
      mn.runSEXP('( shields-off !' .. name .. '!)' )
    else
      mn.runSEXP('( shields-on !' .. name .. '!)' )
    end
    if isPlayer then
      mn.waitAsync(0.2):continueWith(function()
        mn.runSEXP('( fade-in 500 255 255 255 )')
      end)
      self._culler:playerJumpingTo(nil)
      if toSubspace then
        mn.runSEXP('( mission-set-subspace 1 )')
        mn.runSEXP('( hud-set-max-targeting-range 1 )')
      else
        mn.runSEXP('( mission-set-subspace 0 )')
        mn.runSEXP('( hud-set-max-targeting-range 0 )')
      end
    end
  end
end

function Jump:_cleanup()
  local ship = self._ship
  if self._doCleanup and ship:isValid() then
    self:_releaseLockdown()
    self._dockManager:visit(ship, function(s)
      local name = s.Name
      s.Stealthed = self._stealth
      s.HiddenFromSensors = self._hidden
      if self._friendlyStealth then
        mn.runSEXP('( friendly-stealth-visible !' .. name .. '! )')
      else
        mn.runSEXP('( friendly-stealth-invisible !' .. name .. '! )')
      end
    end)
    if ship == hv.Player then
      mn.runSEXP('( hud-set-max-targeting-range 0 )')
      mn.runSEXP('( set-player-throttle-speed !' .. hv.Player.Name .. '! ' .. THROTTLE .. ' )')
    end
  end
end

function Jump:_lockdown()
  local ship = self._ship
  if ship:isValid() then
    local name = ship.Name
    mn.runSEXP('( lock-primary-weapon !' .. name .. '! )')
    mn.runSEXP('( lock-secondary-weapon !' .. name .. '! )')
    mn.runSEXP('( lock-afterburner !' .. name .. '! )')
    mn.runSEXP('( disable-ets !' .. name .. '! )')
    ship:clearOrders()
    ship:giveOrder(ORDER_PLAY_DEAD_PERSISTENT, nil, nil, 200)
    if ship == hv.Player then
      mn.runSEXP('( player-use-ai )')
      mn.runSEXP('( ignore-key -1 !C! !Backspace! !\\! )')
    end
  end
end

function Jump:_releaseLockdown()
  local ship = self._ship
  if ship:isValid() then
    local name = ship.Name
    mn.runSEXP('( unlock-primary-weapon !' .. name .. '! )')
    mn.runSEXP('( unlock-secondary-weapon !' .. name .. '! )')
    mn.runSEXP('( unlock-afterburner !' .. name .. '! )' )
    mn.runSEXP('( enable-ets !' .. name .. '! )')
    ship:clearOrders()
    if ship == hv.Player then
      mn.runSEXP('( player-not-use-ai )')
      mn.runSEXP('( ignore-key 0 !C! !Backspace! !\\! )')
    end
  end
end

local JumpManager = class()

function JumpManager:reset()
  self._subspace = Placeholder(SUBSPACE_Y_M)
  self._nowhere = Placeholder(NOWHERE_Y_M)
  self._culler = JumpCuller()
  self._dockManager = DockManager()
end

function JumpManager:registerCargo(ship, point, cargo, cargoPoint)
  self._dockManager:registerCargo(ship, point, cargo, cargoPoint)
end

function JumpManager:destinationFactory(separation, waypointList, dx, dy, dz, ships)
  separation = self:_separation(separation, ships)
  return Place.ofWaypointList(waypointList)
              :offset(ba.createVector(dx, dy, dz), false)
              :toFactory(separation)
end

function JumpManager:jump(ship, destination)
  destination = destination or self._subspace:next()
  return Jump(ship, destination, self._nowhere, self._culler, self._dockManager)
end

function JumpManager:inSubspace()
  return hv.Player.Position.y < SUBSPACE_Y_M_FUDGE
end

function JumpManager:_separation(separation, ships)
  if separation > 0 then
    -- We have an explicit radius. Assume the caller knows what they're doing.
    return separation
  else
    local radius = MINIMUM_SEPARATION_RADIUS_M
    -- Find the largest radius. To avoid collisions, we separate the ships by
    -- three times this radius - twice would give the diameter, but that's too
    -- tight a tolerance.
    for _, ship in ipairs(ships) do
      if ship:isValid() then
        radius = math.max(radius, 3 * ship.Class.Model.Radius)
      end
    end
    return radius
  end
end

return JumpManager()
