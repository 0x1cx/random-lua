local _0xD=function(b)local r=""for i=1,#b do r=r..string.char(b[i])end return r end
local _0x00=math.floor
local _0x01=math.abs
local _0x02=math.atan2
local _0x03=math.cos
local _0x04=math.sin
local _0x05=math.sqrt
local _0x06=math.pi

local _0x10=game:GetService(_0xD({80,108,97,121,101,114,115}))
local _0x11=_0x10.LocalPlayer
local _0x12=workspace.CurrentCamera

_G[_0xD({106,117,109,112,99,111,110,102,105,103})]={
    [_0xD({77,111,100,101})]=_0xD({83,110,97,112}),
    [_0xD({69,110,97,98,108,101,100})]=true
}

local _0x20=false
local _0x21=false
local _0x22=false
local _0x23=_0xD({83,110,97,112})
local _0x24=_0xD({70,114,101,101})
local _0x25=_0xD({102,108,111,97,116})
local _0x26=_0xD({117,105,110,116,112,116,114,95,116})
local _0x27=_0xD({72,117,109,97,110,111,105,100,82,111,111,116,80,97,114,116})

local _0x30={192,264}
local _0x31={
    {0,0},{4,0},{8,1},{12,0},{16,0},{20,0},{24,0},{28,0},{32,0}
}

pcall(function()
    notify(_0xD({76,111,97,100,101,100}),_0xD({74,82}),2)
end)

spawn(function()
    while true do
        if iskeypressed(66) then
            if not _0x22 then
                _0x22=true
                local _c=_G.jumpconfig
                _c.Mode=_c.Mode==_0x23 and _0x24 or _0x23
                pcall(function()notify(_c.Mode,_0xD({74,82}),2)end)
            end
        else
            _0x22=false
        end

        if _G.jumpconfig.Enabled and _0x11.Character then
            local _0x40=_0x11.Character:FindFirstChild(_0x27)
            if _0x40 then
                local _0x41=_0x40.Velocity
                local _0x42=_0x41.Y
                local _0x43=_G.jumpconfig.Mode

                if not _0x21 and _0x42>3 then
                    _0x21=true
                    _0x20=false
                end

                if _0x21 and _0x01(_0x42)<0.5 then
                    _0x21=false
                    _0x20=false
                end

                local _0x44=false
                if _0x21 then
                    if _0x43==_0x24 then
                        _0x44=true
                    elseif _0x43==_0x23 and not _0x20 then
                        _0x44=true
                        _0x20=true
                    end
                end

                if _0x44 then
                    local _0x50=_0x12.Position
                    local _0x51=_0x40.Position
                    local _0x52=_0x51.X-_0x50.X
                    local _0x53=_0x51.Z-_0x50.Z
                    local _0x54=_0x02(_0x52,_0x53)+_0x06
                    local _c=_0x03(_0x54)
                    local _s=_0x04(_0x54)
                    local _p=memory_read(_0x26,_0x40.Address+328)

                    for _,_off in pairs(_0x30) do
                        memory_write(_0x25,_p+_off,_c)
                        memory_write(_0x25,_p+_off+4,0)
                        memory_write(_0x25,_p+_off+8,_s)
                        memory_write(_0x25,_p+_off+12,0)
                        memory_write(_0x25,_p+_off+16,1)
                        memory_write(_0x25,_p+_off+20,0)
                        memory_write(_0x25,_p+_off+24,-_s)
                        memory_write(_0x25,_p+_off+28,0)
                        memory_write(_0x25,_p+_off+32,_c)
                    end
                end
            end
        end
        task.wait()
    end
end)