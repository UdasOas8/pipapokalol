--[[ NOVA UI v1.0 — Roblox UI library
  Tabs · Sections · Toggle(+bind) · Slider · Dropdown(multi) · Keybind(Toggle/Hold/Always) · Color(ColorPicker) · Button · Cursor · Particles · Textbox
  Configs (save/load/delete/autoload/export/import) · Watermark · Keybind list · Notifications · Search · Drag
  Меню по умолчанию: RShift. Поиск — по всем вкладкам. Меню открыто = свой курсор + разблокировка мыши (игра получает своё состояние обратно при закрытии).
  ЛКМ по биндy = назначить (Backspace = очистить, Esc = отмена), ПКМ по бинду = режим.
]]
local Nova = {Flags = {}, Options = {}, Binds = {}, Hooks = {}, Conns = {}, ShowKL = true, All = {}, CustomCursor = true, FX = {menu = false, ambient = false, style = "Mixed", density = 100, speed = 100, react = true}, Glass = {}, Hud = {},
	Cur = {style = "Arrow", size = 100, trail = false, tlen = 10}}
local function svc(n) local s = game:GetService(n) return cloneref and cloneref(s) or s end
local TS, UIS, RS, Players, Http = svc("TweenService"), svc("UserInputService"), svc("RunService"), svc("Players"), svc("HttpService")
local CAS = svc("ContextActionService")
local GS = svc("GuiService")
local LP = Players.LocalPlayer
local C = {Bg = Color3.fromRGB(12, 12, 18), Panel = Color3.fromRGB(18, 18, 26), Card = Color3.fromRGB(23, 23, 33), Elem = Color3.fromRGB(34, 34, 48),
	Stroke = Color3.fromRGB(53, 53, 76), Text = Color3.fromRGB(236, 236, 246), Sub = Color3.fromRGB(154, 154, 180), Mute = Color3.fromRGB(98, 98, 124), Accent = Color3.fromRGB(139, 92, 246)}
Nova.Theme = C
local FXGLASS = .42 -- прозрачность карточек, когда включены частицы в меню (сквозь них видно движение)
local ICON = Font.new("rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local PAL = {"ef4444","f97316","f59e0b","eab308","84cc16","22c55e","10b981","14b8a6","06b6d4","0ea5e9","3b82f6","6366f1","8b5cf6","a855f7","d946ef","ec4899","f43f5e","ffffff","a3a3a3","404040"}

-- ===== helpers =====
local function new(cls, p, kids)
	local o = Instance.new(cls)
	for k, v in pairs(p or {}) do if k ~= "Parent" then o[k] = v end end
	for _, k in ipairs(kids or {}) do k.Parent = o end
	o.Parent = p and p.Parent
	return o
end
local function corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r), Parent = o}) end
local function stroke(o, c, t, a) return new("UIStroke", {Color = c, Thickness = t, Transparency = a, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o}) end
local function tw(o, t, p) TS:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), p):Play() end
local function conn(sig, f) local c = sig:Connect(f) table.insert(Nova.Conns, c) return c end
local function acc(fn) table.insert(Nova.Hooks, fn) fn() end -- hook: вызывается при смене акцента
local function txt(p)
	p.BackgroundTransparency = 1
	if not p.FontFace then p.Font = p.Font or Enum.Font.GothamMedium end
	p.TextSize = p.TextSize or 12 p.TextColor3 = p.TextColor3 or C.Text p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", p)
end
local function grad(o, rot)
	local g = new("UIGradient", {Rotation = rot or 0, Parent = o})
	acc(function() local h, s, v = C.Accent:ToHSV() g.Color = ColorSequence.new(C.Accent, Color3.fromHSV((h + .09) % 1, s, v)) end)
end
local function short(k)
	if not k then return "None" end
	k = k:gsub("Left", "L"):gsub("Right", "R"):gsub("Control", "Ctrl"):gsub("MouseButton", "MB")
	return k
end
function Nova:SetAccent(c) C.Accent = c for _, f in ipairs(self.Hooks) do pcall(f) end end

-- ===== binds =====
local function attach(r, O, off, key, mode, o)
	local B = {Key = typeof(key) == "EnumItem" and key.Name or key, Mode = mode or "Toggle", Owner = O, Menu = o and o.Menu}
	O.Bind = B table.insert(Nova.Binds, B)
	if B.Menu then Nova.MenuBound = true end
	local chip = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(52, 18), Position = UDim2.new(1, off, .5, -9), BackgroundColor3 = C.Elem, Parent = r}) corner(chip, 5)
	local cl = txt({Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd, Parent = chip})
	function B.Draw() local l = Nova.Listening == B cl.Text = l and "..." or short(B.Key) cl.TextColor3 = l and C.Accent or C.Sub end
	function B:SetMode(m) local old = B.Mode B.Mode = m if m == "Always" then O:Set(true) elseif old == "Always" then O:Set(false) end Nova:_list() end
	function B:Set(k, m) B.Key = k if m and m ~= B.Mode then B:SetMode(m) end B.Draw() Nova:_list() end
	chip.MouseButton1Click:Connect(function() local p = Nova.Listening Nova.Listening = B if p then p.Draw() end B.Draw() end)
	chip.MouseButton2Click:Connect(function()
		Nova:_list_pop(chip, {"Toggle", "Hold", "Always"}, function(m) return B.Mode == m end, function(m) B:SetMode(m) end)
	end)
	B.Draw()
end

local function base(o, t, v)
	local O = {Type = t, Value = v, Flag = o.Flag, Callback = o.Callback, NoSave = o.NoSave, Name = o.Name}
	if o.Flag then Nova.Options[o.Flag] = O Nova.Flags[o.Flag] = v end
	return O
end
local function commit(O, silent)
	if O.Flag then Nova.Flags[O.Flag] = O.Value end
	if not silent and O.Callback then task.spawn(O.Callback, O.Value) end
	if O.Type ~= "Color" then Nova:_list() end
end
local function row(sec, h, name)
	sec.n += 1
	local r = new("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = sec.n, Parent = sec.Card})
	local e = {r, (name or ""):lower(), name = name or "", sec = sec, tab = sec.Tab, sub = sec.Sub}
	table.insert(sec.Rows, r) if sec.Collapsed then r.Visible = false end
	table.insert(sec.Tab.Items, e) table.insert(Nova.All, e)
	return r
end

-- ===== components =====
local S = {} S.__index = S

function S:AddToggle(o)
	local r = row(self, 24, o.Name)
	local O = base(o, "Toggle", o.Default == true)
	local lbl = txt({Text = o.Name, Size = UDim2.new(1, -(o.Bind and 96 or 44), 1, 0), Parent = r})
	local tr = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -34, .5, -9), BackgroundColor3 = C.Elem, Parent = r}) corner(tr, 9)
	local dot = new("Frame", {Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = C.Sub, BorderSizePixel = 0, Parent = tr}) corner(dot, 6)
	local function paint()
		local on = O.Value
		tw(tr, .18, {BackgroundColor3 = on and C.Accent or C.Elem})
		tw(dot, .18, {Position = UDim2.fromOffset(on and 19 or 3, 3), BackgroundColor3 = on and Color3.new(1, 1, 1) or C.Sub})
		tw(lbl, .18, {TextColor3 = on and C.Text or C.Sub})
	end
	acc(paint)
	function O:Set(v, silent) O.Value = v and true or false paint() commit(O, silent) end
	tr.MouseButton1Click:Connect(function() O:Set(not O.Value) end)
	if o.Bind then attach(r, O, -92, type(o.Bind) ~= "boolean" and o.Bind or nil, o.Mode, o) end
	return O
end

