local m = {}

-- Made by Doug Currie (https://stackoverflow.com/users/33252/doug-currie)
-- on Stack Overflow. https://stackoverflow.com/questions/1283388/lua-merge-tables
function m.merge_tables(from, to)
    for k,v in pairs(from) do to[k] = v end
end

return m
