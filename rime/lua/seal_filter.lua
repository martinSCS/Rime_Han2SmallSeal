local M = {}

local function join_path(base, leaf)
  if not base or base == "" then
    return leaf
  end
  if base:sub(-1) == "/" then
    return base .. leaf
  end
  return base .. "/" .. leaf
end

local function data_dir()
  if rime_api and rime_api.get_user_data_dir then
    return rime_api.get_user_data_dir()
  end
  return "."
end

local function read_map(path)
  local map = {}
  local file = io.open(path, "r")
  if not file then
    return map
  end

  for line in file:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local source, rest = line:match("^([^\t]+)\t(.+)$")
      if source and rest then
        local variants = {}
        for target in rest:gmatch("[^\t]+") do
          variants[#variants + 1] = target
        end
        if #variants > 0 then
          map[source] = variants
        end
      end
    end
  end

  file:close()
  return map
end

local function utf8_chars(text)
  return text:gmatch("[%z\1-\127\194-\244][\128-\191]*")
end

local function collect_chars(text)
  local chars = {}
  for char in utf8_chars(text) do
    chars[#chars + 1] = char
  end
  return chars
end

local function convert_default(chars, map)
  local changed = false
  local out = {}

  for _, char in ipairs(chars) do
    local variants = map[char]
    if variants then
      out[#out + 1] = variants[1]
      changed = true
    else
      out[#out + 1] = char
    end
  end

  return table.concat(out), changed
end

local function config_bool(config, key, default)
  if not config or not config.get_bool then
    return default
  end
  local ok, value = pcall(function()
    return config:get_bool(key)
  end)
  if not ok or value == nil then
    return default
  end
  return value
end

local function config_int(config, key, default)
  if not config or not config.get_int then
    return default
  end
  local ok, value = pcall(function()
    return config:get_int(key)
  end)
  if not ok or value == nil then
    return default
  end
  return value
end

function M.init(env)
  local config = env.engine.schema.config
  local map_file = config:get_string(env.name_space .. "/map_file") or "seal_map.tsv"
  env.seal_map = read_map(join_path(data_dir(), map_file))
  env.option_name = config:get_string(env.name_space .. "/option_name")
  env.single_char_variants = config_bool(config, env.name_space .. "/single_char_variants", true)
  env.max_variants = config_int(config, env.name_space .. "/max_variants", 9)
end

function M.func(input, env)
  if env.option_name and not env.engine.context:get_option(env.option_name) then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  local map = env.seal_map or {}

  for cand in input:iter() do
    local chars = collect_chars(cand.text)
    local text, changed = convert_default(chars, map)
    if changed then
      local comment = cand.comment or ""
      if comment == "" then
        comment = cand.text
      else
        comment = comment .. " " .. cand.text
      end
      local variants = nil
      if env.single_char_variants and #chars == 1 then
        variants = map[chars[1]]
      end

      if variants and #variants > 1 then
        local limit = math.min(#variants, env.max_variants)
        for index = 1, limit do
          yield(Candidate(cand.type, cand.start, cand._end, variants[index], comment .. " " .. index .. "/" .. #variants))
        end
      else
        yield(Candidate(cand.type, cand.start, cand._end, text, comment))
      end
    else
      yield(cand)
    end
  end
end

return M
