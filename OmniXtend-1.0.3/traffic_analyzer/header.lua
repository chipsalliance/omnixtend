
-- OmniXtend header
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
local m = {
	virtual_circuit = ProtoField.uint32("omnixtend.vc", "vc", base.DEC, nil, 0xE0000000),
	reserved = ProtoField.uint32("omnixtend.reserved", "reserved", base.DEC, nil, 0x1FC00000),
	sequence_number = ProtoField.uint32("omnixtend.sequence_number", "sequence_number", base.HEX, nil, 0x003FFFFF),
	sequence_number_ack = ProtoField.uint32("omnixtend.sequence_number_ack", "sequence_number_ack", base.HEX, nil, 0xFFFFFC00),
	acknowledge = ProtoField.uint32("omnixtend.acknowledge", "acknowledge", base.DEC, nil, 0x00000200),
	reserved2 = ProtoField.uint32("omnixtend.reserved2", "reserved2", base.HEX, nil, 0x00000100),
	credit_channel = ProtoField.uint32("omnixtend.credit_channel", "credit_channel", base.DEC, channels, 0x000000E0),
	credit_num = ProtoField.uint32("omnixtend.credit_num", "credit_num", base.DEC, nil, 0x00000001F)
}

function m.get_fields()
	local fields = {
		virtual_circuit = m.virtual_circuit,
		reserved = m.reserved,
		sequence_number = m.sequence_number,
		sequence_number_ack = m.sequence_number_ack,
		acknowledge = m.acknowledge,
		reserved2 = m.reserved2,
		credit_channel = m.credit_channel,
		credit_num = m.credit_num
	}

	return fields
end

function m.parse(subtree, buffer)
	local header_hi = buffer(0,4)
	local header_buf = buffer(4,4)
	subtree:add(m.virtual_circuit, header_hi)
	subtree:add(m.reserved, header_hi)
	subtree:add(m.sequence_number, header_hi)
	subtree:add(m.sequence_number_ack, header_buf)
	subtree:add(m.acknowledge, header_buf)
	subtree:add(m.reserved2, header_buf)
	subtree:add(m.credit_channel, header_buf)
	subtree:add(m.credit_num, header_buf)
end

return m
