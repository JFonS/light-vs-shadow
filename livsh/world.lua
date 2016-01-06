local Path = (...):gsub("%p", "/"):sub(1, -6).."/"
local World = {}
local WorldMT = {__index = World}

function love.light.newWorld()
	local self = {}

	self.lights = {}
	self.ambient = {0, 0, 0}
	self.body = {}
	self.refraction = {}
	self.rooms = {}
	self.shadow = love.graphics.newCanvas()
	self.shadow2 = love.graphics.newCanvas()
	self.shine = love.graphics.newCanvas()
	self.shine2 = love.graphics.newCanvas()
	self.normalMap = love.graphics.newCanvas()
	self.glowMap = love.graphics.newCanvas()
	self.glowMap2 = love.graphics.newCanvas()
	self.refractionMap = love.graphics.newCanvas()
	self.refractionMap2 = love.graphics.newCanvas()
	self.reflectionMap = love.graphics.newCanvas()
	self.reflectionMap2 = love.graphics.newCanvas()
	self.normalInvert = false
	self.glowBlur = 1.0
	self.glowTimer = 0.0
	self.glowDown = false
	self.refractionStrength = 8.0
	self.pixelShadow = love.graphics.newCanvas()
	self.pixelShadow2 = love.graphics.newCanvas()
	self.shader = love.graphics.newShader(Path.."shader/poly_shadow.glsl")
	self.glowShader = love.graphics.newShader(Path.."shader/glow.glsl")
	self.normalShader = love.graphics.newShader(Path.."shader/normal.glsl")
	self.normalInvertShader = love.graphics.newShader(Path.."shader/normal_invert.glsl")
	self.materialShader = love.graphics.newShader(Path.."shader/material.glsl")
	self.refractionShader = love.graphics.newShader(Path.."shader/refraction.glsl")
	self.refractionShader:send("screen", {love.graphics.getWidth(), love.graphics.getHeight()})
	self.reflectionShader = love.graphics.newShader(Path.."shader/reflection.glsl")
	self.reflectionShader:send("screen", {love.graphics.getWidth(), love.graphics.getHeight()})
	self.reflectionStrength = 16.0
	self.reflectionVisibility = 1.0
	self.changed = true
	self.blur = 2.0
	self.optionShadows = true
	self.optionPixelShadows = true
	self.optionGlow = true
	self.optionRefraction = true
	self.optionReflection = true
	self.isShadows = false
	self.isLight = false
	self.isPixelShadows = false
	self.isGlow = false
	self.isRefraction = false
	self.isReflection = false
	
	return setmetatable(self, WorldMT)
end

