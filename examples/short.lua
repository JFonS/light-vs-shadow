-- Example: Short Example
require "livsh"

function love.load()
	-- load images
	image = love.graphics.newImage("gfx/machine2.png")
	image_normal = love.graphics.newImage("gfx/cone_normal.png")
	normal = love.graphics.newImage("gfx/refraction_normal.png")
	glow = love.graphics.newImage("gfx/machine2_glow.png")

	-- create light world
	lightWorld = love.light.newWorld()
	--lightWorld:setTranslation(0, 32)
	lightWorld:setAmbientColor(60, 60, 60)
	lightWorld:setRefractionStrength(32.0)
	lightWorld.isPixelShadows = true
	
	function lightWorld:drawObjects()
		love.graphics.setColor(63, 255, 127)
		love.graphics.circle("fill", circleTest:getX() - lightWorld.translate.x, circleTest:getY() - lightWorld.translate.y, circleTest:getRadius())
		love.graphics.polygon("fill", rectangleTest:getVertices())
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(image, 64 - lightWorld.translate.x, 64 - lightWorld.translate.y)
	end

	-- create light
	lightMouse = lightWorld:newLight(0, 0, 255, 255, 255, 300)
	lightMouse:setGlowStrength(0.3)
	--lightMouse.setSmooth(0.01)

	-- create shadow bodys
	circleTest = lightWorld:newCircle(256, 256, 16)
	rectangleTest = lightWorld:newRectangle(512, 512, 64, 64)
	imageTest = lightWorld:newImage(image, 64, 64)
	imageTest:setNormalMap(image_normal)
	--imageTest:setGlowMap(glow)
	imageTest:setOffset(0, 0)
	imageTest:setShadowType("image")

	-- create body object
	--objectTest = lightWorld:newBody("refraction", normal, 64, 64, 128, 128)
	--objectTest:setShine(false)
	--objectTest:setShadowType("rectangle")
	--objectTest:setShadowDimension(64, 64)
	--objectTest:setReflection(true)

	-- set background
	quadScreen = love.graphics.newQuad(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), 32, 24)
	imgFloor = love.graphics.newImage("gfx/floor.png")
	imgFloor:setWrap("repeat", "repeat")
end

function love.update(dt)
	love.window.setTitle("Light vs. Shadow Engine (FPS:" .. love.timer.getFPS() .. ")")
	lightMouse:setPosition(love.mouse.getX(), love.mouse.getY(), 50)
end

function love.draw()
	-- update lightmap (doesn't need deltatime)
	lightWorld:update()

	love.postshader.setBuffer("render")

	-- draw background
	love.graphics.setColor(255, 255, 255)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
	--love.graphics.draw(imgFloor, quadScreen, 0, 0)

	-- draw lightmap shadows
	lightWorld:drawShadow()

	--love.graphics.rectangle("fill", 128 - 32, 128 - 32, 64, 64)

	-- draw lightmap shine
	lightWorld:drawShine()

	-- draw pixel shadow
	lightWorld:drawPixelShadow()

	-- draw glow
	lightWorld:drawGlow()

	-- draw refraction
	lightWorld:drawRefraction()

	-- draw reflection
	lightWorld:drawReflection()

	love.postshader.draw()
end
