'use strict';

// Bridge untuk MTA CEF: stub saat bukan di MTA
if (!window.mta) {
  window.mta = { triggerEvent: function(){ console.log('[stub] mta.triggerEvent', arguments); } };
}

// Disable context menu
window.addEventListener('contextmenu', function(e){ e.preventDefault(); });

var state = {
  credits: 0,
  available: [] // item: { name, durationLabel, costLabel, id }
};

function safeParseJSON(d){
  try { if (typeof d === 'string') return JSON.parse(d); } catch(e) {}
  return d;
}

function toArrayMaybe(list){
  if (Array.isArray && Array.isArray(list)) return list;
  if (!list || typeof list !== 'object') return [];
  var keys = [];
  for (var k in list) {
    if (list.hasOwnProperty(k)) {
      var n = parseInt(k, 10);
      if (!isNaN(n)) keys.push(n);
    }
  }
  keys.sort(function(a,b){ return a-b; });
  if (keys.length === 0) {
    if (Array.isArray && Array.isArray(list.list)) return list.list;
    if (Array.isArray && Array.isArray(list.available)) return list.available;
    return [];
  }
  var out = [];
  for (var i=0;i<keys.length;i++) {
    var key = keys[i];
    var v = (typeof list[key] !== 'undefined') ? list[key] : list[String(key)];
    out.push(v);
  }
  return out;
}

// API dipanggil dari Lua
window.initData = function(data){
  data = safeParseJSON(data);
  applyData(data);
  renderAll();
};

window.refreshAll = function(data){
  data = safeParseJSON(data);
  applyData(data);
  renderAll();
};

window.updateAvailable = function(availableOrObj, creditsMaybe){
  availableOrObj = safeParseJSON(availableOrObj);
  var list = availableOrObj;
  var creditsLocal = creditsMaybe;
  if (availableOrObj && typeof availableOrObj === 'object' && !(Array.isArray && Array.isArray(availableOrObj))) {
    list = (typeof availableOrObj.list !== 'undefined') ? availableOrObj.list : (availableOrObj.available || availableOrObj);
    creditsLocal = (typeof availableOrObj.credits !== 'undefined') ? availableOrObj.credits : creditsMaybe;
  }
  if (typeof creditsLocal === 'string') creditsLocal = Number(creditsLocal) || 0;
  state.available = normalizeAvailable(list || []);
  if (typeof creditsLocal !== 'undefined') state.credits = Number(creditsLocal) || state.credits;
  renderHeader();
  renderAvailable();
};

function applyData(data){
  if (!data || typeof data !== 'object') return;
  state.credits = Number(data.credits) || 0;
  var list = (typeof data.available !== 'undefined') ? data.available : (data.list || []);
  state.available = normalizeAvailable(list);
}

function normalizeAvailable(listInput){
  var list = toArrayMaybe(listInput);
  var out = [];
  for (var i=0;i<list.length;i++) {
    var it = list[i];
    if (it && typeof it === 'object' && !(Array.isArray && Array.isArray(it))) {
      out.push({
        name: (typeof it.name !== 'undefined') ? String(it.name) : '',
        durationLabel: (typeof it.durationLabel !== 'undefined') ? String(it.durationLabel) : (it.duration ? (Number(it.duration)>1 ? String(it.duration)+' days' : 'Permanent') : ''),
        costLabel: (typeof it.costLabel !== 'undefined') ? String(it.costLabel) : (typeof it.cost !== 'undefined' ? String(it.cost) : ''),
        id: Number((typeof it.id !== 'undefined') ? it.id : (it.perkId || it[3])) || 0
      });
      continue;
    }
    if (Array.isArray && Array.isArray(it)) {
      var name = it[0] || '';
      var cost = it[1];
      var duration = it[2];
      var id = Number(it[3]) || 0;
      var durationLabel = (Number(duration) > 1 ? String(duration)+' days' : 'Permanent');
      var costLabel = (typeof cost === 'number') ? String(cost)+' Coin' : String(cost || '');
      out.push({ name: String(name), durationLabel: durationLabel, costLabel: costLabel, id: id });
      continue;
    }
    out.push({ name: String(it || ''), durationLabel: '', costLabel: '', id: 0 });
  }
  return out;
}

