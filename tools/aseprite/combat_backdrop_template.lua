-- Generates Lawrence's combat-scene backdrop TEMPLATE (.aseprite) from the
-- numbers in .claude/todo-archive.md ("Battle animations plan") §7 — one 288×134 canvas at sprite
-- density, project palette attached, named slices for every zone, a guides
-- layer, the puppet ZONE with a tick per map tile (spacing follows the map:
-- 32 px per tile, 16 each way from the centre, capped at 4 tiles), and the two
-- default puppets (Max right, grunt left, mirrored) standing two tiles apart on
-- the feet line for scale. Run from the project root:
--
--   aseprite --batch --script tools/aseprite/combat_backdrop_template.lua
--
-- Optional env: BACKDROP_PREVIEW=<path.png> also writes a flattened preview.
-- Edit the NUMBERS block if the scene knobs move (combat_scene.gd is the truth:
-- GROUND_Y / SKY_BOTTOM / LEFT_X / RIGHT_X ÷ PUPPET_SCALE, + BACKDROP_CORE_OFFSET).

-- ---------------------------------------------------------------- NUMBERS
local W, H = 288, 134                 -- canvas (sprite px)
local CORE = { x = 37, y = 7, w = 214, h = 120 }  -- always visible
local HORIZON = 86                    -- first floor row (sky = rows 0..85)
local FEET = 91                       -- ground row the feet rest on (feet occupy row 90)
local CENTRE_X = 144                  -- stage centre (core 107 + 37)
local TILE = 32                       -- sprite px per map tile (battle_tileset.tres is 32×32)
local MAX_TILES = 4                   -- spread cap: 4 × 32 = 128 (centres CENTRE_X ± 64)
local REF_DISTANCE = 2                -- reference puppets stand this many tiles apart
local LEFT_X, RIGHT_X = CENTRE_X - TILE * REF_DISTANCE / 2, CENTRE_X + TILE * REF_DISTANCE / 2
local HUD = { w = 67, h = 24 }        -- HUD footprint from each top corner of the core
local PALETTE = "art/colors/SpacemanColorPalette_v1.41.gpl"
local AZURE_2, GRAY_3 = 57, 168       -- GPL rows: ramp*11 + intensity (Azure=5, Gray=15)
local LEFT_PUPPET = "art/sprites/characters/grunt/idle.png"   -- enemy side, mirrored
local RIGHT_PUPPET = "art/sprites/characters/max/idle.png"    -- player side
local OUT = "art/backdrops/combat_test/combat_backdrop_template.aseprite"

-- ---------------------------------------------------------------- helpers
local rgba = app.pixelColor.rgba
local function px(img, x, y, c)
  if x >= 0 and y >= 0 and x < img.width and y < img.height then img:drawPixel(x, y, c) end
end
local function hline(img, y, x0, x1, c) for x = x0, x1 do px(img, x, y, c) end end
local function vline(img, x, y0, y1, c) for y = y0, y1 do px(img, x, y, c) end end
local function rect(img, r, c)
  hline(img, r.y, r.x, r.x + r.w - 1, c); hline(img, r.y + r.h - 1, r.x, r.x + r.w - 1, c)
  vline(img, r.x, r.y, r.y + r.h - 1, c); vline(img, r.x + r.w - 1, r.y, r.y + r.h - 1, c)
end
local function fill(img, r, c)
  for y = r.y, r.y + r.h - 1 do hline(img, y, r.x, r.x + r.w - 1, c) end
end
local function opaqueBounds(img)
  local x0, y0, x1, y1 = img.width, img.height, -1, -1
  for it in img:pixels() do
    if app.pixelColor.rgbaA(it()) > 0 then
      local x, y = it.x, it.y
      if x < x0 then x0 = x end; if y < y0 then y0 = y end
      if x > x1 then x1 = x end; if y > y1 then y1 = y end
    end
  end
  return x0, y0, x1, y1
