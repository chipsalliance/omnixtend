-- Copyright 2019-present Western Digital Corporation
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Author: Tu Dang (tu.dang@wdc.com)

tilelink_protocol = Proto("TileLink", "TileLink Protocol")
local tilelink_ethertype = 0x0870

local channels = {
    [0] = "Padding",
    [1] = "A",
    [2] = "B",
    [3] = "C",
    [4] = "D",
    [5] = "E",
    [6] = "F",
    [7] = "User"
}


local opcode_names = {
    [1] = {
        [0] = "Put Full",
        [1] = "Put Part",
        [2] = "Arithmetic",
        [3] = "Logical",
        [4] = "Get",
        [5] = "Intent",
        [6] = "AcquireBlock",
        [7] = "AcquirePerm"
    },
    [2] = {
        [0] = "Put Full",
        [1] = "Put Part",
        [2] = "Arithmetic",
        [3] = "Logical",
        [4] = "Get",
        [5] = "Intent",
        [6] = "ProbeBlock",
        [7] = "ProbePerm"
    },
    [3] = {
        [0] = "Access Ack",
        [1] = "Access Ack Data",
        [2] = "Hint Ack",
        [3] = "C Invalid",
        [4] = "Probe Ack",
        [5] = "Probe Ack Data",
        [6] = "Release",
        [7] = "Release Data"
    },
    [4] = {
        [0] = "Access Ack",
        [1] = "Access AckD",
        [2] = "Hint Ack",
        [3] = "D Invalid",
        [4] = "Grant",
        [5] = "GrantData",
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

fc_vc = ProtoField.uint32("tilelink.vc", "virtual_circuit", base.DEC, nil, 0xE0000000)
fc_res1 = ProtoField.uint32("tilelink.res1", "res1", base.DEC, nil, 0x1FC00000)
fc_sequence_num = ProtoField.uint32("tilelink.seq_num", "sequence_num", base.DEC, nil, 0x003FFFFF)
fc_seq_num_ack = ProtoField.uint32("tilelink.seq_num_ack", "sequence_num_ack", base.DEC, nil, 0xFFFFFC00)
fc_ack = ProtoField.uint32("tilelink.ack", "ack", base.DEC, nil, 0x00000200)
fc_res2 = ProtoField.uint32("tilelink.res2", "res2", base.DEC, nil, 0x00000100)
fc_channel = ProtoField.uint32("tilelink.credit_channel", "credit_channel", base.DEC, nil, 0x000000E0)
fc_credit = ProtoField.uint32("tilelink.credit", "credit", base.DEC, nil, 0x0000001F)


channel = ProtoField.uint32("tilelink.channel", "channel", base.DEC, channels, 0x70000000)
opcode = ProtoField.uint32("tilelink.opcode", "opcode", base.DEC, channels, 0x0E000000)
param = ProtoField.uint32("tilelink.param", "param", base.DEC, nil, 0x00F00000)
m_size = ProtoField.uint32("tilelink.m_size", "m_size", base.DEC, nil, 0x000F0000)
domain = ProtoField.uint32("tilelink.domain", "domain", base.DEC, nil, 0x0000FF00)
err = ProtoField.uint32("tilelink.err", "error", base.DEC, nil, 0x000000C0)
source = ProtoField.uint32("tilelink.source", "source", base.DEC, nil, 0xFFFFFFC0)
-- Channel A,B and C: Address
hi_address = ProtoField.uint32("tilelink.hi_address", "hi_address", base.HEX)
lo_address = ProtoField.uint32("tilelink.lo_address", "lo_address", base.HEX)
-- Channel D: Grant & Grant Data
sink = ProtoField.uint32("tilelink.sink", "sink", base.DEC, nill, 0xFFFFFFC0)
-- Channel F Header
data = ProtoField.bytes("abd.data", "data")

tilelink_protocol.fields = {
  fc_vc, fc_res1, fc_sequence_num, fc_seq_num_ack, fc_ack, fc_res2, fc_channel, fc_credit,
  channel, opcode, param, m_size, domain, err, source,
  hi_address,
  lo_address,
  sink,
  data
}


function tilelink_protocol.dissector(buffer, pinfo, tree)
    length = buffer:len()
    if length == 0 then return end

    pinfo.cols.protocol = tilelink_protocol.name
    pinfo.cols.info = " "
    local subtree = tree:add(tilelink_protocol, buffer(), "TileLink Protocol")

    local offset = 0

    subtree:add(fc_vc, buffer(offset, 4))
    subtree:add(fc_res1, buffer(offset, 4))
    subtree:add(fc_sequence_num, buffer(off, 4))
    subtree:add(fc_seq_num_ack, buffer(offset + 4, 4))
    subtree:add(fc_ack, buffer(offset + 4, 4))
    subtree:add(fc_res2, buffer(offset + 4, 4))
    subtree:add(fc_channel, buffer(offset + 4, 4))
    subtree:add(fc_credit, buffer(offset + 4, 4))

    tilelink_offset = 8

    local header = buffer(tilelink_offset,4):uint()

    local chan_num = bit.rshift(bit.band(header, 0x70000000), 28)
    local op_num = bit.rshift(bit.band(header, 0x0E000000),25)
    local parm = bit.rshift(bit.band(header, 0x00F00000),20)
    local size = bit.rshift(bit.band(header, 0x000F0000),16)
    local domain_num = bit.rshift(bit.band(header, 0x0000FF00),8)
    local err_num = bit.rshift(bit.band(header, 0x000000C0),6)
    local src_num = bit.rshift(bit.band(buffer(tilelink_offset+4,4):uint(), 0xFFFFFFC0), 6)


    pinfo.cols.info:append(string.format(" [%s][%d] %-12s", channels[chan_num],
                                    op_num, opcode_names[chan_num][op_num]))
    -- pinfo.cols.info:append(string.format(" [%s][%d]", channels[chan_num], op_num))
    pinfo.cols.info:append(string.format(" parm: %01u", parm))
    pinfo.cols.info:append(string.format(" size: %02u", size))
    pinfo.cols.info:append(string.format(" domain: %01u", domain_num))
    pinfo.cols.info:append(string.format(" err: %01u", err_num))
    pinfo.cols.info:append(string.format(" source: %05u", src_num))


    subtree:add(channel, buffer(tilelink_offset, 4))
    subtree:add(opcode, buffer(tilelink_offset, 4))
    subtree:add(param, buffer(tilelink_offset, 4))
    subtree:add(m_size, buffer(tilelink_offset, 4))
    subtree:add(domain, buffer(tilelink_offset, 4))
    subtree:add(err, buffer(tilelink_offset, 4))
    subtree:add(source, buffer(tilelink_offset+4, 4))

    if (chan_num == 1 or chan_num == 2 or chan_num == 3) then
        local hi_addr = buffer(tilelink_offset+8,4):uint()
        local lo_addr = buffer(tilelink_offset+12,4):uint()
        pinfo.cols.info:append(string.format(" Addr: 0x%08x", hi_addr))
        pinfo.cols.info:append(string.format(" %08x", lo_addr))
        subtree:add(hi_address, buffer(tilelink_offset+8, 4))
        subtree:add(lo_address, buffer(tilelink_offset+12, 4))
        if (op_num <= 3) then
            subtree:add(data, buffer(tilelink_offset+16, length-(tilelink_offset+16)))
        end
    elseif (chan_num == 4) then
        if (op_num == 4 or op_num == 5) then
            local d_resv_sink = buffer(tilelink_offset+8,4):le_uint()
            pinfo.cols.info:append(string.format(" sink: %05u", d_resv_sink))
            subtree:add(sink, buffer(tilelink_offset+8, 4))
            subtree:add(data, buffer(tilelink_offset+16, length-(tilelink_offset+16)))
        end
    else
        subtree:add(data, buffer(tilelink_offset+8, length-(tilelink_offset+8)))
    end
end



local eth_table = DissectorTable.get ("ethertype")
eth_table:add(tilelink_ethertype, tilelink_protocol)
