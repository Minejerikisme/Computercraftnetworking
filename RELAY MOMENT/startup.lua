local possible = {}
Stand = require("standard")
local sha1 = require("sha")
Maxrange = 290
Currentx,Currenty,temp = gps.locate(5)

if Currentx == nil then
    print("gps not working")
    return
end

print("Currentx: "..Currentx)

rednet.open('top')

local cc = Stand.getfiletable("data/cc.md")
local rc = Stand.getfiletable("data/rc.md")
local rn = Stand.getfiletable("data/rn.md")

local function cleartable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function max(a)
    local values = {}

    for k, v in pairs(a) do
        values[#values + 1] = v
    end
    table.sort(values)
    return values[#values]
end

local function checkmessagehash(message, hash)
    local temp = sha1.hex(message)
    if temp == hash then
        print("true hash")
        return true
    else
        print("false hash")
        return false
    end
end

local function returnMin(t)
    local k
    for i, v in pairs(t) do
        k = k or i
        if v < t[k] then
            k = i
        end
    end
    return k
end

local temp
local temp2
local tempt = {}

local function sendmessage(message, to, protical)
    print("sending " .. message .. " to " .. to.." with protical "..protical)
    rednet.send(to, message, protical)
end

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function finddistancetorelay(relaynum)
    temp = string.find(rc[relaynum], ",")
    local tempxc = tonumber(string.sub(rc[relaynum], 0, temp - 1))
    local tempyc = tonumber(string.sub(rc[relaynum], temp + 1))
    if distance(Currentx, Currenty, tempxc, tempyc) <= Maxrange then
        table.insert(tempt, relaynum)
    else
        return
    end
end

local function finddistancefromrelay(relaynum, reciever)
    temp = string.find(cc[reciever], ",")
    local tempxc = tonumber(string.sub(cc[reciever], 0, temp - 1))
    local tempyc = tonumber(string.sub(cc[reciever], temp + 1))
    temp = string.find(rc[relaynum], ",")
    local dis =
        distance(
        tempxc,
        tempxc,
        tonumber(string.sub(rc[relaynum], 0, temp - 1)),
        tonumber(string.sub(rc[relaynum], temp + 1))
    )
    table.insert(tempt, dis)
    table.insert(possible, relaynum)
end

local function findrelay(reciever)
    cleartable(tempt)
    cleartable(possible)
    for i = 1, Stand.getlength(rc), 1 do
        finddistancetorelay(i)
    end
    temp = max(tempt)
    temp2 = Stand.getlength(tempt)
    cleartable(tempt)
    for i = 1, temp2, 1 do
        finddistancefromrelay(i, reciever)
    end
    temp = returnMin(tempt)
    return rn[possible[temp]]
end





local function proticallcheck(reciever,protical, message)
    if protical == "RELAY_CC" then
        Stand.setfileline("data/cc.md", message, reciever)
        return true
    else
        if protical == "RELAY_RC" then
            Stand.setfileline("data/rc.md", message, reciever)
            return true
        else
            if protical == "RELAY_RN" then
                Stand.setfileline("data/rn.md", message, reciever)
                return true
            else
                if protical == "RELAY_UPDATE" then
                    dofile("updater.lua")
                else
                    return false
                end
            end
        end
    end
end





local function main(input, protical)
    temp = string.find(input, ",")
    local reciever = tonumber(string.sub(input, 0, temp - 1))
    local message = string.sub(input, temp + 1)
    temp = string.find(message, ",")
    local hash = string.sub(message, temp + 1)
    message = string.sub(input, 0, temp + 1)
    temp = string.find(input, ",")
    message = string.sub(message, temp + 1)
    if checkmessagehash(message, hash) == false then
        return
    end
    if proticallcheck(reciever,protical, message) == true then
        return
    end
    temp = string.find(cc[reciever], ".")
    local tempxc = tonumber(string.sub(cc[reciever], 0, temp - 1))
    local tempyc = tonumber(string.sub(cc[reciever], temp + 1))
    local dis = distance(Currentx, Currenty, tempxc, tempyc)
    if dis >= Maxrange then
        print("finding relay")
        temp = findrelay(reciever)
        sendmessage(input, temp,protical)
    else
        print("sending direct")
        sendmessage(message .. "," .. hash, reciever,protical)
    end
end

while true do
    local event, sender, message, protocol = os.pullEvent("rednet_message")
    main(message,protocol)
end


--