function S:AddSlider(o)
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local dec = #((tostring(step):match("%.(%d+)")) or "")
	local r = row(self, 38, o.Name)
	local O = base(o, "Slider", o.Default or min)
	txt({Text = o.Name, Size = UDim2.new(.6, 0, 0, 16), TextColor3 = C.Sub, Parent = r})
	local vb = new("TextBox", {Size = UDim2.new(.4, 0, 0, 16), Position = UDim2.fromScale(.6, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = false, Parent = r})
	local hit = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 20), BackgroundTransparency = 1, Parent = r})
	local trk = new("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, .5, -3), BackgroundColor3 = C.Elem, BorderSizePixel = 0, Parent = hit}) corner(trk, 3)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = trk}) corner(fill, 3) grad(fill)
	local knob = new("Frame", {Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(0, .5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = trk}) corner(knob, 6)
	function O:Set(v, silent)
		v = math.clamp(tonumber(v) or min, min, max)
		v = math.clamp(tonumber(("%." .. dec .. "f"):format(math.floor((v - min) / step + .5) * step + min)), min, max)
		O.Value = v
		local a = (v - min) / (max - min)
		tw(fill, .08, {Size = UDim2.fromScale(a, 1)}) tw(knob, .08, {Position = UDim2.fromScale(a, .5)})
		vb.Text = tostring(v) .. (o.Suffix or "")
		commit(O, silent)
	end
	local drag = false
	local function from(x) O:Set(min + (max - min) * math.clamp((x - trk.AbsolutePosition.X) / trk.AbsoluteSize.X, 0, 1)) end
	local function isP(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
	hit.InputBegan:Connect(function(i) if isP(i) then drag = true from(i.Position.X) end end)
	conn(UIS.InputChanged, function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then from(i.Position.X) end end)
	conn(UIS.InputEnded, function(i) if isP(i) then drag = false end end)
	vb.FocusLost:Connect(function() O:Set(tonumber(vb.Text:match("-?%d+%.?%d*"))) end)
	O:Set(O.Value, true)
	return O
end

function S:AddRange(o) -- двойной ползунок: Value = {Min = a, Max = b}; Default = {a, b}
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local dec = #((tostring(step):match("%.(%d+)")) or "")
	local r = row(self, 38, o.Name)
	local d = o.Default or {min, max}
	local O = base(o, "Range", {Min = d[1] or d.Min or min, Max = d[2] or d.Max or max})
	txt({Text = o.Name, Size = UDim2.new(.5, 0, 0, 16), TextColor3 = C.Sub, Parent = r})
	local vb = new("TextBox", {Size = UDim2.new(.5, 0, 0, 16), Position = UDim2.fromScale(.5, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = false, Parent = r})
	local hit = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 20), BackgroundTransparency = 1, Parent = r})
	local trk = new("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, .5, -3), BackgroundColor3 = C.Elem, BorderSizePixel = 0, Parent = hit}) corner(trk, 3)
	local fill = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = trk}) corner(fill, 3) grad(fill)
	local function knob() return new("Frame", {Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(0, .5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = trk}) end
	local k1, k2 = knob(), knob() corner(k1, 6) corner(k2, 6)
	local function snap(v)
		v = math.clamp(tonumber(v) or min, min, max)
		return math.clamp(tonumber(("%." .. dec .. "f"):format(math.floor((v - min) / step + .5) * step + min)), min, max)
	end
	function O:Set(v, silent)
		local a, b = snap(v[1] or v.Min), snap(v[2] or v.Max)
		if a > b then a, b = b, a end
		O.Value = {Min = a, Max = b}
		local pa, pb = (a - min) / (max - min), (b - min) / (max - min)
		tw(fill, .08, {Position = UDim2.fromScale(pa, 0), Size = UDim2.fromScale(pb - pa, 1)})
		tw(k1, .08, {Position = UDim2.fromScale(pa, .5)}) tw(k2, .08, {Position = UDim2.fromScale(pb, .5)})
		vb.Text = tostring(a) .. " - " .. tostring(b) .. (o.Suffix or "")
		commit(O, silent)
	end
	local which
	local function val(x) return min + (max - min) * math.clamp((x - trk.AbsolutePosition.X) / trk.AbsoluteSize.X, 0, 1) end
	local function move(x)
		local v, a, b = val(x), O.Value.Min, O.Value.Max
		if which == "Min" then a = math.min(v, b) else b = math.max(v, a) end
		O:Set({a, b})
	end
	local function isP(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
	hit.InputBegan:Connect(function(i)
		if not isP(i) then return end
		local v, a, b = val(i.Position.X), O.Value.Min, O.Value.Max
		which = (math.abs(v - a) < math.abs(v - b) or (a == b and v < a)) and "Min" or "Max" -- тянем ближайший ползунок
		move(i.Position.X)
	end)
	conn(UIS.InputChanged, function(i) if which and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then move(i.Position.X) end end)
	conn(UIS.InputEnded, function(i) if isP(i) then which = nil end end)
	vb.FocusLost:Connect(function()
		local n = {} for x in vb.Text:gmatch("-?%d+%.?%d*") do n[#n + 1] = tonumber(x) end
		O:Set(#n >= 2 and {n[1], n[2]} or O.Value)
	end)
	O:Set(O.Value, true)
	return O
end

function S:AddDropdown(o)
	local r, multi = row(self, 26, o.Name), o.Multi
	local O = base(o, "Dropdown", multi and {} or o.Default)
	O.Multi, O.Values = multi, o.Values or {}
	txt({Text = o.Name, Size = UDim2.new(.45, 0, 1, 0), TextColor3 = C.Sub, Parent = r})
	local b = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.new(.55, -4, 1, 0), Position = UDim2.fromScale(.45, 0), BackgroundColor3 = C.Elem, Parent = r}) corner(b, 7)
	local vl = txt({Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(8, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = b})
	txt({Text = "▾", Size = UDim2.fromOffset(16, 26), Position = UDim2.new(1, -18, 0, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Sub, Parent = b})
	local function show()
		if multi then
			local t = {} for _, v in ipairs(O.Values) do if O.Value[v] then t[#t + 1] = v end end
			vl.Text = #t > 0 and table.concat(t, ", ") or "None"
		else vl.Text = tostring(O.Value or "None") end
	end
	function O:Set(v, silent)
		if multi then
			local d = {} if type(v) == "table" then for k, x in pairs(v) do if type(k) == "number" then d[x] = true elseif x then d[k] = true end end end
			O.Value = d
		else O.Value = v end
		show() commit(O, silent)
	end
	function O:SetValues(l) O.Values = l if not multi and not table.find(l, O.Value) then O.Value = nil end show() end
	b.MouseButton1Click:Connect(function()
		Nova:_list_pop(b, O.Values, function(i) if multi then return O.Value[i] == true end return O.Value == i end, function(i)
			if multi then local d = {} for k, v in pairs(O.Value) do d[k] = v end d[i] = not d[i] or nil O:Set(d) else O:Set(i) end
		end, multi)
	end)
	if multi then O:Set(o.Default or {}, true) else show() end
	return O
end

function S:AddKeybind(o)
	local r = row(self, 24, o.Name)
	local O = base(o, "Keybind", false)
	txt({Text = o.Name, Size = UDim2.new(1, -60, 1, 0), TextColor3 = C.Sub, Parent = r})
	function O:Set(v, silent) O.Value = v and true or false commit(O, silent) end
	attach(r, O, -52, o.Default, o.Mode, o)
	return O
end

function S:AddColor(o)
	local r = row(self, 24, o.Name)
	local O = base(o, "Color", o.Default or C.Accent)
	txt({Text = o.Name, Size = UDim2.new(1, -40, 1, 0), TextColor3 = C.Sub, Parent = r})
	local sw = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(30, 16), Position = UDim2.new(1, -30, .5, -8), Parent = r}) corner(sw, 5) stroke(sw, Color3.new(1, 1, 1), 1, .8)
	function O:Set(c, silent) O.Value = c sw.BackgroundColor3 = c commit(O, silent) end
	sw.MouseButton1Click:Connect(function()
		if o.Palette then Nova:_palette(sw, function(c) O:Set(c) end) else Nova:_picker(sw, O) end
	end)
	O:Set(O.Value, true)
	return O
end

function S:AddButton(o)
	local r = row(self, 28, o.Name)
	local b = new("TextButton", {Text = o.Name, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Elem, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.Text, Parent = r}) corner(b, 7)
	local st = stroke(b, C.Accent, 1, 1)
	acc(function() st.Color = C.Accent end)
	b.MouseEnter:Connect(function() tw(st, .15, {Transparency = .2}) end)
	b.MouseLeave:Connect(function() tw(st, .15, {Transparency = 1}) end)
	b.MouseButton1Click:Connect(function()
		tw(b, .08, {BackgroundColor3 = C.Accent}) task.delay(.12, function() tw(b, .25, {BackgroundColor3 = C.Elem}) end)
		if o.Callback then task.spawn(o.Callback) end
	end)
end

function S:AddTextbox(o)
	local r = row(self, 26, o.Name)
	local O = base(o, "Textbox", o.Default or "")
	txt({Text = o.Name, Size = UDim2.new(.4, 0, 1, 0), TextColor3 = C.Sub, Parent = r})
	local bx = new("TextBox", {Size = UDim2.new(.6, -4, 1, 0), Position = UDim2.fromScale(.4, 0), BackgroundColor3 = C.Elem, Text = O.Value, PlaceholderText = o.Placeholder or "", PlaceholderColor3 = C.Mute,
		TextColor3 = C.Text, Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r})
	corner(bx, 7) new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = bx})
	function O:Set(v, silent) O.Value = tostring(v) bx.Text = O.Value commit(O, silent) end
	bx.FocusLost:Connect(function() O:Set(bx.Text) end)
	return O
end

function S:AddLabel(t)
	local r = row(self, 16, t)
	txt({Text = t, TextColor3 = C.Mute, TextSize = 11, Size = UDim2.fromScale(1, 1), Parent = r})
end

-- ===== popups =====
function Nova:_close() if self.Pop then self.Pop:Destroy() self.Pop, self.PopAnchor = nil, nil end end
function Nova:_pop(anchor, w, h)
	if self.Pop and self.PopAnchor == anchor then self:_close() return end
	self:_close()
	local p, vp = anchor.AbsolutePosition, workspace.CurrentCamera.ViewportSize
	local py = p.Y + anchor.AbsoluteSize.Y + 4
	if py + h > vp.Y - 4 then py = math.max(4, p.Y - h - 4) end
	local f = new("Frame", {Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ZIndex = 60,
		Position = UDim2.fromOffset(math.clamp(p.X + anchor.AbsoluteSize.X - w, 4, vp.X - w - 4), py), Parent = self.Gui})
	corner(f, 8) stroke(f, C.Stroke, 1, .2)
	self.Pop, self.PopAnchor = f, anchor
	return f
end
function Nova:_list_pop(anchor, items, isSel, pick, keep)
	local f = self:_pop(anchor, math.max(anchor.AbsoluteSize.X, 96), math.min(#items * 24 + 8, 200)) if not f then return end
	local sc = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = f})
	new("UIListLayout", {Parent = sc}) new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = sc})
	local bs = {}
	local function paint() for it, b in pairs(bs) do local s = isSel(it) b.BackgroundTransparency = s and 0 or 1 b.TextColor3 = s and C.Text or C.Sub end end
	for _, it in ipairs(items) do
		local b = new("TextButton", {Text = "  " .. tostring(it), AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.Elem, BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc}) corner(b, 6)
		bs[it] = b
		b.MouseButton1Click:Connect(function() pick(it) if keep then paint() else self:_close() end end)
	end
	paint()
end
function Nova:_palette(anchor, pick)
	local f = self:_pop(anchor, 156, 126) if not f then return end
	new("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), Parent = f})
	new("UIGridLayout", {CellSize = UDim2.fromOffset(26, 26), CellPadding = UDim2.fromOffset(4, 4), Parent = f})
	for _, hx in ipairs(PAL) do
		local b = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex(hx), Parent = f}) corner(b, 7)
		b.MouseButton1Click:Connect(function() pick(Color3.fromHex(hx)) end)
	end
end

