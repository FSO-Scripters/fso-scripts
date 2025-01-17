local class = require('class')

local AltMessageFactory = {}


local AltMessage = class(function(self, source, message, duration)
  self._source = source
  self._message = message
  self._duration = duration
end)

function AltMessage:send()
  local source = self._source
  local special = (source:sub(1, 1) == '#')
  local canSend = special or mn.Ships[source]:isValid()
  if canSend then
    local message = self._message
    mn.runSEXP('( send-message !' .. source .. '! !Normal! !' .. message .. '! )')
    AltMessageFactory.latest = self
    return mn.waitAsync(self._duration / 1000)
  else
    return nil
  end
end


function AltMessageFactory.reset()
  AltMessageFactory._aliases = {}
  AltMessageFactory.latest = nil
end

function AltMessageFactory.setAlias(alias, sender)
  AltMessageFactory._aliases[alias] = tostring(sender)
end

function AltMessageFactory.create(message, duration)
  local source = AltMessageFactory._getSource(message)
  return AltMessage(source, message.Name, duration)
end

function AltMessageFactory._getSource(message)
  local prefix = AltMessageFactory._extractPrefix(message)
  return AltMessageFactory._aliases[prefix] or prefix
end

function AltMessageFactory._extractPrefix(message)
  local name = message.Name
  local where = name:find(':')
  if where then
    return name:sub(1, where - 1)
  else
    ba.error('"' .. name .. '" is not in the correct format for an alt message - it should look like "Source: Title"')
  end
end


local AltMessageGroup = class(function(self)
  self._candidates = {}
end)

function AltMessageGroup:add(altMessage)
  local list = self._candidates
  list[#list + 1] = altMessage
end

function AltMessageGroup:shuffle()
  local candidates = self._candidates
  for i = #candidates, 2, -1 do
    local j = math.random(i)
    candidates[i], candidates[j] = candidates[j], candidates[i]
  end
end

function AltMessageGroup:send()
  for _, candidate in ipairs(self._candidates) do
    local promise = candidate:send()
    if promise then return promise end
  end
  return mn.waitAsync(.001)
end


local Conversation = class(function(self, stop)
  self._steps = {}
  self._index = 0
  self._stop = stop
end)

function Conversation:add(altMessage)
  local step = AltMessageGroup()
  step:add(altMessage)
  local steps = self._steps
  steps[#steps + 1] = step
end

function Conversation:addAlternative(altMessage)
  local steps = self._steps
  local step = steps[#steps]
  step:add(altMessage)
end

function Conversation:send()
  if not self:cancelled() then
    local index = self._index + 1
    self._index = index
    local step = self._steps[index]
    if step then
      step:shuffle()
      step:send():continueWith(function() self:send() end)
    end
  end
end

function Conversation:cancelled()
  local stop = self._stop
  return stop and mn.evaluateSEXP('( is-event-true-delay !' .. stop .. '! 0 )')
end


InitAltMessaging = AltMessageFactory.reset

mn.LuaSEXPs['set-message-alias'].Action = AltMessageFactory.setAlias
mn.LuaSEXPs['set-freetext-message-alias'].Action = AltMessageFactory.setAlias

mn.LuaSEXPs['send-message-alt'].Action = function(shuffle, ...)
  local group = AltMessageGroup()
  for _, entry in ipairs({...}) do
    if entry[2] then
      local altMessage = AltMessageFactory.create(entry[1], 1)
      group:add(altMessage)
    end
  end
  if shuffle then group:shuffle() end
  group:send()
end

function sendConversation(stop, entries)
  local conversation = Conversation(stop)
  for _, entry in ipairs(entries) do
    local message = entry[1]
    local duration = entry[2]
    -- We use a negative duration to indicate an alternative.
    -- It's kind of kludgy, but it's convenient in FRED.
    local alternative = duration < 0
    duration = (duration == nil or duration == 0) and 1 or math.abs(duration)
    local altMessage = AltMessageFactory.create(message, duration)
    if alternative then
      conversation:addAlternative(altMessage)
    else
      conversation:add(altMessage)
    end
  end
  conversation:send()
end

mn.LuaSEXPs['send-message-list-alt'].Action = function(...)
  sendConversation(nil, {...})
end

mn.LuaSEXPs['send-message-chain-alt'].Action = function(stop, ...)
  sendConversation(stop, {...})
end

mn.LuaSEXPs['get-last-alt-message-source'].Action = function(variable)
  local latest = AltMessageFactory.latest
  if latest then
    variable.Value = latest._source
  else
    variable.Value = ''
  end
end
