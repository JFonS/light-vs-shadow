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

-- vector functions
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

	for i = 1, #body do
		if body[i].shadowType == "rectangle" or body[i].shadowType == "polygon" then
			curPolygon = body[i].data
			if not body[i].castsNoShadow then
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
					curShadowGeometry.alpha = body[i].alpha
					curShadowGeometry.red = body[i].red
					curShadowGeometry.green = body[i].green
					curShadowGeometry.blue = body[i].blue
					shadowGeometry[#shadowGeometry + 1] = curShadowGeometry
				end
			end
		elseif body[i].shadowType == "circle" then
			if not body[i].castsNoShadow then
				local length = math.sqrt(math.pow(light.x - (body[i].x - body[i].ox), 2) + math.pow(light.y - (body[i].y - body[i].oy), 2))
				if length >= body[i].radius and length <= light.range then
					local curShadowGeometry = {}
					local angle = math.atan2(light.x - (body[i].x - body[i].ox), (body[i].y - body[i].oy) - light.y) + math.pi / 2
					local x2 = ((body[i].x - body[i].ox) + math.sin(angle) * body[i].radius)
					local y2 = ((body[i].y - body[i].oy) - math.cos(angle) * body[i].radius)
					local x3 = ((body[i].x - body[i].ox) - math.sin(angle) * body[i].radius)
					local y3 = ((body[i].y - body[i].oy) + math.cos(angle) * body[i].radius)

					curShadowGeometry[1] = x2
					curShadowGeometry[2] = y2
					curShadowGeometry[3] = x3
					curShadowGeometry[4] = y3

					curShadowGeometry[5] = x3 - (light.x - x3) * shadowLength
					curShadowGeometry[6] = y3 - (light.y - y3) * shadowLength
					curShadowGeometry[7] = x2 - (light.x - x2) * shadowLength
					curShadowGeometry[8] = y2 - (light.y - y2) * shadowLength
					curShadowGeometry.alpha = body[i].alpha
					curShadowGeometry.red = body[i].red
					curShadowGeometry.green = body[i].green
					curShadowGeometry.blue = body[i].blue
					shadowGeometry[#shadowGeometry + 1] = curShadowGeometry
				end
			end
		end
	end

	return shadowGeometry
end

shadowStencil = function()
	for i = 1, #LOVE_LIGHT_SHADOW_GEOMETRY do
		if LOVE_LIGHT_SHADOW_GEOMETRY[i].alpha == 1.0 then
			love.graphics.polygon("fill", unpack(LOVE_LIGHT_SHADOW_GEOMETRY[i]))
		end
	end
	for i = 1, #LOVE_LIGHT_BODY do
		if not LOVE_LIGHT_BODY[i].castsNoShadow then
			if LOVE_LIGHT_BODY[i].shadowType == "circle" then
				love.graphics.circle("fill", LOVE_LIGHT_BODY[i].x - LOVE_LIGHT_BODY[i].ox, LOVE_LIGHT_BODY[i].y - LOVE_LIGHT_BODY[i].oy, LOVE_LIGHT_BODY[i].radius)
			elseif LOVE_LIGHT_BODY[i].shadowType == "rectangle" then
				love.graphics.rectangle("fill", LOVE_LIGHT_BODY[i].x - LOVE_LIGHT_BODY[i].ox, LOVE_LIGHT_BODY[i].y - LOVE_LIGHT_BODY[i].oy, LOVE_LIGHT_BODY[i].width, LOVE_LIGHT_BODY[i].height)
			elseif LOVE_LIGHT_BODY[i].shadowType == "polygon" then
				love.graphics.polygon("fill", unpack(LOVE_LIGHT_BODY[i].data))
			elseif LOVE_LIGHT_BODY[i].shadowType == "image" then
			--love.graphics.rectangle("fill", LOVE_LIGHT_BODY[i].x - LOVE_LIGHT_BODY[i].ox, LOVE_LIGHT_BODY[i].y - LOVE_LIGHT_BODY[i].oy, LOVE_LIGHT_BODY[i].width, LOVE_LIGHT_BODY[i].height)
			end
		end
	end
end

polyStencil = function()
	for i = 1, #LOVE_LIGHT_BODY do
		if LOVE_LIGHT_BODY[i].shine and (LOVE_LIGHT_BODY[i].glowStrength == 0.0 or (LOVE_LIGHT_BODY[i].type == "image" and not LOVE_LIGHT_BODY[i].normal)) then
			if LOVE_LIGHT_BODY[i].shadowType == "circle" then
				love.graphics.circle("fill", LOVE_LIGHT_BODY[i].x - LOVE_LIGHT_BODY[i].ox, LOVE_LIGHT_BODY[i].y - LOVE_LIGHT_BODY[i].oy, LOVE_LIGHT_BODY[i].radius)
			elseif LOVE_LIGHT_BODY[i].shadowType == "rectangle" then
				love.graphics.rectangle("fill", LOVE_LIGHT_BODY[i].x - LOVE_LIGHT_BODY[i].ox, LOVE_LIGHT_BODY[i].y - LOVE_LIGHT_BODY[i].oy, LOVE_LIGHT_BODY[i].width, LOVE_LIGHT_BODY[i].height)
			elseif LOVE_LIGHT_BODY[i].shadowType == "polygon" then
				love.graphics.polygon("fill", unpack(LOVE_LIGHT_BODY[i].data))
			elseif LOVE_LIGHT_BODY[i].shadowType == "image" then
			--love.graphics.rectangle("fill", LOVE_LIGHT_BODY[i].x - LOVE_LIGHT_BODY[i].ox, LOVE_LIGHT_BODY[i].y - LOVE_LIGHT_BODY[i].oy, LOVE_LIGHT_BODY[i].width, LOVE_LIGHT_BODY[i].height)
			end
		end
	end
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