-- ColorPicker: SV-квадрат + Hue + HEX + быстрые цвета. Для обычных функций; в Settings (Accent) остаётся палитра.
function Nova:_picker(anchor, O)
	local f = self:_pop(anchor, 216, 224) if not f then return end
	local old = O.Value
	local h, s, v = old:ToHSV()
	local cs, mode = {}, nil
	local W1 = Color3.new(1, 1, 1)
	local function isP(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
	local function pointer(i)
		if i.UserInputType == Enum.UserInputType.Touch then return Vector2.new(i.Position.X, i.Position.Y + GS:GetGuiInset().Y) end
		return UIS:GetMouseLocation()
	end
	local function hit(parent) return new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = parent}) end

	-- насыщенность / яркость
	local sv = new("Frame", {Size = UDim2.new(1, -20, 0, 120), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, Parent = f}) corner(sv, 7)
	local wh = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = W1, BorderSizePixel = 0, ZIndex = 2, Parent = sv}) corner(wh, 7)
	new("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = wh})
	local bk = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3, Parent = sv}) corner(bk, 7)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = bk})
	local sk = new("Frame", {Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(.5, .5), BorderSizePixel = 0, ZIndex = 4, Parent = sv}) corner(sk, 6) stroke(sk, W1, 2, 0)
	local shit = hit(sv)

	-- hue
	local hb = new("Frame", {Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 138), BackgroundColor3 = W1, BorderSizePixel = 0, Parent = f}) corner(hb, 6)
	local ks = {} for i = 0, 6 do ks[#ks + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)) end
	new("UIGradient", {Color = ColorSequence.new(ks), Parent = hb})
	local hk = new("Frame", {Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(.5, .5), BorderSizePixel = 0, ZIndex = 2, Parent = hb}) corner(hk, 7) stroke(hk, W1, 2, 0)
	local hhit = hit(hb)

	-- превью (слева новый, справа исходный — клик по исходному возвращает цвет) + HEX
	local pv = new("Frame", {Size = UDim2.fromOffset(34, 24), Position = UDim2.fromOffset(10, 162), BackgroundColor3 = old, BorderSizePixel = 0, ClipsDescendants = true, Parent = f}) corner(pv, 6) stroke(pv, W1, 1, .85)
	local nw = new("Frame", {Size = UDim2.fromScale(.5, 1), BorderSizePixel = 0, Parent = pv})
	local rv = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(.5, 1), Position = UDim2.fromScale(.5, 0), Parent = pv})
	local hx = new("TextBox", {Size = UDim2.new(1, -64, 0, 24), Position = UDim2.fromOffset(54, 162), BackgroundColor3 = C.Elem, TextColor3 = C.Text, Font = Enum.Font.GothamMedium, TextSize = 12,
		PlaceholderText = "#RRGGBB", PlaceholderColor3 = C.Mute, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = f}) corner(hx, 7)
	new("UIPadding", {PaddingLeft = UDim.new(0, 8), Parent = hx})
	local hs = stroke(hx, C.Accent, 1, 1)

	-- быстрые цвета
	local qr = new("Frame", {Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 194), BackgroundTransparency = 1, Parent = f})
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), Parent = qr})
	local quick = {}

	local function refresh()
		local c = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		sk.Position, sk.BackgroundColor3 = UDim2.fromScale(s, 1 - v), c
		hk.Position, hk.BackgroundColor3 = UDim2.fromScale(h, .5), Color3.fromHSV(h, 1, 1)
		nw.BackgroundColor3 = c
		if not hx:IsFocused() then hx.Text = "#" .. c:ToHex():upper() end
	end
	local function push() O:Set(Color3.fromHSV(h, s, v)) refresh() end
	local function setColor(c) h, s, v = c:ToHSV() O:Set(c) refresh() end

	for _, hex in ipairs({"ef4444", "f97316", "eab308", "22c55e", "06b6d4", "3b82f6", "a855f7", "ffffff"}) do
		local c = Color3.fromHex(hex)
		local b = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(20, 20), BackgroundColor3 = c, Parent = qr}) corner(b, 6) stroke(b, W1, 1, .85)
		b.MouseButton1Click:Connect(function() setColor(c) end)
	end
	rv.MouseButton1Click:Connect(function() setColor(old) end)

	local function move(p)
		if mode == "sv" then
			s = math.clamp((p.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
			push()
		elseif mode == "hue" then
			h = math.clamp((p.X - hb.AbsolutePosition.X) / hb.AbsoluteSize.X, 0, .999)
			push()
		end
	end
	shit.InputBegan:Connect(function(i) if isP(i) then mode = "sv" move(pointer(i)) end end)
	hhit.InputBegan:Connect(function(i) if isP(i) then mode = "hue" move(pointer(i)) end end)
	cs[1] = UIS.InputChanged:Connect(function(i) if mode and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then move(pointer(i)) end end)
	cs[2] = UIS.InputEnded:Connect(function(i) if isP(i) then mode = nil end end)
	f.Destroying:Connect(function() for _, c in ipairs(cs) do c:Disconnect() end end)

	hx.Focused:Connect(function() tw(hs, .15, {Transparency = .1}) end)
	hx.FocusLost:Connect(function()
		tw(hs, .15, {Transparency = 1})
		local t = hx.Text:gsub("[#%s]", "")
		if #t == 3 then t = t:gsub("%x", "%0%0") end
		if #t == 6 and t:match("^%x+$") then setColor(Color3.fromHex(t)) else refresh() end
	end)
	refresh()
end

-- ===== cursor =====
-- Стрелка строится один раз из полигона: сглаженные края (суперсэмплинг 4x4), тёмный контур, градиентная заливка
-- в цвет акцента, мягкое свечение за курсором, сжатие и пульс-кольцо по клику. Ассетов не нужно — только Frame.
local ARROW = {{0, 0}, {0, 16.5}, {3.9, 13}, {6.4, 19.2}, {9, 18.1}, {6.5, 12.1}, {11.8, 12.1}}
local CK, CT = 1.15, 1.25 -- масштаб стрелки, толщина контура (px)
local function arrowRects()
	local P, n = {}, #ARROW
	for i, p in ipairs(ARROW) do P[i] = {p[1] * CK, p[2] * CK} end
	local function inside(x, y)
		local c, j = false, n
		for i = 1, n do
			local xi, yi, xj, yj = P[i][1], P[i][2], P[j][1], P[j][2]
			if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then c = not c end
			j = i
		end
		return c
	end
	local function dist(x, y)
		local d, j = math.huge, n
		for i = 1, n do
			local ax, ay, bx, by = P[j][1], P[j][2], P[i][1], P[i][2]
			local dx, dy = bx - ax, by - ay
			local t = math.clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0, 1)
			local ex, ey = ax + dx * t - x, ay + dy * t - y
			d = math.min(d, math.sqrt(ex * ex + ey * ey))
			j = i
		end
		return d
	end
	local X0, X1, Y0, Y1, SS = -3, 17, -3, 25, 4
	local GF, GO = {}, {}
	for py = Y0, Y1 do
		GF[py], GO[py] = {}, {}
		for px = X0, X1 do
			local cf, co = 0, 0
			for sy = 0, SS - 1 do
				for sx = 0, SS - 1 do
					local x, y = px + (sx + .5) / SS, py + (sy + .5) / SS
					if inside(x, y) then cf += 1 co += 1 elseif dist(x, y) <= CT then co += 1 end
				end
			end
			GF[py][px], GO[py][px] = cf / (SS * SS), co / (SS * SS)
		end
	end
	local function rects(G)
		local out = {}
		for py = Y0, Y1 do
			local run
			local function flush(px) if run then out[#out + 1] = {run, py, px - run, 1, 1} run = nil end end
			for px = X0, X1 do
				local c = G[py][px]
				if c >= .98 then run = run or px
				else
					flush(px)
					if c > .04 then out[#out + 1] = {px, py, 1, 1, c} end
				end
			end
			flush(X1 + 1)
		end
		return out
	end
	return rects(GF), rects(GO)
end
function Nova:_cursor(gui)
	local fillR, outR = arrowRects()
	local D = Color3.fromRGB(8, 8, 14)
	local cur = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, ZIndex = 500, Visible = false, Parent = gui})
	local glow = new("Frame", {Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = C.Accent, BackgroundTransparency = .9, BorderSizePixel = 0, ZIndex = 1, Parent = cur}) corner(glow, 99)
	local glow2 = new("Frame", {Size = UDim2.fromScale(.56, .56), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = C.Accent, BackgroundTransparency = .82, BorderSizePixel = 0, Parent = glow}) corner(glow2, 99)
	local trail = {}
	for i = 1, 16 do trail[i] = new("Frame", {AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Visible = false, ZIndex = 2, Parent = cur}) corner(trail[i], 99) end
	local outer = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, ZIndex = 3, Parent = cur}) -- позиция курсора + масштаб (Cursor size)
	local osc = new("UIScale", {Parent = outer})
	local wrap = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, Parent = outer}) -- сжатие при клике
	local sc = new("UIScale", {Parent = wrap})
	-- Arrow
	local root = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, Parent = wrap})
	local ol = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, ZIndex = 1, Parent = root})
	local fl = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, ZIndex = 2, Parent = root})
	for _, r in ipairs(outR) do
		new("Frame", {Position = UDim2.fromOffset(r[1], r[2]), Size = UDim2.fromOffset(r[3], r[4]), BackgroundColor3 = D, BackgroundTransparency = 1 - r[5] * .94, BorderSizePixel = 0, Parent = ol})
	end
	local fills = {}
	for _, r in ipairs(fillR) do
		fills[#fills + 1] = {new("Frame", {Position = UDim2.fromOffset(r[1], r[2]), Size = UDim2.fromOffset(r[3], r[4]), BackgroundColor3 = C.Accent, BackgroundTransparency = 1 - r[5], BorderSizePixel = 0, Parent = fl}), r[2] + r[4] / 2}
	end
	-- Dot
	local dotR = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, Visible = false, Parent = wrap})
	local core = new("Frame", {Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 2, Parent = dotR}) corner(core, 99) stroke(core, D, 1.5, .1)
	local ring = new("Frame", {Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1, Parent = dotR}) corner(ring, 99)
	local rst = stroke(ring, C.Accent, 1.5, .1)
	-- Crosshair
	local crossR = new("Frame", {Size = UDim2.new(), BackgroundTransparency = 1, Visible = false, Parent = wrap})
	local bars = {}
	for _, b in ipairs({{4, 0, 8, 2, 0, .5}, {-4, 0, 8, 2, 1, .5}, {0, 4, 2, 8, .5, 0}, {0, -4, 2, 8, .5, 1}}) do
		local f = new("Frame", {Position = UDim2.fromOffset(b[1], b[2]), Size = UDim2.fromOffset(b[3], b[4]), AnchorPoint = Vector2.new(b[5], b[6]), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = crossR})
		stroke(f, D, 1, .15) bars[#bars + 1] = f
	end
	local cdot = new("Frame", {Size = UDim2.fromOffset(2, 2), AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = crossR}) corner(cdot, 1)
	acc(function()
		local h, s, v = C.Accent:ToHSV() local c2 = Color3.fromHSV((h + .09) % 1, s, v)
		for _, e in ipairs(fills) do e[1].BackgroundColor3 = C.Accent:Lerp(c2, math.clamp(e[2] / 22, 0, 1)) end
		glow.BackgroundColor3, glow2.BackgroundColor3, core.BackgroundColor3, rst.Color = C.Accent, C.Accent, C.Accent, C.Accent
		for _, b in ipairs(bars) do b.BackgroundColor3 = C.Accent end
		for i, t in ipairs(trail) do t.BackgroundColor3 = C.Accent:Lerp(c2, i / 16) end
	end)
	local goff = Vector2.new(5, 8)
	local function apply() -- стиль / размер / шлейф из Nova.Cur
		local c = Nova.Cur
		local k = c.size / 100
		root.Visible, dotR.Visible, crossR.Visible = c.style == "Arrow", c.style == "Dot", c.style == "Crosshair"
		osc.Scale = k
		glow.Visible = c.style ~= "Crosshair"
		glow.Size = UDim2.fromOffset(34 * k, 34 * k)
		goff = c.style == "Arrow" and Vector2.new(5, 8) * k or Vector2.new()
		local n = math.clamp(c.tlen or 10, 1, 16)
		for i, t in ipairs(trail) do
			t.Visible = (c.trail and i <= n) or false
			local d = math.max(2, (9 - i * .55) * k)
			t.Size = UDim2.fromOffset(d, d)
			t.BackgroundTransparency = .35 + .6 * i / n
		end
	end
	apply()
	local function ripple(m, k)
		local r = new("Frame", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(m.X, m.Y), Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, ZIndex = 2, Parent = cur}) corner(r, 99)
		local st = stroke(r, C.Accent, 2, .1)
		tw(r, .5, {Size = UDim2.fromOffset(46 * k, 46 * k)}) TS:Create(st, TweenInfo.new(.5), {Transparency = 1}):Play()
		task.delay(.55, function() r:Destroy() end)
	end
	conn(UIS.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 and cur.Visible then
			local k = Nova.Cur.size / 100
			tw(sc, .08, {Scale = .84}) tw(glow, .1, {Size = UDim2.fromOffset(46 * k, 46 * k)}) ripple(UIS:GetMouseLocation(), k)
			if Nova.Cur.style == "Crosshair" then tw(crossR, .15, {Rotation = 45}) end
		end
	end)
	conn(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			local k = Nova.Cur.size / 100
			tw(sc, .18, {Scale = 1}) tw(glow, .2, {Size = UDim2.fromOffset(34 * k, 34 * k)}) tw(crossR, .2, {Rotation = 0})
		end
	end)
	local gp, tp = Vector2.new(), {}
	for i = 1, 16 do tp[i] = Vector2.new() end
	return cur, function(m, dt) -- стрелка строго под курсором; свечение и шлейф следуют с запаздыванием
		outer.Position = UDim2.fromOffset(m.X, m.Y)
		local k = dt or 1
		gp = gp:Lerp(m, math.clamp(k * 16, 0, 1))
		glow.Position = UDim2.fromOffset(gp.X + goff.X, gp.Y + goff.Y)
		local c = Nova.Cur
		if c.trail then
			local prev = m + (c.style == "Arrow" and Vector2.new(3, 5) * (c.size / 100) or Vector2.new())
			for i = 1, math.clamp(c.tlen or 10, 1, 16) do
				tp[i] = tp[i]:Lerp(prev, math.clamp(k * math.max(6, 24 - i), 0, 1))
				trail[i].Position = UDim2.fromOffset(tp[i].X, tp[i].Y)
				prev = tp[i]
			end
		end
	end, apply
