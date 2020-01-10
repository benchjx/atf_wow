---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by hydra.
--- DateTime: 2020-01-05 13:53
---

local addonName, L = ...


local trade_log_frame = CreateFrame("FRAME", "ATFTradeFrame")
trade_log_frame:RegisterEvent("TRADE_SHOW");
trade_log_frame:RegisterEvent("TRADE_CLOSED");
trade_log_frame:RegisterEvent("TRADE_REQUEST_CANCEL");
trade_log_frame:RegisterEvent("PLAYER_TRADE_MONEY");

trade_log_frame:RegisterEvent("TRADE_MONEY_CHANGED");
trade_log_frame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED");
trade_log_frame:RegisterEvent("TRADE_ACCEPT_UPDATE");
trade_log_frame:RegisterEvent("UI_INFO_MESSAGE");
trade_log_frame:RegisterEvent("UI_ERROR_MESSAGE");

local trade_hooks = {

}

local hook_example = {
  ["should_hook"] = "callable return (boolean, boolean), first return value indicates if hooked; second indicates if closes trade.",
  ["feed_items"] = "function do feedings at start",
  ["on_trade_complete"] = "function on trade complete",
  ["on_trade_cancel"] = "function on trade cancel",
  ["on_trade_error"] = "function on trade error",
  ["should_accept"] = "function return boolean, if true, accept, if false, close.",
  ["check_target_item"] = "function return boolean, if true, item is ok, otherwise not ok, close it",
}

local current_trade = {}



function L.F.feed(itemname, icount, count_min)
  local x = 0
  if count_min == nil then count_min = 1 end
  for b = 0, 4 do
    for s =1, 32 do
      local _, itemCount, _, _, _, _, link = GetContainerItemInfo(b, s)
      if link and link:find(itemname) and itemCount>=count_min and x < icount then
        UseContainerItem(b, s)
        x = x + 1
      end
    end
  end
end


function L.F.do_accept_trade()
  if TradeHighlightRecipient:IsShown() then
    AcceptTrade()
    return true
  end
  return false
end


local function initiate_new_trade()
  current_trade = {
    ["npc_name"] = UnitName("NPC"),
    ["npc_level"] = UnitLevel("NPC"),
    ["npc_class"] = UnitClass("NPC"),
    ["start_ts"] = GetTime(),
    ["items"] = {},
    ["accepted"] = false,
    ["messages"] = {}
  }
  return current_trade
end


local function destroy_current_trade()
  current_trade = {}
end


local function get_available_hook(trade)
  for _, hook in ipairs(trade_hooks) do
    if hook.should_hook then
      local should_hook, close_trade = hook.should_hook(trade)
      if should_hook then
        return hook, close_trade
      end
    end
  end
  return nil, true
end


local map_ui_indicated = {
  ["UI_INFO_MESSAGE"] = {
    [ERR_TRADE_CANCELLED] = "cancel",
    [ERR_TRADE_COMPLETE] = "complete"
  },
  ["UI_ERROR_MESSAGE"] = {
    [ERR_TRADE_BAG_FULL] = "error",
    [ERR_TRADE_MAX_COUNT_EXCEEDED] = "error",
    [ERR_TRADE_TARGET_BAG_FULL] = "error",
    [ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED] = "error",
  }
}

local function ui_indicated_trade(event, msg)
  if map_ui_indicated[event] then
    local reason = map_ui_indicated[event][msg]
    if reason then
      return reason
    end
  end
  return nil
end


local function get_items(target)
  local get_trade_item_info, get_trade_money
  if target == true then
    get_trade_item_info = GetTradeTargetItemInfo
    get_trade_money = GetTargetTradeMoney
  else
    get_trade_item_info = GetTradePlayerItemInfo
    get_trade_money = GetPlayerTradeMoney

  end
  local target_items = {} local table_cnt = 0
  for t_index = 1, 6 do
    local name, _, cnt = get_trade_item_info(t_index)
    if name then
      if target_items[name] == nil then
        target_items[name] = 0
      end
      target_items[name] = target_items[name] + cnt
      table_cnt = table_cnt + 1
    end
  end

  if get_trade_money() > 0 then
    target_items["Gold"] = get_trade_money()
    table_cnt = table_cnt + 1
  end
  return target_items, table_cnt
end


local function trade_on_event(self, event, arg1, arg2)
  if not (L.atfr_run == true) then
    return
  end
  if event == "TRADE_SHOW" then
    local trade = initiate_new_trade()

    local hook, close_trade = get_available_hook(trade)
    if not close_trade and hook then
      trade.hook = hook
      if hook.feed_items then
        hook.feed_items(trade)
      end
    else
      if hook == nil then
        print("no hook found, check your logic.")
      end
      CloseTrade()
    end
  else
    assert(not(current_trade==nil))
    local trade_close_reason = ui_indicated_trade(event, arg2)
    local hook = current_trade.hook

    if trade_close_reason then
      local callback = hook["on_trade_"..trade_close_reason]
      if callback then
        local ok, msg = pcall(callback, current_trade)
        if not ok then print(msg) end
      end
      destroy_current_trade()
    elseif event == "TRADE_CLOSED" then
      -- do nothing
    elseif event == "TRADE_ACCEPT_UPDATE" then
      if arg2 == 1 and arg1 == 0 then
        local player_items, player_items_count = get_items(false)
        local target_items, target_items_count = get_items(true)
        current_trade.items.player = {["count"]=player_items_count, ["items"]=player_items}
        current_trade.items.target =  {["count"]=target_items_count, ["items"]=target_items}
        local accept, keep
        if hook.should_accept then
          accept, keep = hook.should_accept(current_trade)
        end

        if accept then
          current_trade.accepted = true
        elseif not(keep) then
          CloseTrade()
        end
      elseif arg2 == 1 and arg1 == 1 then
        -- do nothing
      else
        current_trade.accepted = false
      end
    elseif event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" then
      local target_items, target_items_count = get_items(true)
      current_trade.items.target =  {["count"]=target_items_count, ["items"]=target_items}
      if hook.check_target_item and not(hook.check_target_item(current_trade)) then
        CloseTrade()
      end
    end
  end
end


trade_log_frame:SetScript("OnEvent", trade_on_event);


function L.F.append_trade_hook(hook)
  table.insert(trade_hooks, hook)
end


function L.F.accept_accepted_trade()  -- HW
  if current_trade.messages then
    for _, message in ipairs(current_trade.messages) do
      SendChatMessage(message, "say")
    end
    current_trade.messages = {}
  end
  if current_trade.accepted then
    AcceptTrade()
  end
end


function L.F.append_trade_say_messages(trade, message)
  if current_trade.messages == nil then
    current_trade.messages = {}
  end
  table.insert(trade.messages, message)
end
