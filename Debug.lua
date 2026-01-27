local SACIProfiler = {
    data = {},
    wrapped = setmetatable({}, { __mode = "k" }), -- weak keys so GC safe
}

local function WrapFunction(self, func, name)
    self.data[name] = self.data[name] or {
        calls = 0,
        total = 0,
        max = 0,
        min = 999,
    }

    local entry = self.data[name]

    return function(...)
        local t0 = debugprofilestop()
        local a,b,c,d,e,f = func(...)
        local dt = debugprofilestop() - t0

        entry.calls = entry.calls + 1
        entry.total = entry.total + dt
        if dt > entry.max then entry.max = dt end
        if dt < entry.min then entry.min = dt end

        return a,b,c,d,e,f
    end
end

function SACIProfiler:HookMixin(mixin, mixinName)
    if self.wrapped[mixin] then return end
    self.wrapped[mixin] = true

    mixinName = mixinName or tostring(mixin)

    for key, value in pairs(mixin) do
        if type(value) == "function" then
            local fullName = mixinName .. "." .. key
            mixin[key] = WrapFunction(self, value, fullName)
        end
    end
end

function SACIProfiler:Report(limit)
    limit = limit or 40

    local list = {}
    local totalTime = 0
    local totalCalls = 0

    for name, e in pairs(self.data) do
        local calls = e.calls or 0
        local total = e.total or 0

        totalTime = totalTime + total
        totalCalls = totalCalls + calls

        table.insert(list, {
            name = name,
            calls = calls,
            total = total,
            avg = calls > 0 and (total / calls) or 0,
            max = e.max,
            min = e.min
        })
    end

    table.sort(list, function(a, b)
        return a.max > b.max
    end)

    print("------ PROFILER REPORT ------")
    for i = 1, math.min(limit, #list) do
        local e = list[i]
        print(string.format(
            "%2d. %-30s max: %.3fms  min: %.3fms  avg: %.5fms  total: %.3fms  calls: %d",
            i, e.name, e.max, e.min, e.avg, e.total, e.calls
        ))
    end

    local overallAvg = totalCalls > 0 and (totalTime / totalCalls) or 0

    print("-----------------------------------")
    print(string.format(
        "TOTALS: total: %.3fms  avg: %.5fms  calls: %d",
        totalTime, overallAvg, totalCalls
    ))
end

_G.SACIProfiler = SACIProfiler
SACIProfiler:HookMixin(AssistedCombatIconFrame, "SACI")
print("SACI Profiler enabled!")