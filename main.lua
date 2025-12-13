-- =====================================================
-- Main.lua
-- Papi Dimz | HUB
-- ENTRY POINT (BOOTSTRAP ONLY)
-- =====================================================

-- ❗ PENTING:
-- Main.lua TIDAK BOLEH berisi logic game
-- TIDAK BOLEH berisi WindUI
-- HANYA load UI.lua (yang otomatis load logic.lua)

local folder = script

-- Safety check
if not folder:FindFirstChild("logic") then
    warn("[MAIN] logic.lua tidak ditemukan")
    return
end

if not folder:FindFirstChild("UI") then
    warn("[MAIN] UI.lua tidak ditemukan")
    return
end

-- Load UI (UI akan otomatis require logic.lua)
local ok, err = pcall(function()
    require(folder.UI)
end)

if not ok then
    warn("[MAIN] Gagal load UI.lua:", err)
else
    print("[MAIN] Papi Dimz HUB loaded successfully")
end
