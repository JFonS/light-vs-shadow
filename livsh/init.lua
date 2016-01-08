local Path = (...):gsub("%p", "/").."/"

LOVE_LIGHT_CURRENT = nil
LOVE_LIGHT_CIRCLE = nil
LOVE_LIGHT_POLY = nil
LOVE_LIGHT_IMAGE = nil
LOVE_LIGHT_BODY = nil
LOVE_LIGHT_LAST_BUFFER = nil
LOVE_LIGHT_SHADOW_GEOMETRY = nil

LOVE_LIGHT_BLURV = love.graphics.newShader(Path.."shader/blurv.glsl")
LOVE_LIGHT_BLURH = love.graphics.newShader(Path.."shader/blurh.glsl")
LOVE_LIGHT_BLURV:send("screen", {love.graphics.getWidth(), love.graphics.getHeight()})
LOVE_LIGHT_BLURH:send("screen", {love.graphics.getWidth(), love.graphics.getHeight()})

LOVE_LIGHT_TRANSLATE_X = 0
LOVE_LIGHT_TRANSLATE_Y = 0
LOVE_LIGHT_TRANSLATE_X_OLD = 0
LOVE_LIGHT_TRANSLATE_Y_OLD = 0
LOVE_LIGHT_DIRECTION = 0

love.light = {}

local RequirePath = ...

require(RequirePath..".light")
require(RequirePath..".postshader")

require(RequirePath..".world")
require(RequirePath..".body")
require(RequirePath..".room")

function love.light.newRectangle(p, x, y, width, height)
	return p:newBody("rectangle", x, y, width, height)
end

function love.light.newCircle(p, x, y, radius)
	return p:newBody("circle", x, y, radius)
end

function love.light.newPolygon(p, ...)
	return p:newBody("polygon", ...)
end

function love.light.newImage(p, img, x, y, width, height, ox, oy)
	return p:newBody("image", img, x, y, width, height, ox, oy)
end

function love.light.newRefraction(p, normal, x, y, width, height)
	return p:newBody("refraction", normal, x, y, width, height)
end

function love.light.newRefractionHeightMap(p, heightMap, x, y, strength)
	local normal = HeightMapToNormalMap(heightMap, strength)
	return love.light.newRefraction(p, normal, x, y)
end

function love.light.newReflection(p, normal, x, y, width, height)
	return p:newBody("reflection", normal, x, y, width, height)
end

function love.light.newReflectionHeightMap(p, heightMap, x, y, strength)
	local normal = HeightMapToNormalMap(heightMap, strength)
	return love.light.newReflection(p, normal, x, y)
end

function normalize(v)
	local len = math.sqrt(math.pow(v[1], 2) + math.pow(v[2], 2))
	local normalizedv = {v[1] / len, v[2] / len}
	return normalizedv
end

function dot(v1, v2)
	return v1[1] * v2[1] + v1[2] * v2[2]
end

function lengthSqr(v)
	return v[1] * v[1] + v[2] * v[2]
end

function length(v)
	return math.sqrt(lengthSqr(v))
end

