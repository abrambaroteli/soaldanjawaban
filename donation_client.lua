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
end

local function blurUI()
  showCursor(false)
  guiSetInputEnabled(false)
end

local function drawBrowser()
  if UI.isOpen and UI.browser and isElement(UI.browser) then
    dxDrawImage(UI.x, UI.y, UI.w, UI.h, UI.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
  end
end

local function sendToJS(functionName, payload)
  if not (UI.browser and isElement(UI.browser)) then return end
  local js = string.format("window.%s(%s);", tostring(functionName), toJSON(payload or {}))
  executeBrowserJavascript(UI.browser, js)
end

local function pushAll()
  sendToJS("refreshAll", {
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
    -- Tandai kalau init berasal dari Lua
    executeBrowserJavascript(UI.browser, "window.__fromLua = true;")
    local payload = {
      obtained = obtained,
      available = available,
      credits = credits,
      history = history,
      purchased = purchased,
      global = globalPurchaseHistory,
      isFounder = isFounder(),
    }
    sendToJS("initData", payload)
  end)

  addEventHandler("onClientRender", root, drawBrowser)

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
    sendToJS("updateAvailable", { list = available, credits = credits })
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