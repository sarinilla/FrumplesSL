// *** UPDATER ***

// Updater: "Frumple Bumpin' University!" on 1847923857
integer update_channel = 1847923857;
// Bumper:  <set pin to 23048>
// Bumper:  "You know the code, prof." on 29384710
integer response_channel = 29384710;
// Updater: <load cleaner script>
integer cleaner_startup = 932485;
// Cleaner: LinkMessage: 0312050114, "Load me up!", NULL_KEY
integer CLEAN = 0312050114;
string cleaner_start = "Load me up!";
// Bumper:  <set description with SETTINGS>
// Bumper:  LinkMessage: 0312050114, grids, names
// Cleaner: <delete all scripts, except self>
// Cleaner: "All clear; load 'er up!" on 29384710
string clean_response = "All clear; load 'er up!";
// Updater: <load new scripts>
// Updater: "Woot, woot; you are good to go!" on 1847923857
string confirmation = "Woot, woot; you are good to go!";
// Cleaner: LinkMessage: -0312050114, grids, names
// Cleaner: <clear pin, delete self>


string grids;
key names;

default
{
    state_entry()
    {
        if (llGetStartParameter() != cleaner_startup) return;
        llMessageLinked(LINK_SET, CLEAN, cleaner_start, NULL_KEY);
        llSetTimerEvent(2.5);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num != CLEAN) return;
        if (str == cleaner_start) return;
        grids = str;
        names = id;
        state done;
    }
    
    timer()
    {
        state done;
    }
}

state done
{
    state_entry()
    {
        llListen(update_channel, "", NULL_KEY, confirmation);
        integer count = llGetInventoryNumber(INVENTORY_SCRIPT);
        string me = llGetScriptName();
        for (--count; count >= 0; --count) {
            string item = llGetInventoryName(INVENTORY_SCRIPT, count);
            if (item != me) llRemoveInventory(item);
        }
        llRegionSay(response_channel, clean_response);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (grids) llMessageLinked(LINK_SET, -CLEAN, grids, names);
        llSetRemoteScriptAccessPin(0);
        llRemoveInventory(llGetScriptName());
    }
}
