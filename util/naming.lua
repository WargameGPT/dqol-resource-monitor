local Naming = {}

---@param pos IntPosition?
---@param type string
---@return string
function Naming.getSiteName(pos, type)
    if settings.global['dqol-resource-monitor-site-name-generator'].value == 'Numeric' then
        return Naming.getNumericName(pos,type)
    else
        return Naming.getRandomName(pos)
    end
end

-- 
function get_octant_name(vector)
    
    local octant_names = {
        [0] = "E",
        [1] = "SE",
        [2] = "S",
        [3] = "SW",
        [4] = "W",
        [5] = "NW",
        [6] = "N",
        [7] = "NE",
    }
    local radians = math.atan2(vector.y, vector.x)
    local octant = math.floor(8 * radians / (2 * math.pi) + 8.5) % 8

    return octant_names[octant]
end

---@param pos IntPosition?
---@return string
function Naming.getRandomName(pos)
    local name = Naming.names[math.random(1, #Naming.names)]

    -- 2/3 chance to have an adjective in front
    if math.random(1, 3) ~= 3 then
        name = Naming.adjectives[math.random(1, #Naming.adjectives)] .. ' ' .. name
    end

    -- 1/4 cache to have a double name
    if math.random(1, 4) == 1 then
        name = name .. ' ' .. Naming.names[math.random(1, #Naming.names)]
    end

    if pos ~= nil then
       name = Naming.posToCompassDirection(pos) .. ' ' .. name 
    end
    return name
end

---@param type string
---@return string
function Naming.getNumericName(pos, type)
    local count = 1
    for _, surface in pairs(Sites.storage.getSurfaceList()) do
        count = count + #(surface[type] or {})
    end

    return Resources.types[type].translated_name .. ' ' .. string.format("%s-%d", get_octant_name(pos), math.floor(math.sqrt(pos.x * pos.x + pos.y * pos.y)))
end

---@param pos IntPosition
---@return string
function Naming.posToCompassDirection(pos)
    local direction
    if pos.y < 0 then direction = 'N' else direction = 'S' end
    if pos.x > 0 then direction = direction .. 'E' else direction = direction .. 'W' end
    return direction
end

Naming.names = {
    'Julia',
    'Mandeep',
    'Enni',
    'Nastya',
    'Judith',
    'Yenny',
    'Chiyembekezo',
    'Yuuri',
    'Cornelia',
    'Tionge',
    'Kanda',
    'Rosa',
    'Gisila',
    'Peppi ',
    'Amara',
    'Kaleigh',
    'Zoe',
    'Josephine',
    'Tiara',
    'Gia',
    'Julianne',
    'Leila',
    'Amari',
    'Daisy',
    'Daniella',
    'Raquel',
    'Westray',
    'Carningsby',
    'Doveport',
    'Sanlow',
    'Hillford',
    'Aberystwyth',
    'Thorpeness',
    'Malrton',
    'Ely',
    'Cirencester',
    'Astrakhan',
    'Balerno',
    'Willowdale',
    'Fallkirk',
    'Bournemouth',
    'Taernsby',
    'Willsden',
    'Axminster',
    'Cardended',
    'Onryx',
    'Lerwick',
    'Eastborne',
    'Gramsby',
    'Laenteglos',
    'Alnerwick',
    'Stanmore',
    'Inverness',
    'Beachmarsh',
    'Murrayfield',
}

Naming.adjectives = {
    'Little',
    'New',
    'Old',
    'Red',
    'Dark',
    'Ancient',
    'Boring',
    'Bustling',
    'Charming',
    'Compact',
    'Crowded',
    'Famous',
    'Fantastic',
    'Historic',
    'Huge',
    'Polluted',
    'Quiet',
    'Rich',
    'Stupid',
    'Tiny',
    'Victorious',
}

return Naming
