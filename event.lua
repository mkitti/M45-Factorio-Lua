--Carl Frank Otto III
--carlotto81@gmail.com
require "antigrief"
require "info"
require "log"
require "todo"

local function insert_weapons(player, ammo_amount)
  if player.force.technologies["military"].researched then
    player.insert {name = "submachine-gun", count = 1}
  else
    player.insert {name = "pistol", count = 1}
  end

  if player.force.technologies["military-2"].researched then
    player.insert {name = "piercing-rounds-magazine", count = ammo_amount}
  else
    player.insert {name = "firearm-magazine", count = ammo_amount}
  end
end

--Looping timer, 30 seconds
--delete old corpse map pins
--Check spawn area map pin
--Add to player active time if needed
--Refresh players online window

script.on_nth_tick(
  1800,
  function(event)
    update_player_list() --online.lua

    --Remove old corpse tags
    if (global.corpselist) then
      local index = nil
      for i, corpse in pairs(global.corpselist) do
        if (corpse.tick and (corpse.tick + (15 * 60 * 60)) < game.tick) then
          --Destroy corpse lamp
          rendering.destroy(corpse.corpse_lamp)

          --Destory map tag
          if corpse.tag and corpse.tag.valid then
            corpse.tag.destroy()
          end

          index = i
          break
        end
      end
      --Properly remove items
      if global.corpselist and index then
        table.remove(global.corpselist, index)
      end
    else
      create_myglobals()
    end

    --Server tag
    if (global.servertag and not global.servertag.valid) then
      global.servertag = nil
    end
    if (global.servertag and global.servertag.valid) then
      global.servertag.destroy()
      global.servertag = nil
    end
    if (not global.servertag) then
      local label = "Spawn Area"
      local xpos = 0
      local ypos = 0

      if global.servname and global.servname ~= "" then
        label = global.servname
      end

      local chartTag = {
        position = get_default_spawn(),
        icon = {type = "item", name = "heavy-armor"},
        text = label
      }
      local pforce = game.forces["player"]
      local psurface = game.surfaces[1]

      if pforce and psurface then
        global.servertag = pforce.add_chart_tag(psurface, chartTag)
      end
    end

    --Add time to connected players
    if global.active_playtime then
      for _, player in pairs(game.connected_players) do
        if global.playeractive[player.index] then
          if global.playeractive[player.index] == true then
            global.playeractive[player.index] = false --Turn back off

            if global.active_playtime[player.index] then
              global.active_playtime[player.index] = global.active_playtime[player.index] + 1800 --Same as loop time
            else
              --INIT
              global.active_playtime[player.index] = 0
            end
          end
        else
          --INIT
          global.playeractive[player.index] = false
        end
      end
    end

    get_permgroup() --See if player qualifies now
  end
)

--Clean up corpse tags
function on_player_mined_entity(event)
  clear_corpse_tag(event)
end

function on_character_corpse_expired(event)
  clear_corpse_tag(event)
end

--Idea stolen from redmew corpse_tuil.lua, because it is clever
--https://github.com/Refactorio/RedMew/blob/7350e8721d8c5b5cd952e8beb084f33485761234/features/corpse_utility.lua#L147
function on_gui_opened(event)
  clear_corpse_tag(event)
end

--Handle killing, and teleporting users to other surfaces
function on_player_respawned(event)
  send_to_surface(event) --banish.lua

  if event and event.player_index then
    local player = game.players[event.player_index]

    --Cutoff-point, just becomes annoying.
    if not player.force.technologies["military-science-pack"].researched then
      insert_weapons(player, 10)
    end
  end
end

--Player connected, make variables, draw UI, set permissions, and game settings
function on_player_joined_game(event)
  
  global.drawlogo = false --set logo to be redrawn
  dodrawlogo() --redraw logo

  update_player_list() --online.lua

  --If player is in list and alive, kill them (offline banish/damn)
  if global.send_to_surface then
    --Event and player?
    if event and event.player_index then
      local player = game.players[event.player_index]

      --Valid player?
      if player and player.valid and player.character and player.character.valid then
        local index = nil
        --Check list
        for i, item in pairs(global.send_to_surface) do
          --Check if item is valid
          if item and item.victim and item.victim.valid and item.victim.character and item.victim.character.valid then
            --Check if names match
            if item.victim.name == player.name then
              player.character.die()
            end
          end
        end
      end
    end
  end

  --Gui stuff
  if event and event.player_index then
    local player = game.players[event.player_index]
    if player then
      create_myglobals()
      create_player_globals(player)
      create_groups()
      game_settings(player)
      set_perms()
      get_permgroup()

      --Delete old UIs (migrate old saves)
      if player.gui.top.dicon then
        player.gui.top.dicon.destroy()
      end
      if player.gui.top.discordurl then
        player.gui.top.discordurl.destroy()
      end
      if player.gui.top.zout then
        player.gui.top.zout.destroy()
      end
      if player.gui.top.serverlist then
        player.gui.top.serverlist.destroy()
      end
      if player.gui.center.dark_splash then
        player.gui.center.dark_splash.destroy()
      end
      if player.gui.center.splash_screen then
        player.gui.center.splash_screen.destroy()
      end

      dodrawlogo() --logo.lua

      if player.gui and player.gui.top then
        make_info_button(player) --info.lua
        make_online_button(player) --online.lua
      end

      --Always show to new players, everyone else at least once per map
      if is_new(player) or not global.info_shown[player.index] then
        global.info_shown[player.index] = true
        make_m45_online_window(player) --online.lua
        make_m45_info_window(player) --info.lua
      --make_m45_todo_window(player) --todo.lua
      end
    end
  end
