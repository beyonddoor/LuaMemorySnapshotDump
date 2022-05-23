local assert=assert
local print=print

assert(_G ~= nil)


module('TestModule')


assert(_G == nil)

local _Val1 = {name='a local value'}
local _UpValue_Do = {name= 'a upvalue ref by local function _Do'}
local function _Do()
    print("private function _Do")
    print(_UpValue_Do.name)
end

local _UpValue_Do2 = {name= 'a upvalue ref by local function _Do2'}
local function _Do2()
    print("private function _Do2")
    print(_UpValue_Do2.name)
end

local _UpValue = {name= 'a upvalue'}
function Show()
    print("public method")
    print(_UpValue)

    _Do2()
end

GlobalVar2 = 'global var'

Person={
    name='John',
    age='20',
}

