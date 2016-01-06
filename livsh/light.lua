--[[
The MIT License (MIT)

Copyright (c)	2014 Marcus Ihde
					2016 Matías Starkkz Hermosilla

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local Path = (...):gsub("%p", "/"):sub(1, -6).."/"

-- light world

function love.light.newRoom(p, x, y, width, height, red, green, blue)
	local o = {}
	o.x = x or 0
	o.y = y or 0
	o.width = width or 0
	o.height = height or 0
	o.red = red or 0
	o.green = green or 0
	o.blue = blue or 0

	o.setPosition = function(x, y)
		if x ~= o.x or y ~= o.y then
			o.x = x
			o.y = y
		end
	end
	-- get x
	o.getX = function()
		return o.x
	end
	-- get y
	o.getY = function()
		return o.y
	end
	-- set x
	o.setX = function(x)
		if x ~= o.x then
			o.x = x
			o.changed = true
		end
	end
	-- set y
	o.setY = function(y)
		if y ~= o.y then
			o.y = y
			o.changed = true
		end
	end
	-- set color
	o.setColor = function(red, green, blue)
		o.red = red or 0
		o.green = green or 0
		o.blue = blue or 0
		--p.changed = true
	end
	-- get type
	o.getType = function()
		return "room"
	end
	-- clear
	o.clear = function()
		for i = 1, #p.rooms do
			if p.rooms[i] == o then
				for k = i, #p.rooms - 1 do
					p.rooms[k] = p.rooms[k + 1]
				end
				p.rooms[#p.rooms] = nil
				break
			end
		end
	end

	return o
end

-- light object
function love.light.newLight(p, x, y, red, green, blue, range)
	local o = {}
	o.direction = 0
	o.angle = math.pi * 2.0
	o.range = 0
	o.shadow = love.graphics.newCanvas()
	o.shine = love.graphics.newCanvas()
	o.x = x or 0
	o.y = y or 0
	o.z = 15
	o.red = red or 255
	o.green = green or 255
	o.blue = blue or 255
	o.range = range or 300
	o.smooth = 1.0
	o.glowSize = 0.1
	o.glowStrength = 0.0
	o.changed = true
	o.visible = true
	p.isLight = true
	-- set position
	o.setPosition = function(x, y, z)
		if x ~= o.x or y ~= o.y or (z and z ~= o.z) then
			o.x = x
			o.y = y
			if z then
				o.z = z
			end
			o.changed = true
		end
	end
	-- get x
	o.getX = function()
		return o.x
	end
	-- get y
	o.getY = function()
		return o.y
	end
	-- set x
	o.setX = function(x)
		if x ~= o.x then
			o.x = x
			o.changed = true
		end
	end
	-- set y
	o.setY = function(y)
		if y ~= o.y then
			o.y = y
			o.changed = true
		end
	end
	-- set color
	o.setColor = function(red, green, blue)
		o.red = red
		o.green = green
		o.blue = blue
		--p.changed = true
	end
	-- set range
	o.setRange = function(range)
		if range ~= o.range then
			o.range = range
			o.changed = true
		end
	end
	-- set direction
	o.setDirection = function(direction)
		if direction ~= o.direction then
			if direction > math.pi * 2 then
				o.direction = math.mod(direction, math.pi * 2)
			elseif direction < 0.0 then
				o.direction = math.pi * 2 - math.mod(math.abs(direction), math.pi * 2)
			else
				o.direction = direction
			end
			o.changed = true
		end
	end
	-- set angle
	o.setAngle = function(angle)
		if angle ~= o.angle then
			if angle > math.pi then
				o.angle = math.mod(angle, math.pi)
			elseif angle < 0.0 then
				o.angle = math.pi - math.mod(math.abs(angle), math.pi)
			else
				o.angle = angle
			end
			o.changed = true
		end
	end
	-- set glow size
	o.setSmooth = function(smooth)
		o.smooth = smooth
		o.changed = true
	end
	-- set glow size
	o.setGlowSize = function(size)
		o.glowSize = size
		o.changed = true
	end
	-- set glow strength
	o.setGlowStrength = function(strength)
		o.glowStrength = strength
		o.changed = true
	end
	-- get type
	o.getType = function()
		return "light"
	end
	-- clear
	o.clear = function()
		for i = 1, #p.lights do
			if p.lights[i] == o then
				for k = i, #p.lights - 1 do
					p.lights[k] = p.lights[k + 1]
				end
				p.lights[#p.lights] = nil
				break
			end
		end
	end

	return o
end

-- body object
function love.light.newBody(p, type, ...)
	local args = {...}
	local o = {}
	p.body[#p.body + 1] = o
	p.changed = true
	o.id = #p.body
	o.type = type
	o.normal = nil
	o.material = nil
	o.glow = nil
	if o.type == "circle" then
		o.x = args[1] or 0
		o.y = args[2] or 0
		o.radius = args[3] or 16
		o.ox = args[4] or 0
		o.oy = args[5] or 0
		o.shadowType = "circle"
		o.reflection = false
		o.reflective = false
		o.refraction = false
		o.refractive = false
		p.isShadows = true
	elseif o.type == "rectangle" then
		o.x = args[1] or 0
		o.y = args[2] or 0
		o.width = args[3] or 64
		o.height = args[4] or 64
		o.ox = o.width * 0.5
		o.oy = o.height * 0.5
		o.shadowType = "rectangle"
		o.data = {
			o.x - o.ox,
			o.y - o.oy,
			o.x - o.ox + o.width,
			o.y - o.oy,
			o.x - o.ox + o.width,
			o.y - o.oy + o.height,
			o.x - o.ox,
			o.y - o.oy + o.height
		}
		o.reflection = false
		o.reflective = false
		o.refraction = false
		o.refractive = false
		p.isShadows = true
	elseif o.type == "polygon" then
		o.shadowType = "polygon"
		o.data = args or {0, 0, 0, 0, 0, 0}
		o.reflection = false
		o.reflective = false
		o.refraction = false
		o.refractive = false
		p.isShadows = true
	elseif o.type == "image" then
		o.img = args[1]
		o.x = args[2] or 0
		o.y = args[3] or 0
		if o.img then
			o.imgWidth = o.img:getWidth()
			o.imgHeight = o.img:getHeight()
			o.width = args[4] or o.imgWidth
			o.height = args[5] or o.imgHeight
			o.ix = o.imgWidth * 0.5
			o.iy = o.imgHeight * 0.5
			o.vert = {
				{ 0.0, 0.0, 0.0, 0.0 },
				{ o.width, 0.0, 1.0, 0.0 },
				{ o.width, o.height, 1.0, 1.0 },
				{ 0.0, o.height, 0.0, 1.0 },
			}
			o.msh = love.graphics.newMesh(o.vert, "fan")
			o.msh:setTexture(o.img)
		else
			o.width = args[4] or 64
			o.height = args[5] or 64
		end
		o.ox = args[6] or o.width * 0.5
		o.oy = args[7] or o.height * 0.5
		o.shadowType = "rectangle"
		o.data = {
			o.x - o.ox,
			o.y - o.oy,
			o.x - o.ox + o.width,
			o.y - o.oy,
			o.x - o.ox + o.width,
			o.y - o.oy + o.height,
			o.x - o.ox,
			o.y - o.oy + o.height
		}
		o.reflection = false
		o.reflective = true
		o.refraction = false
		o.refractive = false
		p.isShadows = true
	elseif o.type == "refraction" then
		o.normal = args[1]
		o.x = args[2] or 0
		o.y = args[3] or 0
		if o.normal then
			o.normalWidth = o.normal:getWidth()
			o.normalHeight = o.normal:getHeight()
			o.width = args[4] or o.normalWidth
			o.height = args[5] or o.normalHeight
			o.nx = o.normalWidth * 0.5
			o.ny = o.normalHeight * 0.5
			o.normal:setWrap("repeat", "repeat")
			o.normalVert = {
				{0.0, 0.0, 0.0, 0.0},
				{o.width, 0.0, 1.0, 0.0},
				{o.width, o.height, 1.0, 1.0},
				{0.0, o.height, 0.0, 1.0}
			}
			o.normalMesh = love.graphics.newMesh(o.normalVert, "fan")
			o.normalMesh:setTexture(o.normal)
		else
			o.width = args[4] or 64
			o.height = args[5] or 64
		end
		o.ox = o.width * 0.5
		o.oy = o.height * 0.5
		o.reflection = false
		o.reflective = false
		o.refraction = true
		o.refractive = false
		p.isRefraction = true
	elseif o.type == "reflection" then
		o.normal = args[1]
		o.x = args[2] or 0
		o.y = args[3] or 0
		if o.normal then
			o.normalWidth = o.normal:getWidth()
			o.normalHeight = o.normal:getHeight()
			o.width = args[4] or o.normalWidth
			o.height = args[5] or o.normalHeight
			o.nx = o.normalWidth * 0.5
			o.ny = o.normalHeight * 0.5
			o.normal:setWrap("repeat", "repeat")
			o.normalVert = {
				{0.0, 0.0, 0.0, 0.0},
				{o.width, 0.0, 1.0, 0.0},
				{o.width, o.height, 1.0, 1.0},
				{0.0, o.height, 0.0, 1.0}
			}
			o.normalMesh = love.graphics.newMesh(o.normalVert, "fan")
			o.normalMesh:setTexture(o.normal)
		else
			o.width = args[4] or 64
			o.height = args[5] or 64
		end
		o.ox = o.width * 0.5
		o.oy = o.height * 0.5
		o.reflection = true
		o.reflective = false
		o.refraction = false
		o.refractive = false
		p.isReflection = true
	end
	o.shine = true
	o.red = 0
	o.green = 0
	o.blue = 0
	o.alpha = 1.0
	o.glowRed = 255
	o.glowGreen = 255
	o.glowBlue = 255
	o.glowStrength = 0.0
	o.tileX = 0
	o.tileY = 0
	-- refresh
	o.refresh = function()
		if o.data then
			o.data[1] = o.x - o.ox
			o.data[2] = o.y - o.oy
			o.data[3] = o.x - o.ox + o.width
			o.data[4] = o.y - o.oy
			o.data[5] = o.x - o.ox + o.width
			o.data[6] = o.y - o.oy + o.height
			o.data[7] = o.x - o.ox
			o.data[8] = o.y - o.oy + o.height
		end
	end
	-- set position
	o.setPosition = function(x, y)
		if x ~= o.x or y ~= o.y then
			o.x = x
			o.y = y
			o.refresh()
			p.changed = true
		end
	end
	-- set x position
	o.setX = function(x)
		if x ~= o.x then
			o.x = x
			o.refresh()
			p.changed = true
		end
	end
	-- set y position
	o.setY = function(y)
		if y ~= o.y then
			o.y = y
			o.refresh()
			p.changed = true
		end
	end
	-- get x position
	o.getX = function()
		return o.x
	end
	-- get y position
	o.getY = function(y)
		return o.y
	end
	-- get width
	o.getWidth = function()
		return o.width
	end
	-- get height
	o.getHeight = function()
		return o.height
	end
	-- get image width
	o.getImageWidth = function()
		return o.imgWidth
	end
	-- get image height
	o.getImageHeight = function()
		return o.imgHeight
	end
	-- set dimension
	o.setDimension = function(width, height)
		o.width = width
		o.height = height
		o.refresh()
		p.changed = true
	end
	-- set offset
	o.setOffset = function(ox, oy)
		if ox ~= o.ox or oy ~= o.oy then
			o.ox = ox
			o.oy = oy
			if o.shadowType == "rectangle" then
				o.refresh()
			end
			p.changed = true
		end
	end
	-- set offset
	o.setImageOffset = function(ix, iy)
		if ix ~= o.ix or iy ~= o.iy then
			o.ix = ix
			o.iy = iy
			o.refresh()
			p.changed = true
		end
	end
	-- set offset
	o.setNormalOffset = function(nx, ny)
		if nx ~= o.nx or ny ~= o.ny then
			o.nx = nx
			o.ny = ny
			o.refresh()
			p.changed = true
		end
	end
	-- set glow color
	o.setGlowColor = function(red, green, blue)
		o.glowRed = red
		o.glowGreen = green
		o.glowBlue = blue
		p.changed = true
	end
	-- set glow alpha
	o.setGlowStrength = function(strength)
		o.glowStrength = strength
		p.changed = true
	end
	-- get radius
	o.getRadius = function()
		return o.radius
	end
	-- set radius
	o.setRadius = function(radius)
		if radius ~= o.radius then
			o.radius = radius
			p.changed = true
		end
	end
	-- set polygon data
	o.setPoints = function(...)
		o.data = {...}
		p.changed = true
	end
	-- get polygon data
	o.getPoints = function()
		return unpack(o.data)
	end
	-- set shadow on/off
	o.setShadowType = function(type)
		o.shadowType = type
		p.changed = true
	end
	-- set shadow on/off
	o.setShadow = function(b)
		o.castsNoShadow = not b
		p.changed = true
	end
	-- set shine on/off
	o.setShine = function(b)
		o.shine = b
		p.changed = true
	end
	-- set glass color
	o.setColor = function(red, green, blue)
		o.red = red
		o.green = green
		o.blue = blue
		p.changed = true
	end
	-- set glass alpha
	o.setAlpha = function(alpha)
		o.alpha = alpha
		p.changed = true
	end
	-- set reflection on/off
	o.setReflection = function(reflection)
		o.reflection = reflection
	end
	-- set refraction on/off
	o.setRefraction = function(refraction)
		o.refraction = refraction
	end
	-- set reflective on other objects on/off
	o.setReflective = function(reflective)
		o.reflective = reflective
	end
	-- set refractive on other objects on/off
	o.setRefractive = function(refractive)
		o.refractive = refractive
	end
	-- set image
	o.setImage = function(img)
		if img then
			o.img = img
			o.imgWidth = o.img:getWidth()
			o.imgHeight = o.img:getHeight()
			o.ix = o.imgWidth * 0.5
			o.iy = o.imgHeight * 0.5
		end
	end
	-- set normal
	o.setNormalMap = function(normal, width, height, nx, ny)
		if normal then
			o.normal = normal
			o.normal:setWrap("repeat", "repeat")
			o.normalWidth = width or o.normal:getWidth()
			o.normalHeight = height or o.normal:getHeight()
			o.nx = nx or o.normalWidth * 0.5
			o.ny = ny or o.normalHeight * 0.5
			o.normalVert = {
				{0.0, 0.0, 0.0, 0.0},
				{o.normalWidth, 0.0, o.normalWidth / o.normal:getWidth(), 0.0},
				{o.normalWidth, o.normalHeight, o.normalWidth / o.normal:getWidth(), o.normalHeight / o.normal:getHeight()},
				{0.0, o.normalHeight, 0.0, o.normalHeight / o.normal:getHeight()}
			}
			o.normalMesh = love.graphics.newMesh(o.normalVert, "fan")
			o.normalMesh:setTexture(o.normal)

			p.isPixelShadows = true
		else
			o.normalMesh = nil
		end
	end
	-- set height map
	o.setHeightMap = function(heightMap, strength)
		o.setNormalMap(HeightMapToNormalMap(heightMap, strength))
	end
	-- generate flat normal map
	o.generateNormalMapFlat = function(mode)
		local imgData = o.img:getData()
		local imgNormalData = love.image.newImageData(o.imgWidth, o.imgHeight)
		local color

		if mode == "top" then
			color = {127, 127, 255}
		elseif mode == "front" then
			color = {127, 0, 127}
		elseif mode == "back" then
			color = {127, 255, 127}
		elseif mode == "left" then
			color = {31, 0, 223}
		elseif mode == "right" then
			color = {223, 0, 127}
		end

		for i = 0, o.imgHeight - 1 do
			for k = 0, o.imgWidth - 1 do
				local r, g, b, a = imgData:getPixel(k, i)
				if a > 0 then
					imgNormalData:setPixel(k, i, color[1], color[2], color[3], 255)
				end
			end
		end

		o.setNormalMap(love.graphics.newImage(imgNormalData))
	end
	-- generate faded normal map
	o.generateNormalMapGradient = function(horizontalGradient, verticalGradient)
		local imgData = o.img:getData()
		local imgNormalData = love.image.newImageData(o.imgWidth, o.imgHeight)
		local dx = 255.0 / o.imgWidth
		local dy = 255.0 / o.imgHeight
		local nx
		local ny
		local nz

		for i = 0, o.imgWidth - 1 do
			for k = 0, o.imgHeight - 1 do
				local r, g, b, a = imgData:getPixel(i, k)
				if a > 0 then
					if horizontalGradient == "gradient" then
						nx = i * dx
					elseif horizontalGradient == "inverse" then
						nx = 255 - i * dx
					else
						nx = 127
					end

					if verticalGradient == "gradient" then
						ny = 127 - k * dy * 0.5
						nz = 255 - k * dy * 0.5
					elseif verticalGradient == "inverse" then
						ny = 127 + k * dy * 0.5
						nz = 127 - k * dy * 0.25
					else
						ny = 255
						nz = 127
					end

					imgNormalData:setPixel(i, k, nx, ny, nz, 255)
				end
			end
		end

		o.setNormalMap(love.graphics.newImage(imgNormalData))
	end
	-- generate normal map
	o.generateNormalMap = function(strength)
		o.setNormalMap(HeightMapToNormalMap(o.img, strength))
	end
	-- set material
	o.setMaterial = function(material)
		if material then
			o.material = material
		end
	end
	-- set normal
	o.setGlowMap = function(glow)
		o.glow = glow
		o.glowStrength = 1.0

		p.isGlow = true
	end
	-- set tile offset
	o.setNormalTileOffset = function(tx, ty)
		o.tileX = tx / o.normalWidth
		o.tileY = ty / o.normalHeight
		o.normalVert = {
			{0.0, 0.0, o.tileX, o.tileY},
			{o.normalWidth, 0.0, o.tileX + 1.0, o.tileY},
			{o.normalWidth, o.normalHeight, o.tileX + 1.0, o.tileY + 1.0},
			{0.0, o.normalHeight, o.tileX, o.tileY + 1.0}
		}
		p.changed = true
	end
	-- get type
	o.getType = function()
		return o.type
	end
	-- get type
	o.setShadowType = function(type, ...)
		o.shadowType = type
		local args = {...}
		if o.shadowType == "circle" then
			o.radius = args[1] or 16
			o.ox = args[2] or 0
			o.oy = args[3] or 0
		elseif o.shadowType == "rectangle" then
			o.width = args[1] or 64
			o.height = args[2] or 64
			o.ox = args[3] or o.width * 0.5
			o.oy = args[4] or o.height * 0.5
			o.data = {
				o.x - o.ox,
				o.y - o.oy,
				o.x - o.ox + o.width,
				o.y - o.oy,
				o.x - o.ox + o.width,
				o.y - o.oy + o.height,
				o.x - o.ox,
				o.y - o.oy + o.height
			}
		elseif o.shadowType == "polygon" then
			o.data = args or {0, 0, 0, 0, 0, 0}
		elseif o.shadowType == "image" then
			if o.img then
				o.width = o.imgWidth
				o.height = o.imgHeight
				o.shadowVert = {
					{0.0, 0.0, 0.0, 0.0},
					{o.width, 0.0, 1.0, 0.0},
					{o.width, o.height, 1.0, 1.0},
					{0.0, o.height, 0.0, 1.0}
				}
				if not o.shadowMesh then
					o.shadowMesh = love.graphics.newMesh(o.shadowVert, "fan")
					o.shadowMesh:setTexture(o.img)
					o.shadowMesh:setAttributeEnabled("VertexColor", true)
				end
			else
				o.width = 64
				o.height = 64
			end
			o.shadowX = args[1] or 0
			o.shadowY = args[2] or 0
			o.fadeStrength = args[3] or 0.0
		end
	end
	-- clear
	o.clear = function()
		for i = 1, #p.body do
			if p.body[i] == o then
				for k = i, #p.body - 1 do
					p.body[k] = p.body[k + 1]
				end
				p.body[#p.body] = nil
				break
			end
		end
		p.changed = true
	end

	return o
end

-- rectangle object
function love.light.newRectangle(p, x, y, width, height)
	return p:newBody("rectangle", x, y, width, height)
end

-- circle object
function love.light.newCircle(p, x, y, radius)
	return p:newBody("circle", x, y, radius)
end

-- poly object
function love.light.newPolygon(p, ...)
	return p:newBody("polygon", ...)
end

-- image object
function love.light.newImage(p, img, x, y, width, height, ox, oy)
	return p:newBody("image", img, x, y, width, height, ox, oy)
end

-- refraction object
function love.light.newRefraction(p, normal, x, y, width, height)
	return p:newBody("refraction", normal, x, y, width, height)
end

-- refraction object (height map)
function love.light.newRefractionHeightMap(p, heightMap, x, y, strength)
	local normal = HeightMapToNormalMap(heightMap, strength)
	return love.light.newRefraction(p, normal, x, y)
end

-- reflection object
function love.light.newReflection(p, normal, x, y, width, height)
	return p:newBody("reflection", normal, x, y, width, height)
end

-- reflection object (height map)
function love.light.newReflectionHeightMap(p, heightMap, x, y, strength)
	local normal = HeightMapToNormalMap(heightMap, strength)
	return love.light.newReflection(p, normal, x, y)
end
