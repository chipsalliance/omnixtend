tilelink_protocol = Proto("TileLink", "TileLink Protocol")
local tilelink_ethertype = 0x0000
local tilelink_ethertype2 = 0x0870

local channels = {
    [0] = "A",
    [1] = "B",
    [2] = "C",
    [3] = "D",
    [4] = "E",
    [5] = "F",
    [6] = "User",
    [7] = "Escape"
}


local opcode_names = {
    [0] = {
        [0] = "Put Full",
        [1] = "Put Part",
        [2] = "Arithmetic",
        [3] = "Logical",
        [4] = "Get",
        [5] = "Intent",
        [6] = "Acquire"
    },
    [1] = {
        [0] = "Put Full",
        [1] = "Put Part",
        [2] = "Arithmetic",
        [3] = "Logical",
        [4] = "Get",
        [5] = "Intent",
        [6] = "Probe"
    },
    [2] = {
        [0] = "Access Ack",
        [1] = "Access AckD",
        [2] = "Hint Ack",
        [3] = "C Invalid",
        [4] = "Probe Ack",
        [5] = "Probe AckD",
        [6] = "Release",
        [7] = "Release Data"
    },
    [3] = {
        [0] = "Access Ack",
        [1] = "Access AckD",
        [2] = "Hint Ack",
        [3] = "D Invalid",
        [4] = "Grant",
        [5] = "GrantD",
        [6] = "Release Ack"
    },
    [4] = {
        [0] = "Grant Ack"
    },
    [5] = {
        [0] = "Credits"
    },
    [6] = {
        [0] = "User"
    },
    [7] = {
        [0] = "Escape"
    }
}


reserved = ProtoField.uint16("tilelink.reserved", "reserved", base.DEC)
source = ProtoField.uint32("tilelink.source", "source", base.DEC, nil, 0xFFFF0000)
domain = ProtoField.uint32("tilelink.domain", "domain", base.DEC, nil, 0x0000E000)
m_size = ProtoField.uint32("tilelink.m_size", "m_size", base.DEC, nil, 0x1E00)
param = ProtoField.uint32("tilelink.param", "param", base.DEC, nil, 0x01C0)
opcode = ProtoField.uint32("tilelink.opcode", "opcode", base.DEC, nil, 0x0038)
channel = ProtoField.uint32("tilelink.channel", "channel", base.DEC, channels, 0x007)
-- Channel A,B and C: Address
hi_address = ProtoField.uint32("tilelink.hi_address", "hi_address", base.HEX)
lo_address = ProtoField.uint32("tilelink.lo_address", "lo_address", base.HEX)
-- Channel D: Grant & Grant Data
d_reserved = ProtoField.uint32("tilelink.d_reserved", "d_reserved", base.HEX, nill, 0xFFFF0000)
sink = ProtoField.uint32("tilelink.sink", "sink", base.DEC, nill, 0x0000FFFF)

-- Channel F Header
ecredit = ProtoField.uint32("tilelink.ECredit", "ECredit", base.DEC, nil, 0xF8000000)
dcredit = ProtoField.uint32("tilelink.DCredit", "DCredit", base.DEC, nil, 0x07C00000)
ccredit = ProtoField.uint32("tilelink.CCredit", "CCredit", base.DEC, nil, 0x003E0000)
bcredit = ProtoField.uint32("tilelink.BCredit", "BCredit", base.DEC, nil, 0x0001F000)
acredit = ProtoField.uint32("tilelink.ACredit", "ACredit", base.DEC, nil, 0x00000F80)
zero = ProtoField.uint32("tilelink.zero", "zero", base.DEC, nil,          0x00000078)

data = ProtoField.bytes("abd.data", "data")

tilelink_protocol.fields = {
    reserved,
    source, domain, m_size, param, opcode,
    ecredit, dcredit, ccredit, bcredit, acredit, zero,
    channel,
    lo_address,
    hi_address,
    d_reserved,
    sink,
    data
}