end
function Nova:SetCursor(k, v)
	if v ~= nil then self.Cur[k] = v end
	if self.CursorApply then self.CursorApply() end
end

-- ===== particles =====
-- Стили: Mixed (искры + облёт меню), Dust (пыль), Fireflies (светлячки), Snow (снег), Constellation (точки + линии).
-- Menu particles — на фоне самого меню (карточки становятся полупрозрачными), Ambient — за меню и вокруг него.
-- Density / Speed — плотность и скорость; Cursor reaction — частицы отталкиваются от курсора (в Constellation — линии тянутся к курсору).
local HUES = {0, 0, .07, -.07, .14, 99} -- сдвиги оттенка от акцента (99 = белая искра)
local FIRE = {{.13, .6}, {.16, .6}, {.11, .6}, {.19, .55}, 0, 99} -- {оттенок, насыщенность}
local ICE = {{.56, .25}, {.6, .2}, {.58, .3}, 99, 99}
local function pcol(hu)
	if hu == 99 then return Color3.fromRGB(235, 235, 255) end
	if type(hu) == "table" then return Color3.fromHSV(hu[1], hu[2], 1) end
	local h, s = C.Accent:ToHSV()
	return Color3.fromHSV((h + hu) % 1, math.clamp(s * .8, 0, 1), 1)
