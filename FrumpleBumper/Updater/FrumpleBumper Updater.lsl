// *** UPDATER ***

// Updater: "Frumple Bumpin' University!" on 1847923857
integer update_channel = 1847923857;
string update_announcement = "Frumple Bumpin' University!";
// Bumper:  <set pin to 23048>
integer pin = 23048;
// Bumper:  "You know the code, prof." on 29384710
integer response_channel = 29384710;
string update_response = "You know the code, prof.";
// Updater: <load cleaner script>
string cleaner_script = "FrumpleBumper Cleaner v0.1";
integer cleaner_startup = 932485;
// Cleaner: LinkMessage: 0312050114, "Load me up!", NULL_KEY
// Bumper:  LinkMessage: 0312050114, grids, names
// Cleaner: <delete all scripts, except self>
// Cleaner: "All clear; load 'er up!" on 29384710
string clean_response = "All clear; load 'er up!";
// Updater: <load new scripts>
integer script_startup = 23498;
// Updater: "Woot, woot; you are good to go!" on 1847923857
string confirmation = "Woot, woot; you are good to go!";
// Cleaner: LinkMessage: -0312050114, grids, names
// Cleaner: <clear pin, delete self>


default
{
    state_entry()
    {
        llSetPrimitiveParams([PRIM_TEXTURE, ALL_SIDES,
                              "1f3b15ae-aa2e-4df6-f73c-05200de40448",
                              <1.0, 1.0, 1.0>, <0.0, 0.0, 0.0>, 0.0]);
        llListen(response_channel, "", NULL_KEY, update_response);
        llListen(response_channel, "", NULL_KEY, clean_response);
        llOwnerSay("Attempting to update your FrumpleBumper...");
        llRegionSay(update_channel, update_announcement);
        llSetTimerEvent(5.0);
    }
    
    on_rez(integer start_param)
    {
        llOwnerSay("Attempting to update your FrumpleBumper...");
        llRegionSay(update_channel, update_announcement);
        llSetTimerEvent(5.0);
    }        
    
    timer()
    {
        llSetTimerEvent(0.0);
        llOwnerSay("No FrumpleBumper found to update!  Please rez your FrumpleBumper and touch me to try again.");
    }

    touch_start(integer total_number)
    {
        llOwnerSay("Attempting to update your FrumpleBumper...");
        llRegionSay(update_channel, update_announcement);
        llSetTimerEvent(5.0);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (llGetOwnerKey(id) != llGetOwner()) return;
        
        if (message == update_response) {
            llSetTimerEvent(0.0);
            llRemoteLoadScriptPin(id, cleaner_script, pin, 
                                  TRUE, cleaner_startup);
        }
        
        else if (message == clean_response) {
            integer count = llGetInventoryNumber(INVENTORY_SCRIPT);
            string me = llGetScriptName();
            for (--count; count >= 0; --count) {
                string item = llGetInventoryName(INVENTORY_SCRIPT, count);
                if (item != me && item != cleaner_script)
                    llRemoteLoadScriptPin(id, item, pin, TRUE, script_startup);
            }
            llRegionSayTo(id, update_channel, confirmation);
            llOwnerSay(name + " update complete!");
            llDie();
        }
    }
}
