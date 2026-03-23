--[[
    Locale: Türkçe
    cross-factions için Türkçe dil desteği

    Locale dosyaları alfabetik sırayla yüklenir (en.lua → tr.lua).
    Her dosya kendi dil tablosunu genel Locales tablosuna yazar.
    T() fonksiyonu her zaman tanımlıdır; eksik anahtar durumunda fallback gösterir.
--]]

-- Genel Locales tablosunu başlat (ilk yüklenen dosyada oluşturulur)
Locales = Locales or {}

if Config.Locale == 'tr' then
    Locales = {
        -- Genel
        ['no_permission']           = 'Bu işlem için yetkiniz yok.',
        ['player_not_found']        = 'Oyuncu bulunamadı.',
        ['server_error']            = 'Sunucu hatası oluştu.',
        ['not_enough_money']        = 'Yeterli paran yok. Gerekli: $%s',
        ['not_enough_item']         = 'Gerekli eşya bulunamadı: %s',
        ['cooldown_active']         = 'Bu işlem için beklemeniz gerekiyor: %s saniye',

        -- Gang
        ['no_gang']                 = 'Bir gange üye değilsiniz.',
        ['already_in_gang']         = 'Zaten bir gange üyesiniz.',
        ['gang_created']            = '%s adlı gang başarıyla oluşturuldu!',
        ['gang_create_fail']        = 'Gang oluşturulamadı.',
        ['gang_name_taken']         = 'Bu gang adı zaten kullanılıyor.',
        ['gang_name_invalid']       = 'Gang adı %s ile %s karakter arasında olmalı.',
        ['gang_tag_invalid']        = 'Gang etiketi en fazla %s karakter olabilir.',
        ['gang_max_reached']        = 'Maksimum gang sayısına ulaşıldı.',
        ['gang_disbanded']          = '%s gangı dağıtıldı.',
        ['gang_invited']            = '%s gangına davet aldınız!',
        ['gang_invite_sent']        = '%s kişisine davet gönderildi.',
        ['gang_joined']             = '%s gangına katıldınız!',
        ['gang_join_fail']          = 'Gange katılamadınız.',
        ['gang_kicked']             = '%s gangından çıkarıldınız.',
        ['gang_kick_success']       = '%s başarıyla gangdan çıkarıldı.',
        ['gang_left']               = 'Gangdan ayrıldınız.',
        ['gang_promoted']           = 'Rütbeniz %s olarak güncellendi.',
        ['gang_promote_success']    = '%s başarıyla terfi ettirildi.',
        ['gang_demoted']            = 'Rütbeniz %s olarak düşürüldü.',
        ['gang_demote_success']     = '%s başarıyla düşürüldü.',
        ['gang_leader_transfer']    = 'Gang liderliği %s oyuncusuna devredildi.',

        -- Turf
        ['turf_entered']            = '%s bölgesine girdiniz. Sahip: %s',
        ['turf_no_owner']           = 'Sahipsiz',
        ['turf_your_gang']          = 'Bu bölge zaten sizin ganginize ait.',
        ['turf_capture_started']    = 'Ele geçirme başladı! Bölgede kalın.',
        ['turf_capture_cancelled']  = 'Ele geçirme iptal edildi!',
        ['turf_capture_success']    = '%s bölgesi ele geçirildi!',
        ['turf_under_attack']       = 'DİKKAT! %s bölgeniz saldırı altında!',
        ['turf_cooldown']           = 'Bu bölge için bekleme süresi devam ediyor: %s dakika',
        ['turf_not_enough_members'] = 'Ele geçirme için yeterli gang üyesi yok. Gereken: %s',
        ['turf_police_required']    = 'Bölge savaşı için yeterli polis aktif değil.',
        ['turf_max_wars']           = 'Maksimum eş zamanlı turf savaşı sayısına ulaşıldı.',
        ['turf_reset']              = '%s bölgesi sıfırlandı.',

        -- War
        ['war_declared']            = '%s gangına savaş ilan ettiniz!',
        ['war_received']            = '%s gangı size savaş ilan etti!',
        ['war_accepted']            = '%s gangıyla savaş başladı!',
        ['war_rejected']            = '%s gangı savaş teklifinizi reddetti.',
        ['war_ended_win']           = '%s gangıyla savaşı kazandınız! +%s itibar',
        ['war_ended_lose']          = '%s gangıyla savaşı kaybettiniz. %s itibar',
        ['war_ended_draw']          = '%s gangıyla savaş beraberlikle sona erdi.',
        ['war_not_active']          = 'Bu gangla aktif bir savaş bulunmuyor.',
        ['war_already_active']      = 'Bu gangla zaten aktif bir savaşınız var.',
        ['no_war_with_ally']        = 'Müttefiklerinizle savaş ilan edemezsiniz.',

        -- Alliance
        ['alliance_sent']           = '%s gangına ittifak teklifi gönderildi.',
        ['alliance_received']       = '%s gangı size ittifak teklifi gönderdi!',
        ['alliance_accepted']       = '%s gangıyla ittifak kuruldu!',
        ['alliance_rejected']       = '%s gangı ittifak teklifinizi reddetti.',
        ['alliance_broken']         = '%s gangıyla ittifak bozuldu.',
        ['already_allied']          = 'Bu gangla zaten ittifakınız var.',

        -- Spray
        ['spray_no_item']           = 'Spray için "%s" eşyasına ihtiyacınız var.',
        ['spray_success']           = 'Duvar başarıyla işaretlendi!',
        ['spray_cooldown']          = 'Spray için beklemeniz gerekiyor.',
        ['spray_not_in_turf']       = 'Bu nokta bir turf bölgesinde değil.',
        ['spray_progress']          = 'Spray yapılıyor...',

        -- Stash / Armory / Garage
        ['stash_access_denied']     = 'Depoya erişim yetkiniz yok.',
        ['armory_access_denied']    = 'Silah deposuna erişim yetkiniz yok.',
        ['garage_access_denied']    = 'Garaja erişim yetkiniz yok.',
        ['vehicle_spawn_cooldown']  = 'Araç spawn için beklemeniz gerekiyor.',
        ['vehicle_max_spawned']     = 'Maksimum araç sayısına ulaşıldı.',

        -- Finans
        ['treasury_deposit']        = 'Gang kasasına $%s yatırdınız.',
        ['treasury_withdraw']       = 'Gang kasasından $%s çektiniz.',
        ['treasury_no_funds']       = 'Gang kasasında yeterli para yok.',
        ['income_received']         = 'Gang kasanıza %s bölgesinden $%s gelir geldi.',

        -- Admin
        ['admin_gang_created']      = '[ADMİN] %s gangı oluşturuldu.',
        ['admin_gang_deleted']      = '[ADMİN] %s gangı silindi.',
        ['admin_turf_reset']        = '[ADMİN] %s bölgesi sıfırlandı.',
        ['admin_turf_owner_set']    = '[ADMİN] %s bölgesinin sahibi %s olarak ayarlandı.',
        ['admin_war_ended']         = '[ADMİN] Savaş sonlandırıldı.',
        ['admin_rep_added']         = '[ADMİN] %s gangına %s itibar eklendi.',
        ['admin_spray_cleared']     = '[ADMİN] Spray temizlendi.',
    }
end

-- T() fonksiyonu: zaten tanımlanmışsa yeniden tanımlamaz (en.lua ilk yüklenir)
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