end

--New player created, insert items set perms, show players online, welcome to map.
function on_player_created(event)
  if event and event.player_index then
    local player = game.players[event.player_index]

    if player and player.valid then
      global.drawlogo = false --set logo to be redrawn
      dodrawlogo() --redraw logo
      send_to_default_spawn(player) --incase spawn moved

      update_player_list() --online.lua

      --Cutoff-point, just becomes annoying.
      if not player.force.technologies["military-2"].researched then
        player.insert {name = "iron-plate", count = 50}
        player.insert {name = "copper-plate", count = 50}
        player.insert {name = "wood", count = 50}
        player.insert {name = "burner-mining-drill", count = 2}
        player.insert {name = "stone-furnace", count = 2}
        player.insert {name = "iron-chest", count = 1}
      end
      player.insert {name = "light-armor", count = 1}

      insert_weapons(player, 50) --research-based

      set_perms()
      show_players(player)
      message_all("[color=green](SYSTEM) Welcome " .. player.name .. " to the map![/color]")
    end
  end
end

--Corpse Map Marker
function on_pre_player_died(event)
  if event and event.player_index then
    local player = game.players[event.player_index]

    global.drawlogo = false --set logo to be redrawn
    dodrawlogo() --redraw logo

    --Disable corpse map markers if another similar mod is loaded
    local disable_corpsemap = false
    for name, version in pairs(game.active_mods) do
      if name == "space-exploration" or name == "CorpseFlare" or name == "some-corpsemarker" or name == "WhereIsMyBody" then
        disable_corpsemap = true
        break
      end
    end

    --Sanity check
    if not disable_corpsemap then
      if player and player.valid and player.character then
        --Make map pin
        local centerPosition = player.position
        local label = ("Body of: " .. player.name)
        local chartTag = {position = centerPosition, icon = nil, text = label}
        local qtag = player.force.add_chart_tag(player.surface, chartTag)

        create_myglobals()
        create_player_globals(player)

        --Add a light, so it is easier to see
        local clight =
          rendering.draw_light {
          sprite = "utility/light_medium",
          target = centerPosition,
          render_layer = 148,
          surface = player.surface,
          color = {0.5, 0.25, 0},
          scale = 1,
          target_offset = {0, 0}
        }

        --Add to list of pins
        table.insert(
          global.corpselist,
          {tag = qtag, tick = game.tick + 600, pos = player.position, pindex = player.index, corpse_lamp = clight}
        )
      end

      --Log to discord
      if event.cause and event.cause.valid then
        cause = event.cause.name
        gsysmsg(
          player.name ..
            " was killed by " ..
              cause .. " at [gps=" .. math.floor(player.position.x) .. "," .. math.floor(player.position.y) .. "]"
        )
      else
        gsysmsg(
          player.name ..
            " was killed at [gps=" .. math.floor(player.position.x) .. "," .. math.floor(player.position.y) .. "]"
        )
      end
    end
  end
end