end
-- Copy `src` into `dst` so its opaque bounds are centred on `cx` and its
-- bottom opaque row is FEET-1 (feet rest on the line). mirror = flip_h.
local function standPuppet(dst, src, cx, mirror)
  local x0, y0, x1, y1 = opaqueBounds(src)
  if x1 < 0 then return end
  local bw = x1 - x0 + 1
  local left = cx - math.floor(bw / 2)
  local top = (FEET - 1) - (y1 - y0)
  for y = y0, y1 do
    for x = x0, x1 do
      local c = src:getPixel(x, y)
      if app.pixelColor.rgbaA(c) > 0 then
        local dx = mirror and (left + (x1 - x)) or (left + (x - x0))
        px(dst, dx, top + (y - y0), c)
      end
    end
  end
end
local function addSlice(spr, r, name, color)
  local s = spr:newSlice(Rectangle(r.x, r.y, r.w, r.h))
  s.name = name
  s.color = color
end

-- ---------------------------------------------------------------- sprite
local spr = Sprite(W, H, ColorMode.RGB)
local pal = Palette{ fromFile = PALETTE }
spr:setPalette(pal)
local skyColor = pal:getColor(AZURE_2)
local floorColor = pal:getColor(GRAY_3)
local frame = spr.frames[1]

-- Layer 1: sky (placeholder = the palette band the code draws today).
local sky = spr.layers[1]
sky.name = "sky"
local skyImg = Image(W, H, ColorMode.RGB)
fill(skyImg, { x = 0, y = 0, w = W, h = HORIZON }, rgba(skyColor.red, skyColor.green, skyColor.blue, 255))
spr:newCel(sky, frame, skyImg, Point(0, 0))

-- Layer 2: floor — transparent above the horizon so props can rise into the sky.
local floor = spr:newLayer()
floor.name = "floor"
local floorImg = Image(W, H, ColorMode.RGB)
fill(floorImg, { x = 0, y = HORIZON, w = W, h = H - HORIZON }, rgba(floorColor.red, floorColor.green, floorColor.blue, 255))
spr:newCel(floor, frame, floorImg, Point(0, 0))

-- Layer 3: reference puppets, feet on the line. Not for export.
local ref = spr:newLayer()
ref.name = "reference puppets — do not export"
local refImg = Image(W, H, ColorMode.RGB)
for _, entry in ipairs({ { LEFT_PUPPET, LEFT_X, true }, { RIGHT_PUPPET, RIGHT_X, false } }) do
  if app.fs.isFile(entry[1]) then
    local puppet = app.open(entry[1])
    if puppet then
      local cel = puppet.layers[1]:cel(1)
      if cel then standPuppet(refImg, cel.image, entry[2], entry[3]) end
      puppet:close()
    end
  else
    print("missing reference sprite: " .. entry[1])
  end
end
spr:newCel(ref, frame, refImg, Point(0, 0))

-- Layer 4: GUIDES. Bleed tint, core outline, horizon, feet line, puppet
-- centres, HUD footprints. Hide before export.
local guides = spr:newLayer()
guides.name = "GUIDES — hide before export"
local g = Image(W, H, ColorMode.RGB)
local bleed = rgba(0, 0, 0, 96)
fill(g, { x = 0, y = 0, w = CORE.x, h = H }, bleed)                                   -- left bleed (phones / ultrawide)
fill(g, { x = CORE.x + CORE.w, y = 0, w = W - CORE.x - CORE.w, h = H }, bleed)          -- right bleed
fill(g, { x = CORE.x, y = 0, w = CORE.w, h = CORE.y }, bleed)                            -- top bleed (Steam Deck)
fill(g, { x = CORE.x, y = CORE.y + CORE.h, w = CORE.w, h = H - CORE.y - CORE.h }, bleed) -- bottom bleed
rect(g, CORE, rgba(255, 0, 255, 255))                                                    -- core outline: magenta
hline(g, HORIZON, 0, W - 1, rgba(0, 220, 255, 255))                                      -- horizon: cyan
hline(g, FEET, 0, W - 1, rgba(255, 230, 0, 255))                                         -- feet line: yellow
-- Puppet zone: centres range CENTRE_X ± 8 per tile of distance (both sides
-- move half the spread), a tick per tile, the cap marked strong.
local half = TILE / 2
fill(g, { x = CENTRE_X - half * MAX_TILES, y = FEET + 1, w = TILE * MAX_TILES + 1, h = 2 }, rgba(255, 230, 0, 60))
for d = 1, MAX_TILES do
  local strong = (d == MAX_TILES) and 255 or 160
  vline(g, CENTRE_X - half * d, FEET + 1, FEET + 4, rgba(255, 230, 0, strong))
  vline(g, CENTRE_X + half * d, FEET + 1, FEET + 4, rgba(255, 230, 0, strong))