function tilelink_protocol.dissector(buffer, pinfo, tree)
    length = buffer:len()
    if length == 0 then return end

    pinfo.cols.protocol = tilelink_protocol.name
    pinfo.cols.info = " "
    local subtree = tree:add(tilelink_protocol, buffer(), "TileLink Protocol")

    local header = buffer(2,4):uint()

    local chan_num = bit.band(header, 0x7)

    if (chan_num == 5) then
        local zeros = bit.rshift(bit.band(header, 0x00000078), 3)
        local acred = bit.rshift(bit.band(header, 0x00000F80), 7)
        local bcred = bit.rshift(bit.band(header, 0x0001F000), 12)
        local ccred = bit.rshift(bit.band(header, 0x003E0000), 17)
        local dcred = bit.rshift(bit.band(header, 0x07C00000), 22)
        local ecred = bit.rshift(bit.band(header, 0xF8000000), 27)
        pinfo.cols.info:append(string.format("Credits: A:%u B:%u C:%u D:%u E:%u",
                                acred, bcred, ccred, dcred, ecred))
        subtree:add(ecredit, buffer(2,4))
        subtree:add(dcredit, buffer(2,4))
        subtree:add(ccredit, buffer(2,4))
        subtree:add(bcredit, buffer(2,4))
        subtree:add(acredit, buffer(2,4))
        subtree:add(zero, buffer(2,4))
        subtree:add(channel, buffer(2,4))
        return
    end
    local src = bit.rshift(bit.band(header, 0xFFFF0000), 16)

    local dom = bit.rshift(bit.band(header, 0xE000), 13)
    local size = bit.rshift(bit.band(header, 0x1E00), 9)
    local parm = bit.rshift(bit.band(header, 0x01C0), 6)
    local op_num = bit.rshift(bit.band(header, 0x0038), 3)


    pinfo.cols.info:append(string.format(" source: %05u", src))
    pinfo.cols.info:append(string.format(" domain: %01u", dom))
    pinfo.cols.info:append(string.format(" size: %02u", size))
    pinfo.cols.info:append(string.format(" parm: %01u", parm))
    pinfo.cols.info:append(string.format(" [%s][%d] %-12s", channels[chan_num],
                                    op_num, opcode_names[chan_num][op_num]))


    subtree:add(reserved, buffer(0, 2))
    subtree:add(source, buffer(2, 4))
    subtree:add(domain, buffer(2, 4))
    subtree:add(m_size, buffer(2, 4))
    subtree:add(param, buffer(2, 4))
    subtree:add(opcode, buffer(2, 4))
    subtree:add(channel, buffer(2, 4))

    if (chan_num == 0 or chan_num == 1 or chan_num == 2) then
        local hi_addr = buffer(6,4):uint()
        local lo_addr = buffer(10,4):uint()
        pinfo.cols.info:append(string.format(" Addr: 0x%08x", hi_addr))
        pinfo.cols.info:append(string.format(" %08x", lo_addr))
        subtree:add(hi_address, buffer(6, 4))
        subtree:add(lo_address, buffer(10, 4))
        if (op_num <= 3) then
            subtree:add(data, buffer(14, length-14))
        end
    elseif (chan_num == 3) then
        if (op_num == 4 or op_num == 5) then
            local d_resv_sink = buffer(6,4):le_uint()
            local d_resv = bit.rshift(bit.band(d_resv_sink, 0xFFFF0000), 16)
            local d_sink = bit.band(d_resv_sink, 0xFFFF)
            pinfo.cols.info:append(string.format(" sink: %05u", d_sink))
            subtree:add(d_reserved, buffer(6, 4))
            subtree:add(sink, buffer(6, 4))
            subtree:add(data, buffer(10, length-10))
        end
    else
        subtree:add(data, buffer(6, length-6))
    end
end



local eth_table = DissectorTable.get ("ethertype")
eth_table:add(tilelink_ethertype, tilelink_protocol)
eth_table:add(tilelink_ethertype2, tilelink_protocol)