--Main event handler
script.on_event(
  {
    --Player join/leave respawn
    defines.events.on_player_created,
    defines.events.on_pre_player_died,
    defines.events.on_player_respawned,
    --
    defines.events.on_player_joined_game,
    defines.events.on_player_left_game,
    --activity
    defines.events.on_player_changed_position,
    defines.events.on_console_chat,
    defines.events.on_player_repaired_entity,
    --gui
    defines.events.on_gui_click,
    defines.events.on_gui_text_changed,
    --log
    defines.events.on_console_command,
    defines.events.on_chart_tag_removed,
    defines.events.on_chart_tag_modified,
    defines.events.on_chart_tag_added,
    defines.events.on_research_finished,
    --clean up corpse tags
    defines.events.on_player_mined_entity,
    defines.events.on_gui_opened,
    -- anti-grief
    defines.events.on_player_deconstructed_area,
    defines.events.on_player_banned,
    defines.events.on_player_rotated_entity,
    defines.events.on_pre_player_mined_item,
    defines.events.on_player_cursor_stack_changed,
    --darkness
    defines.events.on_chunk_charted,
    defines.events.on_player_dropped_item,
    defines.events.on_built_entity,
    defines.events.on_post_entity_died,
    defines.events.on_robot_mined,
    defines.events.on_sector_scanned
  },
  function(event)
    --If no event, or event is a tick
    if not event or (event and event.name == defines.events.on_tick) then
      return
    end

    --Mark player active
    if event.player_index then
      local player = game.players[event.player_index]
      if player and player.valid then
        --Only mark active on movement if walking
        if event.name == defines.events.on_player_changed_position then
          if player.walking_state then
            if
              player.walking_state.walking == true and
                (player.walking_state.direction == defines.direction.north or
                  player.walking_state.direction == defines.direction.northeast or
                  player.walking_state.direction == defines.direction.east or
                  player.walking_state.direction == defines.direction.southeast or
                  player.walking_state.direction == defines.direction.south or
                  player.walking_state.direction == defines.direction.southwest or
                  player.walking_state.direction == defines.direction.west or
                  player.walking_state.direction == defines.direction.northwest)
             then
              set_player_active(player)
            end
          end
        else
          set_player_active(player)
        end
      end
    end

    --Player join/leave respawn
    if event.name == defines.events.on_player_created then
      on_player_created(event)
    elseif event.name == defines.events.on_pre_player_died then
      on_pre_player_died(event)
    elseif event.name == defines.events.on_player_respawned then
      --
      on_player_respawned(event)
    elseif event.name == defines.events.on_player_joined_game then
      on_player_joined_game(event)
    elseif event.name == defines.events.on_player_left_game then
      --activity
      --changed-position
      --console_chat
      --repaired_entity
      --
      --gui
      on_player_left_game(event)
    elseif event.name == defines.events.on_gui_click then
      on_gui_click(event)
      online_on_gui_click(event) --online.lua
    elseif event.name == defines.events.on_gui_text_changed then
      --log
      on_gui_text_changed(event)
    elseif event.name == defines.events.on_console_command then
      on_console_command(event)
    elseif event.name == defines.events.on_chart_tag_removed then
      on_chart_tag_removed(event)
    elseif event.name == defines.events.on_chart_tag_modified then
      on_chart_tag_modified(event)
    elseif event.name == defines.events.on_chart_tag_added then
      on_chart_tag_added(event)
    elseif event.name == defines.events.on_research_finished then
      --clean up corspe tags
      on_research_finished(event)
    elseif event.name == defines.events.on_player_mined_entity then
      on_player_mined_entity(event)
    elseif event.name == defines.events.on_gui_opened then
      --anti-grief
      on_gui_opened(event)
    elseif event.name == defines.events.on_player_deconstructed_area then
      on_player_deconstructed_area(event)
    elseif event.name == defines.events.on_player_banned then
      on_player_banned(event)
    elseif event.name == defines.events.on_player_rotated_entity then
      on_player_rotated_entity(event)
    elseif event.name == defines.events.on_pre_player_mined_item then
      on_pre_player_mined_item(event)
    elseif event.name == defines.events.on_player_cursor_stack_changed then
      on_player_cursor_stack_changed(event)
    elseif event.name == defines.events.on_built_entity then
      on_built_entity(event)
    end

    --darkness--
    --chunk_charted
    --player_dropped_item
    --built_entity
    --entity_died

    --To-Do--
    --player_joined_game
    --on_gui_click
    todo_event_handler(event)

    --External module event send
    --dark_event_handler(event)
  end
)

function clear_corpse_tag(event)
  if event and event.entity and event.entity.valid then
    local ent = event.entity

    if ent.type == "character-corpse" then
      if ent and event.player_index then
        player = game.players[event.player_index]
        victim = game.players[ent.character_corpse_player_index]

        if victim and victim.valid and player and player.valid then
          if victim.name ~= player.name then
            gsysmsg(
              player.name ..
                " looted the body of " ..
                  victim.name ..
                    ", at [gps=" .. math.floor(player.position.x) .. "," .. math.floor(player.position.y) .. "]"
            )
          end
        end
      end

      local index
      for i, ctag in pairs(global.corpselist) do
        if
          ctag and ctag.pos and ctag.pos.x == ent.position.x and ctag.pos.y == ent.position.y and
            ctag.pindex == ent.character_corpse_player_index
         then
          --Destroy corpse lamp
          rendering.destroy(ctag.corpse_lamp)

          --Destory map tag
          if ctag and ctag.tag and ctag.tag.valid then
            ctag.tag.destroy()
          end

          index = i
          break
        end
      end

      --Properly remove items
      if global.corpselist and index then
        table.remove(global.corpselist, index)
      end
    end
  end
end
