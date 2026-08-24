-- layout_test.lua : 터치 컨트롤 배치(scripts/ui/layout.lua)의 순수 로직 검증 (T1)
--
-- Android는 논리 높이가 고정(448)이고 가로만 기기 비율대로 늘어난다.
-- 데스크톱 미리보기(384)부터 좁은 화면 방어(300), 태블릿(597), 16:9(796),
-- Galaxy S24(971), 초광폭(1200)까지 전부에서 배치 불변식이 지켜져야 한다.

local M = {}

local HIT_SLOP = 1.25      -- buttons.lua의 판정 반경 배수
local GRAB = 0.48          -- vpad.lua의 잡기 반경 비율

local DEFS = {
    main = { { id = "jump", label = "점프" }, { id = "attack", label = "공격" } },
    sub = { { id = "skill", label = "폭주" }, { id = "bolt", label = "검기" } },
    sys = { { id = "pause", label = "II" } },
}

function M.run(t)
    local Layout = require("scripts/ui/layout")
    t.check_type(Layout.metrics, "function", "Layout.metrics 존재")
    t.check_type(Layout.controls, "function", "Layout.controls 존재")

    for _, W in ipairs({ 300, 384, 597, 796, 971, 1200 }) do
        local H = 448
        local c = Layout.controls(W, H, DEFS)
        local tag = W .. "x" .. H .. ": "

        -- 패드가 화면 안에 있다
        t.check(c.pad.x >= 0 and c.pad.y >= 0
            and c.pad.x + c.pad.size <= W and c.pad.y + c.pad.size <= H,
            tag .. "패드가 화면 안", c.pad.x .. "," .. c.pad.y .. " " .. c.pad.size)

        -- 버튼이 다섯이고 전부 화면 안에 있다
        t.check_eq(#c.buttons, 5, tag .. "버튼 다섯")
        for _, b in ipairs(c.buttons) do
            t.check(b.x >= 0 and b.y >= 0 and b.x + b.size <= W and b.y + b.size <= H,
                tag .. b.id .. " 화면 안", b.x .. "," .. b.y .. " " .. b.size)
        end

        -- 패드의 잡기 원과 버튼의 판정 원(슬롭 포함)이 겹치지 않는다.
        -- 겹치면 패드를 잡으려다 버튼이 눌린다.
        local pcx, pcy = c.pad.x + c.pad.size / 2, c.pad.y + c.pad.size / 2
        for _, b in ipairs(c.buttons) do
            local dx = (b.x + b.size / 2) - pcx
            local dy = (b.y + b.size / 2) - pcy
            local minDist = c.pad.size * GRAB + b.size / 2 * HIT_SLOP
            t.check(dx * dx + dy * dy > minDist * minDist,
                tag .. "패드와 " .. b.id .. " 분리",
                math.floor(math.sqrt(dx * dx + dy * dy)) .. " < " .. math.floor(minDist))
        end

        -- 버튼끼리 표시 원이 겹치지 않는다 (판정 슬롭은 겹쳐도 가까운 쪽이 이긴다)
        for i = 1, #c.buttons do
            for j = i + 1, #c.buttons do
                local a, b = c.buttons[i], c.buttons[j]
                local dx = (a.x + a.size / 2) - (b.x + b.size / 2)
                local dy = (a.y + a.size / 2) - (b.y + b.size / 2)
                local minDist = a.size / 2 + b.size / 2
                t.check(dx * dx + dy * dy >= minDist * minDist,
                    tag .. a.id .. "와 " .. b.id .. " 분리")
            end
        end
    end

    -- 크기 위계: 주 버튼 > 보조 > 시스템, 패드가 가장 크다
    local m = Layout.metrics(971, 448)
    t.check(m.pad > m.btnMain and m.btnMain > m.btnSub and m.btnSub >= m.btnSys,
        "크기 위계", m.pad .. " " .. m.btnMain .. " " .. m.btnSub .. " " .. m.btnSys)

    -- 비례: 높이가 두 배면 크기도 두 배 (반올림 1 이내)
    local m2 = Layout.metrics(971, 896)
    for _, k in ipairs({ "pad", "btnMain", "btnSub", "btnSys", "margin", "gap" }) do
        t.check(math.abs(m2[k] - 2 * m[k]) <= 1, "비례: " .. k,
            m[k] .. " → " .. m2[k])
    end

    -- 앵커: 점프(첫 main)가 우하단 모서리, 정지(sys)가 우상단 모서리
    local c = Layout.controls(971, 448, DEFS)
    local byId = {}
    for _, b in ipairs(c.buttons) do byId[b.id] = b end
    t.check(byId.jump.x + byId.jump.size == 971 - c.metrics.margin,
        "점프가 오른쪽 모서리", byId.jump.x)
    t.check(byId.jump.y + byId.jump.size == 448 - c.metrics.margin,
        "점프가 아래 모서리", byId.jump.y)
    t.check(byId.pause.y == c.metrics.margin, "정지가 위 모서리", byId.pause.y)
    t.check(byId.attack.x < byId.jump.x, "공격은 점프 안쪽")
    t.check(byId.skill.y < byId.jump.y, "폭주는 점프 윗줄")
    t.check(byId.jump.label == "점프" and byId.pause.label == "II", "라벨 유지")

    -- 좁은 화면 방어: 300에서도 전체가 줄어 한 줄에 들어간다 (위 불변식이 이미
    -- 확인했다). 축소가 실제로 일어났는지만 본다.
    local narrow = Layout.controls(300, 448, DEFS)
    t.check(narrow.pad.size < c.pad.size, "좁은 화면에서 패드 축소",
        narrow.pad.size .. " < " .. c.pad.size)
end

return M
