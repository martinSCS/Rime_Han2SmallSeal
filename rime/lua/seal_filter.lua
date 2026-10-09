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

local function read_liding_map(path)
  local map = {}
  local max_key_len = 0
  local file = io.open(path, "r")
  if not file then
    return map, max_key_len
  end

  for line in file:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local source, target = line:match("^([^\t]+)\t([^\t]+)")
      if source and target then
        map[source] = target
        local len = 0
        for _ in source:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
          len = len + 1
        end
        if len > max_key_len then
          max_key_len = len
        end
      end
    end
  end

  file:close()
  return map, max_key_len
end

local function merge_liding_map(map, max_key_len, path)
  local extra_map, extra_max_key_len = read_liding_map(path)
  for source, target in pairs(extra_map) do
    local existing = map[source]
    if existing and existing ~= target then
      map[source] = existing .. "\t" .. target
    else
      map[source] = target
    end
  end
  return map, math.max(max_key_len or 0, extra_max_key_len or 0)
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

local function concat_chars(chars, start_index, end_index)
  local out = {}
  for index = start_index, end_index do
    out[#out + 1] = chars[index]
  end
  return table.concat(out)
end

local function split_targets(value)
  local targets = {}
  if not value then
    return targets
  end
  for target in value:gmatch("[^\t]+") do
    targets[#targets + 1] = target
  end
  return targets
end

local function apply_liding(chars, map, max_key_len)
  if not map or max_key_len < 1 then
    return chars, false
  end

  local out = {}
  local changed = false
  local index = 1
  while index <= #chars do
    local matched = nil
    local matched_len = 0
    local limit = math.min(max_key_len, #chars - index + 1)

    for len = limit, 1, -1 do
      local key = concat_chars(chars, index, index + len - 1)
      local replacement = map[key]
      if replacement then
        matched = replacement
        matched_len = len
        break
      end
    end

    if matched then
      local target = split_targets(matched)[1]
      for char in utf8_chars(target) do
        out[#out + 1] = char
      end
      changed = true
      index = index + matched_len
    else
      out[#out + 1] = chars[index]
      index = index + 1
    end
  end

  return out, changed
end

local function liding_targets_for_text(text, map)
  local targets = {}
  local seen = {}
  local value = map and map[text]
  for _, target in ipairs(split_targets(value)) do
    if target ~= text and not seen[target] then
      targets[#targets + 1] = target
      seen[target] = true
    end
  end
  return targets
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

local function build_comment(base_comment, original_text, liding_text)
  local parts = {}
  if base_comment and base_comment ~= "" then
    parts[#parts + 1] = base_comment
  end

  if liding_text and liding_text ~= original_text then
    parts[#parts + 1] = original_text .. "（" .. liding_text .. "）"
  else
    parts[#parts + 1] = original_text
  end

  return table.concat(parts, " ")
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
  local liding_map_file = config:get_string(env.name_space .. "/liding_map_file") or "opencc/SealVariants.txt"
  local extra_liding_map_file = config:get_string(env.name_space .. "/extra_liding_map_file")
  env.seal_map = read_map(join_path(data_dir(), map_file))
  env.liding_map, env.liding_max_key_len = read_liding_map(join_path(data_dir(), liding_map_file))
  if extra_liding_map_file and extra_liding_map_file ~= "" then
    env.liding_map, env.liding_max_key_len = merge_liding_map(
      env.liding_map,
      env.liding_max_key_len,
      join_path(data_dir(), extra_liding_map_file)
    )
  end
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
    local original_chars = collect_chars(cand.text)
    local chars = apply_liding(original_chars, env.liding_map, env.liding_max_key_len or 0)
    local liding_text = table.concat(chars)
    local text, changed = convert_default(original_chars, map)
    local original_changed = changed
    local liding_changed = false
    if not changed or liding_text ~= cand.text then
      local liding_output
      liding_output, liding_changed = convert_default(chars, map)
      if not changed and liding_changed then
        text = liding_output
        changed = true
      end
    end
    if changed then
      local comment = build_comment(cand.comment, cand.text, original_changed and cand.text or liding_text)
      local variants = nil
      if env.single_char_variants and #original_chars == 1 then
        variants = map[original_chars[1]]
      end

      if variants and #variants > 1 then
        local limit = math.min(#variants, env.max_variants)
        for index = 1, limit do
          yield(Candidate(cand.type, cand.start, cand._end, variants[index], comment .. " " .. index .. "/" .. #variants))
        end
      else
        yield(Candidate(cand.type, cand.start, cand._end, text, comment))
      end

      if env.single_char_variants and #original_chars == 1 then
        for _, extra_liding_text in ipairs(liding_targets_for_text(cand.text, env.liding_map)) do
          if original_changed or extra_liding_text ~= liding_text then
            local extra_chars = collect_chars(extra_liding_text)
            local extra_variants = nil
            if #extra_chars == 1 then
              extra_variants = map[extra_chars[1]]
            end
            if extra_variants then
              local extra_comment = build_comment(cand.comment, cand.text, extra_liding_text)
              local limit = math.min(#extra_variants, env.max_variants)
              for index = 1, limit do
                local suffix = ""
                if #extra_variants > 1 then
                  suffix = " " .. index .. "/" .. #extra_variants
                end
                yield(Candidate(cand.type, cand.start, cand._end, extra_variants[index], extra_comment .. suffix))
              end
            end
          end
        end
      end
    else
      yield(cand)
    end
  end
end

return M