end
local function mkp(kind, parent, size)
	local f = new("Frame", {Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1, Parent = parent})
	local o = {f = f, A = {}, Cs = {}}
	local function frame(k, w, rot)
		local x = new("Frame", {Size = UDim2.fromScale(k[1], k[2]), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Rotation = rot or 0, BackgroundColor3 = C.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = f})
		corner(x, 999) o.A[#o.A + 1] = {x, "BackgroundTransparency", w} o.Cs[#o.Cs + 1] = {x, "BackgroundColor3"}
		return x
	end
	if kind == "dot" then frame({2.8, 2.8}, .15) frame({1, 1}, 1)
	elseif kind == "ring" then
		local r = frame({1.6, 1.6}, 0)
		local st = new("UIStroke", {Thickness = 1.3, Color = C.Accent, Transparency = 1, Parent = r})
		o.A[#o.A + 1] = {st, "Transparency", 1} o.Cs[#o.Cs + 1] = {st, "Color"}
	elseif kind == "diamond" then frame({2.4, 2.4}, .12) frame({.8, .8}, 1, 45)
	else frame({2.2, 2.2}, .12) frame({1.5, .17}, 1) frame({.17, 1.5}, 1) end
	function o:alpha(a) for _, e in ipairs(self.A) do e[1][e[2]] = 1 - math.clamp(a * e[3], 0, 1) end end
	function o:paint(c) for _, e in ipairs(self.Cs) do e[1][e[2]] = c end end
	return o
end
function Nova:SetFX(which, v)
	if which == "menu" or which == "ambient" then
		self.FX[which] = v and true or false
		if which == "menu" then for _, c in ipairs(self.Glass) do tw(c, .35, {BackgroundTransparency = v and FXGLASS or 0}) end end
	elseif v ~= nil then
		self.FX[which] = v
		if which == "style" or which == "density" then self.FXDirty = os.clock() + .2 end -- пересборка частиц с задержкой
	end
end
function Nova:_fx(main, gui, W)
	local FX, rnd = self.FX, Random.new()
	local inC = new("Frame", {Name = "FXMenu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 0, Visible = false, Parent = main}) corner(inC, 14)
	local outC = new("Frame", {Name = "FXAmbient", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Visible = false, Parent = gui})
	local MW, MH = main.Size.X.Offset, main.Size.Y.Offset
	local all, ORB, BL, built = {}, {}, {}, {}
	local LIN, LOUT = {root = inC, out = false, D = 100, LM = 70, w = MW, h = MH}, {root = outC, out = true, D = 130, LM = 100, w = 1000, h = 700}
	local function newLayer(L) L.parent = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = L.root}) L.list, L.pool, L.lastK = {}, {}, 0 end
	newLayer(LIN) newLayer(LOUT)
	local function add(o, hu) o.hu = hu all[#all + 1] = o o:paint(pcol(hu)) return o end
	acc(function() for _, o in ipairs(all) do o:paint(pcol(o.hu)) end end)
	local function R(a, b) return rnd:NextNumber(a, b) end
	local function pick(t) return t[rnd:NextInteger(1, #t)] end
	local WI = {{"dot", .55}, {"ring", .12}, {"diamond", .15}, {"spark", .18}}
	local SZ = {dot = {3, 6}, ring = {8, 12}, diamond = {5, 8}, spark = {9, 14}}
	local function pk() local r, a = rnd:NextNumber(), 0 for _, e in ipairs(WI) do a += e[2] if r <= a then return e[1] end end return "dot" end
	local function mk(L, kind, size, hu, p, into)
		p.o = add(mkp(kind, L.parent, math.max(2, math.floor(size + .5))), hu)
		p.ph, p.ts, p.sw, p.r0, p.ox, p.oy = R(0, 6.28), R(.8, 2.2), R(.4, 1.1), R(0, 360), 0, 0
		p.spin = p.spin or 0
		local l = into or L.list l[#l + 1] = p
		return p
	end
	local function mkLinks(L)
		for i = 1, L.LM do
			local f = new("Frame", {AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Visible = false, Parent = L.parent})
			L.pool[i] = f add({f = f, paint = function(s2, col) s2.f.BackgroundColor3 = col end}, 0)
		end
	end
	local function build(L)
		local st, d, o = FX.style, math.max(.25, FX.density / 100), L.out
		local function N(a, b) return math.max(1, math.floor((o and b or a) * d + .5)) end
		local function spot() return R(0, L.w), R(0, L.h) end
		if not o then -- мягкие цветные пятна на фоне меню
			for b = 1, 2 do
				local f = new("Frame", {Size = UDim2.fromOffset(360, 360), AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1, Parent = L.parent})
				local cs = {}
				for _, e in ipairs({{1, .93}, {.7, .91}, {.42, .9}}) do
					cs[#cs + 1] = new("Frame", {Size = UDim2.fromScale(e[1], e[1]), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = C.Accent, BackgroundTransparency = e[2], BorderSizePixel = 0, Parent = f})
					corner(cs[#cs], 999)
				end
				local ob = {f = f, paint = function(_, col) for _, c in ipairs(cs) do c.BackgroundColor3 = col end end}
				add(ob, b == 1 and 0 or .12)
				BL[#BL + 1] = {o = ob, ph = b * 2.3, sp = .07 + b * .03}
			end
		end
		if st == "Dust" then
			for _ = 1, N(24, 44) do
				local z, x, y = R(.3, 1), spot()
				mk(L, "dot", R(2, 5) * (.6 + z * .6), pick(HUES), {mode = "drift", x = x, y = y, vx = R(-4, 4), vy = -(4 + z * 14), base = .2 + z * .45, amp = R(6, 18)})
			end
		elseif st == "Fireflies" then
			for _ = 1, N(12, 26) do
				local x, y = spot()
				mk(L, "dot", R(4, 7), pick(FIRE), {mode = "wander", x = x, y = y, vx = R(-3, 3), vy = R(-3, 3), base = R(.6, .95), amp = R(14, 40), blink = true})
			end
		elseif st == "Snow" then
			for _ = 1, N(24, 56) do
				local z, flake = R(.3, 1), rnd:NextNumber() < .25
				local x, y = spot()
				mk(L, flake and "spark" or "dot", (flake and R(6, 9) or R(2, 6)) * (.6 + z * .6), pick(ICE), {mode = "drift", x = x, y = y, vx = R(-5, 5), vy = 8 + z * 28, base = .35 + z * .5, amp = R(6, 18), spin = flake and R(-50, 50) or 0})
			end
		elseif st == "Constellation" then
			for _ = 1, N(22, 38) do
				local x, y = spot()
				mk(L, "dot", R(2, 4), pick(HUES), {mode = "bounce", x = x, y = y, vx = R(-14, 14), vy = R(-14, 14), base = R(.7, .95), steady = true})
			end
			mkLinks(L)
		else -- Mixed
			for _ = 1, N(20, 26) do
				local kind, z, x, y = pk(), o and R(.3, 1) or 1, spot()
				mk(L, kind, R(SZ[kind][1], SZ[kind][2]) * (o and .55 + z * .7 or 1), pick(HUES), {mode = "drift", x = x, y = y, vx = o and R(-5, 5) or R(-6, 6), vy = o and -(8 + z * 26) or R(-16, -3),
					base = o and .25 + z * .5 or R(.35, .75), amp = o and R(6, 22) or R(4, 14), spin = (kind == "diamond" or kind == "spark") and R(-40, 40) or 0})
			end
			if o then
				for i = 1, math.max(2, math.floor(12 * d + .5)) do
					local kind = pk()
					local p = mk(L, kind, R(SZ[kind][1], SZ[kind][2]) * 1.15, pick(HUES), {mode = "orbit", th = R(0, 6.28), pad = R(16, 72), dir = i % 2 == 0 and 1 or -1, sp = R(.08, .2), base = R(.65, .95), tr = {},
						spin = (kind == "diamond" or kind == "spark") and R(-40, 40) or 0}, ORB)
					local sz = p.o.f.Size.X.Offset
					for k = 1, 3 do
						local dd = math.max(2, sz * (1 - k * .2))
						local f = new("Frame", {Size = UDim2.fromOffset(dd, dd), AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = C.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = L.parent}) corner(f, 99)
						p.tr[k] = f add({f = f, paint = function(s2, col) s2.f.BackgroundColor3 = col end}, p.o.hu)
					end
				end
			end
		end
	end
	local function reset()
		for _, L in ipairs({LIN, LOUT}) do L.parent:Destroy() newLayer(L) end
		all, ORB, BL, built = {}, {}, {}, {}
	end
	local function step(p, L, t, dt, al, mx, my)
		local m = p.mode
		p.x += p.vx * dt p.y += p.vy * dt
		if m == "bounce" then
			if p.x < 0 or p.x > L.w then p.vx = -p.vx p.x = math.clamp(p.x, 0, L.w) end
			if p.y < 0 or p.y > L.h then p.vy = -p.vy p.y = math.clamp(p.y, 0, L.h) end
			p.px, p.py = p.x, p.y
		else
			if p.y < -24 then p.y = L.h + 24 p.x = R(0, L.w) elseif p.y > L.h + 24 then p.y = -24 p.x = R(0, L.w) end
			if p.x < -24 then p.x = L.w + 24 elseif p.x > L.w + 24 then p.x = -24 end
			if m == "wander" then
				p.px = p.x + math.sin(t * p.sw + p.ph) * p.amp + math.sin(t * p.sw * 1.7 + p.ph * 2) * p.amp * .5
				p.py = p.y + math.cos(t * p.sw * .8 + p.ph) * p.amp * .7
			else p.px, p.py = p.x + math.sin(t * p.sw + p.ph) * p.amp, p.y end
		end
		local tx, ty = 0, 0
		if mx and m ~= "bounce" then -- отталкивание от курсора
			local dx, dy = p.px - mx, p.py - my
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < 120 and dist > .5 then local f = (120 - dist) * .7 / dist tx, ty = dx * f, dy * f end
		end
		local k = math.min(1, dt * 7)
		p.ox += (tx - p.ox) * k p.oy += (ty - p.oy) * k
		p.o.f.Position = UDim2.fromOffset(p.px + p.ox, p.py + p.oy)
		if p.spin ~= 0 then p.o.f.Rotation = p.r0 + t * p.spin end
		if al then
			local a
			if p.blink then local sn = math.sin(t * p.ts + p.ph) a = p.base * (.12 + .88 * sn * sn)
			elseif p.steady then a = p.base
			else a = p.base * (.25 + .75 * (.5 + .5 * math.sin(t * p.ts + p.ph))) end
			p.o:alpha(a)
		end
	end
	local function links(L, mx, my) -- «созвездие»: линии между близкими точками и к курсору
		local list, pool, D = L.list, L.pool, L.D
		local k = 0
		local function seg(x1, y1, x2, y2, a)
			k += 1
			local f = pool[k] if not f then k -= 1 return end
			local dx, dy = x2 - x1, y2 - y1
			f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 1)
			f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
			f.Rotation = math.deg(math.atan2(dy, dx))
			f.BackgroundTransparency = 1 - a
			f.Visible = true
		end
		for i = 1, #list do
			local a = list[i]
			for j = i + 1, #list do
				local b = list[j]
				local dx, dy = a.px - b.px, a.py - b.py
				local d2 = dx * dx + dy * dy
				if d2 < D * D then seg(a.px, a.py, b.px, b.py, (1 - math.sqrt(d2) / D) * .55) end
			end
			if mx then
				local dx, dy = a.px - mx, a.py - my
				local dist = math.sqrt(dx * dx + dy * dy)
				if dist < 150 then seg(a.px, a.py, mx, my, (1 - dist / 150) * .85) end
			end
		end
		for i = k + 1, L.lastK do pool[i].Visible = false end
		L.lastK = k
	end
	local function sgn(v) return v >= 0 and 1 or -1 end
	local tt, fc = 0, 0
	conn(RS.RenderStepped, function(dt)
		if not W.Open then if outC.Visible then outC.Visible = false end return end
		local on1, on2 = FX.menu, FX.ambient
		if inC.Visible ~= on1 then inC.Visible = on1 end
		if outC.Visible ~= on2 then outC.Visible = on2 end
		if self.FXDirty and os.clock() >= self.FXDirty then self.FXDirty = nil reset() end
		local vp = workspace.CurrentCamera.ViewportSize
		if on1 and not built.i then built.i = true build(LIN) end
		if on2 and not built.o then built.o = true LOUT.w, LOUT.h = vp.X, vp.Y build(LOUT) end
		if not (on1 or on2) then return end
		dt = math.min(dt, .05) * FX.speed / 100
		tt += dt fc += 1
		local al = fc % 2 == 0
		local m = FX.react and UIS:GetMouseLocation() or nil
		if on1 then
			local ap, as = main.AbsolutePosition, main.AbsoluteSize
			local sc = math.max(.01, as.X / MW)
			local mx, my
			if m then mx, my = (m.X - ap.X) / sc, (m.Y - ap.Y) / sc end
			for _, b in ipairs(BL) do b.o.f.Position = UDim2.fromOffset(MW * (.5 + .32 * math.sin(tt * b.sp + b.ph)), MH * (.5 + .32 * math.cos(tt * b.sp * 1.2 + b.ph))) end
			for _, p in ipairs(LIN.list) do step(p, LIN, tt, dt, al, mx, my) end
			if FX.style == "Constellation" then links(LIN, mx, my) end
		end
		if on2 then
			LOUT.w, LOUT.h = vp.X, vp.Y
			local mx, my = m and m.X, m and m.Y
			for _, p in ipairs(LOUT.list) do step(p, LOUT, tt, dt, al, mx, my) end
			if FX.style == "Constellation" then links(LOUT, mx, my) end
			local ap, as = main.AbsolutePosition, main.AbsoluteSize
			local cx, cy, hw, hh = ap.X + as.X / 2, ap.Y + as.Y / 2, as.X / 2, as.Y / 2
			for _, p in ipairs(ORB) do
				local function pos(th)
					local c, s = math.cos(th), math.sin(th)
					local a, b = hw + p.pad + math.sin(tt * .6 + p.ph) * 7, hh + p.pad + math.cos(tt * .5 + p.ph) * 7
					return cx + a * sgn(c) * math.abs(c) ^ .32, cy + b * sgn(s) * math.abs(s) ^ .32
				end
				local th = p.th + p.dir * p.sp * tt
				local x, y = pos(th)
				p.o.f.Position = UDim2.fromOffset(x, y)
				if p.spin ~= 0 then p.o.f.Rotation = p.r0 + tt * p.spin end
				local a = p.base * (.6 + .4 * math.sin(th + p.ph)) * (.7 + .3 * math.sin(tt * p.ts + p.ph))
				if al then p.o:alpha(a) end
				for k, f in ipairs(p.tr) do
					local tx, ty = pos(th - p.dir * k * .05)
					f.Position = UDim2.fromOffset(tx, ty)
					if al then f.BackgroundTransparency = 1 - math.clamp(a * (.55 - k * .14), 0, 1) end
				end
			end
		end
	end)
end

-- ===== notifications / HUD =====
function Nova:Notify(o)
	if self.NoNotify or not self.Gui then return end
	local h = self.Toasts
	if not h then
		h = new("Frame", {Size = UDim2.new(0, 250, 1, -20), Position = UDim2.new(1, -262, 0, 10), BackgroundTransparency = 1, Parent = self.Gui})
		new("UIListLayout", {Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Parent = h})
		self.Toasts = h
	end
	local t = new("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ClipsDescendants = true, Parent = h}) corner(t, 8) stroke(t, C.Stroke, 1, .3)
	local bar = new("Frame", {Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = t}) corner(bar, 2)
	txt({Text = o.Title or "Nova", Font = Enum.Font.GothamBold, Size = UDim2.new(1, -28, 0, 16), Position = UDim2.fromOffset(20, 6), Parent = t})
	txt({Text = o.Text or "", TextColor3 = C.Sub, TextSize = 11, Size = UDim2.new(1, -28, 0, 14), Position = UDim2.fromOffset(20, 23), Parent = t})
	local pr = new("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = t})
	local dur = o.Time or 3
	TS:Create(pr, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)}):Play()
	task.delay(dur, function() t:Destroy() end)
end
function Nova:_hud(name)
	local wm = new("Frame", {Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(14, 14), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Parent = self.Gui})
	corner(wm, 7) stroke(wm, C.Stroke, 1, .3) new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = wm})
	local l = txt({Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Font = Enum.Font.GothamBold, TextSize = 11, RichText = true, Parent = wm})
	self.WM = wm
	local kl = new("Frame", {Size = UDim2.fromOffset(150, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Visible = false, Parent = self.Gui})
	corner(kl, 8) stroke(kl, C.Stroke, 1, .3)
	new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = kl})
	new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = kl})
	txt({Text = "KEYBINDS", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 12), Parent = kl})
	self.KL = kl
	self.HudF = {wm = wm, kl = kl}
	self:_dragHud(wm, "wm") self:_dragHud(kl, "kl")
	local frames = 0
	conn(RS.RenderStepped, function() frames += 1 end)
	task.spawn(function()
		while self.Gui and self.Gui.Parent do
			local ping = 0
			pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			l.Text = ('<font color="#%s">%s</font>  %s  |  %d fps  |  %d ms'):format(C.Accent:ToHex(), name, LP.DisplayName, frames, ping)
			frames = 0 task.wait(1)
		end
	end)
end
function Nova:_dragHud(f, key) -- HUD можно таскать мышью, пока меню открыто
	local st = f:FindFirstChildOfClass("UIStroke")
	local drag, off
	local function hot(on) if st then tw(st, .15, {Color = on and C.Accent or C.Stroke, Transparency = on and .1 or .3}) end end
	local function open() return self.Window and self.Window.Open end
	f.MouseEnter:Connect(function() if open() then hot(true) end end)
	f.MouseLeave:Connect(function() if not drag then hot(false) end end)
	f.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 and open() then
			local ap = f.AbsolutePosition
			off = ap - UIS:GetMouseLocation()
			f.AnchorPoint = Vector2.new() f.Position = UDim2.fromOffset(ap.X, ap.Y) drag = true hot(true)
		end
	end)
	conn(UIS.InputChanged, function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
			local vp, sz, p = self.Gui.AbsoluteSize, f.AbsoluteSize, UIS:GetMouseLocation() + off
			f.Position = UDim2.fromOffset(math.clamp(p.X, 0, math.max(0, vp.X - sz.X)), math.clamp(p.Y, 0, math.max(0, vp.Y - sz.Y)))
		end
	end)
	conn(UIS.InputEnded, function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = false hot(false)
			local vp, ap = self.Gui.AbsoluteSize, f.AbsolutePosition
			self:SetHud(key, ap.X / vp.X, ap.Y / vp.Y)
		end
	end)
end
function Nova:SetHud(key, fx, fy)
	local f = self.HudF and self.HudF[key] if not f then return end
	fx, fy = math.clamp(tonumber(fx) or 0, 0, 1), math.clamp(tonumber(fy) or 0, 0, 1)
	self.Hud[key] = {fx, fy}
	f.AnchorPoint = Vector2.new() f.Position = UDim2.fromScale(fx, fy)
end
function Nova:ResetHud()
	self.Hud = {}
	local w, k = self.HudF.wm, self.HudF.kl
	w.AnchorPoint, w.Position = Vector2.new(), UDim2.fromOffset(14, 14)
	k.AnchorPoint, k.Position = Vector2.new(1, 0), UDim2.new(1, -14, 0, 14)
end
function Nova:_list()
	local kl = self.KL if not kl then return end
	for _, c in ipairs(kl:GetChildren()) do if c.Name == "e" then c:Destroy() end end
	local n = 0
	for _, B in ipairs(self.Binds) do
		if B.Key and not B.Menu and B.Owner.Value then
			n += 1 txt({Name = "e", Text = B.Owner.Name .. "  [" .. short(B.Key) .. "]", TextColor3 = C.Accent, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = n, Parent = kl})
		end
	end
	kl.Visible = self.ShowKL and (n > 0 or (self.Window and self.Window.Open) or false) -- пока меню открыто, список виден, чтобы его можно было переставить
end

-- ===== input =====
function Nova:_input()
	local function inside(o, p) local a, s = o.AbsolutePosition, o.AbsoluteSize return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y end
	conn(UIS.InputBegan, function(i, gp)
		local t, L = i.UserInputType, self.Listening
		if L then
			if t == Enum.UserInputType.Keyboard then
				self.Listening = nil
				if i.KeyCode == Enum.KeyCode.Backspace then L:Set(nil) elseif i.KeyCode == Enum.KeyCode.Escape then L.Draw() else L:Set(i.KeyCode.Name) end
			elseif t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 then self.Listening = nil L:Set(t.Name)
			elseif t == Enum.UserInputType.MouseButton1 then self.Listening = nil L.Draw() end
			return
		end
		if self.Pop and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			local p = UIS:GetMouseLocation()
			if not inside(self.Pop, p) and not inside(self.PopAnchor, p) then self:_close() end
		end
		if gp or UIS:GetFocusedTextBox() then return end
		local n = t == Enum.UserInputType.Keyboard and i.KeyCode.Name or t.Name
		local W = self.Window
		if not self.MenuBound and n == W.Key then W:SetOpen(not W.Open) end
		for _, B in ipairs(self.Binds) do
			if B.Key == n then
				if B.Menu then W:SetOpen(not W.Open)
				elseif B.Mode == "Toggle" then B.Owner:Set(not B.Owner.Value)
				elseif B.Mode == "Hold" then B.Owner:Set(true) end
			end
		end
	end)
	conn(UIS.InputEnded, function(i)
		local t = i.UserInputType
		local n = t == Enum.UserInputType.Keyboard and i.KeyCode.Name or t.Name
		for _, B in ipairs(self.Binds) do if B.Key == n and B.Mode == "Hold" then B.Owner:Set(false) end end
	end)
end

-- ===== configs =====
function Nova:Export()
	local d = {}
	for f, O in pairs(self.Options) do
		if not O.NoSave then
			local v = O.Value
			if O.Type == "Color" then v = v:ToHex()
			elseif O.Type == "Dropdown" and O.Multi then local a = {} for k, on in pairs(v) do if on then a[#a + 1] = k end end v = a end
			d[f] = {v = v, b = O.Bind and {k = O.Bind.Key, m = O.Bind.Mode} or nil}
		end
	end
	if next(self.Hud) then d._hud = self.Hud end
	return Http:JSONEncode(d)
end
function Nova:Import(s)
	local ok, d = pcall(Http.JSONDecode, Http, s)
	if not ok or type(d) ~= "table" then return false end
	if type(d._hud) == "table" then for k, v in pairs(d._hud) do if type(v) == "table" then self:SetHud(k, v[1], v[2]) end end end
	for f, e in pairs(d) do
		local O = self.Options[f]
		if O then pcall(function()
			if e.b and O.Bind then O.Bind:Set(e.b.k, e.b.m) end
			if O.Type ~= "Keybind" and not (O.Bind and O.Bind.Mode ~= "Toggle") then O:Set(O.Type == "Color" and Color3.fromHex(e.v) or e.v) end
		end) end
	end
	return true
end
function Nova:_path(n) return self.Folder .. "/configs/" .. n .. ".json" end
function Nova:ListConfigs()
	local t = {}
	pcall(function() for _, p in ipairs(listfiles(self.Folder .. "/configs")) do local n = p:match("([^/\\]+)%.json$") if n then t[#t + 1] = n end end end)
	table.sort(t) return t
end
function Nova:SaveConfig(n) if not n or n == "" then return false end return (pcall(writefile, self:_path(n), self:Export())) end
function Nova:LoadConfig(n) local ok, s = pcall(readfile, self:_path(n)) return ok and self:Import(s) end
function Nova:DeleteConfig(n) return (pcall(delfile, self:_path(n))) end
function Nova:SetAutoload(n) pcall(writefile, self.Folder .. "/autoload.txt", n or "") end
function Nova:Autoload()
	local ok, n = pcall(readfile, self.Folder .. "/autoload.txt")
	if ok and n ~= "" and self:LoadConfig(n) then self:Notify({Title = "Config", Text = "Autoload: " .. n}) end
end
function Nova:Unload()
	if self.Restore then self.Restore() self.Restore = nil end
	self.All = {}
	for _, c in ipairs(self.Conns) do pcall(c.Disconnect, c) end
	if self.Gui then self.Gui:Destroy() end
	self.Gui, self.Binds, self.Options, self.Flags, self.Hooks, self.Conns, self.Pop, self.KL, self.Toasts = nil, {}, {}, {}, {}, {}, nil, nil, nil
	self.Glass, self.FX, self.Hud, self.Window, self.CursorApply = {}, {menu = false, ambient = false, style = "Mixed", density = 100, speed = 100, react = true}, {}, nil, nil
	self.Cur = {style = "Arrow", size = 100, trail = false, tlen = 10}
end

-- ===== window =====
function Nova:CreateWindow(cfg)
	cfg = cfg or {}
	local name = cfg.Name or "Nova"
	local W = {Tabs = {}, Open = true, Key = (typeof(cfg.Key) == "EnumItem" and cfg.Key.Name) or cfg.Key or "RightShift"} -- по умолчанию RShift
	self.Window, self.Folder = W, cfg.Folder or "Nova"
	pcall(function() for _, p in ipairs({self.Folder, self.Folder .. "/configs"}) do if not isfolder(p) then makefolder(p) end end end)
	local gui = new("ScreenGui", {Name = "Nova", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 999})
	if not pcall(function() gui.Parent = (gethui and gethui()) or svc("CoreGui") end) or not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
	self.Gui = gui
	local main = new("Frame", {Size = UDim2.fromOffset(700, 460), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = C.Bg, BorderSizePixel = 0, Parent = gui})
	corner(main, 14) stroke(main, C.Stroke, 1, .35)
	local sc = new("UIScale", {Parent = main})
	local bar = new("Frame", {Size = UDim2.new(1, -40, 0, 2), Position = UDim2.fromOffset(20, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5, Parent = main}) corner(bar, 2) grad(bar)

	-- rail
	local rail = new("Frame", {Size = UDim2.new(0, 170, 1, 0), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Parent = main}) corner(rail, 14)
	new("Frame", {Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Parent = rail})
	local logo = new("Frame", {Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = rail}) corner(logo, 9) grad(logo, 45)
	txt({Text = "star", FontFace = ICON, TextSize = 16, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = logo})
	txt({Text = name, Font = Enum.Font.GothamBold, TextSize = 15, Size = UDim2.new(1, -60, 0, 16), Position = UDim2.fromOffset(52, 14), Parent = rail})
	txt({Text = cfg.Sub or "v1.0", TextSize = 10, TextColor3 = C.Mute, Size = UDim2.new(1, -60, 0, 12), Position = UDim2.fromOffset(52, 31), Parent = rail})
	local list = new("ScrollingFrame", {Size = UDim2.new(1, -16, 1, -126), Position = UDim2.fromOffset(8, 62), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = rail})
	new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})
	local uc = new("Frame", {Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0, 8, 1, -54), BackgroundColor3 = C.Card, BorderSizePixel = 0, Parent = rail}) corner(uc, 10)
	local av = new("ImageLabel", {Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(9, 9), BackgroundColor3 = C.Elem, Parent = uc}) corner(av, 14)
	task.spawn(function() local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) if ok then av.Image = img end end)
	txt({Text = LP.DisplayName, Font = Enum.Font.GothamBold, Size = UDim2.new(1, -52, 0, 14), Position = UDim2.fromOffset(44, 10), TextTruncate = Enum.TextTruncate.AtEnd, Parent = uc})
	txt({Text = "@" .. LP.Name, TextSize = 10, TextColor3 = C.Mute, Size = UDim2.new(1, -52, 0, 12), Position = UDim2.fromOffset(44, 24), TextTruncate = Enum.TextTruncate.AtEnd, Parent = uc})

	-- body / topbar
	local body = new("Frame", {Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(170, 0), BackgroundTransparency = 1, Parent = main})
	local top = new("Frame", {Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = body})
	local title = txt({Font = Enum.Font.GothamBold, TextSize = 15, Size = UDim2.new(.4, 0, 1, 0), Position = UDim2.fromOffset(16, 0), Parent = top})
	local sb = new("Frame", {Size = UDim2.fromOffset(180, 28), Position = UDim2.new(1, -232, .5, -14), BackgroundColor3 = C.Elem, BorderSizePixel = 0, Parent = top}) corner(sb, 8)
	txt({Text = "magnifying-glass", FontFace = ICON, TextSize = 13, TextColor3 = C.Mute, Size = UDim2.fromOffset(26, 28), TextXAlignment = Enum.TextXAlignment.Center, Parent = sb})
	local box = new("TextBox", {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(26, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Search", PlaceholderColor3 = C.Mute,
		TextColor3 = C.Text, Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = sb})
	local xb = new("TextButton", {Text = "x", FontFace = ICON, TextSize = 14, TextColor3 = C.Sub, BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -40, .5, -14), Parent = top})
	xb.MouseEnter:Connect(function() tw(xb, .15, {TextColor3 = C.Text}) end) xb.MouseLeave:Connect(function() tw(xb, .15, {TextColor3 = C.Sub}) end)
	xb.MouseButton1Click:Connect(function() W:SetOpen(false) end)
	-- глобальный поиск: ищет по всем вкладкам, клик = переход к элементу + подсветка
	local sres = new("ScrollingFrame", {Size = UDim2.new(1, -24, 1, -60), Position = UDim2.fromOffset(12, 52), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, Parent = body})
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sres})
	function W:ClearHL() W.JumpToken = nil if W.HL then W.HL:Destroy() W.HL = nil end end
	function W:Jump(e)
		e.tab:Select()
		if e.sub then e.sub:Select() end
		if e.sec.Collapsed then e.sec:SetCollapsed(false) end
		local token = {} W.JumpToken = token
		task.defer(function()
			task.wait()
			if W.JumpToken ~= token or W.Cur ~= e.tab then return end -- ушли с вкладки — не подсвечиваем
			local card = e.sec.Card
			local colf = card.Parent
			colf.CanvasPosition = Vector2.new(0, math.max(0, card.AbsolutePosition.Y - colf.AbsolutePosition.Y + colf.CanvasPosition.Y - 6))
			local hl = new("Frame", {Size = UDim2.new(1, 8, 1, 6), Position = UDim2.fromOffset(-4, -3), BackgroundColor3 = C.Accent, BackgroundTransparency = .65, BorderSizePixel = 0, ZIndex = 3, Parent = e[1]}) corner(hl, 7)
			W.HL = hl
			tw(hl, 1.4, {BackgroundTransparency = 1})
			task.delay(1.4, function() if W.HL == hl then W.HL = nil end hl:Destroy() end)
		end)
	end
	conn(box:GetPropertyChangedSignal("Text"), function()
		local q = box.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
		for _, c in ipairs(sres:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		sres.Visible = q ~= ""
		if W.Cur then W.Cur.Page.Visible = q == "" end
		title.Text = q ~= "" and "Search" or (W.Cur and W.Cur.Name or "")
		if q == "" then return end
		local n = 0
		for _, e in ipairs(Nova.All) do
			if n < 40 and (e[2] .. " " .. e.tab.Name:lower() .. " " .. e.sec.Name:lower()):find(q, 1, true) then
				n += 1
				local b = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.Card, LayoutOrder = n, Parent = sres}) corner(b, 9)
				txt({Text = e.name, Font = Enum.Font.GothamBold, Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 5), Parent = b})
				txt({Text = e.tab.Name .. "  ›  " .. (e.sub and (e.sub.Name .. "  ›  ") or "") .. e.sec.Name, TextSize = 10, TextColor3 = C.Mute, Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 23), Parent = b})
				b.MouseEnter:Connect(function() tw(b, .15, {BackgroundColor3 = C.Elem}) end) b.MouseLeave:Connect(function() tw(b, .15, {BackgroundColor3 = C.Card}) end)
				b.MouseButton1Click:Connect(function() W:Jump(e) end)
			end
		end
		if n == 0 then txt({Text = "Nothing found", TextColor3 = C.Mute, Size = UDim2.new(1, 0, 0, 30), Parent = sres}) end
	end)

	-- drag
	local dragging, ds, sp = false
	top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging, ds, sp = true, i.Position, main.Position end
	end)
	conn(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - ds main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
	conn(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)

	-- кастомный курсор + разблокировка мыши (работает, даже если игра фиксирует курсор)
	local cur, cmove, capply = Nova:_cursor(gui)
	Nova.CursorApply = capply
	new("TextButton", {Text = "", Modal = true, Size = UDim2.new(), BackgroundTransparency = 1, Parent = main})
	local saved
	function W:Grab(on)
		if on == (W.Grabbed == true) then return end
		W.Grabbed = on
		if on then
			saved = {UIS.MouseBehavior, UIS.MouseIconEnabled} -- запоминаем состояние игры
			cmove(UIS:GetMouseLocation(), 1) -- свечение сразу встаёт под курсор
			RS:BindToRenderStep("NovaCursor", Enum.RenderPriority.Last.Value, function(dt) -- после камеры игры, перебивает её lock
				UIS.MouseBehavior = Enum.MouseBehavior.Default
				local show = Nova.CustomCursor and UIS.MouseEnabled
				UIS.MouseIconEnabled = not show
				cur.Visible = show
				if show then cmove(UIS:GetMouseLocation(), dt) end
			end)
			CAS:BindActionAtPriority("NovaSink", function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value,
				Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseWheel) -- клики по меню не доходят до игры
		else
			RS:UnbindFromRenderStep("NovaCursor") CAS:UnbindAction("NovaSink")
			cur.Visible = false
			if saved then UIS.MouseBehavior, UIS.MouseIconEnabled = saved[1], saved[2] end -- возвращаем как считает игра
		end
	end
	Nova.Restore = function() W:Grab(false) end

	self.Window = W
	self:_fx(main, gui, W)

	function W:SetOpen(v)
		W.Open = v Nova:_close() W:Grab(v) Nova:_list()
		if v then main.Visible = true sc.Scale = .94 tw(sc, .3, {Scale = 1})
		else tw(sc, .15, {Scale = .94}) task.delay(.15, function() if not W.Open then main.Visible = false end end) end
	end

	local ord = 0
	function W:AddDivider(t)
		ord += 1 txt({Text = "  " .. t:upper(), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.Mute, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = ord, Parent = list})
	end
	function W:AddTab(tname, icon)
		ord += 1
		local Tab = {Name = tname, Items = {}, Sections = {}}
		local btn = new("TextButton", {Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.Elem, BackgroundTransparency = 1, LayoutOrder = ord, Parent = list}) corner(btn, 9)
		local ic = txt({Text = icon or "circle", FontFace = ICON, TextSize = 15, TextColor3 = C.Sub, Size = UDim2.fromOffset(24, 34), Position = UDim2.fromOffset(10, 0), TextXAlignment = Enum.TextXAlignment.Center, Parent = btn})
		local lb = txt({Text = tname, TextColor3 = C.Sub, Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(40, 0), Parent = btn})
		local ind = new("Frame", {Size = UDim2.fromOffset(3, 0), AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, -8, .5, 0), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = btn}) corner(ind, 2)
		acc(function() ind.BackgroundColor3 = C.Accent if W.Cur == Tab then ic.TextColor3 = C.Accent end end)
		local page = new("Frame", {Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 1, Visible = false, Parent = body})
		local function col(par, pos)
			local s = new("ScrollingFrame", {Size = UDim2.new(.5, -16, 1, 0), Position = pos, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.Stroke,
				AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = par})
			new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s}) new("UIPadding", {PaddingBottom = UDim.new(0, 10), Parent = s})
			return s
		end
		Tab.Page = page
		local function style(on)
			page.Visible = on
			tw(btn, .2, {BackgroundTransparency = on and 0 or 1}) tw(ic, .2, {TextColor3 = on and C.Accent or C.Sub}) tw(lb, .2, {TextColor3 = on and C.Text or C.Sub}) tw(ind, .2, {Size = UDim2.fromOffset(3, on and 16 or 0)})
		end
		function Tab:Select()
			Nova:_close() W:ClearHL()
			for _, t in ipairs(W.Tabs) do t._style(false) end
			W.Cur = Tab style(true) title.Text = tname box.Text = ""
		end
		Tab._style = style
		btn.MouseButton1Click:Connect(function() Tab:Select() end)
		local function mkSection(owner, sub, sname, c, opt)
			local cols = owner.GetCols()
			local parent = (c == 1 and cols[1]) or (c == 2 and cols[2]) or (#owner.Sections % 2 == 0 and cols[1] or cols[2])
			local card = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Card, BorderSizePixel = 0, LayoutOrder = #owner.Sections, Parent = parent})
			corner(card, 11) stroke(card, Color3.new(1, 1, 1), 1, .94)
			table.insert(Nova.Glass, card) card.BackgroundTransparency = Nova.FX.menu and FXGLASS or 0
			new("UIPadding", {PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = card})
			new("UIListLayout", {Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card})
			local dot = new("Frame", {Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = nil}) corner(dot, 3)
			local head = txt({Text = "      " .. sname:upper(), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 14), Parent = card})
			dot.Parent = head acc(function() dot.BackgroundColor3 = C.Accent end)
			dot.Position = UDim2.fromOffset(0, 4)
			local chev = txt({Text = "▾", TextSize = 12, TextColor3 = C.Mute, Size = UDim2.fromOffset(16, 14), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), TextXAlignment = Enum.TextXAlignment.Center, Parent = head})
			local hb = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = head})
			local sec = setmetatable({Card = card, Tab = Tab, Sub = sub, n = 0, Name = sname, Rows = {}, Collapsed = false}, S)
			function sec:SetCollapsed(v) -- свернуть / развернуть секцию (клик по заголовку)
				sec.Collapsed = v and true or false
				for _, r in ipairs(sec.Rows) do r.Visible = not sec.Collapsed end
				tw(chev, .2, {Rotation = sec.Collapsed and -90 or 0})
			end
			hb.MouseButton1Click:Connect(function() sec:SetCollapsed(not sec.Collapsed) end)
			hb.MouseEnter:Connect(function() tw(chev, .15, {TextColor3 = C.Text}) end) hb.MouseLeave:Connect(function() tw(chev, .15, {TextColor3 = C.Mute}) end)
			table.insert(owner.Sections, sec)
			if opt and opt.Collapsed then sec:SetCollapsed(true) end
			return sec
		end
		Tab.GetCols = function()
			if not Tab.Cols then Tab.Cols = {col(page, UDim2.fromOffset(12, 0)), col(page, UDim2.new(.5, 4, 0, 0))} end
			return Tab.Cols
		end
		function Tab:AddSection(sname, c, opt) return mkSection(Tab, nil, sname, c, opt) end -- opt = {Collapsed = true}
		function Tab:AddSubTab(stname) -- подвкладка внутри вкладки (не смешивать с Tab:AddSection)
			if not Tab.Bar then
				Tab.Bar = new("Frame", {Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Parent = page})
				new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Tab.Bar})
				Tab.Subs = {}
			end
			local sp = new("Frame", {Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, Visible = false, Parent = page})
			local St = {Name = stname, Tab = Tab, Sections = {}, Page = sp}
			St.Cols = {col(sp, UDim2.fromOffset(12, 0)), col(sp, UDim2.new(.5, 4, 0, 0))}
			St.GetCols = function() return St.Cols end
			St.Btn = new("TextButton", {Text = stname, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.Sub, AutoButtonColor = false, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26),
				BackgroundColor3 = C.Elem, BackgroundTransparency = 1, LayoutOrder = #Tab.Subs + 1, Parent = Tab.Bar}) corner(St.Btn, 8)
			new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = St.Btn})
			function St:Select()
				Nova:_close() W:ClearHL()
				for _, o in ipairs(Tab.Subs) do
					o.Page.Visible = o == St
					tw(o.Btn, .2, {BackgroundTransparency = o == St and 0 or 1, TextColor3 = o == St and C.Text or C.Sub})
				end
				Tab.CurSub = St
			end
			St.Btn.MouseButton1Click:Connect(function() St:Select() end)
			function St:AddSection(sname, c, opt) return mkSection(St, St, sname, c, opt) end
			table.insert(Tab.Subs, St)
			if #Tab.Subs == 1 then St:Select() end
			return St
		end
		table.insert(W.Tabs, Tab)
		if #W.Tabs == 1 then Tab:Select() end
		return Tab
	end

	-- готовая вкладка Settings: меню, акцент, HUD, конфиги
	function W:BuildSettings()
		local tab = W:AddTab("Settings", "gear")
		local gen, fxt = tab:AddSubTab("General"), tab:AddSubTab("Effects")
		local m = gen:AddSection("Menu", 1)
		m:AddKeybind({Name = "Menu key", Flag = "menu_key", Default = W.Key, Menu = true})
		m:AddColor({Name = "Accent", Flag = "accent", Default = C.Accent, Palette = true, Callback = function(c) Nova:SetAccent(c) end})
		m:AddToggle({Name = "Notifications", Flag = "notify", Default = true, Callback = function(v) Nova.NoNotify = not v end})
		m:AddButton({Name = "Unload menu", Callback = function() Nova:Unload() end})
		local hs = gen:AddSection("HUD", 1)
		hs:AddToggle({Name = "Watermark", Flag = "show_wm", Default = true, Callback = function(v) Nova.WM.Visible = v end})
		hs:AddToggle({Name = "Keybind list", Flag = "show_kl", Default = true, Callback = function(v) Nova.ShowKL = v Nova:_list() end})
		hs:AddButton({Name = "Reset HUD positions", Callback = function() Nova:ResetHud() end})
		local c = gen:AddSection("Configs", 2)
		c:AddTextbox({Name = "Name", Flag = "cfg_name", Placeholder = "my_config", NoSave = true})
		local dd = c:AddDropdown({Name = "Saved", Flag = "cfg_sel", Values = Nova:ListConfigs(), NoSave = true})
		local function cur() local n = Nova.Flags.cfg_name if n == "" or not n then n = Nova.Flags.cfg_sel end return n end
		local function refresh() dd:SetValues(Nova:ListConfigs()) end
		c:AddButton({Name = "Save / overwrite", Callback = function()
			local n = cur() if not n then return Nova:Notify({Title = "Config", Text = "Enter a name"}) end
			Nova:SaveConfig(n) refresh() dd:Set(n, true) Nova:Notify({Title = "Config", Text = "Saved: " .. n})
		end})
		c:AddButton({Name = "Load", Callback = function()
			local n = cur() Nova:Notify({Title = "Config", Text = (n and Nova:LoadConfig(n)) and ("Loaded: " .. n) or "Load failed"})
		end})
		c:AddButton({Name = "Delete", Callback = function()
			local n = Nova.Flags.cfg_sel if n then Nova:DeleteConfig(n) refresh() Nova:Notify({Title = "Config", Text = "Deleted: " .. n}) end
		end})
		c:AddButton({Name = "Set as autoload", Callback = function()
			local n = cur() if n then Nova:SetAutoload(n) Nova:Notify({Title = "Config", Text = "Autoload: " .. n}) end
		end})
		c:AddButton({Name = "Export to clipboard", Callback = function()
			local ok = pcall(setclipboard, Nova:Export()) Nova:Notify({Title = "Config", Text = ok and "Copied" or "Clipboard unavailable"})
		end})
		local imp = c:AddTextbox({Name = "Import", Flag = "cfg_import", Placeholder = "paste JSON", NoSave = true})
		c:AddButton({Name = "Import from field", Callback = function()
			Nova:Notify({Title = "Config", Text = Nova:Import(imp.Value) and "Imported" or "Invalid JSON"})
		end})
		-- Effects: курсор и частицы
		local cs = fxt:AddSection("Cursor", 1)
		cs:AddToggle({Name = "Custom cursor", Flag = "custom_cursor", Default = true, Callback = function(v) Nova.CustomCursor = v end})
		cs:AddDropdown({Name = "Cursor style", Flag = "cur_style", Values = {"Arrow", "Dot", "Crosshair"}, Default = "Arrow", Callback = function(v) Nova:SetCursor("style", v) end})
		cs:AddSlider({Name = "Cursor size", Flag = "cur_size", Min = 60, Max = 200, Step = 5, Default = 100, Suffix = "%", Callback = function(v) Nova:SetCursor("size", v) end})
		cs:AddToggle({Name = "Cursor trail", Flag = "cur_trail", Default = false, Callback = function(v) Nova:SetCursor("trail", v) end})
		cs:AddSlider({Name = "Trail length", Flag = "cur_tlen", Min = 4, Max = 16, Default = 10, Callback = function(v) Nova:SetCursor("tlen", v) end})
		local ps = fxt:AddSection("Particles", 2)
		ps:AddToggle({Name = "Menu particles", Flag = "fx_menu", Default = true, Callback = function(v) Nova:SetFX("menu", v) end})
		ps:AddToggle({Name = "Ambient particles", Flag = "fx_ambient", Default = true, Callback = function(v) Nova:SetFX("ambient", v) end})
		ps:AddDropdown({Name = "Particle style", Flag = "fx_style", Values = {"Mixed", "Dust", "Fireflies", "Snow", "Constellation"}, Default = "Mixed", Callback = function(v) Nova:SetFX("style", v) end})
		ps:AddSlider({Name = "Particle density", Flag = "fx_density", Min = 25, Max = 200, Step = 5, Default = 100, Suffix = "%", Callback = function(v) Nova:SetFX("density", v) end})
		ps:AddSlider({Name = "Particle speed", Flag = "fx_speed", Min = 25, Max = 250, Step = 5, Default = 100, Suffix = "%", Callback = function(v) Nova:SetFX("speed", v) end})
		ps:AddToggle({Name = "Cursor reaction", Flag = "fx_react", Default = true, Callback = function(v) Nova:SetFX("react", v) end}) -- отталкивает частицы; в Constellation — линии к курсору
		for _, k in ipairs({"menu", "ambient", "style", "density", "speed", "react"}) do Nova:SetFX(k, Nova.Flags["fx_" .. k]) end
		for k, f in pairs({style = "cur_style", size = "cur_size", trail = "cur_trail", tlen = "cur_tlen"}) do Nova:SetCursor(k, Nova.Flags[f]) end
		return tab
	end

	self:_input() self:_hud(name) W:SetOpen(true)
	self:Notify({Title = name, Text = "Loaded · " .. short(W.Key) .. " to toggle"})
	return W
