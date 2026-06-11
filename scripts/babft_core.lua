
if game.PlaceId ~= 537413528 then
    warn("BABFT: script only works in Build A Boat For Treasure")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local httprequest = request or syn_request or http_request
if not httprequest and syn and syn.request then
    httprequest = syn.request
end

-- Папка для локальных картинок
pcall(function()
    if not isfolder("BABFT") then makefolder("BABFT") end
    if not isfolder("BABFT/Image") then makefolder("BABFT/Image") end
    if not isfolder("BABFT/Models") then makefolder("BABFT/Models") end
end)

local function httpGet(url)
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        ["Accept"] = "image/png,image/*,*/*",
    }
    if url:find("discordapp%.com", 1, true) or url:find("discord%.com", 1, true) then
        headers["Referer"] = "https://discord.com/"
    end

    if httprequest then
        local ok, res = pcall(function()
            return httprequest({Url = url, Method = "GET", Headers = headers})
        end)
        if ok and res and res.Body and #res.Body > 0 and (not res.StatusCode or res.StatusCode == 200) then
            return res.Body
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and body and #body > 0 then return body end
    ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body and #body > 0 then return body end
    return nil
end

local function normalizeImageUrl(url)
    url = (url or ""):gsub("^%s+", ""):gsub("%s+$", "")
    url = url:gsub("&+$", ""):gsub("/+$", "")
    if url == "" then
        return nil, "Вставь полную ссылку на .png"
    end
    if not url:find("://", 1, true) then
        if url:match("^[%x]+$") and #url >= 20 then
            return nil, "Это хеш, не ссылка. Нужен URL: https://i.imgur.com/xxx.png"
        end
        url = "https://" .. url
    end
    if url:find("imgur%.com/") and not url:find("%.png", 1, true) and not url:find("%.jpg", 1, true) then
        url = url:gsub("%?.*$", ""):gsub("/+$", "") .. ".png"
    end
    return url
end

local function isHtmlResponse(body)
    if type(body) ~= "string" or #body < 16 then return false end
    local head = body:sub(1, 256):lower()
    return head:find("<!doctype", 1, true) ~= nil or head:find("<html", 1, true) ~= nil
end

local function defaultNotify(opts)
    opts = opts or {}
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(opts.Title or "BABFT"),
            Text = tostring(opts.Content or ""),
            Duration = math.floor(opts.Duration or 5),
        })
    end)
end

local notifyImpl = defaultNotify
local function Notify(opts)
    notifyImpl(opts)
end

-- Shared bridge with WindUI loader (loader.lua)
_G.BABFT = _G.BABFT or {}
local BABFTBridge = _G.BABFT

-- PNG декодер встроен в скрипт (без скачивания)
local pngCache = {}