function renderAll(){
  renderHeader();
  renderAvailable();
  wireGlobalActions();
}

function renderHeader(){
  var creditsEl = document.getElementById('creditsValue');
  if (creditsEl) creditsEl.textContent = String(state.credits);
}

function renderAvailable(){
  var tbody = document.querySelector('#availableTable tbody');
  if (!tbody) return;
  while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
  try {
    for (var i=0;i<state.available.length;i++) {
      var item = state.available[i];
      var tr = document.createElement('tr');
      tr.innerHTML = ''+
        '<td>'+escapeHtml(item.name)+'</td>'+
        '<td>'+escapeHtml(item.durationLabel)+'</td>'+
        '<td>'+escapeHtml(item.costLabel)+'</td>'+
        '<td>'+escapeHtml(String(item.id))+'</td>';
      (function(it){
        tr.addEventListener('dblclick', function(){ openPurchaseModal(it); });
      })(item);
      tbody.appendChild(tr);
    }
  } catch(e) {
    // tampilkan info error minimal di UI agar mudah debug
    var tr = document.createElement('tr');
    tr.innerHTML = '<td colspan="4">Render error</td>';
    tbody.appendChild(tr);
  }
}

function wireGlobalActions(){
  var btnClose = document.getElementById('btnClose');
  if (btnClose && !btnClose._wired) {
    btnClose._wired = true;
    btnClose.addEventListener('click', function(){ mta.triggerEvent('donation:close'); });
  }
  var btnDonate = document.getElementById('btnDonate');
  if (btnDonate && !btnDonate._wired) {
    btnDonate._wired = true;
    btnDonate.addEventListener('click', function(){ mta.triggerEvent('donation:info', 1); });
  }
  var overlay = document.getElementById('modalOverlay');
  if (overlay && !overlay._wired) {
    overlay._wired = true;
    overlay.addEventListener('click', function(){ closePurchaseModal(); });
  }
}

// Modal
var currentItem = null;
function openPurchaseModal(item){
  currentItem = item;
  var modal = document.getElementById('purchaseModal');
  if (!modal) return;
  setText('mPerkName', item.name);
  setText('mDuration', item.durationLabel);
  setText('mCost', item.costLabel);
  modal.classList.remove('hidden');
  var confirmBtn = document.getElementById('mConfirm');
  var cancelBtn = document.getElementById('mCancel');
  if (confirmBtn && !confirmBtn._wired) {
    confirmBtn._wired = true;
    confirmBtn.addEventListener('click', function(){
      if (!currentItem) return;
      mta.triggerEvent('donation:purchase', Number(currentItem.id) || 0, null);
      closePurchaseModal();
    });
  }
  if (cancelBtn && !cancelBtn._wired) {
    cancelBtn._wired = true;
    cancelBtn.addEventListener('click', function(){ closePurchaseModal(); });
  }
}

function closePurchaseModal(){
  var modal = document.getElementById('purchaseModal');
  if (modal) modal.classList.add('hidden');
  currentItem = null;
}

function setText(id, text){
  var el = document.getElementById(id);
  if (el) el.textContent = String(text || '');
}

function escapeHtml(str){
  str = String(str || '');
  str = str.replace(/&/g, '&amp;');
  str = str.replace(/</g, '&lt;');
  str = str.replace(/>/g, '&gt;');
  str = str.replace(/"/g, '&quot;');
  str = str.replace(/'/g, '&#039;');
  return str;
}

// Demo lokal saat bukan dari Lua
(function(){
  try {
    var isFromLua = !!window.__fromLua;
    if (isFromLua) return;
    window.initData({
      credits: 25,
      available: [
        { name: 'Max Interiors +1', durationLabel: 'Permanent', costLabel: '6 Coin', id: 14 },
        { name: 'Private Number', durationLabel: 'Permanent', costLabel: '1 Coin', id: 33 },
        { name: 'Custom Chat Icon', durationLabel: 'Permanent', costLabel: '3 Coin', id: 29 }
      ]
    });
  } catch(e) {}
})();