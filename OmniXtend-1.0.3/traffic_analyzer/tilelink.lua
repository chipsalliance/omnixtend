
local channels = {
    [0] = "0",
    [1] = "A",
    [2] = "B",
    [3] = "C",
    [4] = "D",
    [5] = "E",
    [6] = "F",
    [7] = "User"
}


local opcode_names = {
    [0] = {
      [0] = "Padding"
    },
    [1] = {
        [0] = "Put Full",
        [1] = "Put Part",
        [2] = "Arithmetic",
        [3] = "Logical",
        [4] = "Get",
        [5] = "Intent",
        [6] = "Acquire"
    },
    [2] = {
        [0] = "Put Full",
        [1] = "Put Part",
        [2] = "Arithmetic",
        [3] = "Logical",
        [4] = "Get",
        [5] = "Intent",
        [6] = "Probe"
    },
    [3] = {
        [0] = "Access Ack",
        [1] = "Access AckD",
        [2] = "Hint Ack",
        [3] = "C Invalid",
        [4] = "Probe Ack",
        [5] = "Probe AckD",
        [6] = "Release",
        [7] = "Release Data"
    },
    [4] = {
        [0] = "Access Ack",
        [1] = "Access AckD",
        [2] = "Hint Ack",
        [3] = "D Invalid",
        [4] = "Grant",
        [5] = "GrantD",
        [6] = "Release Ack"
    },
    [5] = {
        [0] = "Grant Ack"
    },
    [6] = {
        [0] = "Credits"
    },
    [7] = {
        [0] = "User"
    }
}


-- TileLink
m = {
	channel = ProtoField.uint32("TileLink.channel", "channel", base.DEC, channels, 0x70000000),
	opcode = ProtoField.uint32("TileLink.opcode", "opcode", base.DEC, nil, 0x0E000000),
	param = ProtoField.uint32("TileLink.param", "param", base.DEC, nil, 0x00F00000),
	m_size = ProtoField.uint32("TileLink.m_size", "m_size", base.DEC, nil, 0x000F0000),
	domain = ProtoField.uint32("TileLink.domain", "domain", base.DEC, nil, 0x0000FF00),
	source = ProtoField.uint32("TileLink.source", "source", base.DEC, nil, 0x003FFFFF),
	sink = ProtoField.uint32("TileLink.sink", "sink", base.DEC, nil, 0x003FFFFF),
	address_hi = ProtoField.uint32("TileLink.address_hi", "address_hi", base.HEX, nil, 0xFFFFFFFF),
	address_lo = ProtoField.uint32("TileLink.address_lo", "address_lo", base.HEX, nil, 0xFFFFFFFF),
	pad_hi = ProtoField.uint32("TileLink.pad_hi", "pad_hi", base.HEX, nil, 0xFFFFFFFF),
	pad_lo = ProtoField.uint32("TileLink.pad_lo", "pad_lo", base.HEX, nil, 0xFFFFFFFF),
  data = ProtoField.bytes("TileLink.data", "data")

}

function m.get_fields()
	local fields = {
		channel = m.channel,
		opcode = m.opcode,
		param = m.param,
		m_size = m.m_size,
		domain = m.domain,
		source = m.source,
		sink = m.sink,
		address_hi = m.address_hi,
		address_lo = m.address_lo,
    pad_hi = m.pad_hi,
    pad_lo = m.pad_lo,
    data = m.data
	}

	return fields
end

function m.parse(message_subtree, pinfo, buffer, offset)
	local message_buf_hi = buffer(offset, 4)
  offset = offset + 4
	local message_buf = buffer(offset, 4)
  offset = offset + 4

	local channel = bit.band(bit.rshift(message_buf_hi:uint(), 28), 7)
	local opcode = bit.band(bit.rshift(message_buf_hi:uint(), 25), 7)
	-- pinfo.cols.info:append(string.format(" %d %d", channel, opcode))
	pinfo.cols.info:append(string.format(" %s", opcode_names[channel][opcode]))
  if channel == 0 then
    message_subtree:add(m.pad_hi, message_buf_hi)
    message_subtree:add(m.pad_lo, message_buf)
  elseif channel > 0 and channel < 4 then
    message_subtree:add(m.channel, message_buf_hi)
    message_subtree:add(m.opcode, message_buf_hi)
    message_subtree:add(m.param, message_buf_hi)
    message_subtree:add(m.m_size, message_buf_hi)
    message_subtree:add(m.domain, message_buf_hi)
    message_subtree:add(m.source, message_buf)
    local addr_hi = buffer(offset,4):uint()
    message_subtree:add(m.address_hi, buffer(offset,4))
    offset = offset + 4
    local addr_lo = buffer(offset,4):uint()
    message_subtree:add(m.address_lo, buffer(offset,4))
    offset = offset + 4
    pinfo.cols.info:append(string.format(" 0x%08x", addr_hi))
    pinfo.cols.info:append(string.format("-%08x", addr_lo))
    if channel == 3 and (opcode == 1 or opcode == 5 or opcode == 7) then
      local data_size = 2^bit.band(bit.rshift(message_buf_hi:uint(), 16), 0x000F)
      pinfo.cols.info:append(string.format(" data_size %u", data_size))
      message_subtree:add(m.data, buffer(offset, data_size))
      offset = offset + data_size
    end

  elseif channel == 4 then
    message_subtree:add(m.channel, message_buf_hi)
    message_subtree:add(m.opcode, message_buf_hi)
    message_subtree:add(m.param, message_buf_hi)
    message_subtree:add(m.m_size, message_buf_hi)
    message_subtree:add(m.domain, message_buf_hi)
    message_subtree:add(m.source, message_buf)
    offset = offset + 4
    local sink = buffer(offset, 4):uint()
    pinfo.cols.info:append(string.format(" sink# %u", sink))
    message_subtree:add(m.sink, buffer(offset, 4))
    offset = offset + 4
    if opcode == 1 or opcode == 5 then
      local data_size = 2^bit.band(bit.rshift(message_buf_hi:uint(), 16), 0x000F)
      pinfo.cols.info:append(string.format(" DATA size %u ", data_size))
      message_subtree:add(m.data, buffer(offset, data_size))
      offset = offset + data_size
    end
  elseif channel == 5 then
    message_subtree:add(m.sink, buffer(offset,4))
    local sink = buffer(offset, 4):uint()
    pinfo.cols.info:append(string.format(" sink# %u", sink))
  end
  return offset
end

return m