function calculateShadows(light, body)
	local shadowGeometry = {}
	local shadowLength = 100000

	for i, Body in pairs(body) do
		if Body.shadowType == "rectangle" or Body.shadowType == "polygon" then
			curPolygon = Body.data
			if not Body.castsNoShadow then
				local edgeFacingTo = {}
				for k = 1, #curPolygon, 2 do
					local indexOfNextVertex = (k + 2) % #curPolygon
					local normal = {-curPolygon[indexOfNextVertex+1] + curPolygon[k + 1], curPolygon[indexOfNextVertex] - curPolygon[k]}
					local lightToPoint = {curPolygon[k] - light.x, curPolygon[k + 1] - light.y}

					normal = normalize(normal)
					lightToPoint = normalize(lightToPoint)

					local dotProduct = dot(normal, lightToPoint)
					if dotProduct > 0 then table.insert(edgeFacingTo, true)
					else table.insert(edgeFacingTo, false) end
				end

				local curShadowGeometry = {}
				for k = 1, #edgeFacingTo do
					local nextIndex = (k + 1) % #edgeFacingTo
					if nextIndex == 0 then nextIndex = #edgeFacingTo end
					if edgeFacingTo[k] and not edgeFacingTo[nextIndex] then
						curShadowGeometry[1] = curPolygon[nextIndex*2-1]
						curShadowGeometry[2] = curPolygon[nextIndex*2]

						local lightVecFrontBack = normalize({curPolygon[nextIndex*2-1] - light.x, curPolygon[nextIndex*2] - light.y})
						curShadowGeometry[3] = curShadowGeometry[1] + lightVecFrontBack[1] * shadowLength
						curShadowGeometry[4] = curShadowGeometry[2] + lightVecFrontBack[2] * shadowLength

					elseif not edgeFacingTo[k] and edgeFacingTo[nextIndex] then
						curShadowGeometry[7] = curPolygon[nextIndex*2-1]
						curShadowGeometry[8] = curPolygon[nextIndex*2]

						local lightVecBackFront = normalize({curPolygon[nextIndex*2-1] - light.x, curPolygon[nextIndex*2] - light.y})
						curShadowGeometry[5] = curShadowGeometry[7] + lightVecBackFront[1] * shadowLength
						curShadowGeometry[6] = curShadowGeometry[8] + lightVecBackFront[2] * shadowLength
					end
				end
				if  curShadowGeometry[1]
					and curShadowGeometry[2]
					and curShadowGeometry[3]
					and curShadowGeometry[4]
					and curShadowGeometry[5]
					and curShadowGeometry[6]
					and curShadowGeometry[7]
					and curShadowGeometry[8]
				then
					curShadowGeometry.alpha = Body.alpha
					curShadowGeometry.red = Body.red
					curShadowGeometry.green = Body.green
					curShadowGeometry.blue = Body.blue
					shadowGeometry[#shadowGeometry + 1] = curShadowGeometry
				end
			end
		elseif Body.shadowType == "circle" then
			if not Body.castsNoShadow then
				local length = math.sqrt(math.pow(light.x - (Body.x - Body.ox), 2) + math.pow(light.y - (Body.y - Body.oy), 2))
				if length >= Body.radius and length <= light.range then
					local curShadowGeometry = {}
					local angle = math.atan2(light.x - (Body.x - Body.ox), (Body.y - Body.oy) - light.y) + math.pi / 2
					local x2 = ((Body.x - Body.ox) + math.sin(angle) * Body.radius)
					local y2 = ((Body.y - Body.oy) - math.cos(angle) * Body.radius)
					local x3 = ((Body.x - Body.ox) - math.sin(angle) * Body.radius)
					local y3 = ((Body.y - Body.oy) + math.cos(angle) * Body.radius)

					curShadowGeometry[1] = x2
					curShadowGeometry[2] = y2
					curShadowGeometry[3] = x3
					curShadowGeometry[4] = y3

					curShadowGeometry[5] = x3 - (light.x - x3) * shadowLength
					curShadowGeometry[6] = y3 - (light.y - y3) * shadowLength
					curShadowGeometry[7] = x2 - (light.x - x2) * shadowLength
					curShadowGeometry[8] = y2 - (light.y - y2) * shadowLength
					curShadowGeometry.alpha = Body.alpha
					curShadowGeometry.red = Body.red
					curShadowGeometry.green = Body.green
					curShadowGeometry.blue = Body.blue
					shadowGeometry[#shadowGeometry + 1] = curShadowGeometry
				end
			end
		end
	end

	return shadowGeometry
end

function shadowStencil()
	for i, Shadow in pairs(LOVE_LIGHT_SHADOW_GEOMETRY) do
		if Shadow.alpha == 1.0 then
			love.graphics.polygon("fill", unpack(Shadow))
		end
	end
	for i, Body in pairs(LOVE_LIGHT_BODY) do
		if not Body.castsNoShadow then
			if Body.shadowType == "circle" then
				love.graphics.circle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.radius)
			elseif Body.shadowType == "rectangle" then
				love.graphics.rectangle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.width, Body.height)
			elseif Body.shadowType == "polygon" then
				love.graphics.polygon("fill", unpack(Body.data))
			elseif Body.shadowType == "image" then
				--love.graphics.rectangle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.width, Body.height)
				--love.graphics.draw(Body.img, Body.x - Body.ox, Body.y - Body.oy)
			end
		end
	end
end

function polyStencil()
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
--[[
	for i, Body in pairs(LOVE_LIGHT_BODY) do
		if Body.shine and (Body.glowStrength == 0.0 or (Body.type == "image" and not Body.normal)) then
			if Body.shadowType == "circle" then
				love.graphics.circle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.radius)
			elseif Body.shadowType == "rectangle" then
				love.graphics.rectangle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.width, Body.height)
			elseif Body.shadowType == "polygon" then
				love.graphics.polygon("fill", unpack(Body.data))
			elseif Body.shadowType == "image" then
				--love.graphics.rectangle("fill", Body.x - Body.ox, Body.y - Body.oy, Body.width, Body.height)
				love.graphics.draw(Body.msh, Body.x - Body.ox, Body.y - Body.oy)
			end
		end
	end
]]
end

function HeightMapToNormalMap(heightMap, strength)
	local imgData = heightMap:getData()
	local imgData2 = love.image.newImageData(heightMap:getWidth(), heightMap:getHeight())
	local red, green, blue, alpha
	local x, y
	local matrix = {}
	matrix[1] = {}
	matrix[2] = {}
	matrix[3] = {}
	strength = strength or 1.0

	for i = 0, heightMap:getHeight() - 1 do
		for k = 0, heightMap:getWidth() - 1 do
			for l = 1, 3 do
				for m = 1, 3 do
					if k + (l - 1) < 1 then
						x = heightMap:getWidth() - 1
					elseif k + (l - 1) > heightMap:getWidth() - 1 then
						x = 1
					else
						x = k + l - 1
					end

					if i + (m - 1) < 1 then
						y = heightMap:getHeight() - 1
					elseif i + (m - 1) > heightMap:getHeight() - 1 then
						y = 1
					else
						y = i + m - 1
					end

					local red, green, blue, alpha = imgData:getPixel(x, y)
					matrix[l][m] = red
				end
			end

			red = (255 + ((matrix[1][2] - matrix[2][2]) + (matrix[2][2] - matrix[3][2])) * strength) / 2.0
			green = (255 + ((matrix[2][2] - matrix[1][1]) + (matrix[2][3] - matrix[2][2])) * strength) / 2.0
			blue = 192

			imgData2:setPixel(k, i, red, green, blue)
		end
	end

	return love.graphics.newImage(imgData2)
end