local EMBEDDED_BABFT_PNG = [=====[
-- Встроенный PNG декодер (offline)
local bitlib = bit32 or bit
if not bitlib then
    error("BabftPNG: нужен bit32 или bit")
end
local unpackFn = unpack or table.unpack

local function makeModuleEnv(requireFn, extra)
    local env = {
        require = requireFn,
        bit32 = bitlib,
        unpack = unpackFn,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        table = table,
        math = math,
        string = string,
        ipairs = ipairs,
        pairs = pairs,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        error = error,
        assert = assert,
        select = select,
        pcall = pcall,
        rawget = rawget,
        rawset = rawset,
        next = next,
        Color3 = Color3,
    }
    if extra then
        for k, v in pairs(extra) do
            env[k] = v
        end
    end
    return setmetatable(env, { __index = _G })
end

local SOURCES = {
    ["Modules/BinaryReader"] = [===[
local BinaryReader = {}
BinaryReader.__index = BinaryReader

function BinaryReader.new(buffer)
	local reader = 
	{
		Position = 1;
		Buffer = buffer;
		Length = #buffer;
	}
	
	return setmetatable(reader, BinaryReader)
end

function BinaryReader:ReadByte()
	local buffer = self.Buffer
	local pos = self.Position
	
	if pos <= self.Length then
		local result = buffer:sub(pos, pos)
		self.Position = pos + 1
		
		return result:byte()
	end
end

function BinaryReader:ReadBytes(count, asArray)
	local values = {}
	
	for i = 1, count do
		values[i] = self:ReadByte()
	end
	
	if asArray then
		return values
	end
	
	if count == 0 then
		return
	elseif count == 1 then
		return values[1]
	elseif count == 2 then
		return values[1], values[2]
	end
	return unpack(values)
end

function BinaryReader:ReadAllBytes()
	return self:ReadBytes(self.Length, true)
end

function BinaryReader:IterateBytes()
	return function ()
		return self:ReadByte()
	end
end

function BinaryReader:TwosComplementOf(value, numBits)
	if value >= (2 ^ (numBits - 1)) then
		value = value - (2 ^ numBits)
	end
	
	return value
end

function BinaryReader:ReadUInt16()
	local upper, lower = self:ReadBytes(2)
	return (upper * 256) + lower
end

function BinaryReader:ReadInt16()
	local unsigned = self:ReadUInt16()
	return self:TwosComplementOf(unsigned, 16)
end

function BinaryReader:ReadUInt32()
	local upper = self:ReadUInt16()
	local lower = self:ReadUInt16()
	
	return (upper * 65536) + lower
end

function BinaryReader:ReadInt32()
	local unsigned = self:ReadUInt32()
	return self:TwosComplementOf(unsigned, 32)
end

function BinaryReader:ReadString(length)
    if length == nil then
        length = self:ReadByte()
    end
    
    local pos = self.Position
    local nextPos = math.min(self.Length, pos + length)
    
    local result = self.Buffer:sub(pos, nextPos - 1)
    self.Position = nextPos
    
    return result
end

function BinaryReader:ForkReader(length)
	local chunk = self:ReadString(length)
	return BinaryReader.new(chunk)
end

return BinaryReader
]===],
    ["Modules/Deflate"] = [===[
--[[

LUA MODULE

compress.deflatelua - deflate (and zlib) implemented in Lua.

DESCRIPTION

This is a pure Lua implementation of decompressing the DEFLATE format,
including the related zlib format.

Note: This library only supports decompression.
Compression is not currently implemented.

REFERENCES

[1] DEFLATE Compressed Data Format Specification version 1.3
http://tools.ietf.org/html/rfc1951
[2] GZIP file format specification version 4.3
http://tools.ietf.org/html/rfc1952
[3] http://en.wikipedia.org/wiki/DEFLATE
[4] pyflate, by Paul Sladen
http://www.paul.sladen.org/projects/pyflate/
[5] Compress::Zlib::Perl - partial pure Perl implementation of
Compress::Zlib
http://search.cpan.org/~nwclark/Compress-Zlib-Perl/Perl.pm

LICENSE

(c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).
    Heavily modified by Max G. (2019)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
(end license)
--]]

local Deflate = {}

local band = bit32.band
local lshift = bit32.lshift
local rshift = bit32.rshift

local BTYPE_NO_COMPRESSION = 0
local BTYPE_FIXED_HUFFMAN = 1
local BTYPE_DYNAMIC_HUFFMAN = 2

local lens = -- Size base for length codes 257..285
{
	[0] = 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
	35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
}

local lext = -- Extra bits for length codes 257..285
{
	[0] = 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
	3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
}

local dists = -- Offset base for distance codes 0..29
{
	[0] = 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
	257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
	8193, 12289, 16385, 24577
}

local dext = -- Extra bits for distance codes 0..29
{
	[0] = 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
	7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
	12, 12, 13, 13
}

local order = -- Permutation of code length codes
{
	16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 
	11, 4, 12, 3, 13, 2, 14, 1, 15
}

-- Fixed literal table for BTYPE_FIXED_HUFFMAN
local fixedLit = {0, 8, 144, 9, 256, 7, 280, 8, 288}

 -- Fixed distance table for BTYPE_FIXED_HUFFMAN
local fixedDist = {0, 5, 32}

local function createState(bitStream)
	local state = 
	{
		Output = bitStream;
		Window = {};
		Pos = 1;
	}
	
	return state
end

local function write(state, byte)
	local pos = state.Pos
	state.Output(byte)
	state.Window[pos] = byte
	state.Pos = pos % 32768 + 1  -- 32K
end

local pow2Cache = {}
local function pow2(n)
	local v = pow2Cache[n]
	if not v then
		v = 2 ^ n
		pow2Cache[n] = v
	end
	return v
end

local isBitStream = {}

local function createBitStream(reader)
	local buffer = 0
	local bitsLeft = 0
	
	local stream = {}
	isBitStream[stream] = true
	
	function stream:GetBitsLeft()
		return bitsLeft
	end
	
	function stream:Read(count)
		count = count or 1
		
		while bitsLeft < count do
			local byte = reader:ReadByte()
			
			if not byte then 
				return 
			end
			
			buffer = buffer + lshift(byte, bitsLeft)
			bitsLeft = bitsLeft + 8
		end
		
		local bits
		
		if count == 0 then
			bits = 0
		elseif count == 32 then
			bits = buffer
			buffer = 0
		else
			bits = band(buffer, rshift(2^32 - 1, 32 - count))
			buffer = rshift(buffer, count)
		end
		
		bitsLeft = bitsLeft - count
		return bits
	end
	
	return stream
end

local function getBitStream(obj)
	if isBitStream[obj] then
		return obj
	end
	
	return createBitStream(obj)
end

local function sortHuffman(a, b)
	return a.NumBits == b.NumBits and a.Value < b.Value or a.NumBits < b.NumBits
end

local function msb(bits, numBits)
	local res = 0
		
	for i = 1, numBits do
		res = lshift(res, 1) + band(bits, 1)
		bits = rshift(bits, 1)
	end
		
	return res
end

local function createHuffmanTable(init, isFull)
	local hTable = {}
	
	if isFull then
		for val, numBits in pairs(init) do
			if numBits ~= 0 then
				hTable[#hTable + 1] = 
				{
					Value = val;
					NumBits = numBits;
				}
			end
		end
	else
		for i = 1, #init - 2, 2 do
			local firstVal = init[i]
			
			local numBits = init[i + 1]
			local nextVal = init[i + 2]
			
			if numBits ~= 0 then
				for val = firstVal, nextVal - 1 do
					hTable[#hTable + 1] = 
					{
						Value = val;
						NumBits = numBits;
					}
				end
			end
		end
	end
	
	table.sort(hTable, sortHuffman)
	
	local code = 1
	local numBits = 0
	
	for i, slide in ipairs(hTable) do
		if slide.NumBits ~= numBits then
			code = code * pow2(slide.NumBits - numBits)
			numBits = slide.NumBits
		end
		
		slide.Code = code
		code = code + 1
	end
	
	local minBits = math.huge
	local look = {}
	
	for i, slide in ipairs(hTable) do
		minBits = math.min(minBits, slide.NumBits)
		look[slide.Code] = slide.Value
	end

	local firstCodeCache = {}
	local function firstCode(bits)
		local v = firstCodeCache[bits]
		if not v then
			v = pow2(minBits) + msb(bits, minBits)
			firstCodeCache[bits] = v
		end
		return v
	end
	
	function hTable:Read(bitStream)
		local code = 1 -- leading 1 marker
		local numBits = 0
		
		while true do
			if numBits == 0 then  -- small optimization (optional)
				local index = bitStream:Read(minBits)
				numBits = numBits + minBits
				code = firstCode(index)
			else
				local bit = bitStream:Read()
				numBits = numBits + 1
				code = code * 2 + bit -- MSB first
			end
			
			local val = look[code]
			
			if val then
				return val
			end
		end
	end
	
	return hTable
end

local function parseZlibHeader(bitStream)
	-- Compression Method
	local cm = bitStream:Read(4)
	
	-- Compression info
	local cinfo = bitStream:Read(4)  
	
	-- FLaGs: FCHECK (check bits for CMF and FLG)   
	local fcheck = bitStream:Read(5)
	
	-- FLaGs: FDICT (present dictionary)
	local fdict = bitStream:Read(1)
	
	-- FLaGs: FLEVEL (compression level)
	local flevel = bitStream:Read(2)
	
	-- CMF (Compresion Method and flags)
	local cmf = cinfo * 16  + cm
	
	-- FLaGs
	local flg = fcheck + fdict * 32 + flevel * 64 
	
	if cm ~= 8 then -- not "deflate"
		error("unrecognized zlib compression method: " .. cm)
	end
	
	if cinfo > 7 then
		error("invalid zlib window size: cinfo=" .. cinfo)
	end
	
	local windowSize = 2 ^ (cinfo + 8)
	
	if (cmf * 256 + flg) % 31 ~= 0 then
		error("invalid zlib header (bad fcheck sum)")
	end
	
	if fdict == 1 then
		error("FIX:TODO - FDICT not currently implemented")
	end
	
	return windowSize
end

local function parseHuffmanTables(bitStream)
	local numLits  = bitStream:Read(5) -- # of literal/length codes - 257
	local numDists = bitStream:Read(5) -- # of distance codes - 1
	local numCodes = bitStream:Read(4) -- # of code length codes - 4
	
	local codeLens = {}
	
	for i = 1, numCodes + 4 do
		local index = order[i]
		codeLens[index] = bitStream:Read(3)
	end
	
	codeLens = createHuffmanTable(codeLens, true)

	local function decode(numCodes)
		local init = {}
		local numBits
		local val = 0
		
		while val < numCodes do
			local codeLen = codeLens:Read(bitStream)
			local numRepeats
			
			if codeLen <= 15 then
				numRepeats = 1
				numBits = codeLen
			elseif codeLen == 16 then
				numRepeats = 3 + bitStream:Read(2)
			elseif codeLen == 17 then
				numRepeats = 3 + bitStream:Read(3)
				numBits = 0
			elseif codeLen == 18 then
				numRepeats = 11 + bitStream:Read(7)
				numBits = 0
			end
			
			for i = 1, numRepeats do
				init[val] = numBits
				val = val + 1
			end
		end
		
		return createHuffmanTable(init, true)
	end

	local numLitCodes = numLits + 257
	local numDistCodes = numDists + 1
	
	local litTable = decode(numLitCodes)
	local distTable = decode(numDistCodes)
	
	return litTable, distTable
end

local function parseCompressedItem(bitStream, state, litTable, distTable)
	local val = litTable:Read(bitStream)
	
	if val < 256 then -- literal
		write(state, val)
	elseif val == 256 then -- end of block
		return true
	else
		local lenBase = lens[val - 257]
		local numExtraBits = lext[val - 257]
		
		local extraBits = bitStream:Read(numExtraBits)
		local len = lenBase + extraBits
		
		local distVal = distTable:Read(bitStream)
		local distBase = dists[distVal]
		
		local distNumExtraBits = dext[distVal]
		local distExtraBits = bitStream:Read(distNumExtraBits)
		
		local dist = distBase + distExtraBits
		
		for i = 1, len do
			local pos = (state.Pos - 1 - dist) % 32768 + 1
			local byte = assert(state.Window[pos], "invalid distance")
			write(state, byte)
		end
	end
	
	return false
end

local function parseBlock(bitStream, state)
	local bFinal = bitStream:Read(1)
	local bType = bitStream:Read(2)
	
	if bType == BTYPE_NO_COMPRESSION then
		local left = bitStream:GetBitsLeft()
		bitStream:Read(left)
		
		local len = bitStream:Read(16)
		local nlen = bitStream:Read(16)

		for i = 1, len do
			local byte = bitStream:Read(8)
			write(state, byte)
		end
	elseif bType == BTYPE_FIXED_HUFFMAN or bType == BTYPE_DYNAMIC_HUFFMAN then
		local litTable, distTable

		if bType == BTYPE_DYNAMIC_HUFFMAN then
			litTable, distTable = parseHuffmanTables(bitStream)
		else
			litTable = createHuffmanTable(fixedLit)
			distTable = createHuffmanTable(fixedDist)
		end
		
		repeat until parseCompressedItem(bitStream, state, litTable, distTable)
	else
		error("unrecognized compression type")
	end

	return bFinal ~= 0
end

function Deflate:Inflate(io)
	local state = createState(io.Output)
	local bitStream = getBitStream(io.Input)
	
	repeat until parseBlock(bitStream, state)
end

function Deflate:InflateZlib(io)
	local bitStream = getBitStream(io.Input)
	local windowSize = parseZlibHeader(bitStream)
	
	self:Inflate
	{
		Input = bitStream;
		Output = io.Output;
	}
	
	local bitsLeft = bitStream:GetBitsLeft()
	bitStream:Read(bitsLeft)
end

return Deflate
]===],
    ["Modules/Unfilter"] = [===[
local Unfilter = {}

function Unfilter:None(scanline, pixels, bpp, row)
	for i = 1, #scanline do
		pixels[row][i] = scanline[i]
	end
end

function Unfilter:Sub(scanline, pixels, bpp, row)
	for i = 1, bpp do
		pixels[row][i] = scanline[i]
	end
	
	for i = bpp + 1, #scanline do
		local x = scanline[i]
		local a = pixels[row][i - bpp]
		pixels[row][i] = bit32.band(x + a, 0xFF)
	end
end

function Unfilter:Up(scanline, pixels, bpp, row)
	if row > 1 then
		local upperRow = pixels[row - 1]
		
		for i = 1, #scanline do
			local x = scanline[i]
			local b = upperRow[i]
			pixels[row][i] = bit32.band(x + b, 0xFF)
		end
	else
		self:None(scanline, pixels, bpp, row)
	end
end

function Unfilter:Average(scanline, pixels, bpp, row)
	if row > 1 then
		for i = 1, bpp do
			local x = scanline[i]
			local b = pixels[row - 1][i]
			
			b = bit32.rshift(b, 1)
			pixels[row][i] = bit32.band(x + b, 0xFF)
		end
		
		for i = bpp + 1, #scanline do
			local x = scanline[i]
			local b = pixels[row - 1][i]
			
			local a = pixels[row][i - bpp]
			local ab = bit32.rshift(a + b, 1)
			
			pixels[row][i] = bit32.band(x + ab, 0xFF)
		end
	else
		for i = 1, bpp do
			pixels[row][i] = scanline[i]
		end
	
		for i = bpp + 1, #scanline do
			local x = scanline[i]
			local b = pixels[row - 1][i]
			
			b = bit32.rshift(b, 1)
			pixels[row][i] = bit32.band(x + b, 0xFF)
		end
	end
end

function Unfilter:Paeth(scanline, pixels, bpp, row)
	if row > 1 then
		local pr
		
		for i = 1, bpp do
			local x = scanline[i]
			local b = pixels[row - 1][i]
			pixels[row][i] = bit32.band(x + b, 0xFF)
		end
		
		for i = bpp + 1, #scanline do
			local a = pixels[row][i - bpp]
			local b = pixels[row - 1][i]
			local c = pixels[row - 1][i - bpp]
			
			local x = scanline[i]
			local p = a + b - c
			
			local pa = math.abs(p - a)
			local pb = math.abs(p - b)
			local pc = math.abs(p - c)
			
			if pa <= pb and pa <= pc then
				pr = a
			elseif pb <= pc then
				pr = b
			else
				pr = c
			end
			
			pixels[row][i] = bit32.band(x + pr, 0xFF)
		end
	else
		self:Sub(scanline, pixels, bpp, row)
	end
end

return Unfilter
]===],
    ["Chunks/IDAT"] = [===[
local function IDAT(file, chunk)
	local crc = chunk.CRC
	local hash = file.Hash or 0
	
	local data = chunk.Data
	local buffer = data.Buffer
	
	file.Hash = bit32.bxor(hash, crc)
	file.ZlibStream = file.ZlibStream .. buffer
end

return IDAT
]===],
    ["Chunks/IEND"] = [===[
local function IEND(file)
	file.Reading = false
end

return IEND
]===],
    ["Chunks/IHDR"] = [===[
local function IHDR(file, chunk)
	local data = chunk.Data
	
	file.Width = data:ReadInt32();
	file.Height = data:ReadInt32();
	
	file.BitDepth = data:ReadByte();
	file.ColorType = data:ReadByte();
	
	file.Methods =
	{
		Compression = data:ReadByte();
		Filtering   = data:ReadByte();
		Interlace   = data:ReadByte();
	}
end

return IHDR
]===],
    ["Chunks/PLTE"] = [===[
local function PLTE(file, chunk)
	if not file.Palette then
		file.Palette = {}
	end
	
	local data = chunk.Data
	local palette = data:ReadAllBytes()
	
	if #palette % 3 ~= 0 then
		error("PNG - Invalid PLTE chunk.")
	end
	
	for i = 1, #palette, 3 do
		local r = palette[i]
		local g = palette[i + 1]
		local b = palette[i + 2]
		
		local index = #file.Palette + 1
		file.Palette[index] = {r, g, b}
	end
end

return PLTE
]===],
    ["Chunks/tRNS"] = [===[
local function tRNS(file, chunk)
	local data = chunk.Data
	
	local bitDepth = file.BitDepth
	local colorType = file.ColorType
	
	bitDepth = (2 ^ bitDepth) - 1
	
	if colorType == 3 then
		local palette = file.Palette
		local alphaMap = {}
		
		for i = 1, #palette do
			local alpha = data:ReadByte()
			
			if not alpha then
				alpha = 255
			end
			
			alphaMap[i] = alpha
		end
		
		file.AlphaData = alphaMap
	elseif colorType == 0 then
		local grayAlpha = data:ReadUInt16()
		file.Alpha = grayAlpha / bitDepth
	elseif colorType == 2 then
		-- TODO: This seems incorrect...
		local r = data:ReadUInt16() / bitDepth
		local g = data:ReadUInt16() / bitDepth
		local b = data:ReadUInt16() / bitDepth
		file.Alpha = Color3.new(r, g, b)
	else
		error("PNG - Invalid tRNS chunk")
	end	
end

return tRNS
]===],
    ["Chunks/sRGB"] = [===[
local function sRGB(file, chunk)
	file.RenderingIntent = chunk.Data:ReadByte()
end
return sRGB
]===],
    ["Chunks/gAMA"] = [===[
local function gAMA(file, chunk)
	file.Gamma = chunk.Data:ReadUInt32() / 100000
end
return gAMA
]===],
    ["Chunks/bKGD"] = [===[
local function bKGD(file, chunk)
	local data = chunk.Data
	local colorType = file.ColorType
	if colorType == 0 or colorType == 4 then
		file.BackgroundColor = data:ReadUInt16()
	elseif colorType == 2 or colorType == 6 then
		file.BackgroundColor = {
			data:ReadUInt16(),
			data:ReadUInt16(),
			data:ReadUInt16(),
		}
	elseif colorType == 3 then
		file.BackgroundColor = data:ReadByte()
	end
end
return bKGD
]===],
    ["Chunks/tEXt"] = [===[
local function tEXt(file)
	if not file.Metadata then file.Metadata = {} end
end
return tEXt
]===],
    ["Chunks/tIME"] = [===[
local function tIME(file, chunk)
	local data = chunk.Data
	file.ModificationTime = {
		Year = data:ReadUInt16(),
		Month = data:ReadByte(),
		Day = data:ReadByte(),
		Hour = data:ReadByte(),
		Minute = data:ReadByte(),
		Second = data:ReadByte(),
	}
end
return tIME
]===],
    ["Chunks/cHRM"] = [===[
local function cHRM(file, chunk)
	local data = chunk.Data
	file.Chromaticity = {
		WhiteX = data:ReadUInt32(),
		WhiteY = data:ReadUInt32(),
		RedX = data:ReadUInt32(),
		RedY = data:ReadUInt32(),
		GreenX = data:ReadUInt32(),
		GreenY = data:ReadUInt32(),
		BlueX = data:ReadUInt32(),
		BlueY = data:ReadUInt32(),
	}
end
return cHRM
]===],
    ["init"] = [===[
---------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2019
---------------------------------------------------------------------------------------------
-- [PNG Library]
--
--  A module for opening PNG files into a readable bitmap.
--  This implementation works with most PNG files.
--
---------------------------------------------------------------------------------------------

local PNG = {}
PNG.__index = PNG

local chunks = script.Chunks
local modules = script.Modules

local Deflate = require(modules.Deflate)
local Unfilter = require(modules.Unfilter)
local BinaryReader = require(modules.BinaryReader)

local function getBytesPerPixel(colorType)
	if colorType == 0 or colorType == 3 then
		return 1
	elseif colorType == 4 then
		return 2
	elseif colorType == 2 then
		return 3
	elseif colorType == 6 then
		return 4
	else
		return 0
	end
end

local function clampInt(value, min, max)
	local num = tonumber(value) or 0
	num = math.floor(num + .5)
	
	return math.clamp(num, min, max)
end

local function indexBitmap(file, x, y)
	local width = file.Width
	local height = file.Height
	
	local x = clampInt(x, 1, width) 
	local y = clampInt(y, 1, height)
	
	local bitmap = file.Bitmap
	local bpp = file.BytesPerPixel
	
	local i0 = ((x - 1) * bpp) + 1
	local i1 = i0 + bpp
	
	return bitmap[y], i0, i1
end

function PNG:GetPixel(x, y)
	local row, i0, i1 = indexBitmap(self, x, y)
	local colorType = self.ColorType
	
	local color, alpha do
		if colorType == 0 then
			local gray = unpack(row, i0, i1)
			color = Color3.fromHSV(0, 0, gray)
			alpha = 255
		elseif colorType == 2 then
			local r, g, b = unpack(row, i0, i1)
			color = Color3.fromRGB(r, g, b)
			alpha = 255
		elseif colorType == 3 then
			local palette = self.Palette
			local alphaData = self.AlphaData
			
			local index = unpack(row, i0, i1)
			index = index + 1
			
			if palette then
				local entry = palette[index]
				if entry then
					if type(entry) == "table" then
						color = Color3.fromRGB(entry[1], entry[2], entry[3])
					else
						color = entry
					end
				end
			end
			
			if alphaData then
				alpha = alphaData[index]
			end
		elseif colorType == 4 then
			local gray, a = unpack(row, i0, i1)
			color = Color3.fromHSV(0, 0, gray)
			alpha = a
		elseif colorType == 6 then
			local r, g, b, a = unpack(row, i0, i1)
			color = Color3.fromRGB(r, g, b, a)
			alpha = a
		end
	end
	
	if not color then
		color = Color3.new()
	end
	
	if not alpha then
		alpha = 255
	end
	
	return color, alpha
end

function PNG.new(buffer)
	-- Create the reader.
	local reader = BinaryReader.new(buffer)
	
	-- Create the file object.
	local file =
	{
		Chunks = {};
		Metadata = {};
		
		Reading = true;
		ZlibStream = "";
	}
	
	-- Verify the file header.
	local header = reader:ReadString(8)
	
	if header ~= string.char(137) .. "PNG\r\n\26\n" then
		error("PNG - Input data is not a PNG file.", 2)
	end
	
	while file.Reading do
		local length = reader:ReadInt32()
		local chunkType = reader:ReadString(4)
		
		local data, crc
		
		if length > 0 then
			data = reader:ForkReader(length)
			crc = reader:ReadUInt32()
		end
		
		local chunk = 
		{
			Length = length;
			Type = chunkType;
			
			Data = data;
			CRC = crc;
		}
		
		local handler = chunks:FindFirstChild(chunkType)
		
		if handler then
			handler = require(handler)
			handler(file, chunk)
		end
		
		table.insert(file.Chunks, chunk)
	end
	
	-- Decompress the zlib stream.
	local success, response = pcall(function ()
		local result = {}
		local index = 0
		
		Deflate:InflateZlib
		{
			Input = BinaryReader.new(file.ZlibStream);
			
			Output = function (byte)
				index = index + 1
				result[index] = string.char(byte)
			end
		}
		
		return table.concat(result)
	end)
	
	if not success then
		error("PNG - Unable to unpack PNG data. " .. tostring(response), 2)
	end
	
	-- Grab expected info from the file.
	
	local width = file.Width
	local height = file.Height
	
	local bitDepth = file.BitDepth
	local colorType = file.ColorType
	
	local buffer = BinaryReader.new(response)
	file.ZlibStream = nil
	
	local bitmap = {}
	file.Bitmap = bitmap
	
	local channels = getBytesPerPixel(colorType)
	file.NumChannels = channels
	
	local bpp = math.max(1, channels * (bitDepth / 8))
	file.BytesPerPixel = bpp
	
	-- Unfilter the buffer and 
	-- load it into the bitmap.
	
	for row = 1, height do	
		local filterType = buffer:ReadByte()
		local scanline = buffer:ReadBytes(width * bpp, true)
		
		bitmap[row] = {}
		
		if filterType == 0 then
			-- None
			Unfilter:None(scanline, bitmap, bpp, row)
		elseif filterType == 1 then
			-- Sub
			Unfilter:Sub(scanline, bitmap, bpp, row)
		elseif filterType == 2 then
			-- Up
			Unfilter:Up(scanline, bitmap, bpp, row)
		elseif filterType == 3 then
			-- Average
			Unfilter:Average(scanline, bitmap, bpp, row)
		elseif filterType == 4 then
			-- Paeth
			Unfilter:Paeth(scanline, bitmap, bpp, row)
		end
	end
	
	return setmetatable(file, PNG)
end

return PNG
]===],
}

local cache = {}

local function compileInEnv(src, chunkName, env)
    if not loadstring then
        error("loadstring недоступен в Real")
    end
    local fn, err = loadstring(src, chunkName)
    if not fn then
        error(err or "compile failed")
    end
    if setfenv then
        setfenv(fn, env)
    end
    return fn
end

local function loadEmbedded(path)
    if cache[path] then return cache[path] end
    local src = SOURCES[path]
    if not src then error("BabftPNG: missing " .. path) end
    local env = makeModuleEnv(loadEmbedded)
    cache[path] = compileInEnv(src, path, env)()
    return cache[path]
end

local modulesFolder, chunksMap = {}, {}
for _, n in ipairs({"BinaryReader", "Deflate", "Unfilter"}) do modulesFolder[n] = {Name = n} end
for _, n in ipairs({"IDAT","IEND","IHDR","PLTE","tRNS","bKGD","gAMA","sRGB","tEXt","tIME","cHRM"}) do chunksMap[n] = {Name = n} end

local noopChunk = function() end

local function pngRequire(target)
    if type(target) == "table" and target.Name then
        if modulesFolder[target.Name] then return loadEmbedded("Modules/" .. target.Name) end
        if chunksMap[target.Name] then
            local ok, mod = pcall(loadEmbedded, "Chunks/" .. target.Name)
            if ok then return mod end
            return noopChunk
        end
    end
    error("pngRequire: " .. tostring(target))
end

local env = makeModuleEnv(pngRequire, {
    script = {
        Modules = modulesFolder,
        Chunks = { FindFirstChild = function(_, name) return chunksMap[name] end },
    },
})

return compileInEnv(SOURCES["init"], "PNG", env)()
]=====]

local function getPNGLib()
    if pngCache.__PNG then return pngCache.__PNG end
    if not loadstring then error("loadstring недоступен") end
    local fn, err = loadstring(EMBEDDED_BABFT_PNG, "BabftPNG")
    if not fn then error("PNG декодер: " .. tostring(err)) end
    local ok, lib = pcall(fn)
    if not ok or not lib or type(lib.new) ~= "function" then
        error("PNG декодер: " .. tostring(lib))
    end
    pngCache.__PNG = lib
    return lib
end

-- ===================== НАСТРОЙКИ =====================

local IMAGE_DIR = "BABFT/Image"
local SelectedLocalFile = ""
local StatusLabel = nil

local SETTINGS_PATH = "BABFT/settings.json"
local Locale = BABFTBridge.Locale or "en"

local function loadSettings()
    if BABFTBridge.Locale == "en" or BABFTBridge.Locale == "ru" then
        Locale = BABFTBridge.Locale
    end
    if not readfile or not isfile or not isfile(SETTINGS_PATH) then return end
    local ok, raw = pcall(readfile, SETTINGS_PATH)
    if not ok or not raw then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and data and (data.Locale == "en" or data.Locale == "ru") then
        Locale = data.Locale
        BABFTBridge.Locale = Locale
    end
end

local function saveSettings()
    BABFTBridge.Locale = Locale
    if not writefile then return end
    pcall(function()
        writefile(SETTINGS_PATH, HttpService:JSONEncode({Locale = Locale}))
    end)
end

loadSettings()

local I18N = {
    en = {
        wrong_place = "BABFT: script only works in Build A Boat For Treasure",
        hub_title = "BABFT Hub",
        hub_loading = "Loading...",
        hub_subtitle = "by Mizuhura",
        hub_tab = "Settings",
        hub_pick = "Choose a module",
        hub_lang = "Language",
        hub_ui = "UI Library",
        hub_ui_active = "Active: %s",
        hub_ui_preferred = "Preferred (saved): %s",
        hub_ui_soon = "Full support coming soon — using Rayfield for now",
        hub_ui_changed = "UI preference saved — re-run script to apply",
        ui_rayfield = "Rayfield — smooth Dark/Light themes, animations. Fully supported in BABFT.",
        ui_windui = "WindUI — modern Script Hub UI with icons and themes.",
        ui_linoria = "LinoriaLib — tabs, group boxes, sliders, auto-scroll. Great for large scripts.",
        ui_cascade = "CascadeUI — clean Venyx-style menus with tabs and sections.",
        ui_mercury = "MercuryUI — minimal modern library for quick elegant UIs.",
        ui_iris = "Iris — Dear ImGui immediate-mode GUI for debug and visualization.",
        lang_en = "English",
        lang_ru = "Russian",
        lang_changed = "Language changed — reopening hub",
        mod_image = "Image Printer",
        mod_image_desc = "Build pixel art from PNG files or URLs",
        mod_model = "3D Model (.obj)",
        mod_model_desc = "Import .obj models and build them from blocks",
        mod_farm = "Auto-Farm",
        mod_farm_desc = "Automatic gold farming loop",
        mod_player = "Player Tools",
        mod_player_desc = "Teleport, character reset, quick utilities",
        mod_blocks = "Block Manager",
        mod_blocks_desc = "Check inventory and block counts",
        mod_back = "Back to Hub",
        mod_back_ui = "Back to UI Selector",
        win_image = "BABFT Image Printer",
        win_model = "BABFT 3D Model",
        win_farm = "BABFT Auto-Farm",
        win_player = "BABFT Player Tools",
        win_blocks = "BABFT Block Manager",
        tab_image = "Image Printer",
        tab_model = "3D Model",
        tab_farm = "Auto-Farm",
        tab_player = "Player Tools",
        tab_blocks = "Block Manager",
        status_pick = "Status: pick an image from the folder",
        status_reading = "Status: reading file...",
        status_loading = "Status: loading...",
        status_error = "Status: error",
        status_ready = "Status: ready | %dx%d | %d blocks | step %d",
        status_building = "Status: building... %d / %d",
        folder_image = "Folder: BABFT/Image (executor workspace)",
        folder_models = "Folder: BABFT/Models",
        label_drop_png = "Put .png files in BABFT/Image and refresh the list",
        label_drop_obj = "Put .obj files (car, house) in BABFT/Models",
        label_compression = "[Fewer blocks = stronger compression, blurrier image]",
        label_move_image = "Movement — use buttons below",
        label_move_model = "Movement — Image Printer tab or Player Tools",
        dropdown_image = "Image from folder",
        dropdown_block = "Block type",
        dropdown_model = ".obj model",
        btn_refresh = "Refresh file list",
        btn_load_file = "Load selected file",
        btn_load_url = "Load from URL",
        btn_apply_compress = "Apply compression (recalculate)",
        btn_show_frame = "Show size frame",
        btn_preview = "Image preview (required before build)",
        btn_fwd = "Forward (+Z)",
        btn_back = "Back (-Z)",
        btn_left = "Left (-X)",
        btn_right = "Right (+X)",
        btn_up = "Up (+Y)",
        btn_down = "Down (-Y)",
        btn_rotate = "Rotate 90°",
        btn_build = "BUILD IMAGE",
        btn_build_model = "BUILD MODEL",
        btn_stop = "Stop building",
        btn_clear = "Clear preview",
        btn_refresh_models = "Refresh model list",
        btn_load_model = "Load model",
        section_url = "Or via URL (optional)",
        section_move = "Movement",
        section_build = "Building",
        input_url = "Image URL (.png only)",
        input_max_blocks = "Max blocks (manual input)",
        input_max_blocks_ph = "e.g. 500",
        input_model_max = "Max blocks for model (manual)",
        slider_block_size = "Block size (studs)",
        slider_max_blocks = "Max blocks per image",
        slider_move_step = "Move step",
        slider_build_speed = "Build speed (1=safe, 5=turbo)",
        slider_model_scale = "Model scale",
        toggle_flip_y = "Flip Y axis (fix upside-down OBJ)",
        status_model_pick = "Status: pick an .obj file",
        status_model_preview = "Status: preview %d blocks — press BUILD",
        list_updated = "List updated",
        files_found = "Files found: %d",
        wait = "Please wait",
        already_building = "Building already in progress",
        no_preview = "Enable preview first",
        need_tools = "Need BuildingTool, ScalingTool and PaintingTool in inventory",
        no_zone = "Team build zone not found",
        not_enough_blocks = "Need %d %s, you have %d",
        building_started = "Building in waves — blocks appear on preview...",
        partial_done = "Placed %d of %d. Lower speed to 2-3.",
        done = "Done! Built %d blocks",
        load_image_first = "Load an image first",
        preview_done = "Preview ready",
        preview_blocks = "Blocks: %d — move with buttons below",
        preview_building = "Building %d blocks in front of you...",
        preview_title = "Preview",
        success = "Success",
        loaded_blocks = "Loaded: %d blocks. Building preview...",
        compression = "Compression",
        now_blocks = "Now %d blocks (max %d)",
        error = "Error",
        paste_png_url = "Paste a direct .png link",
        empty_image = "Empty image data",
        pick_file = "Pick a file from the list",
        pick_obj = "Pick an .obj from the list",
        obj_no_verts = "OBJ has no vertices (v)",
        model_empty = "Model is empty",
        obj_loaded = "Model: %d blocks. Move preview and build.",
        obj_error = "OBJ error",
        obj_fail = "Failed to load",
        block_count = "Block",
        you_have = " — you have: %d",
        speed = "Speed",
        speed_labels = {"slow", "normal", "fast", "very fast", "turbo"},
        stop = "Stop",
        building_stopped = "Building stopped",
        cleared = "Cleared",
        preview_removed = "Preview removed",
        png_ok = "PNG decoder OK. Pick an image from the folder.",
        png_err = "PNG error",
        tp_zone = "Teleport to build zone",
        tp_spawn = "Teleport to spawn",
        reset_char = "Reset character",
        tp_done = "Teleported",
        tp_fail = "Teleport failed — no character",
        reset_done = "Character reset",
        check_blocks = "Check selected block count",
        check_all = "Show all block counts",
        blocks_header = "Your block inventory",
        farm_saved = "Saved",
        farm_loaded = "Loaded",
        farm_started = "Auto-farm started",
        farm_stopped = "Stopped",
        config = "Config",
    },
    ru = {
        wrong_place = "BABFT: скрипт только для Build A Boat For Treasure",
        hub_title = "BABFT Хаб",
        hub_loading = "Загрузка...",
        hub_subtitle = "by Mizuhura",
        hub_tab = "Настройки",
        hub_pick = "Выберите модуль",
        hub_lang = "Язык",
        hub_ui = "UI-библиотека",
        hub_ui_active = "Активна: %s",
        hub_ui_preferred = "Выбрана (сохранено): %s",
        hub_ui_soon = "Полная поддержка скоро — пока используется Rayfield",
        hub_ui_changed = "UI сохранён — перезапусти скрипт для применения",
        ui_rayfield = "Rayfield — плавные Dark/Light темы, анимации. Полностью поддержан в BABFT.",
        ui_windui = "WindUI — современный UI для Script Hub с иконками и темами.",
        ui_linoria = "LinoriaLib — вкладки, group boxes, слайдеры, авто-прокрутка.",
        ui_cascade = "CascadeUI — аккуратные меню в стиле Venyx с вкладками.",
        ui_mercury = "MercuryUI — минималистичная «сочная» библиотека.",
        ui_iris = "Iris — immediate-mode GUI на базе Dear ImGui для отладки.",
        lang_en = "English",
        lang_ru = "Русский",
        lang_changed = "Язык изменён — обновляю хаб",
        mod_image = "Image Printer",
        mod_image_desc = "Строй пиксель-арт из PNG или по URL",
        mod_model = "3D Model (.obj)",
        mod_model_desc = "Импорт .obj моделей и постройка из блоков",
        mod_farm = "Auto-Farm",
        mod_farm_desc = "Автоматический фарм золота",
        mod_player = "Player Tools",
        mod_player_desc = "Телепорт, сброс персонажа, утилиты",
        mod_blocks = "Block Manager",
        mod_blocks_desc = "Проверка инвентаря и количества блоков",
        mod_back = "Назад в хаб",
        mod_back_ui = "Назад к выбору UI",
        win_image = "BABFT Image Printer",
        win_model = "BABFT 3D Model",
        win_farm = "BABFT Auto-Farm",
        win_player = "BABFT Player Tools",
        win_blocks = "BABFT Block Manager",
        tab_image = "Image Printer",
        tab_model = "3D Model",
        tab_farm = "Auto-Farm",
        tab_player = "Player Tools",
        tab_blocks = "Block Manager",
        status_pick = "Статус: выбери картинку из папки",
        status_reading = "Статус: читаю файл...",
        status_loading = "Статус: загрузка...",
        status_error = "Статус: ошибка",
        status_ready = "Статус: готово | %dx%d | %d блоков | шаг %d",
        status_building = "Статус: строю... %d / %d",
        folder_image = "Папка: BABFT/Image (workspace executor)",
        folder_models = "Папка: BABFT/Models",
        label_drop_png = "Положи .png в BABFT/Image и обнови список",
        label_drop_obj = "Положи .obj (машина, дом) в BABFT/Models",
        label_compression = "[Меньше блоков = сильнее сжатие, картинка размазаннее]",
        label_move_image = "Перемещение — кнопки ниже",
        label_move_model = "Перемещение — вкладка Image Printer",
        dropdown_image = "Картинка из папки",
        dropdown_block = "Тип блока",
        dropdown_model = "Модель .obj",
        btn_refresh = "Обновить список файлов",
        btn_load_file = "Загрузить выбранный файл",
        btn_load_url = "Загрузить по URL",
        btn_apply_compress = "Применить сжатие (пересчитать)",
        btn_show_frame = "Показать рамку размера",
        btn_preview = "Превью картинки (обязательно перед строительством)",
        btn_fwd = "Вперёд (+Z)",
        btn_back = "Назад (-Z)",
        btn_left = "Влево (-X)",
        btn_right = "Вправо (+X)",
        btn_up = "Выше (+Y)",
        btn_down = "Ниже (-Y)",
        btn_rotate = "Повернуть 90°",
        btn_build = "ПОСТРОИТЬ КАРТИНКУ",
        btn_build_model = "ПОСТРОИТЬ МОДЕЛЬ",
        btn_stop = "Остановить строительство",
        btn_clear = "Очистить превью",
        btn_refresh_models = "Обновить список моделей",
        btn_load_model = "Загрузить модель",
        section_url = "Или по URL (необязательно)",
        section_move = "Перемещение",
        section_build = "Строительство",
        input_url = "URL картинки (только .png)",
        input_max_blocks = "Макс. блоков (ручной ввод)",
        input_max_blocks_ph = "напр. 500",
        input_model_max = "Макс. блоков для модели (ручной)",
        slider_block_size = "Размер блока (studs)",
        slider_max_blocks = "Макс. блоков на картинку",
        slider_move_step = "Шаг перемещения",
        slider_build_speed = "Скорость строительства (1=безопасно, 5=турбо)",
        slider_model_scale = "Масштаб модели",
        toggle_flip_y = "Инвертировать Y (если модель перевёрнута)",
        status_model_pick = "Статус: выбери .obj файл",
        status_model_preview = "Статус: превью %d блоков — жми ПОСТРОИТЬ",
        list_updated = "Список обновлён",
        files_found = "Найдено файлов: %d",
        wait = "Подождите",
        already_building = "Строительство уже идёт",
        no_preview = "Сначала включите превью",
        need_tools = "Нужны BuildingTool, ScalingTool и PaintingTool в инвентаре",
        no_zone = "Не найдена зона команды",
        not_enough_blocks = "Нужно %d %s, у вас %d",
        building_started = "Строю волнами — блоки появятся на превью...",
        partial_done = "Поставлено %d из %d. Уменьши скорость до 2-3.",
        done = "Готово! Построено %d блоков",
        load_image_first = "Сначала загрузи картинку",
        preview_done = "Превью готово",
        preview_blocks = "Блоков: %d — двигай кнопками ниже",
        preview_building = "Строю %d блоков перед тобой...",
        preview_title = "Превью",
        success = "Успех",
        loaded_blocks = "Загружено: %d блоков. Превью строится...",
        compression = "Сжатие",
        now_blocks = "Теперь %d блоков (макс %d)",
        error = "Ошибка",
        paste_png_url = "Вставьте прямую ссылку на .png",
        empty_image = "Пустые данные картинки",
        pick_file = "Выбери файл из списка",
        pick_obj = "Выбери .obj из списка",
        obj_no_verts = "В OBJ нет вершин (v)",
        model_empty = "Модель пустая",
        obj_loaded = "Модель: %d блоков. Перемести превью и строй.",
        obj_error = "OBJ ошибка",
        obj_fail = "не удалось",
        block_count = "Блок",
        you_have = " — у вас: %d",
        speed = "Скорость",
        speed_labels = {"медленно", "нормально", "быстро", "очень быстро", "турбо"},
        stop = "Стоп",
        building_stopped = "Строительство остановлено",
        cleared = "Очищено",
        preview_removed = "Превью удалено",
        png_ok = "PNG декодер OK. Выбери картинку из папки.",
        png_err = "PNG ошибка",
        tp_zone = "Телепорт в зону постройки",
        tp_spawn = "Телепорт на спавн",
        reset_char = "Сбросить персонажа",
        tp_done = "Телепорт выполнен",
        tp_fail = "Телепорт не удался — нет персонажа",
        reset_done = "Персонаж сброшен",
        check_blocks = "Проверить выбранный блок",
        check_all = "Показать все блоки",
        blocks_header = "Ваш инвентарь блоков",
        farm_saved = "Сохранено",
        farm_loaded = "Загружено",
        farm_started = "Авто-фарм запущен",
        farm_stopped = "Остановлен",
        config = "Config",
    },
}

local function L(key, ...)
    local pack = I18N[Locale] or I18N.en
    local s = pack[key] or I18N.en[key] or key
    if select("#", ...) > 0 then
        return string.format(s, ...)
    end
    return s
end

local Config = {
    ImgUrl = "",
    BlockType = "PlasticBlock",
    BlockSize = 2,
    BlockDepth = 2,
    MaxBlocks = 500,
    ModelMaxBlocks = 500,
    MoveStep = 5,
    BuildSpeed = 400,
    BuildFastness = 4,
    IsBuilding = false,
    PreviewEnabled = false,
    AutoPreview = true,
    ModelScale = 2,
    ModelFlipY = true,
}

local BlockTypes = {
    "BrickBlock", "CoalBlock", "ConcreteBlock", "FabricBlock", "GlassBlock",
    "GoldBlock", "GrassBlock", "IceBlock", "MarbleBlock", "MetalBlock",
    "NeonBlock", "ObsidianBlock", "PlasticBlock", "RustedBlock",
    "SmoothWoodBlock", "StoneBlock", "TitaniumBlock", "ToyBlock", "WoodBlock",
}

local TeamZones = {
    black = "BlackZone",
    blue = "Really blueZone",
    green = "CamoZone",
    red = "Really redZone",
    white = "WhiteZone",
    yellow = "New YellerZone",
    magenta = "MagentaZone",
}

-- ===================== ПАПКИ / ПРЕВЬЮ =====================

local previewFolder = workspace:FindFirstChild("ImagePreview") or Instance.new("Folder")
previewFolder.Name = "ImagePreview"
previewFolder.Parent = workspace

local centerPart = nil
local previewParts = {}
local imageData = nil
local sourceBinary = nil
local positionOffset = Vector3.zero
local rotationAngle = 0
local previewConnection = nil
local previewToggle = nil

-- Рамка размера (объявляем заранее — иначе movePreview не видит переменную)
local PreviewFrame = Instance.new("Part")
PreviewFrame.Name = "PreviewSize"
PreviewFrame.Size = Vector3.new(20, 15, 1)
PreviewFrame.Anchored = true
PreviewFrame.CanCollide = false
PreviewFrame.Material = Enum.Material.ForceField
PreviewFrame.Color = Color3.fromRGB(0, 255, 128)
PreviewFrame.Transparency = 1
PreviewFrame.Parent = previewFolder
if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
    PreviewFrame.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 5, -15)
else
    PreviewFrame.Position = Vector3.new(0, 20, 0)
end

local function clearPreview(keepFrame)
    if previewConnection then
        previewConnection:Disconnect()
        previewConnection = nil
    end
    for _, part in ipairs(previewParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    previewParts = {}
    if centerPart then
        centerPart:Destroy()
        centerPart = nil
    end
    if not keepFrame then
        for _, child in ipairs(previewFolder:GetChildren()) do
            if child ~= PreviewFrame then
                child:Destroy()
            end
        end
    end
end

-- ===================== УТИЛИТЫ ИГРЫ =====================

local function getTeamZoneName()
    local team = player.Team
    if not team then return nil end
    return TeamZones[team.Name]
end

local function getBuildZone()
    local zoneName = getTeamZoneName()
    if zoneName then
        return workspace:FindFirstChild(zoneName)
    end
    return nil
end

local function getStartPosition()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        return (hrp.CFrame * CFrame.new(0, 6, -28)).Position + positionOffset
    end
    local zone = getBuildZone()
    if zone then
        return zone.Position + Vector3.new(0, 25, -40) + positionOffset
    end
    return Vector3.new(0, 30, -40) + positionOffset
end

local function getBlockOwner()
    if player.Settings and player.Settings:FindFirstChild("ShareBlocks") and player.Settings.ShareBlocks.Value == false then
        return player.Name
    end
    local team = player.Team
    if team and team:FindFirstChild("TeamLeader") then
        return team.TeamLeader.Value
    end
    return player.Name
end

local function getUserBlockCount(blockType)
    local data = player:FindFirstChild("Data")
    if not data then return 0 end
    local blockData = data:FindFirstChild(blockType)
    if blockData then
        return blockData.Value or 0
    end
    return 0
end

local function getTool(name)
    return (player.Backpack and player.Backpack:FindFirstChild(name))
        or (player.Character and player.Character:FindFirstChild(name))
end

-- ===================== ЗАГРУЗКА КАРТИНКИ =====================

local function parseColorData(raw)
    local data = {}
    if type(raw) == "table" then
        if raw.data then
            raw = raw.data
        elseif raw.pixels then
            raw = raw.pixels
        else
            for _, v in ipairs(raw) do
                table.insert(data, v)
            end
            return data
        end
    end
    if type(raw) ~= "string" then
        return nil
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(decoded) == "table" then
        if decoded.data then
            raw = decoded.data
        elseif decoded.pixels then
            for _, px in ipairs(decoded.pixels) do
                if type(px) == "table" then
                    table.insert(data, px[1] or px.r or 0)
                    table.insert(data, px[2] or px.g or 0)
                    table.insert(data, px[3] or px.b or 0)
                end
            end
            return data
        end
    end
    for value in string.gmatch(raw, "[^,]+") do
        value = value:match("^%s*(.-)%s*$")
        local num = tonumber(value)
        if num then
            table.insert(data, num)
        else
            table.insert(data, value)
        end
    end
    return data
end

local PNG_MAGIC = string.char(137) .. "PNG\r\n\26\n"

local function isPngBinary(binary)
    return type(binary) == "string" and #binary >= 8 and binary:sub(1, 8) == PNG_MAGIC
end

local function readBinaryFile(filePath)
    if not filePath then return nil end
    if readbinaryfile then
        local ok, data = pcall(readbinaryfile, filePath)
        if ok and type(data) == "string" and #data > 0 then
            return data
        end
    end
    if readfile then
        local ok, data = pcall(readfile, filePath, true)
        if ok and type(data) == "string" and #data > 0 then
            return data
        end
        ok, data = pcall(readfile, filePath)
        if ok and type(data) == "string" and #data > 0 then
            return data
        end
    end
    return nil
end

local function readPixelFromPng(png, x, y)
    local w, h = png.Width, png.Height
    x = math.max(1, math.min(w, math.floor(x)))
    y = math.max(1, math.min(h, math.floor(y)))

    local row = png.Bitmap and png.Bitmap[y]
    if not row then return 0, 0, 0, 0 end

    local bpp = png.BytesPerPixel or 3
    local i = ((x - 1) * bpp) + 1
    local ct = png.ColorType

    if ct == 6 then
        return row[i] or 0, row[i + 1] or 0, row[i + 2] or 0, row[i + 3] or 255
    elseif ct == 2 then
        return row[i] or 0, row[i + 1] or 0, row[i + 2] or 0, 255
    elseif ct == 0 then
        local g = row[i] or 0
        return g, g, g, 255
    elseif ct == 4 then
        local g = row[i] or 0
        return g, g, g, row[i + 1] or 255
    elseif ct == 3 then
        local pal = png.Palette
        local alphaData = png.AlphaData
        local idx = (row[i] or 0) + 1
        if pal and pal[idx] then
            local entry = pal[idx]
            local r, g, b
            if type(entry) == "table" then
                r, g, b = entry[1] or 0, entry[2] or 0, entry[3] or 0
            else
                r = math.floor(entry.R * 255 + 0.5)
                g = math.floor(entry.G * 255 + 0.5)
                b = math.floor(entry.B * 255 + 0.5)
            end
            local a = 255
            if alphaData then a = alphaData[idx] or 255 end
            return r, g, b, a
        end
        return 0, 0, 0, 0
    end

    return row[i] or 0, row[i + 1] or 0, row[i + 2] or 0, 255
end

local function computeSamplingStep(width, height, maxBlocks)
    maxBlocks = math.max(50, tonumber(maxBlocks) or 500)
    for step = 1, 500 do
        local cols = math.ceil(width / step)
        local rows = math.ceil(height / step)
        if cols * rows <= maxBlocks then
            return step
        end
    end
    return 500
end

local function pngToColorData(png, step)
    step = math.max(1, math.floor(step or 1))
    local data = {}
    for y = 1, png.Height, step do
        for x = 1, png.Width, step do
            local r, g, b, a = readPixelFromPng(png, x, y)
            if a < 128 then
                table.insert(data, "R")
                table.insert(data, "R")
                table.insert(data, "R")
            else
                table.insert(data, r)
                table.insert(data, g)
                table.insert(data, b)
            end
        end
        table.insert(data, "B")
        table.insert(data, "B")
        table.insert(data, "B")
    end
    return data
end

local function decodePNG(binary, maxBlocks)
    local libOk, PNG = pcall(getPNGLib)
    if not libOk or not PNG then
        return nil, tostring(PNG or "PNG декодер не загрузился")
    end
    if not isPngBinary(binary) then
        return nil, "Это не PNG файл. Сохрани картинку как .png (не .jpg)"
    end

    local okPng, pngOrErr = pcall(function()
        return PNG.new(binary)
    end)
    if not okPng or not pngOrErr then
        return nil, "PNG decode: " .. tostring(pngOrErr or "неизвестная ошибка")
    end

    local step = computeSamplingStep(pngOrErr.Width, pngOrErr.Height, maxBlocks)
    local okData, packed = pcall(function()
        return {data = pngToColorData(pngOrErr, step), step = step}
    end)
    if not okData or not packed or not packed.data then
        return nil, "Пиксели: " .. tostring(packed or "неизвестная ошибка")
    end
    return packed.data, packed.step
end

local function processSourceBinary(binary, maxBlocks)
    if not binary or #binary < 3 then
        return nil, "Пустой файл"
    end
    sourceBinary = binary
    if isPngBinary(binary) then
        return decodePNG(binary, maxBlocks)
    end
    local parsed = parseColorData(binary)
    if parsed and #parsed >= 3 then
        return parsed, 1
    end
    return nil, "Файл должен быть .png"
end

local function fetchImageFromUrl(url)
    local normalized, normErr = normalizeImageUrl(url)
    if not normalized then
        return nil, normErr
    end

    Notify({Title = "Загрузка", Content = "Скачиваю картинку...", Duration = 3})

    local binary = httpGet(normalized)
    if not binary or #binary < 8 then
        return nil, "Не удалось скачать. Нужна прямая ссылка на .png\nПример: https://i.imgur.com/xxxxx.png"
    end
    if isHtmlResponse(binary) then
        return nil, "Ссылка открывает страницу, а не файл .png. Открой картинку в браузере → ПКМ → Копировать адрес изображения"
    end

    return processSourceBinary(binary, Config.MaxBlocks)
end

local function fetchImageFromFile(filePath)
    if not isfile then
        return nil, "Файловая система недоступна"
    end
    if not isfile(filePath) then
        return nil, "Файл не найден: " .. filePath
    end
    local content = readBinaryFile(filePath)
    if not content then
        return nil, "Не удалось прочитать файл: " .. filePath
    end
    return processSourceBinary(content, Config.MaxBlocks)
end

local function getImageFileList()
    local files = {}
    if not listfiles then
        return {"(listfiles недоступен)"}
    end
    local ok, listed = pcall(function()
        return listfiles(IMAGE_DIR)
    end)
    if not ok or not listed then
        return {"(папка пуста)"}
    end
    for _, path in ipairs(listed) do
        local name = path:match("([^/\\]+)$") or path
        local lower = string.lower(name)
        if lower:match("%.png$") or lower:match("%.txt$") then
            table.insert(files, name)
        end
    end
    table.sort(files)
    if #files == 0 then
        table.insert(files, "(нет файлов — положи .png сюда)")
    end
    return files
end

local function getImageFilePath(fileName)
    if not fileName or fileName:sub(1, 1) == "(" then
        return nil
    end
    return IMAGE_DIR .. "/" .. fileName
end

local function loadLocalImageByName(fileName)
    local filePath = getImageFilePath(fileName)
    if not filePath then
        return nil, "Выбери файл из списка"
    end
    return fetchImageFromFile(filePath)
end

local function calculateImageSize(data, blockSize)
    local width, height, rowWidth = 0, 0, 0
    for i = 1, #data, 3 do
        local r, g, b = data[i], data[i + 1], data[i + 2]
        if r == "B" and g == "B" and b == "B" then
            height += 1
            width = math.max(width, rowWidth)
            rowWidth = 0
        elseif r == "R" and g == "R" and b == "R" then
            rowWidth += 1
        elseif type(r) == "number" then
            rowWidth += 1
        end
    end
    height += 1
    width = math.max(width, rowWidth)
    return width, height, Vector3.new(width * blockSize, height * blockSize, Config.BlockDepth)
end

local function countPixels(data)
    local count = 0
    for i = 1, #data, 3 do
        local r, g, b = data[i], data[i + 1], data[i + 2]
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            count += 1
        end
    end
    return count
end

local function setStatus(text)
    if not StatusLabel then return end
    if type(StatusLabel) == "function" then
        StatusLabel(text)
    elseif StatusLabel.Set then
        StatusLabel:Set(text)
    elseif StatusLabel.Update then
        StatusLabel:Update(text)
    end
end

local function applyLoadedImage(data, step)
    if not data or #data < 3 then
        return false, "Пустые данные картинки"
    end
    imageData = data
    local px = countPixels(data)
    local w, h = calculateImageSize(data, Config.BlockSize)
    setStatus(L("status_ready", w, h, px, step or 1))
    Notify({
        Title = L("success"),
        Content = L("loaded_blocks", px),
        Duration = 4,
    })
    if Config.AutoPreview then
        Config.PreviewEnabled = true
        pcall(function()
            if previewToggle and previewToggle.Set then previewToggle:Set(true) end
        end)
        task.spawn(buildPreview)
    end
    return true
end

-- ===================== ПРЕВЬЮ =====================

local function createCenterPart(frameSize, startPos)
    if centerPart then centerPart:Destroy() end
    centerPart = Instance.new("Part")
    centerPart.Name = "Centerimage"
    centerPart.Size = frameSize
    centerPart.CFrame = CFrame.new(startPos + Vector3.new(frameSize.X / 2, frameSize.Y / 2, 0))
    centerPart.Transparency = 1
    centerPart.Anchored = true
    centerPart.CanCollide = false
    centerPart.Parent = previewFolder
    return centerPart
end

local function buildPreview()
    if not imageData then
        Notify({Title = L("error"), Content = L("load_image_first"), Duration = 4})
        return
    end

    clearPreview(true)
    positionOffset = Vector3.zero
    rotationAngle = 0

    local blockSize = Config.BlockSize
    local startPos = getStartPosition()
    local _, _, frameSize = calculateImageSize(imageData, blockSize)
    local center = createCenterPart(frameSize, startPos)

    PreviewFrame.Size = Vector3.new(frameSize.X, frameSize.Y, 0.5)
    PreviewFrame.CFrame = center.CFrame
    PreviewFrame.Transparency = 0.55
    PreviewFrame.Color = Color3.fromRGB(0, 255, 120)

    local currentX = startPos.X
    local currentY = startPos.Y + frameSize.Y - blockSize
    local initialX = currentX
    local dataIndex = 1
    local rotCF = CFrame.Angles(0, math.rad(rotationAngle), 0)
    local totalBlocks = countPixels(imageData)

    previewConnection = RunService.Heartbeat:Connect(function()
        local batch = Config.BuildSpeed
        for _ = 1, batch do
            if dataIndex > #imageData then
                previewConnection:Disconnect()
                previewConnection = nil
                Notify({
                    Title = L("preview_done"),
                    Content = L("preview_blocks", #previewParts),
                    Duration = 5,
                })
                return
            end

            local r, g, b = imageData[dataIndex], imageData[dataIndex + 1], imageData[dataIndex + 2]

            if r == "B" and g == "B" and b == "B" then
                currentX = initialX
                currentY -= blockSize
            elseif r == "R" and g == "R" and b == "R" then
                currentX += blockSize
            elseif type(r) == "number" and type(g) == "number" and type(b) == "number" then
                local block = Instance.new("Part")
                block.Name = "PreviewBlock"
                block.Size = Vector3.new(blockSize, blockSize, Config.BlockDepth)
                block.Color = Color3.fromRGB(
                    math.clamp(r, 0, 255),
                    math.clamp(g, 0, 255),
                    math.clamp(b, 0, 255)
                )
                block.Material = Enum.Material.Neon
                block.Anchored = true
                block.CanCollide = false
                block.CastShadow = false
                block.Parent = previewFolder

                local worldPos = Vector3.new(currentX + blockSize / 2, currentY + blockSize / 2, startPos.Z)
                local relCF = center.CFrame:ToObjectSpace(CFrame.new(worldPos))
                block.CFrame = center.CFrame * rotCF * relCF

                table.insert(previewParts, block)
                currentX += blockSize
            end
            dataIndex += 3
        end
    end)

    Notify({
        Title = L("preview_title"),
        Content = L("preview_building", totalBlocks),
        Duration = 3,
    })
end

local function recompressLoadedImage()
    if not sourceBinary then
        return nil, "Сначала загрузи картинку"
    end
    local data, stepOrErr, third = processSourceBinary(sourceBinary, Config.MaxBlocks)
    if not data then
        return nil, stepOrErr
    end
    local step = stepOrErr
    if type(step) ~= "number" then step = third or 1 end
    imageData = data
    local px = countPixels(data)
    local w, h = calculateImageSize(data, Config.BlockSize)
    setStatus(L("status_ready", w, h, px, step))
    if Config.PreviewEnabled then
        task.spawn(buildPreview)
    end
    Notify({
        Title = L("compression"),
        Content = L("now_blocks", px, Config.MaxBlocks),
        Duration = 3,
    })
    return data
end

local function movePreview(delta)
    positionOffset += delta
    if centerPart then
        centerPart.CFrame = centerPart.CFrame + delta
    end
    for _, part in ipairs(previewParts) do
        if part and part.Parent then
            part.CFrame = part.CFrame + delta
        end
    end
    if PreviewFrame and PreviewFrame.Parent then
        PreviewFrame.CFrame = PreviewFrame.CFrame + delta
    end
end

local function rotatePreview(degrees)
    if not centerPart then return end
    rotationAngle = (rotationAngle + degrees) % 360
    local rotCF = CFrame.Angles(0, math.rad(degrees), 0)
    local pivot = centerPart.CFrame
    centerPart.CFrame = pivot * rotCF
    for _, part in ipairs(previewParts) do
        if part and part.Parent then
            part.CFrame = pivot * rotCF * pivot:ToObjectSpace(part.CFrame)
        end
    end
    if PreviewFrame and PreviewFrame.Parent then
        PreviewFrame.CFrame = pivot * rotCF * pivot:ToObjectSpace(PreviewFrame.CFrame)
    end
end

-- ===================== 3D МОДЕЛИ (.obj) =====================

local MODEL_DIR = "BABFT/Models"
local SelectedModelFile = ""
local ModelStatusLabel = nil

local function getModelFileList()
    local files = {}
    if not listfiles then return {"(listfiles недоступен)"} end
    local ok, listed = pcall(function() return listfiles(MODEL_DIR) end)
    if not ok or not listed then return {"(положи .obj в BABFT/Models)"} end
    for _, path in ipairs(listed) do
        local name = path:match("([^/\\]+)$") or path
        if name:lower():match("%.obj$") then
            table.insert(files, name)
        end
    end
    table.sort(files)
    if #files == 0 then table.insert(files, "(нет .obj файлов)") end
    return files
end

local function parseOBJ(content)
    local vertices = {}
    local facePoints = {}
    local flipY = Config.ModelFlipY ~= false

    local function resolveIndex(i, count)
        if i < 0 then
            return count + i + 1
        end
        return i
    end

    local function toRobloxVertex(x, y, z)
        local fx, fy, fz = tonumber(x), tonumber(y), tonumber(z)
        if not fx then return nil end
        if flipY then
            fy = -fy
        end
        return Vector3.new(fx, fy, fz)
    end

    for line in content:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local cmd = line:match("^(%S+)")
            if cmd == "v" then
                local x, y, z = line:match("^v%s+([%d%.%-eE%+]+)%s+([%d%.%-eE%+]+)%s+([%d%.%-eE%+]+)")
                if x then
                    local v = toRobloxVertex(x, y, z)
                    if v then
                        table.insert(vertices, v)
                    end
                end
            elseif cmd == "f" then
                local idx = {}
                for token in line:gmatch("%S+") do
                    if token ~= "f" then
                        local vi = tonumber(token:match("^(%d+)") or token:match("^(%d+)/"))
                        if vi then
                            vi = resolveIndex(vi, #vertices)
                            table.insert(idx, vi)
                        end
                    end
                end
                if #idx >= 3 then
                    for t = 2, #idx - 1 do
                        local a, b, c = vertices[idx[1]], vertices[idx[t]], vertices[idx[t + 1]]
                        if a and b and c then
                            table.insert(facePoints, (a + b + c) / 3)
                        end
                    end
                end
            end
        end
    end
    return vertices, facePoints
end

local function sampleModelPoints(vertices, facePoints, maxBlocks)
    local seen = {}
    local points = {}
    local function addPoint(v)
        local key = string.format("%.3f,%.3f,%.3f", v.X, v.Y, v.Z)
        if not seen[key] then
            seen[key] = true
            points[#points + 1] = v
        end
    end
    for _, v in ipairs(vertices) do addPoint(v) end
    for _, v in ipairs(facePoints) do addPoint(v) end
    if #points > maxBlocks then
        local step = math.ceil(#points / maxBlocks)
        local reduced = {}
        for i = 1, #points, step do
            reduced[#reduced + 1] = points[i]
        end
        points = reduced
    end
    return points
end

local function buildModelPreview(points, modelColor)
    if #points == 0 then return nil, L("model_empty") end

    clearPreview(true)
    positionOffset = Vector3.zero
    rotationAngle = 0
    imageData = nil

    local blockSize = Config.BlockSize
    local scale = Config.ModelScale or 2
    local startPos = getStartPosition()
    local color = modelColor or Color3.fromRGB(180, 180, 180)

    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, p in ipairs(points) do
        minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
        maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
    end
    local geoCenter = (minV + maxV) / 2
    local rawSize = maxV - minV
    local frameSize = rawSize * scale * blockSize
    frameSize = Vector3.new(
        math.max(frameSize.X, blockSize),
        math.max(frameSize.Y, blockSize),
        math.max(frameSize.Z, Config.BlockDepth)
    )

    if centerPart then centerPart:Destroy() end
    centerPart = Instance.new("Part")
    centerPart.Name = "CenterModel"
    centerPart.Size = frameSize
    centerPart.CFrame = CFrame.new(startPos)
    centerPart.Transparency = 1
    centerPart.Anchored = true
    centerPart.CanCollide = false
    centerPart.Parent = previewFolder

    PreviewFrame.Size = frameSize
    PreviewFrame.CFrame = centerPart.CFrame
    PreviewFrame.Transparency = 0.55

    previewParts = {}
    local pointIndex = 1
    local totalPoints = #points

    if previewConnection then
        previewConnection:Disconnect()
        previewConnection = nil
    end

    previewConnection = RunService.Heartbeat:Connect(function()
        local batch = math.min(Config.BuildSpeed, 800)
        for _ = 1, batch do
            if pointIndex > totalPoints then
                previewConnection:Disconnect()
                previewConnection = nil
                Notify({
                    Title = L("preview_done"),
                    Content = L("preview_blocks", #previewParts),
                    Duration = 5,
                })
                return
            end

            local p = points[pointIndex]
            local rel = (p - geoCenter) * scale * blockSize
            local block = Instance.new("Part")
            block.Name = "ModelPreviewBlock"
            block.Size = Vector3.new(blockSize, blockSize, Config.BlockDepth)
            block.Color = color
            block.Material = Enum.Material.Neon
            block.Anchored = true
            block.CanCollide = false
            block.CastShadow = false
            block.Parent = previewFolder
            block.CFrame = centerPart.CFrame * CFrame.new(rel)
            previewParts[#previewParts + 1] = block
            pointIndex += 1
        end
    end)

    Config.PreviewEnabled = true
    Notify({
        Title = L("preview_title"),
        Content = L("preview_building", totalPoints),
        Duration = 3,
    })
    return totalPoints
end

local function loadOBJByName(fileName)
    if not fileName or fileName:sub(1, 1) == "(" then
        return nil, L("pick_obj")
    end
    local path = MODEL_DIR .. "/" .. fileName
    local content = readBinaryFile(path)
    if not content then return nil, L("error") .. ": " .. path end
    local verts, faces = parseOBJ(content)
    if #verts == 0 then return nil, L("obj_no_verts") end
    local maxBlocks = Config.ModelMaxBlocks or Config.MaxBlocks
    local points = sampleModelPoints(verts, faces, maxBlocks)
    local count = buildModelPreview(points)
    if not count then return nil, L("obj_fail") end
    return count
end

-- ===================== СТРОИТЕЛЬСТВО =====================

local BUILD_TUNING = {
    {waveSize = 8,  poll = 0.2,  paintChunk = 500},
    {waveSize = 15, poll = 0.12, paintChunk = 1000},
    {waveSize = 25, poll = 0.08, paintChunk = 2000},
    {waveSize = 40, poll = 0.04, paintChunk = 4000},
    {waveSize = 60, poll = 0.02, paintChunk = 8000},
}

local function getBuildTuning()
    local level = math.clamp(math.floor(Config.BuildFastness or 4), 1, 5)
    return BUILD_TUNING[level]
end

local function collectBlocksSince(folder, startCount)
    local blocks = {}
    if not folder then return blocks end
    local all = folder:GetChildren()
    for i = startCount + 1, #all do
        blocks[#blocks + 1] = all[i]
    end
    return blocks
end

local function buildImage()
    if Config.IsBuilding then
        Notify({Title = L("wait"), Content = L("already_building"), Duration = 3})
        return
    end
    if #previewParts == 0 then
        Notify({Title = L("error"), Content = L("no_preview"), Duration = 4})
        return
    end

    local buildTool = getTool("BuildingTool")
    local scaleTool = getTool("ScalingTool")
    local paintTool = getTool("PaintingTool")
    if not buildTool or not scaleTool or not paintTool then
        Notify({Title = L("error"), Content = L("need_tools"), Duration = 5})
        return
    end

    local zone = getBuildZone()
    if not zone then
        Notify({Title = L("error"), Content = L("no_zone"), Duration = 4})
        return
    end

    local blockCount = getUserBlockCount(Config.BlockType)
    if blockCount < #previewParts then
        Notify({
            Title = L("error"),
            Content = L("not_enough_blocks", #previewParts, Config.BlockType, blockCount),
            Duration = 6,
        })
        return
    end

    Config.IsBuilding = true
    Notify({Title = L("section_build"), Content = L("building_started"), Duration = 5})

    task.spawn(function()
        local tuning = getBuildTuning()
        local blockOwner = getBlockOwner()
        local blocksFolder = workspace:FindFirstChild("Blocks")
        local playerBlocks = blocksFolder and blocksFolder:FindFirstChild(blockOwner)
        local needed = #previewParts
        local placed = 0
        local scaleSize = Vector3.new(Config.BlockDepth, Config.BlockSize, Config.BlockSize)
        local scaleRot = CFrame.Angles(0, math.rad(90), 0)
        local spawnCF = CFrame.new(math.random(-50, 50), math.random(-2000000, -100000), math.random(-50, 50))
        local paintData = {}

        for waveStart = 1, needed, tuning.waveSize do
            if not Config.IsBuilding then break end

            local waveEnd = math.min(waveStart + tuning.waveSize - 1, needed)
            local waveCount = waveEnd - waveStart + 1
            local startCount = playerBlocks and #playerBlocks:GetChildren() or 0

            for i = waveStart, waveEnd do
                if not Config.IsBuilding then break end
                pcall(function()
                    buildTool.RF:InvokeServer(Config.BlockType, blockCount, zone, spawnCF, true)
                end)
            end

            local waveBlocks = {}
            local t0 = tick()
            while #waveBlocks < waveCount and Config.IsBuilding and tick() - t0 < math.max(8, waveCount * 0.2) do
                task.wait(tuning.poll)
                waveBlocks = collectBlocksSince(playerBlocks, startCount)
            end

            for bi = 1, math.min(#waveBlocks, waveCount) do
                if not Config.IsBuilding then break end
                local previewPart = previewParts[waveStart + bi - 1]
                local targetBlock = waveBlocks[bi]
                if previewPart and previewPart.Parent and targetBlock then
                    local placeCF = previewPart.CFrame * scaleRot
                    pcall(function()
                        scaleTool.RF:InvokeServer(targetBlock, scaleSize, placeCF)
                    end)
                    table.insert(paintData, {targetBlock, previewPart.Color})
                    placed += 1
                end
            end

            if #paintData >= tuning.paintChunk then
                pcall(function() paintTool.RF:InvokeServer(paintData) end)
                paintData = {}
            end

            setStatus(L("status_building", placed, needed))
            task.wait()
        end

        if #paintData > 0 then
            pcall(function() paintTool.RF:InvokeServer(paintData) end)
        end

        Config.IsBuilding = false
        clearPreview()

        if placed < needed then
            Notify({
                Title = L("error"),
                Content = L("partial_done", placed, needed),
                Duration = 7,
            })
        else
            Notify({Title = L("success"), Content = L("done", placed), Duration = 6})
        end
    end)
end

-- ===================== AUTO-FARM CORE =====================

local FARM_CONFIG_PATH = "BABFT/farm_config.json"

local FarmState = {
    Enabled = false,
    AntiAfk = true,
    Silent = false,
    WebhookUrl = "",
    WebhookInterval = 60,
    WebhookActive = false,
    StartTime = 0,
    StartGold = 0,
    StartGoldBlocks = 0,
}

local FarmLabels = {}

local function getPlayerGold()
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local gold = ls:FindFirstChild("Gold")
        if gold then return gold.Value end
    end
    return 0
end

local function formatTime(sec)
    sec = math.max(0, math.floor(sec))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function formatNumber(n)
    if n >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(math.floor(n))
end

local function updateFarmStats()
    if not FarmLabels.elapsed then return end
    local elapsed = FarmState.StartTime > 0 and (tick() - FarmState.StartTime) or 0
    local goldNow = getPlayerGold()
    local goldGained = math.max(0, goldNow - FarmState.StartGold)
    local blocksNow = getUserBlockCount("GoldBlock")
    local blocksGained = math.max(0, blocksNow - FarmState.StartGoldBlocks)
    local perHour = elapsed > 0 and (goldGained / elapsed) * 3600 or 0
    FarmLabels.elapsed:Set("Elapsed Time: " .. formatTime(elapsed))
    FarmLabels.blocks:Set("Gold Blocks Gained: " .. blocksGained)
    FarmLabels.gold:Set("Gold Gained: " .. goldGained)
    FarmLabels.perHour:Set("Gold Per Hour: " .. formatNumber(perHour))
end

local function farmNotify(title, content)
    if not FarmState.Silent then
        Notify({Title = title, Content = content, Duration = 3})
    end
end

local function saveFarmConfig()
    if not writefile then return end
    local data = HttpService:JSONEncode({
        AntiAfk = FarmState.AntiAfk,
        Silent = FarmState.Silent,
        WebhookUrl = FarmState.WebhookUrl,
        WebhookInterval = FarmState.WebhookInterval,
        WebhookActive = FarmState.WebhookActive,
    })
    pcall(function() writefile(FARM_CONFIG_PATH, data) end)
    farmNotify(L("config"), L("farm_saved"))
end

local function loadFarmConfig()
    if not readfile or not isfile or not isfile(FARM_CONFIG_PATH) then return end
    local ok, raw = pcall(readfile, FARM_CONFIG_PATH)
    if not ok or not raw then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and data then
        FarmState.AntiAfk = data.AntiAfk ~= false
        FarmState.Silent = data.Silent == true
        FarmState.WebhookUrl = data.WebhookUrl or ""
        FarmState.WebhookInterval = tonumber(data.WebhookInterval) or 60
        FarmState.WebhookActive = data.WebhookActive == true
    end
end

loadFarmConfig()

local VirtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
    if FarmState.AntiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

task.spawn(function()
    while true do
        if FarmState.Enabled then updateFarmStats() end
        if FarmState.WebhookActive and FarmState.WebhookUrl ~= "" and httprequest then
            if not FarmState._lastHook then FarmState._lastHook = 0 end
            if tick() - FarmState._lastHook >= FarmState.WebhookInterval then
                FarmState._lastHook = tick()
                local elapsed = FarmState.StartTime > 0 and (tick() - FarmState.StartTime) or 0
                local goldGained = math.max(0, getPlayerGold() - FarmState.StartGold)
                pcall(function()
                    httprequest({
                        Url = FarmState.WebhookUrl,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = HttpService:JSONEncode({
                            content = string.format("BABFT Farm | %s | Gold: +%d | %.1fK/h", formatTime(elapsed), goldGained, (elapsed > 0 and (goldGained/elapsed)*3600/1000 or 0)),
                        }),
                    })
                end)
            end
        end
        task.wait(1)
    end
end)


local Core = {}
Core.Init = function(opts)
    if opts and opts.Notify then
        notifyImpl = opts.Notify
    end
    local pngOk, pngErr = pcall(getPNGLib)
    if pngOk then
        Notify({Title = "BABFT", Content = L("png_ok"), Duration = 5})
    else
        Notify({Title = L("png_err"), Content = tostring(pngErr), Duration = 8})
    end
end
Core.Cleanup = function()
    Config.IsBuilding = false
    FarmState.Enabled = false
    _G.FarmEnabled = false
    pcall(function() clearPreview(true) end)
end
Core.Notify = function(opts) notifyImpl(opts) end
Core.L = L
Core.I18N = I18N
Core.Config = Config
Core.BlockTypes = BlockTypes
Core.getLocale = function() return Locale end
Core.setLocale = function(v) Locale = v; BABFTBridge.Locale = v; saveSettings() end
Core.saveSettings = saveSettings
Core.loadSettings = loadSettings
Core.setStatus = setStatus
Core.getImageFileList = getImageFileList
Core.loadLocalImageByName = loadLocalImageByName
Core.fetchImageFromUrl = fetchImageFromUrl
Core.applyLoadedImage = applyLoadedImage
Core.recompressLoadedImage = recompressLoadedImage
Core.buildPreview = buildPreview
Core.clearPreview = clearPreview
Core.buildImage = buildImage
Core.movePreview = movePreview
Core.rotatePreview = rotatePreview
Core.getUserBlockCount = getUserBlockCount
Core.getModelFileList = getModelFileList
Core.loadOBJByName = loadOBJByName
Core.getBuildZone = getBuildZone
Core.getPlayerGold = getPlayerGold
Core.FarmState = FarmState
Core.FarmLabels = FarmLabels
Core.saveFarmConfig = saveFarmConfig
Core.loadFarmConfig = loadFarmConfig
Core.farmNotify = farmNotify
Core.getPNGLib = getPNGLib
Core.setPreviewToggle = function(t) previewToggle = t end
Core.setStatusLabel = function(l) StatusLabel = l end
Core.setModelStatusLabel = function(l) ModelStatusLabel = l end
return Core