end
vline(g, CENTRE_X, FEET + 1, FEET + 8, rgba(255, 255, 255, 200))                          -- stage centre
for _, cx in ipairs({ LEFT_X, RIGHT_X }) do
  vline(g, cx, CORE.y + 1, FEET - 1, rgba(255, 230, 0, 50))                              -- reference puppets' centre lines
end
local hudTint = rgba(255, 60, 60, 70)
fill(g, { x = CORE.x, y = CORE.y, w = HUD.w, h = HUD.h }, hudTint)
fill(g, { x = CORE.x + CORE.w - HUD.w, y = CORE.y, w = HUD.w, h = HUD.h }, hudTint)
spr:newCel(guides, frame, g, Point(0, 0))

-- Slices: named rectangles Lawrence can read in the editor.
addSlice(spr, CORE, "CORE — always visible (214x120)", Color{ r = 255, g = 0, b = 255 })
addSlice(spr, { x = 0, y = 0, w = W, h = HORIZON }, "sky — rows 0-85 → sky.png", Color{ r = 0, g = 220, b = 255 })
addSlice(spr, { x = 0, y = HORIZON, w = W, h = H - HORIZON }, "floor — rows 86-133 → floor.png (may rise above the horizon)", Color{ r = 120, g = 120, b = 120 })
addSlice(spr, { x = 0, y = FEET, w = W, h = 1 }, "FEET LINE — puppets stand on row 91", Color{ r = 255, g = 230, b = 0 })
addSlice(spr, { x = CENTRE_X - half * MAX_TILES, y = FEET - 60, w = TILE * MAX_TILES + 1, h = 61 },
  "PUPPET ZONE — centres 16 px per map tile each side of x=144, cap 4 tiles (x 80..208)", Color{ r = 255, g = 230, b = 0 })
addSlice(spr, { x = CORE.x, y = CORE.y, w = HUD.w, h = HUD.h }, "HUD (left column) — keep the sky quiet", Color{ r = 255, g = 60, b = 60 })
addSlice(spr, { x = CORE.x + CORE.w - HUD.w, y = CORE.y, w = HUD.w, h = HUD.h }, "HUD (right column) — keep the sky quiet", Color{ r = 255, g = 60, b = 60 })
addSlice(spr, { x = 0, y = 0, w = CORE.x, h = H }, "bleed — phones / ultrawide only", Color{ r = 0, g = 0, b = 0 })
addSlice(spr, { x = CORE.x + CORE.w, y = 0, w = W - CORE.x - CORE.w, h = H }, "bleed — phones / ultrawide only", Color{ r = 0, g = 0, b = 0 })
addSlice(spr, { x = CORE.x, y = 0, w = CORE.w, h = CORE.y }, "bleed — Steam Deck (8:5) only", Color{ r = 0, g = 0, b = 0 })
addSlice(spr, { x = CORE.x, y = CORE.y + CORE.h, w = CORE.w, h = H - CORE.y - CORE.h }, "bleed — Steam Deck (8:5) only", Color{ r = 0, g = 0, b = 0 })

spr:saveAs(OUT)
print("template written: " .. OUT)
local preview = os.getenv("BACKDROP_PREVIEW")
if preview and preview ~= "" then
  spr:saveCopyAs(preview)
  print("preview written: " .. preview)
end
