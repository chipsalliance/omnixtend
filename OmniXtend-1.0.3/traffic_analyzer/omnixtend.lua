package.prepend_path("omnixtend")
local helpers = require("helpers")
local header = require("header")
local tilelink = require("tilelink")

omnixtend_protocol = Proto("OmniXtend", "OmniXtend Protocol")
local omnixtend_ethertype = 0xaaaa

local header_fields = header.get_fields()
local tilelink_fields = tilelink.get_fields()

helpers.merge_tables(header_fields, omnixtend_protocol.fields)
helpers.merge_tables(tilelink_fields, omnixtend_protocol.fields)


function omnixtend_protocol.dissector(buffer, pinfo, tree)
    length = buffer:len()
    if length == 0 then return end

    pinfo.cols.protocol = omnixtend_protocol.name
    pinfo.cols.info = " "
    -- pinfo.cols.info:append(string.format(" length %u", length))

    local subtree = tree:add(omnixtend_protocol, buffer(), "Omnixtend Header")
    header.parse(subtree, buffer)

    local mesg_num = 1
    local offset = 8
    -- pinfo.cols.info:append(string.format(" length %u ", length))

    -- Minus TLoE Mask (8 bytes)
    while (offset < (length - 8)) do
      -- pinfo.cols.info:append(string.format(" offset %u ", offset))
      local message_subtree = tree:add(omnixtend_protocol, buffer(), string.format("TileLink Message %u", mesg_num))
      mesg_num = mesg_num + 1
      offset = tilelink.parse(message_subtree, pinfo, buffer, offset)
    end

end



local eth_table = DissectorTable.get ("ethertype")
eth_table:add(omnixtend_ethertype, omnixtend_protocol)
