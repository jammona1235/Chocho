-- ╔══════════════════════════════════════════════╗
-- ║          Chocola Finder - by Apelaxz                                                         ║
-- ╚══════════════════════════════════════════════╝

-- ══════════════════════════════════════════
-- SERVICIOS
-- ══════════════════════════════════════════
local HttpService     = game:GetService("HttpService")
local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LOCAL_PLAYER = Players.LocalPlayer

-- ══════════════════════════════════════════
-- CONSTANTES DE UI
-- ══════════════════════════════════════════
local PANEL_WIDTH  = 400
local PANEL_HEIGHT = 450
local CARD_WIDTH   = 360
local CARD_HEIGHT  = 85
local PADDING      = 8
local BORDER_SIZE  = 4

-- ══════════════════════════════════════════
-- HTTP REQUEST (compatible con ejecutores)
-- ══════════════════════════════════════════
local httpRequest = http_request or request
if not httpRequest then
    warn("Chocola Finder: No http_request disponible - Modo mocho activado")
end

-- ══════════════════════════════════════════
-- ESTADO GLOBAL
-- ══════════════════════════════════════════
local mainFrame    = nil   -- Frame principal del panel
local screenGui    = nil   -- ScreenGui raíz
local isOpen       = false -- Panel abierto
local isDraggingIcon  = false
local iconDragStart   = nil
local iconStartPos    = nil
local isDraggingPanel = false
local panelDragStart  = nil
local panelStartPos   = nil

-- Referencias a elementos del panel (para refresh)
local statusLabel_ref = nil
local scrollFrame_ref = nil

