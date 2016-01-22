local function normalize(v)
	local len = math.sqrt(math.pow(v[1], 2) + math.pow(v[2], 2))
	local normalizedv = {v[1] / len, v[2] / len}
	return normalizedv
end

local function dot(v1, v2)
	return v1[1] * v2[1] + v1[2] * v2[2]
end

local function lengthSqr(v)
	return v[1] ^ 2 + v[2] ^ 2
end

local function length(v)
	return math.sqrt(lengthSqr(v))
end

function love.light.calculateShadows(light, body)
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

					table.insert(edgeFacingTo, dot(normal, lightToPoint) > 0)
				end

				local curShadowGeometry =  {}
				for k = 1, #edgeFacingTo do
					local prevIndex = k - 1
					if prevIndex <= 0 then
						prevIndex = #edgeFacingTo + prevIndex
					end
					
					local nextIndex = (k + 1) % #edgeFacingTo
					if nextIndex == 0 then
						nextIndex = #edgeFacingTo
					end

					if not edgeFacingTo[prevIndex] then
						local Length = shadowLength
						if Body.z and light.z and light.z > Body.z then
							Length = Body.z / math.atan2(math.sqrt(math.pow(light.x - curPolygon[k*2-1], 2) + math.pow(light.y - curPolygon[k*2], 2)), light.z)
						end
						
						local lightVecBackFront = normalize({curPolygon[k*2-1] - light.x, curPolygon[k*2] - light.y})
						table.insert(curShadowGeometry, curPolygon[k*2-1] + lightVecBackFront[1] * Length)
						table.insert(curShadowGeometry, curPolygon[k*2] + lightVecBackFront[2] * Length)
					end

					if edgeFacingTo[k] then
						table.insert(curShadowGeometry, curPolygon[k*2-1])
						table.insert(curShadowGeometry, curPolygon[k*2])
					end
					
					if not edgeFacingTo[nextIndex] then
						if edgeFacingTo[k] then
							table.insert(curShadowGeometry, curPolygon[nextIndex*2-1])
							table.insert(curShadowGeometry, curPolygon[nextIndex*2])
						end
						
						local Length = shadowLength
						if Body.z and light.z and light.z > Body.z then
							Length = Body.z / math.atan2(math.sqrt(math.pow(light.x - curPolygon[nextIndex*2-1], 2) + math.pow(light.y - curPolygon[nextIndex*2], 2)), light.z)
						end
						
						local lightVecBackFront = normalize({curPolygon[nextIndex*2-1] - light.x, curPolygon[nextIndex*2] - light.y})
						table.insert(curShadowGeometry, curPolygon[nextIndex*2-1] + lightVecBackFront[1] * Length)
						table.insert(curShadowGeometry, curPolygon[nextIndex*2] + lightVecBackFront[2] * Length)
					end
				end

				curShadowGeometry.alpha = Body.alpha
				curShadowGeometry.red = Body.red
				curShadowGeometry.green = Body.green
				curShadowGeometry.blue = Body.blue
				shadowGeometry[#shadowGeometry + 1] = curShadowGeometry
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
					local L2 = math.sqrt(x2^2 + y2^2)
					local L3 = math.sqrt(x3^3 + y3^3)
					
					local Length = shadowLength
					local h = Body.z or 16
					if light.z and light.z > h then
						Length = h / math.atan2(length, light.z)
					end

					curShadowGeometry[1] = x2
					curShadowGeometry[2] = y2
					curShadowGeometry[3] = x3
					curShadowGeometry[4] = y3

					curShadowGeometry[5] = x3 - (light.x - x3) * Length
					curShadowGeometry[6] = y3 - (light.y - y3) * Length
					curShadowGeometry[7] = x2 - (light.x - x2) * Length
					curShadowGeometry[8] = y2 - (light.y - y2) * Length
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

function love.light.HeightMapToNormalMap(heightMap, strength)
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