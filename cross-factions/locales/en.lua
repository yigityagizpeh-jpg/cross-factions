--[[
    Locale: English
    English language support for cross-factions

    Locale files load alphabetically (en.lua → tr.lua).
    Each file writes its language table to the shared Locales global.
    T() is always defined; falls back to a missing-key indicator.
--]]

-- Initialize shared Locales table (created on first load)
Locales = Locales or {}

if Config.Locale == 'en' then
    Locales = {
        -- General
        ['no_permission']           = 'You do not have permission for this action.',
        ['player_not_found']        = 'Player not found.',
        ['server_error']            = 'A server error occurred.',
        ['not_enough_money']        = 'Not enough money. Required: $%s',
        ['not_enough_item']         = 'Required item not found: %s',
        ['cooldown_active']         = 'You must wait before doing this: %s seconds',

        -- Gang
        ['no_gang']                 = 'You are not in a gang.',
        ['already_in_gang']         = 'You are already in a gang.',
        ['gang_created']            = 'Gang %s created successfully!',
        ['gang_create_fail']        = 'Failed to create gang.',
        ['gang_name_taken']         = 'This gang name is already taken.',
        ['gang_name_invalid']       = 'Gang name must be between %s and %s characters.',
        ['gang_tag_invalid']        = 'Gang tag can be at most %s characters.',
        ['gang_max_reached']        = 'Maximum number of gangs has been reached.',
        ['gang_disbanded']          = '%s gang has been disbanded.',
        ['gang_invited']            = 'You received an invite to %s gang!',
        ['gang_invite_sent']        = 'Invite sent to %s.',
        ['gang_joined']             = 'You joined %s gang!',
        ['gang_join_fail']          = 'Failed to join gang.',
        ['gang_kicked']             = 'You were kicked from %s gang.',
        ['gang_kick_success']       = '%s was successfully kicked.',
        ['gang_left']               = 'You left the gang.',
        ['gang_promoted']           = 'Your rank was updated to %s.',
        ['gang_promote_success']    = '%s was successfully promoted.',
        ['gang_demoted']            = 'Your rank was lowered to %s.',
        ['gang_demote_success']     = '%s was successfully demoted.',
        ['gang_leader_transfer']    = 'Gang leadership transferred to %s.',

        -- Turf
        ['turf_entered']            = 'You entered %s. Owner: %s',
        ['turf_no_owner']           = 'Unclaimed',
        ['turf_your_gang']          = 'Your gang already owns this turf.',
        ['turf_capture_started']    = 'Capture started! Stay in the zone.',
        ['turf_capture_cancelled']  = 'Capture cancelled!',
        ['turf_capture_success']    = 'Turf %s captured!',
        ['turf_under_attack']       = 'ALERT! Your turf %s is under attack!',
        ['turf_cooldown']           = 'Cooldown active for this turf: %s minutes',
        ['turf_not_enough_members'] = 'Not enough gang members to capture. Required: %s',
        ['turf_police_required']    = 'Not enough active police for a turf war.',
        ['turf_max_wars']           = 'Maximum simultaneous turf wars reached.',
        ['turf_reset']              = 'Turf %s has been reset.',

        -- War
        ['war_declared']            = 'War declared on %s gang!',
        ['war_received']            = '%s gang declared war on you!',
        ['war_accepted']            = 'War with %s gang has begun!',
        ['war_rejected']            = '%s gang rejected your war offer.',
        ['war_ended_win']           = 'You won the war against %s! +%s reputation',
        ['war_ended_lose']          = 'You lost the war against %s. %s reputation',
        ['war_ended_draw']          = 'War against %s ended in a draw.',
        ['war_not_active']          = 'No active war with this gang.',
        ['war_already_active']      = 'You already have an active war with this gang.',
        ['no_war_with_ally']        = 'You cannot declare war on your allies.',

        -- Alliance
        ['alliance_sent']           = 'Alliance offer sent to %s gang.',
        ['alliance_received']       = '%s gang sent you an alliance offer!',
        ['alliance_accepted']       = 'Alliance with %s gang established!',
        ['alliance_rejected']       = '%s gang rejected your alliance offer.',
        ['alliance_broken']         = 'Alliance with %s gang broken.',
        ['already_allied']          = 'You are already allied with this gang.',

        -- Spray
        ['spray_no_item']           = 'You need "%s" item to spray.',
        ['spray_success']           = 'Wall tagged successfully!',
        ['spray_cooldown']          = 'You must wait before spraying again.',
        ['spray_not_in_turf']       = 'This point is not in a turf zone.',
        ['spray_progress']          = 'Spraying...',

        -- Stash / Armory / Garage
        ['stash_access_denied']     = 'You do not have access to the stash.',
        ['armory_access_denied']    = 'You do not have access to the armory.',
        ['garage_access_denied']    = 'You do not have access to the garage.',
        ['vehicle_spawn_cooldown']  = 'You must wait before spawning another vehicle.',
        ['vehicle_max_spawned']     = 'Maximum vehicle limit reached.',

        -- Finance
        ['treasury_deposit']        = 'Deposited $%s into gang treasury.',
        ['treasury_withdraw']       = 'Withdrew $%s from gang treasury.',
        ['treasury_no_funds']       = 'Not enough funds in gang treasury.',
        ['income_received']         = 'Gang treasury received $%s income from %s.',

        -- Admin
        ['admin_gang_created']      = '[ADMIN] Gang %s created.',
        ['admin_gang_deleted']      = '[ADMIN] Gang %s deleted.',
        ['admin_turf_reset']        = '[ADMIN] Turf %s reset.',
        ['admin_turf_owner_set']    = '[ADMIN] Turf %s owner set to %s.',
        ['admin_war_ended']         = '[ADMIN] War ended.',
        ['admin_rep_added']         = '[ADMIN] %s reputation added to %s gang.',
        ['admin_spray_cleared']     = '[ADMIN] Spray cleared.',
    }
end

-- T() function: always defined; tr.lua (which loads after) will skip this block
if not T then
    function T(key, ...)
        local str = Locales[key]
        if not str then
            return '[MISSING: ' .. tostring(key) .. ']'
        end
        if select('#', ...) > 0 then
            return string.format(str, ...)
        end
        return str
    end
end
