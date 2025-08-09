-- Donation CEF UI (client-side)
-- Migrasi dari GUI MTA ke CEF HTML/CSS/JS

local UI = {
  wnd = nil,        -- GUI Browser element
  br = nil,         -- Browser handle
  isOpen = false,
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

local function focusUI()
  if UI.br and isElement(UI.br) then
    focusBrowser(UI.br)
  end
  showCursor(true)
  guiSetInputEnabled(true)
end

local function blurUI()
  showCursor(false)
  guiSetInputEnabled(false)
end

local function sendToJS(functionName, payload)
  if not (UI.br and isElement(UI.br)) then return end
  local js = string.format("window.%s(%s);", tostring(functionName), toJSON(payload or {}))
  executeBrowserJavascript(UI.br, js)
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

  if UI.wnd and isElement(UI.wnd) and UI.br and isElement(UI.br) then
    UI.isOpen = true
    triggerEvent('hud:blur', resourceRoot, 6, false, 0.5, nil)
    focusUI()
    pushAll()
    return
  end

  local sw, sh = guiGetScreenSize()
  local w, h = 980, 620
  local x, y = (sw - w) / 2, (sh - h) / 2

  UI.wnd = guiCreateBrowser(x, y, w, h, true, true, false)
  UI.br = guiGetBrowser(UI.wnd)

  addEventHandler("onClientBrowserDocumentReady", UI.br, function()
    -- Tandai kalau init berasal dari Lua
    executeBrowserJavascript(UI.br, "window.__fromLua = true;")
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
  end, false)

  loadBrowserURL(UI.br, "http://mta/local/ui/index.html")
  UI.isOpen = true
  triggerEvent('hud:blur', resourceRoot, 6, false, 0.5, nil)
  focusUI()
end
addEvent("donation-system:GUI:open", true)
addEventHandler("donation-system:GUI:open", root, openDonationGUI)

function closeDonationGUI()
  if UI.wnd and isElement(UI.wnd) then
    destroyElement(UI.wnd)
  end
  UI = { wnd = nil, br = nil, isOpen = false }
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
  -- Jika fungsi showInfoPanel ada di resource lama, panggil.
  if type(showInfoPanel) == 'function' then
    showInfoPanel(state)
  else
    -- Fallback: salin link di server lama jika diperlukan, atau abaikan.
    outputChatBox("Info panel is not available in this build.")
  end
end)

-- Update sinkronisasi (opsional dipanggil dari server/client)
function updateAvailablePerksCEF(available1, credits1)
  available = available1 or available
  credits = tonumber(credits1) or credits
  if UI.br and isElement(UI.br) then
    sendToJS("updateAvailable", { list = available, credits = credits })
  end
end
addEvent("donation-system:GUI:updateAvailable", true)
addEventHandler("donation-system:GUI:updateAvailable", root, function(a, c)
  updateAvailablePerksCEF(a, c)
end)

-- Respon server (opsional)
function getResponseFromServer(code, msg)
  if not (UI.br and isElement(UI.br)) then return end
  -- Anda bisa menambahkan notifikasi JS di sini bila diperlukan
  -- contoh: executeBrowserJavascript(UI.br, string.format("window.toast(%s,%s);", toJSON(code), toJSON(msg)))
end
addEvent("donation-system:getResponseFromServer", true)
addEventHandler("donation-system:getResponseFromServer", root, getResponseFromServer)

-- Penutup paksa saat resource stop
addEventHandler("onClientResourceStop", resourceRoot, function()
  blurUI()
end)