function World:update()
	LOVE_LIGHT_LAST_BUFFER = love.graphics.getCanvas()

	if LOVE_LIGHT_TRANSLATE_X ~= LOVE_LIGHT_TRANSLATE_X_OLD or LOVE_LIGHT_TRANSLATE_Y ~= LOVE_LIGHT_TRANSLATE_Y_OLD then
		LOVE_LIGHT_TRANSLATE_X_OLD = LOVE_LIGHT_TRANSLATE_X
		LOVE_LIGHT_TRANSLATE_Y_OLD = LOVE_LIGHT_TRANSLATE_Y
		self.changed = true
	end

		love.graphics.setColor(255, 255, 255)
		love.graphics.setBlendMode("alpha")

		if self.optionShadows and (self.isShadows or self.isLight) then
			love.graphics.setShader(self.shader)

			LOVE_LIGHT_BODY = self.body

			local lightsOnScreen = 0
			for i, Light in pairs(self.lights) do
				if Light.changed or self.changed then
					if Light.x + Light.range > LOVE_LIGHT_TRANSLATE_X and Light.x - Light.range < love.graphics.getWidth() + LOVE_LIGHT_TRANSLATE_X
						and Light.y + Light.range > LOVE_LIGHT_TRANSLATE_Y and Light.y - Light.range < love.graphics.getHeight() + LOVE_LIGHT_TRANSLATE_Y
					then
						local lightposrange = {Light.x, Light.y, Light.range}
						LOVE_LIGHT_CURRENT = Light
						LOVE_LIGHT_DIRECTION = LOVE_LIGHT_DIRECTION + 0.002
						self.shader:send("lightPosition", {Light.x - LOVE_LIGHT_TRANSLATE_X, Light.y - LOVE_LIGHT_TRANSLATE_Y, Light.z})
						self.shader:send("lightRange", Light.range)
						self.shader:send("lightColor", {Light.red / 255.0, Light.green / 255.0, Light.blue / 255.0})
						self.shader:send("lightSmooth", Light.smooth)
						self.shader:send("lightGlow", {1.0 - Light.glowSize, Light.glowStrength})
						self.shader:send("lightAngle", math.pi - Light.angle / 2.0)
						self.shader:send("lightDirection", Light.direction)

						love.graphics.setCanvas(Light.shadow)
						love.graphics.clear()

						-- calculate shadows
						LOVE_LIGHT_SHADOW_GEOMETRY = calculateShadows(LOVE_LIGHT_CURRENT, self.body)

						-- draw shadow
						love.graphics.stencil(shadowStencil)
						love.graphics.setStencilTest("equal", 0)
						--love.graphics.setBlendMode("add")
						love.graphics.rectangle("fill", LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y, love.graphics.getWidth(), love.graphics.getHeight())

						-- draw color shadows
						love.graphics.setBlendMode("multiply")
						love.graphics.setShader()
						for k = 1,#LOVE_LIGHT_SHADOW_GEOMETRY do
							if LOVE_LIGHT_SHADOW_GEOMETRY[k].alpha < 1.0 then
								love.graphics.setColor(
									LOVE_LIGHT_SHADOW_GEOMETRY[k].red * (1.0 - LOVE_LIGHT_SHADOW_GEOMETRY[k].alpha),
									LOVE_LIGHT_SHADOW_GEOMETRY[k].green * (1.0 - LOVE_LIGHT_SHADOW_GEOMETRY[k].alpha),
									LOVE_LIGHT_SHADOW_GEOMETRY[k].blue * (1.0 - LOVE_LIGHT_SHADOW_GEOMETRY[k].alpha)
								)
								love.graphics.polygon("fill", unpack(LOVE_LIGHT_SHADOW_GEOMETRY[k]))
							end
						end

						for k, Body in pairs(self.body) do
							if Body.alpha < 1.0 then
								love.graphics.setBlendMode("multiply")
								love.graphics.setColor(Body.red, Body.green, Body.blue)
								if Body.shadowType == "circle" then
									love.graphics.circle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.radius)
								elseif Body.shadowType == "rectangle" then
									love.graphics.rectangle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.width, Body.height)
								elseif Body.shadowType == "polygon" then
									love.graphics.polygon("fill", unpack(Body.data))
								end
							end

							if Body.shadowType == "image" and Body.img then
								love.graphics.setBlendMode("alpha")
								local length = 1.0
								local shadowRotation = math.atan2((Body.x) - Light.x, (Body.y + Body.oy) - Light.y)
								local alpha = math.abs(math.cos(shadowRotation))

								Body.shadowVert = {
									{math.sin(shadowRotation) * Body.imgHeight * length, (length * math.cos(shadowRotation) + 1.0) * Body.imgHeight + (math.cos(shadowRotation) + 1.0) * Body.shadowY, 0, 0, Body.red, Body.green, Body.blue, Body.alpha * Body.fadeStrength * 255},
									{Body.imgWidth + math.sin(shadowRotation) * Body.imgHeight * length, (length * math.cos(shadowRotation) + 1.0) * Body.imgHeight + (math.cos(shadowRotation) + 1.0) * Body.shadowY, 1, 0, Body.red, Body.green, Body.blue, Body.alpha * Body.fadeStrength * 255},
									{Body.imgWidth, Body.imgHeight + (math.cos(shadowRotation) + 1.0) * Body.shadowY, 1, 1, Body.red, Body.green, Body.blue, Body.alpha * 255},
									{0, Body.imgHeight + (math.cos(shadowRotation) + 1.0) * Body.shadowY, 0, 1, Body.red, Body.green, Body.blue, Body.alpha * 255}
								}

								Body.shadowMesh:setVertices(Body.shadowVert)
								love.graphics.draw(Body.shadowMesh, Body.x - Body.ox + LOVE_LIGHT_TRANSLATE_X, Body.y - Body.oy + LOVE_LIGHT_TRANSLATE_Y)
							end
						end

						love.graphics.setShader(self.shader)

						-- draw shine
						love.graphics.setCanvas(Light.shine)
						love.graphics.clear(255, 255, 255)
						love.graphics.setBlendMode("alpha")
						love.graphics.stencil(polyStencil)
						love.graphics.setStencilTest("greater", 0)
						love.graphics.rectangle("fill", LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y, love.graphics.getWidth(), love.graphics.getHeight())

						lightsOnScreen = lightsOnScreen + 1

						Light.visible = true
					else
						Light.visible = false
					end

					Light.changed = self.changed
				end
			end

			-- update shadow
			love.graphics.setShader()
			love.graphics.setCanvas(self.shadow)
			love.graphics.setStencilTest()
			love.graphics.setColor(unpack(self.ambient))
			love.graphics.setBlendMode("alpha")
			love.graphics.rectangle("fill", LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y, love.graphics.getWidth(), love.graphics.getHeight())

			for _, Room in pairs(self.rooms) do
				love.graphics.setColor(Room.red, Room.green, Room.blue)
				love.graphics.rectangle("fill", Room.x - LOVE_LIGHT_TRANSLATE_X, Room.y - LOVE_LIGHT_TRANSLATE_Y, Room.width, Room.height)
			end

			love.graphics.setColor(255, 255, 255)
			love.graphics.setBlendMode("add")
			for i, Light in pairs(self.lights) do
				if Light.visible then
					love.graphics.draw(Light.shadow, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
				end
			end
			self.isShadowBlur = false

			-- update shine
			love.graphics.setCanvas(self.shine)
			love.graphics.setColor(unpack(self.ambient))
			love.graphics.setBlendMode("alpha")
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

			for _, Room in pairs(self.rooms) do
				love.graphics.setColor(Room.red, Room.green, Room.blue)
				love.graphics.rectangle("fill", Room.x - LOVE_LIGHT_TRANSLATE_X, Room.y - LOVE_LIGHT_TRANSLATE_Y, Room.width, Room.height)
			end

			love.graphics.setColor(255, 255, 255)
			love.graphics.setBlendMode("add")
			for i, Light in pairs(self.lights) do
				if Light.visible then
					love.graphics.draw(Light.shine, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
				end
			end
		end

		if self.optionPixelShadows and self.isPixelShadows then
			-- update pixel shadow
			love.graphics.setBlendMode("alpha")

			-- create normal map
			love.graphics.setShader()
			love.graphics.setCanvas(self.normalMap)
			love.graphics.clear()
			for i, Body in pairs(self.body) do
				if Body.type == "image" and Body.normalMesh then
					love.graphics.setColor(255, 255, 255)
					love.graphics.draw(Body.normalMesh, Body.x - Body.nx + LOVE_LIGHT_TRANSLATE_X, Body.y - Body.ny + LOVE_LIGHT_TRANSLATE_Y)
				end
			end
			love.graphics.setColor(255, 255, 255)
			love.graphics.setBlendMode("alpha")

			love.graphics.setCanvas(self.pixelShadow2)
			love.graphics.clear()
			love.graphics.setBlendMode("add")
			love.graphics.setShader(self.shader2)

			for i, Light in pairs(self.lights) do
				if Light.visible then
					if self.normalInvert then
						self.normalInvertShader:send('screenResolution', {love.graphics.getWidth(), love.graphics.getHeight()})
						self.normalInvertShader:send('lightColor', {Light.red / 255.0, Light.green / 255.0, Light.blue / 255.0})
						self.normalInvertShader:send('lightPosition',{Light.x, Light.y, Light.z / 255.0})
						self.normalInvertShader:send('lightRange',{Light.range})
						self.normalInvertShader:send("lightSmooth", Light.smooth)
						self.normalInvertShader:send("lightAngle", math.pi - Light.angle / 2.0)
						self.normalInvertShader:send("lightDirection", Light.direction)
						love.graphics.setShader(self.normalInvertShader)
					else
						self.normalShader:send('screenResolution', {love.graphics.getWidth(), love.graphics.getHeight()})
						self.normalShader:send('lightColor', {self.lights[i].red / 255.0, self.lights[i].green / 255.0, self.lights[i].blue / 255.0})
						self.normalShader:send('lightPosition',{self.lights[i].x, self.lights[i].y, self.lights[i].z / 255.0})
						self.normalShader:send('lightRange',{self.lights[i].range})
						self.normalShader:send("lightSmooth", self.lights[i].smooth)
						self.normalShader:send("lightAngle", math.pi - self.lights[i].angle / 2.0)
						self.normalShader:send("lightDirection", self.lights[i].direction)
						love.graphics.setShader(self.normalShader)
					end
					love.graphics.draw(self.normalMap, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
				end
			end

			love.graphics.setShader()
			love.graphics.setCanvas(self.pixelShadow)
			love.graphics.clear(255, 255, 255)
			love.graphics.setBlendMode("alpha")
			love.graphics.draw(self.pixelShadow2, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setBlendMode("add")
			love.graphics.setColor({self.ambient[1], self.ambient[2], self.ambient[3]})
			love.graphics.rectangle("fill", LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y, love.graphics.getWidth(), love.graphics.getHeight())
			love.graphics.setBlendMode("alpha")
		end

		if self.optionGlow and self.isGlow then
			-- create glow map
			love.graphics.setCanvas(self.glowMap)
			love.graphics.clear(0, 0, 0)

			if self.glowDown then
				self.glowTimer = math.max(0.0, self.glowTimer - love.timer.getDelta())
				if self.glowTimer == 0.0 then
					self.glowDown = not self.glowDown
				end
			else
				self.glowTimer = math.min(self.glowTimer + love.timer.getDelta(), 1.0)
				if self.glowTimer == 1.0 then
					self.glowDown = not self.glowDown
				end
			end

			for i, Body in pairs(self.body) do
				if self.body[i].glowStrength > 0.0 then
					love.graphics.setColor(self.body[i].glowRed * self.body[i].glowStrength, self.body[i].glowGreen * self.body[i].glowStrength, self.body[i].glowBlue * self.body[i].glowStrength)
				else
					love.graphics.setColor(0, 0, 0)
				end

				if self.body[i].type == "circle" then
					love.graphics.circle("fill", self.body[i].x, self.body[i].y, self.body[i].radius)
				elseif self.body[i].type == "rectangle" then
					love.graphics.rectangle("fill", self.body[i].x, self.body[i].y, self.body[i].width, self.body[i].height)
				elseif self.body[i].type == "polygon" then
					love.graphics.polygon("fill", unpack(self.body[i].data))
				elseif self.body[i].type == "image" and self.body[i].img then
					if self.body[i].glowStrength > 0.0 and self.body[i].glow then
						love.graphics.setShader(self.glowShader)
						self.glowShader:send("glowImage", self.body[i].glow)
						self.glowShader:send("glowTime", love.timer.getTime() * 0.5)
						love.graphics.setColor(255, 255, 255)
					else
						love.graphics.setShader()
						love.graphics.setColor(0, 0, 0)
					end
					love.graphics.draw(self.body[i].img, self.body[i].x - self.body[i].ix + LOVE_LIGHT_TRANSLATE_X, self.body[i].y - self.body[i].iy + LOVE_LIGHT_TRANSLATE_Y)
				end
			end
		end

		if self.optionRefraction and self.isRefraction then
			love.graphics.setShader()

			-- create refraction map
			love.graphics.setCanvas(self.refractionMap)
			love.graphics.clear()
			for i, Body in pairs(self.body) do
				if self.body[i].refraction and self.body[i].normal then
					love.graphics.setColor(255, 255, 255)
					if self.body[i].tileX == 0.0 and self.body[i].tileY == 0.0 then
						love.graphics.draw(normal, self.body[i].x - self.body[i].nx + LOVE_LIGHT_TRANSLATE_X, self.body[i].y - self.body[i].ny + LOVE_LIGHT_TRANSLATE_Y)
					else
						self.body[i].normalMesh:setVertices(self.body[i].normalVert)
						love.graphics.draw(self.body[i].normalMesh, self.body[i].x - self.body[i].nx + LOVE_LIGHT_TRANSLATE_X, self.body[i].y - self.body[i].ny + LOVE_LIGHT_TRANSLATE_Y)
					end
				end
			end

			love.graphics.setColor(0, 0, 0)
			for i, Body in pairs(self.body) do
				if not self.body[i].refractive then
					if self.body[i].type == "circle" then
						love.graphics.circle("fill", self.body[i].x, self.body[i].y, self.body[i].radius)
					elseif self.body[i].type == "rectangle" then
						love.graphics.rectangle("fill", self.body[i].x, self.body[i].y, self.body[i].width, self.body[i].height)
					elseif self.body[i].type == "polygon" then
						love.graphics.polygon("fill", unpack(self.body[i].data))
					elseif self.body[i].type == "image" and self.body[i].img then
						love.graphics.draw(self.body[i].img, self.body[i].x - self.body[i].ix + LOVE_LIGHT_TRANSLATE_X, self.body[i].y - self.body[i].iy + LOVE_LIGHT_TRANSLATE_Y)
					end
				end
			end
		end

		if self.optionReflection and self.isReflection then
			-- create reflection map
			if self.changed then
				self.reflectionMap:clear(0, 0, 0)
				love.graphics.setCanvas(self.reflectionMap)
				for i, Body in pairs(self.body) do
					if self.body[i].reflection and self.body[i].normal then
						love.graphics.setColor(255, 0, 0)
						self.body[i].normalMesh:setVertices(self.body[i].normalVert)
						love.graphics.draw(self.body[i].normalMesh, self.body[i].x - self.body[i].nx + LOVE_LIGHT_TRANSLATE_X, self.body[i].y - self.body[i].ny + LOVE_LIGHT_TRANSLATE_Y)
					end
				end
				for i, Body in pairs(self.body) do
					if self.body[i].reflective and self.body[i].img then
						love.graphics.setColor(0, 255, 0)
						love.graphics.draw(self.body[i].img, self.body[i].x - self.body[i].ix + LOVE_LIGHT_TRANSLATE_X, self.body[i].y - self.body[i].iy + LOVE_LIGHT_TRANSLATE_Y)
					elseif not self.body[i].reflection and self.body[i].img then
						love.graphics.setColor(0, 0, 0)
						love.graphics.draw(self.body[i].img, self.body[i].x - self.body[i].ix + LOVE_LIGHT_TRANSLATE_X, self.body[i].y - self.body[i].iy + LOVE_LIGHT_TRANSLATE_Y)
					end
				end
			end
		end

		love.graphics.setShader()
		love.graphics.setBlendMode("alpha")
		love.graphics.setStencilTest()
		love.graphics.setCanvas(LOVE_LIGHT_LAST_BUFFER)

		self.changed = false
end

function World:refreshScreenSize()
	self.shadow = love.graphics.newCanvas()
	self.shadow2 = love.graphics.newCanvas()
	self.shine = love.graphics.newCanvas()
	self.shine2 = love.graphics.newCanvas()
	self.normalMap = love.graphics.newCanvas()
	self.glowMap = love.graphics.newCanvas()
	self.glowMap2 = love.graphics.newCanvas()
	self.refractionMap = love.graphics.newCanvas()
	self.refractionMap2 = love.graphics.newCanvas()
	self.reflectionMap = love.graphics.newCanvas()
	self.reflectionMap2 = love.graphics.newCanvas()
	self.pixelShadow = love.graphics.newCanvas()
	self.pixelShadow2 = love.graphics.newCanvas()
end

function World:drawShine()
	if self.optionShadows and self.isShadows then
		love.graphics.setColor(255, 255, 255)
		if self.blur and false then
			LOVE_LIGHT_LAST_BUFFER = love.graphics.getCanvas()
			LOVE_LIGHT_BLURV:send("steps", self.blur)
			LOVE_LIGHT_BLURH:send("steps", self.blur)
			love.graphics.setBlendMode("alpha")
			love.graphics.setCanvas(self.shine2)
			love.graphics.setShader(LOVE_LIGHT_BLURV)
			love.graphics.draw(self.shine, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(self.shine)
			love.graphics.setShader(LOVE_LIGHT_BLURH)
			love.graphics.draw(self.shine2, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(LOVE_LIGHT_LAST_BUFFER)
			love.graphics.setBlendMode("multiply")
			love.graphics.setShader()
			love.graphics.draw(self.shine, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setBlendMode("alpha")
		else
			love.graphics.setBlendMode("multiply")
			love.graphics.setShader()
			love.graphics.draw(self.shine, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setBlendMode("alpha")
		end
	end
end

function World:drawShadow()
	if self.optionShadows and (self.isShadows or self.isLight) then
		love.graphics.setColor(255, 255, 255)
		if self.blur then
			LOVE_LIGHT_LAST_BUFFER = love.graphics.getCanvas()
			LOVE_LIGHT_BLURV:send("steps", self.blur)
			LOVE_LIGHT_BLURH:send("steps", self.blur)
			love.graphics.setBlendMode("alpha")
			love.graphics.setCanvas(self.shadow2)
			love.graphics.setShader(LOVE_LIGHT_BLURV)
			love.graphics.draw(self.shadow, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(self.shadow)
			love.graphics.setShader(LOVE_LIGHT_BLURH)
			love.graphics.draw(self.shadow2, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(LOVE_LIGHT_LAST_BUFFER)
			love.graphics.setBlendMode("multiply")
			love.graphics.setShader()
			love.graphics.draw(self.shadow, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setBlendMode("alpha")
		else
			love.graphics.setBlendMode("multiply")
			love.graphics.setShader()
			love.graphics.draw(self.shadow, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setBlendMode("alpha")
		end
	end
end

function World:drawPixelShadow()
	if self.optionPixelShadows and self.isPixelShadows then
		love.graphics.setColor(255, 255, 255)
		love.graphics.setBlendMode("multiply")
		love.graphics.setShader()
		love.graphics.draw(self.pixelShadow, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
		love.graphics.setBlendMode("alpha")
	end
end

function World:drawMaterial()
	love.graphics.setShader(self.materialShader)
	for i, Body in pairs(self.body) do
		if Body.material and Body.normal then
			love.graphics.setColor(255, 255, 255)
			self.materialShader:send("material", Body.material)
			love.graphics.draw(Body.normal, Body.x - Body.nx + LOVE_LIGHT_TRANSLATE_X, Body.y - Body.ny + LOVE_LIGHT_TRANSLATE_Y)
		end
	end
	love.graphics.setShader()
end

function World:drawGlow()
	if self.optionGlow and self.isGlow then
		love.graphics.setColor(255, 255, 255)
		if self.glowBlur == 0.0 then
			love.graphics.setBlendMode("add")
			love.graphics.setShader()
			love.graphics.draw(self.glowMap, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setBlendMode("alpha")
		else
			LOVE_LIGHT_BLURV:send("steps", self.glowBlur)
			LOVE_LIGHT_BLURH:send("steps", self.glowBlur)
			LOVE_LIGHT_LAST_BUFFER = love.graphics.getCanvas()
			love.graphics.setBlendMode("add")
			love.graphics.setCanvas(self.glowMap2)
			love.graphics.clear()
			love.graphics.setShader(LOVE_LIGHT_BLURV)
			love.graphics.draw(self.glowMap, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(self.glowMap)
			love.graphics.setShader(LOVE_LIGHT_BLURH)
			love.graphics.draw(self.glowMap2, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(LOVE_LIGHT_LAST_BUFFER)
			love.graphics.setShader()
			love.graphics.draw(self.glowMap, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setBlendMode("alpha")
		end
	end
end

function World:drawRefraction()
	if self.optionRefraction and self.isRefraction then
		LOVE_LIGHT_LAST_BUFFER = love.graphics.getCanvas()
		if LOVE_LIGHT_LAST_BUFFER then
			love.graphics.setColor(255, 255, 255)
			love.graphics.setBlendMode("alpha")
			love.graphics.setCanvas(self.refractionMap2)
			love.graphics.draw(LOVE_LIGHT_LAST_BUFFER, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(LOVE_LIGHT_LAST_BUFFER)
			self.refractionShader:send("backBuffer", self.refractionMap2)
			self.refractionShader:send("refractionStrength", self.refractionStrength)
			love.graphics.setShader(self.refractionShader)
			love.graphics.draw(self.refractionMap, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setShader()
		end
	end
end

function World:drawReflection()
	if self.optionReflection and self.isReflection then
		LOVE_LIGHT_LAST_BUFFER = love.graphics.getCanvas()
		if LOVE_LIGHT_LAST_BUFFER then
			love.graphics.setColor(255, 255, 255)
			love.graphics.setBlendMode("alpha")
			love.graphics.setCanvas(self.reflectionMap2)
			love.graphics.draw(LOVE_LIGHT_LAST_BUFFER, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setCanvas(LOVE_LIGHT_LAST_BUFFER)
			self.reflectionShader:send("backBuffer", self.reflectionMap2)
			self.reflectionShader:send("reflectionStrength", self.reflectionStrength)
			self.reflectionShader:send("reflectionVisibility", self.reflectionVisibility)
			love.graphics.setShader(self.reflectionShader)
			love.graphics.draw(self.reflectionMap, LOVE_LIGHT_TRANSLATE_X, LOVE_LIGHT_TRANSLATE_Y)
			love.graphics.setShader()
		end
	end
end

function World:newLight(x, y, red, green, blue, range)
	local Index = #self.lights + 1
	local Light = love.light.newLight(self, x, y, red, green, blue, range)
	self.lights[Index] = Light

	return Light
end

function World:newRoom(x, y, width, height, red, green, blue)
	return love.light.newRoom(self, x, y, width, height, red, green, blue)
end

function World:clearLights()
	self.lights = {}
	self.isLight = false
	self.changed = true
end

function World:clearBodies()
	self.body = {}
	self.changed = true
	self.isShadows = false
	self.isPixelShadows = false
	self.isGlow = false
	self.isRefraction = false
	self.isReflection = false
end

function World:setTranslation(translateX, translateY)
	LOVE_LIGHT_TRANSLATE_X = translateX
	LOVE_LIGHT_TRANSLATE_Y = translateY
end

function World:setAmbientColor(red, green, blue)
	self.ambient = {red, green, blue}
end

function World:setAmbientRed(red)
	self.ambient[1] = red
end

function World:setAmbientGreen(green)
	self.ambient[2] = green
end

function World:setAmbientBlue(blue)
	self.ambient[3] = blue
end

function World:setNormalInvert(invert)
	self.normalInvert = invert
end

function World:setBlur(blur)
	self.blur = blur
	self.changed = true
end

function World:setShadowBlur(blur)
	self.blur = blur
	self.changed = true
end

function World:setBuffer(buffer)
	if buffer == "render" then
		love.graphics.setCanvas(LOVE_LIGHT_LAST_BUFFER)
	else
		LOVE_LIGHT_LAST_BUFFER = love.graphics.getCanvas()
	end

	if buffer == "glow" then
		love.graphics.setCanvas(self.glowMap)
	end
end

function World:setGlowStrength(strength)
	self.glowBlur = strength
	self.changed = true
end

function World:setRefractionStrength(strength)
	self.refractionStrength = strength
end

function World:setReflectionStrength(strength)
	self.reflectionStrength = strength
end

function World:setReflectionVisibility(visibility)
	self.reflectionVisibility = visibility
end

function World:newRectangle(x, y, w, h)
	return love.light.newRectangle(self, x, y, w, h)
end

function World:newCircle(x, y, r)
	return love.light.newCircle(self, x, y, r)
end

function World:newPolygon(...)
	return love.light.newPolygon(self, ...)
end

function World:newImage(img, x, y, width, height, ox, oy)
	return love.light.newImage(self, img, x, y, width, height, ox, oy)
end

function World:newRefraction(normal, x, y)
	return love.light.newRefraction(self, normal, x, y)
end
 
 function World:newRefractionHeightMap(heightMap, x, y, strength)
	return love.light.newRefractionHeightMap(self, heightMap, x, y, strength)
end

function World:newReflection(normal, x, y)
	return love.light.newReflection(self, normal, x, y)
end

function World:newReflectionHeightMap(heightMap, x, y, strength)
	return love.light.newReflectionHeightMap(self, heightMap, x, y, strength)
end

function World:newBody(type, ...)
	return love.light.newBody(self, type, ...)
end

function World:setPoints(n, ...)
	self.body[n].data = {...}
end

function World:getBodyCount()
	return #self.body
end

function World:getPoints(n)
	if self.body[n].data then
		return unpack(self.body[n].data)
	end
end

function World:setLightPosition(n, x, y, z)
	local Light = self.lights[n]
	if Light then
		Light:setPosition(x, y, z)
	end
end

function World:setLightX(n, x)
	local Light = self.lights[n]
	if Light then
		Light:setX(x)
	end
end

function World:setLightY(n, y)
	local Light = self.lights[n]
	if Light then
		Light:setY(y)
	end
end

function World:setLightAngle(n, angle)
	local Light = self.lights[n]
	if Light then
		Light:setAngle(angle)
	end
end

function World:setLightDirection(n, direction)
	local Light = self.lights[n]
	if Light then
		Light:setDirection(direction)
	end
end

function World:getLightCount()
	return #self.lights
end

function World:getLightX(n)
	local Light = self.lights[n]
	if Light then
		return Light:getX()
	end
end

function World:getLightY(n)
	local Light = self.lights[n]
	if Light then
		return Light:getY()
	end
end

function World:getType()
	return "world"
end