-- ══════════════════════════════════════════
-- FUNCIÓN: Parsear respuesta HTTP
-- ══════════════════════════════════════════
local function parseHttpResponse(response)
    local t = type(response)
    if t == "table" then
        local statusCode = tonumber(response.StatusCode)
        local body = tostring(response.Body)
        return statusCode, body
    elseif t == "string" then
        return nil, response
    else
        return nil, tostring(response)
    end
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Obtener datos del servidor
-- ══════════════════════════════════════════
local function fetchData()
    if not httpRequest then
        return nil, "Sin http_request disponible"
    end

    local API_URL = "https://brain-pro.vercel.app/all"

    local ok, response = pcall(function()
        return httpRequest({
            Url    = API_URL,
            Method = "GET",
        })
    end)

    if not ok then
        return nil, tostring(response)
    end

    local statusCode, body = parseHttpResponse(response)
    if not statusCode then
        return nil, body
    end

    local ok2, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 then
        return nil, tostring(data)
    end

    -- Normalizar a array
    local result = {}
    if type(data) == "table" then
        if #data > 0 then
            result = data
        else
            table.insert(result, data)
        end
    end

    return true, result
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Cerrar panel con animación
-- ══════════════════════════════════════════
local function closePanel()
    if not mainFrame then return end
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    local tween = TweenService:Create(mainFrame, tweenInfo, {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
    })
    tween:Play()
    wait(0.2)
    mainFrame.Visible = false
    mainFrame.BackgroundTransparency = 0.15
    isOpen = false
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Crear tarjeta de un Chocola
-- ══════════════════════════════════════════
local function createCard(parent, data, order)
    -- Contenedor de la tarjeta
    local card = Instance.new("Frame")
    card.Name = "ScriptCard"
    card.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
    card.BackgroundColor3 = Color3.fromRGB(42, 42, 46)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent = card

    -- Nombre del Chocola (brainrotName)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.6, -10, 0, 26)
    nameLabel.Position = UDim2.new(0, 8, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 16
    nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = tostring(data.brainrotName or "???")
    nameLabel.Parent = card

    -- Rareza
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(0.35, -12, 0, 20)
    rarityLabel.Position = UDim2.new(0, 8, 0, 36)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Font = Enum.Font.Gotham
    rarityLabel.TextSize = 14
    rarityLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
    rarityLabel.Text = "Rareza: " .. tostring(data.rarity or "?")
    rarityLabel.Parent = card

    -- Base
    local baseLabel = Instance.new("TextLabel")
    baseLabel.Size = UDim2.new(0.35, -12, 0, 20)
    baseLabel.Position = UDim2.new(0.6, -12, 0, 36)
    baseLabel.BackgroundTransparency = 1
    baseLabel.Font = Enum.Font.Gotham
    baseLabel.TextSize = 14
    baseLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    baseLabel.TextXAlignment = Enum.TextXAlignment.Right
    baseLabel.Text = tostring(data.base or "?")
    baseLabel.Parent = card

    -- PPS y Timestamp
    local ppsLabel = Instance.new("TextLabel")
    ppsLabel.Size = UDim2.new(1, -16, 0, 16)
    ppsLabel.Position = UDim2.new(0, 8, 0, 60)
    ppsLabel.BackgroundTransparency = 1
    ppsLabel.Font = Enum.Font.Gotham
    ppsLabel.TextSize = 12
    ppsLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
    ppsLabel.TextXAlignment = Enum.TextXAlignment.Left
    ppsLabel.Text = string.format("PPS: %s | %s",
        tostring(data.value or "?"),
        tostring(data.timestamp or "?")
    )
    ppsLabel.Parent = card

    -- Botón de teleport
    local teleportBtn = Instance.new("TextButton")
    teleportBtn.Size = UDim2.new(0, 80, 0, 28)
    teleportBtn.Position = UDim2.new(1, -88, 0, 8)
    teleportBtn.BackgroundColor3 = Color3.fromRGB(64, 160, 255)
    teleportBtn.BorderSizePixel = 0
    teleportBtn.Text = "Ir"
    teleportBtn.Font = Enum.Font.Gotham
    teleportBtn.TextSize = 14
    teleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = teleportBtn

    -- Lógica de teleport
    teleportBtn.MouseButton1Click:Connect(function()
        local jobId = tostring(data.jobId or "")
        if jobId == "" or jobId == game.JobId then
            return  -- Ya estás en este servidor
        end
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LOCAL_PLAYER)
        end)
        if not success then
            warn("Chocola Finder: Teleport failed:", err)
        end
    end)

    return card
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Refrescar lista de tarjetas
-- ══════════════════════════════════════════
local function refreshScroll(scroll, data)
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    for index, entry in ipairs(data) do
        createCard(scroll, entry, index)
    end
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Hacer refresh completo (fetch + UI)
-- ══════════════════════════════════════════
local function doRefresh()
    if not statusLabel_ref then return end
    statusLabel_ref.Text = "Actualizando..."

    local ok, data = fetchData()
    if not ok then
        statusLabel_ref.Text = "Error al obtener datos"
        return
    end

    if type(data) == "table" then
        refreshScroll(scrollFrame_ref, data)
    end

    statusLabel_ref.Text = "Última actualización: " .. os.date("%X")
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Crear el panel principal
-- ══════════════════════════════════════════
local function createMainPanel()
    -- Frame contenedor
    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 20)
    frameCorner.Parent = frame

    -- ── Bordes arcoíris ──
    local rainbowColors = {
        Color3.fromRGB(255, 0,   0),    -- Rojo
        Color3.fromRGB(255, 165, 0),    -- Naranja
        Color3.fromRGB(255, 255, 0),    -- Amarillo
        Color3.fromRGB(0,   255, 0),    -- Verde
        Color3.fromRGB(0,   0,   255),  -- Azul
        Color3.fromRGB(75,  0,   130),  -- Índigo
        Color3.fromRGB(238, 130, 238),  -- Violeta
    }

    local borderDefs = {
        { Size = UDim2.new(1, 0, 0, BORDER_SIZE), Position = UDim2.new(0, 0, 0, 0) },               -- Top
        { Size = UDim2.new(1, 0, 0, BORDER_SIZE), Position = UDim2.new(0, 0, 1, -BORDER_SIZE) },     -- Bottom
        { Size = UDim2.new(0, BORDER_SIZE, 1, 0), Position = UDim2.new(0, 0, 0, 0) },               -- Left
        { Size = UDim2.new(0, BORDER_SIZE, 1, 0), Position = UDim2.new(1, -BORDER_SIZE, 0, 0) },    -- Right
    }

    local borderFrames = {}
    for i, def in ipairs(borderDefs) do
        local border = Instance.new("Frame")
        border.Size = def.Size
        border.Position = def.Position
        border.BackgroundColor3 = rainbowColors[i]
        border.BorderSizePixel = 0
        border.Parent = frame
        table.insert(borderFrames, border)
    end

    -- Animación arcoíris en loop
    local colorOffset = 1
    task.spawn(function()
        while frame.Parent do
            for i, borderFrame in ipairs(borderFrames) do
                local colorIdx = ((colorOffset + i - 2) % #rainbowColors) + 1
                local tween = TweenService:Create(
                    borderFrame,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                    { BackgroundColor3 = rainbowColors[colorIdx] }
                )
                tween:Play()
            end
            colorOffset = (colorOffset % #rainbowColors) + 1
            wait(0.3)
        end
    end)

    -- ── Título ──
    local margin = BORDER_SIZE + 5
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -margin * 2, 0, 36)
    titleLabel.Position = UDim2.new(0, margin, 0, margin)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Chocola Finder"
    titleLabel.TextSize = 20
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = frame

    -- ── Botón Actualizar ──
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Name = "RefreshBtn"
    refreshBtn.Size = UDim2.new(0, 90, 0, 28)
    refreshBtn.Position = UDim2.new(1, -margin - 90, 0, margin)
    refreshBtn.Text = "Actualizar"
    refreshBtn.Font = Enum.Font.Gotham
    refreshBtn.TextSize = 14
    refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(58, 58, 60)
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Parent = frame

    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 8)
    refreshCorner.Parent = refreshBtn

    -- ── Status ──
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -margin * 2, 0, 20)
    statusLabel.Position = UDim2.new(0, margin, 0, margin + 36)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Última actualización: nunca"
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = frame

    -- ── ScrollingFrame ──
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "Scroll"
    scrollFrame.Size = UDim2.new(1, -margin * 2, 1, -margin - 80)
    scrollFrame.Position = UDim2.new(0, margin, 0, margin + 60)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.Parent = frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, PADDING)
    listLayout.Parent = scrollFrame

    -- Auto-resize canvas del scroll
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + PADDING)
    end)

    -- ── Arrastrar panel ──
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingPanel = true
            panelDragStart  = input.Position
            panelStartPos   = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDraggingPanel = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDraggingPanel and (
            input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            frame.Position = UDim2.new(
                panelStartPos.X.Scale,
                panelStartPos.X.Offset + (input.Position - panelDragStart).X,
                panelStartPos.Y.Scale,
                panelStartPos.Y.Offset + (input.Position - panelDragStart).Y
            )
        end
    end)

    -- Guardar referencias globales
    mainFrame       = frame
    statusLabel_ref = statusLabel
    scrollFrame_ref = scrollFrame

    -- Conectar botón refresh
    refreshBtn.MouseButton1Click:Connect(doRefresh)

    return frame
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Abrir panel con animación
-- ══════════════════════════════════════════
local function openPanel()
    if not mainFrame then
        createMainPanel()
    end

    isOpen = true
    mainFrame.Visible = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tween = TweenService:Create(mainFrame, tweenInfo, {
        Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
    })
    tween:Play()

    -- Cargar datos al abrir
    doRefresh()
