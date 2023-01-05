local class = require('class')

local DockManager = class(function(self)
  self._dockers = {}
  self._nextSuffix = 0
end)

function DockManager:registerCargo(ship, point, cargo, cargoPoint)
  local name = ship.Name
  local dockers = self._dockers[name]
  if not dockers then
    dockers = {}
    self._dockers[name] = dockers
  end
  local record = {point, cargo, cargoPoint}
  table.insert(dockers, record)
end

function DockManager:visit(ship, callback)
  if ship:isValid() then
    callback(ship)
    local dockers = self._dockers[ship.Name]
    if dockers then
      local len = #dockers
      for i = 1, len, 1 do
        local record = dockers[i]
        local cargo = record[2]
        if self:_areDocked(ship, cargo) then
          self:visit(cargo, callback)
        end
      end
    end
  end
end

function DockManager:cloneWithCargo(ship)
  if ship:isValid() then
    local pos = ship.Position
    local ori = ship.Orientation
    local class = ship.Class
    local team = ship.Team
    local suffix = self._nextSuffix
    local name = ship.Name .. "#Jump" .. suffix
    self._nextSuffix = suffix + 1
    local clone = mn.createShip(name, class, ori, pos, team)
    mn.runSEXP("( ship-copy-damage !" .. ship.Name .. "! !" .. name .. "! )")
    self:_cloneDockers(ship, clone)
    return clone
  end
end

function DockManager:_cloneDockers(ship, clone)
  local dockers = self._dockers[ship.Name]
  if dockers then
    local len = #dockers
    for i = 1, len, 1 do
      local record = dockers[i]
      local cargo = record[2]
      if self:_areDocked(ship, cargo) then
        local point = record[1]
        local cargoClone = self:cloneWithCargo(cargo)
        local cargoPoint = record[3]
        mn.runSEXP("( set-docked !" .. clone.Name .. "! !" .. point .. "! !" .. cargoClone.Name .. "! !" .. cargoPoint .. "!)")
      end
    end
  end
end

function DockManager:_areDocked(ship, cargo)
  return ship:isValid() and
         cargo:isValid() and
         mn.evaluateSEXP("( is-docked !" .. ship.Name .. "! !" .. cargo.Name .. "! )")
end

return DockManager
