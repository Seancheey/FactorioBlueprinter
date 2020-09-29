--[[
  Copyright (C) 2017 Masatoshi Teruya
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
  lib/minheap.lua
  lua-minheap
  Created by Masatoshi Teruya on 17/03/01.
--]]


--- isLessThen
-- @param newNum
-- @param nodeNum
-- @return ok
local function isLessThen(newNum, nodeNum)
    return newNum < nodeNum;
end


--- @class MinHeap
--- @type MinHeap
MinHeap = {};

--- heapDown
-- @param arr
-- @param len
-- @param idx
function MinHeap:heapDown(arr, len, idx)
    local node = arr[idx];
    local hsize = math.floor(len / 2);

    while idx < hsize do
        local left = idx * 2 + 1;
        local right = left + 1;
        local child = arr[left];

        if right < len then
            if self.lessFunc(arr[right].num, child.num) then
                left = right;
                child = arr[right];
            end
        end

        if not self.lessFunc(child.num, node.num) then
            break ;
        end

        child.idx = idx;
        arr[idx] = child;
        idx = left;
    end

    node.idx = idx;
    arr[idx] = node;
end


--- isEmpty
-- @return ok
function MinHeap:isEmpty()
    return self.len == 0;
end


--- peek
-- @return rootNode
function MinHeap:peek()
    return self.arr[0];
end


--- push
-- @param num
-- @param val
-- @return node
function MinHeap:push(num, val)
    local arr = self.arr;
    local idx = self.len;
    local node = { num = num, val = val, idx = idx };

    self.len = idx + 1;
    arr[idx] = node;

    while idx > 0 do
        local prev = math.floor((idx - 1) / 2);
        local parent = arr[prev];

        if not self.lessFunc(num, parent.num) then
            break ;
        end

        parent.idx = idx;
        arr[idx] = parent;
        idx = prev;
    end

    arr[idx] = node;
    node.idx = idx;

    return node;
end


--- pop
-- @return rootNode
function MinHeap:pop()
    return self:del(0);
end


--- del
-- @param idx
-- @return node
function MinHeap:del(idx)
    local arr = self.arr;
    local node = arr[idx];

    if node then
        local len = self.len - 1;

        if idx == len then
            self.len = len;
            arr[idx] = nil;
        else
            self.len = len;
            arr[idx] = arr[len];
            arr[len] = nil;
            self:heapDown(arr, self.len, idx);
        end
    end

    return node;
end

--- new
--- @return MinHeap
function MinHeap.new(lessThanFunc)
    return setmetatable({
        arr = {},
        len = 0,
        lessFunc = lessThanFunc or isLessThen
    }, {
        __index = MinHeap
    })
end