end

--[[ ПРИМЕР
local Nova = loadstring(readfile("NovaUI.lua"))()
local Win  = Nova:CreateWindow({Name = "Nova", Sub = "v1.0", Key = "RightShift", Folder = "NovaCfg"})
Win:AddDivider("Main")
local Main = Win:AddTab("Main", "crosshairs")
local A = Main:AddSection("Aim assist", 1) -- 3-й аргумент {Collapsed = true} — секция свёрнута; клик по заголовку сворачивает
A:AddToggle({Name = "Enabled", Flag = "aim", Default = true, Bind = "E", Callback = function(v) print("aim", v) end})
A:AddSlider({Name = "FOV", Flag = "fov", Min = 1, Max = 360, Default = 90, Suffix = "°"})
A:AddRange({Name = "Distance", Flag = "dist", Min = 0, Max = 500, Default = {20, 300}, Suffix = " m"}) -- Nova.Flags.dist.Min / .Max
A:AddDropdown({Name = "Hitbox", Flag = "hit", Values = {"Head", "Torso"}, Default = "Head"})
A:AddDropdown({Name = "Targets", Flag = "tgt", Values = {"Players", "NPCs"}, Multi = true, Default = {"Players"}})
A:AddKeybind({Name = "Panic key", Flag = "panic", Default = "X", Mode = "Hold", Callback = function(s) print("panic", s) end})
A:AddColor({Name = "Color", Flag = "col", Default = Color3.fromRGB(139, 92, 246)}) -- полноценный ColorPicker (Palette = true — простая палитра)
A:AddButton({Name = "Hello", Callback = function() Nova:Notify({Title = "Hi", Text = "It works"}) end})
-- подвкладки: local T = Win:AddTab("Misc"); local a, b = T:AddSubTab("One"), T:AddSubTab("Two"); a:AddSection("X", 1)
Win:AddDivider("Config")
Win:BuildSettings()
Nova:Autoload()
-- читать значения: Nova.Flags.fov  |  Nova.Options.aim:Set(true)
]]
return Nova