end

-- ══════════════════════════════════════════
-- FUNCIÓN: Crear ScreenGui + FloatingIcon
-- ══════════════════════════════════════════
local function createUI()
    local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

    -- Destruir instancia previa si existe
    local existing = playerGui:FindFirstChild("ChocolaFinderUI")
    if existing then
        existing:Destroy()
    end

    -- ScreenGui raíz
    local gui = Instance.new("ScreenGui")
    gui.Name = "ChocolaFinderUI"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui
    screenGui = gui

    -- ── Icono flotante ──
    local floatingIcon = Instance.new("ImageButton")
    floatingIcon.Name = "FloatingIcon"
    floatingIcon.Size = UDim2.new(0, 55, 0, 55)
    floatingIcon.Position = UDim2.new(0, 25, 0.7, -27)
    floatingIcon.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    floatingIcon.Image = "rbxassetid://135932881512072"
    floatingIcon.Parent = gui

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 12)
    iconCorner.Parent = floatingIcon

    local iconStroke = Instance.new("UIStroke")
    iconStroke.Thickness = 2
    iconStroke.Color = Color3.fromRGB(255, 0, 0)
    iconStroke.Parent = floatingIcon

    -- Animación pulso del borde
    local strokeTween = TweenService:Create(
        iconStroke,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Thickness = 3, Color = Color3.fromRGB(255, 50, 50) }
    )
    strokeTween:Play()

    return floatingIcon
end

-- ══════════════════════════════════════════
-- INICIALIZACIÓN
-- ══════════════════════════════════════════
local floatingIcon = createUI()

-- ── Arrastrar icono flotante ──
floatingIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDraggingIcon = true
        iconDragStart  = input.Position
        iconStartPos   = floatingIcon.Position

        -- Encogimiento en touch
        if input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(floatingIcon, TweenInfo.new(0.1), {
                Size = UDim2.new(0, 50, 0, 50)
            }):Play()
        end

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDraggingIcon = false
                -- Restaurar tamaño en touch
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(floatingIcon, TweenInfo.new(0.1), {
                        Size = UDim2.new(0, 55, 0, 55)
                    }):Play()
                end
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingIcon and (
        input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch
    ) then
        floatingIcon.Position = UDim2.new(
            iconStartPos.X.Scale,
            iconStartPos.X.Offset + (input.Position - iconDragStart).X,
            iconStartPos.Y.Scale,
            iconStartPos.Y.Offset + (input.Position - iconDragStart).Y
        )
    end
end)

-- ── Click del icono: toggle panel ──
floatingIcon.MouseButton1Click:Connect(function()
    -- Ignorar si fue un arrastre (delta > umbral)
    if isDraggingIcon then return end
    if not isOpen then
        openPanel()
    else
        closePanel()
    end
end)

print("Chocola Finder")
