-- Donation CEF UI (client-side)
-- Versi menggunakan createBrowser() + dxDraw sebagai container.

local UI = {
  browser = nil,   -- web browser element
  isOpen = false,
  w = 980,
  h = 620,
  x = 0,
  y = 0,
}

-- State yang dikirim/dipakai UI
local obtained = {}
local available = {}
local credits = 0
local history = {}
local purchased = {}
local globalPurchaseHistory = {}

local function isFounder()
  if getResourceFromName("integration") and exports["integration"].isPlayerFounder then
    return exports["integration"]:isPlayerFounder(localPlayer) and true or false
  end
  return false
end

local function calcCenter()
  local sw, sh = guiGetScreenSize()
  UI.x = math.floor((sw - UI.w) / 2)
  UI.y = math.floor((sh - UI.h) / 2)
end

local function focusUI()
  if UI.browser and isElement(UI.browser) then
    focusBrowser(UI.browser)
  end
  showCursor(true)
  guiSetInputEnabled(true)
  if guiSetInputMode then
    guiSetInputMode("no_binds_when_editing")
  end
end

local function blurUI()
  showCursor(false)
  guiSetInputEnabled(false)
  if guiSetInputMode then
    guiSetInputMode("allow_binds")
  end
end

local function drawBrowser()
  if UI.isOpen and UI.browser and isElement(UI.browser) then
    dxDrawImage(UI.x, UI.y, UI.w, UI.h, UI.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
  end
end

-- Input injection helpers
local function screenToBrowser(px, py)
  local bx = px - UI.x
  local by = py - UI.y
  return bx, by, (bx >= 0 and by >= 0 and bx <= UI.w and by <= UI.h)
end

local function onCursorMove(_, _, absX, absY)
  if not (UI.isOpen and UI.browser and isElement(UI.browser)) then return end
  local bx, by, inside = screenToBrowser(absX, absY)
  if inside then
    injectBrowserMouseMove(UI.browser, bx, by)
  end
end

local function onClick(button, state, absX, absY)
  if not (UI.isOpen and UI.browser and isElement(UI.browser)) then return end
  local bx, by, inside = screenToBrowser(absX, absY)
  if not inside then return end
  if state == "down" then
    injectBrowserMouseDown(UI.browser, button)
  else
    injectBrowserMouseUp(UI.browser, button)
  end
end

local function onKey(button, press)
  if not (UI.isOpen and UI.browser and isElement(UI.browser)) then return end
  -- Mouse wheel
  if button == "mouse_wheel_up" and press then
    injectBrowserMouseWheel(UI.browser, 40, 0)
    cancelEvent()
    return
  elseif button == "mouse_wheel_down" and press then
    injectBrowserMouseWheel(UI.browser, -40, 0)
    cancelEvent()
    return
  end
  -- Keyboard
  local hasKeyDown = type(injectBrowserKeyDown) == "function"
  local hasKeyUp = type(injectBrowserKeyUp) == "function"
  if press then
    if hasKeyDown then injectBrowserKeyDown(UI.browser, button) end
  else
    if hasKeyUp then injectBrowserKeyUp(UI.browser, button) end
  end
end

local function onCharacter(c)
  if not (UI.isOpen and UI.browser and isElement(UI.browser)) then return end
  if type(c) == "string" and #c > 0 then
    injectBrowserInput(UI.browser, c)
  end
end

local function bindInputs()
  addEventHandler("onClientCursorMove", root, onCursorMove)
  addEventHandler("onClientClick", root, onClick)
  addEventHandler("onClientKey", root, onKey)
  addEventHandler("onClientCharacter", root, onCharacter)
end

local function unbindInputs()
  removeEventHandler("onClientCursorMove", root, onCursorMove)
  removeEventHandler("onClientClick", root, onClick)
  removeEventHandler("onClientKey", root, onKey)
  removeEventHandler("onClientCharacter", root, onCharacter)
end

local function execJS(fn, tbl)
  if not (UI.browser and isElement(UI.browser)) then return end
  local ok, json = pcall(toJSON, tbl or {})
  if not ok then return end
  local code = string.format("window.%s(%s);", tostring(fn), json)
  executeBrowserJavascript(UI.browser, code)
end

local function pushAll()
  execJS("refreshAll", {
    obtained = obtained,
    available = available,
    credits = credits,
    history = history,
    purchased = purchased,
    global = globalPurchaseHistory,
    isFounder = isFounder(),
  })
end

function openDonationGUI(obtained1, available1, credits1, history1, purchased1, globalPurchaseHistory1)
  obtained = obtained1 or {}
  available = available1 or {}
  credits = tonumber(credits1) or 0
  history = history1 or {}
  purchased = purchased1 or {}
  globalPurchaseHistory = globalPurchaseHistory1 or {}

  if UI.browser and isElement(UI.browser) then
    UI.isOpen = true
    triggerEvent('hud:blur', resourceRoot, 6, false, 0.5, nil)
    focusUI()
    pushAll()
    return
  end

  calcCenter()
  UI.browser = createBrowser(UI.w, UI.h, true, false)

  addEventHandler("onClientBrowserCreated", UI.browser, function()
    loadBrowserURL(UI.browser, "http://mta/local/ui/index.html")
  end)

  addEventHandler("onClientBrowserDocumentReady", UI.browser, function()
    executeBrowserJavascript(UI.browser, "window.__fromLua = true;")
    execJS("initData", {
      obtained = obtained,
      available = available,
      credits = credits,
      history = history,
      purchased = purchased,
      global = globalPurchaseHistory,
      isFounder = isFounder(),
    })
    -- Fallback kirim lagi setelah 100ms untuk mengatasi race condition
    setTimer(function()
      if UI.browser and isElement(UI.browser) then
        execJS("refreshAll", {
          obtained = obtained,
          available = available,
          credits = credits,
          history = history,
          purchased = purchased,
          global = globalPurchaseHistory,
          isFounder = isFounder(),
        })
      end
    end, 100, 1)
  end)

  addEventHandler("onClientRender", root, drawBrowser)
  bindInputs()

  UI.isOpen = true
  triggerEvent('hud:blur', resourceRoot, 6, false, 0.5, nil)
  focusUI()
end
addEvent("donation-system:GUI:open", true)
addEventHandler("donation-system:GUI:open", root, openDonationGUI)

function closeDonationGUI()
  if UI.browser and isElement(UI.browser) then
    destroyElement(UI.browser)
  end
  removeEventHandler("onClientRender", root, drawBrowser)
  unbindInputs()
  UI.browser = nil
  UI.isOpen = false
  triggerEvent('hud:blur', resourceRoot, 'off')
  blurUI()
end
addEvent("donation:close", true)
addEventHandler("donation:close", resourceRoot, closeDonationGUI)

-- Bridge dari JS ke Lua
addEvent("donation:purchase", true)
addEventHandler("donation:purchase", resourceRoot, function(perkId, payload)
  perkId = tonumber(perkId) or 0
  triggerServerEvent("donation-system:GUI:activate", localPlayer, perkId, payload)
end)

addEvent("donation:info", true)
addEventHandler("donation:info", resourceRoot, function(state)
  state = tonumber(state) or 1
  if type(showInfoPanel) == 'function' then
    showInfoPanel(state)
  else
    outputChatBox("Info panel is not available in this build.")
  end
end)

-- Update sinkronisasi
function updateAvailablePerksCEF(available1, credits1)
  available = available1 or available
  credits = tonumber(credits1) or credits
  if UI.browser and isElement(UI.browser) then
    execJS("updateAvailable", { list = available, credits = credits })
  end
end
addEvent("donation-system:GUI:updateAvailable", true)
addEventHandler("donation-system:GUI:updateAvailable", root, function(a, c)
  updateAvailablePerksCEF(a, c)
end)

-- Respon server (opsional)
function getResponseFromServer(code, msg)
  if not (UI.browser and isElement(UI.browser)) then return end
  -- Contoh ekstensi: executeBrowserJavascript(UI.browser, string.format("window.toast(%s,%s);", toJSON(code), toJSON(msg)))
end
addEvent("donation-system:getResponseFromServer", true)
addEventHandler("donation-system:getResponseFromServer", root, getResponseFromServer)

-- Penutup paksa saat resource stop
addEventHandler("onClientResourceStop", resourceRoot, function()
  blurUI()
end)