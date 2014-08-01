// Main module: UI, input/output, updates
//
// Change Log:
//   1.3  Allow Cupido ID in notecards,
//        implement Role Call API,
//        use CHAT rather than DEBUG in menu,
//        spin off scans & notecards for memory usage
//   1.4  Self-pairing options
//   1.6  Perfect match & magic number options

integer THRESHOLD = 3;   // minimum match to mention

// Self-pairing options
integer SELF_PAIR_SHOW_ALL  = 0;  // show all matches
integer SELF_PAIR_SHOW_SOME = 1;  // show only == and >= matches
integer SELF_PAIR_SHOW_NONE = 2;  // hide all matches <= self-pair

// Settings defaults
integer DEBUG = FALSE;   // full match-checking output in local
integer AUTO = TRUE;     // show pairs as they are found
integer CHAT = TRUE;     // normal feedback in local
integer SELF_PAIR = SELF_PAIR_SHOW_SOME;
integer SHOW_PERFECT = TRUE;  // show perfect matches regardless of threshold
integer MAGIC_NUMBER = 0;     // no magic number


// ************************  ROLE CALL API  ***********************

// ROLE CALL: "Hey, who's out there?!" on 2847291301
integer role_call_channel = 2847291301;
string role_call_message = "Hey, who's out there?!";
// EVERYBODY: "HNE Frumpler", <base script name>, <version>, <owner key> on 938110239
integer role_call_response_channel = 938110239;
string role_call_response = "HNE Frumpler";


// ********************  SCRIPT COMMUNICATION  ********************

// *** STORAGE ***

integer PRINT_ALL     =   16011212;  // PALL ++
integer MATCH_FOUND   = 0615211404;  // FOUND
    // string == "\n"[2-digit score, 
    //                MY:    grid, ID, name, type, level, pairing_time,
    //                THEIR: grid, ID, name, type, level, pairing_time,
    //                         owner_name, owner_key]
    // key == CSV[AUTO]
integer PRINT_MATCHES = 1613200308;  // PMTCH
integer CLEAR_MATCHES = 0313200308;  // CMTCH
integer READ_NOTECARD =   18050104;  //  READ
    // string == notecard name
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER, mine]
    // -READ_NOTECARD when the read is complete
integer SCAN_LOCAL    =   19030114;  //  SCAN
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER, mine]
integer READ_PASTED   = 1601192005;  // PASTE
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER, FALSE]   // never mine

  
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
// Cleaner: LinkMessage: 0312050114, "Load me up!", NULL_KEY
integer CLEAN = 0312050114;
string cleaner_start = "Load me up!";
// Bumper:  <set description with SETTINGS>
// Bumper:  LinkMessage: 0312050114, grids, names
// Cleaner: <delete all scripts, except self>
// Cleaner: "All clear; load 'er up!" on 29384710
// Updater: <load new scripts>
integer script_startup = 23498;
// Updater: "Woot, woot; you are good to go!" on 1847923857
// Cleaner: LinkMessage: -0312050114, grids, names
// Cleaner: <clear pin, delete self>


// Reset all scripts, ending with this one
reset()
{
    reset_others();
    llResetScript();
}

// Reset all other scripts
reset_others()
{
    integer i;
    for (i=llGetInventoryNumber(INVENTORY_SCRIPT)-1; i>=0; --i) {
        string script = llGetInventoryName(INVENTORY_SCRIPT, i);
        if (script != llGetScriptName())
            llResetOtherScript(script);
    }
}

// Save settings for a reset
save_settings()
{
    llSetObjectDesc("SETTINGS: " 
                    + llList2CSV([THRESHOLD, DEBUG, AUTO, CHAT, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER]));
}


// ***************************  STORAGE  **************************

// Current stored data
string grids_nc;         // card loaded with MY frumple grids
integer matches_stored;  // simple True || False

// Current read session details
integer matches_found;   // matches found so far
integer action_type;     // READ_NOTECARD || READ_PASTED || SCAN_LOCAL
string action_detail;    // notecard name or pasted text
integer action_mine;     // is this read/scan for MY frumples?

// Player communication
integer dialog_channel;  // randomized upon init
integer grid_channel;    // randomized upon ready state


// ************************  MENU SYSTEM  ************************

list self_pair_text = ["Show All  - ignore self-pairing; show all matches",
                       "Show Some - show pairs that beat self-pairing for one",
                       "Show None - show only pairs that beat self-pairing for both"];
string short_self_pair_text(integer self_pair)
{
    return llGetSubString(llList2String(self_pair_text, self_pair), 0, 8);
}

// Waiting for YOUR notecard
preload_menu()
{
    string msg = llGetScriptName() + "\n\n"
            + "Drop the notecard with YOUR frumple grids onto me now.\n
\n"
            + "Current match threshold: " + (string)THRESHOLD
            + "\nSelf-pair setting: " + short_self_pair_text(SELF_PAIR);
    if (MAGIC_NUMBER) msg += "\nMagic number: " + (string)MAGIC_NUMBER;
    else msg += "\nMagic number: NONE";
    if (SHOW_PERFECT) msg += "\nShowing PERFECT matches always";
            
    // Bottom row: settings "Auto ON/OFF", "Chat ON/OFF", "Show/Hide Perfect"
    list options = [];
    if (AUTO) options += ["Auto OFF"]; else options += ["Auto ON"];
    if (CHAT) options += ["Chat OFF"]; else options += ["Chat ON"];
    if (SHOW_PERFECT) options += ["Hide Perfect"];
    else options += ["Show Perfect"];
            
    // Center row: "Magic Number", "Threshold", "Self-Pairing"
    options += ["Magic Number", "Threshold", "Self-Pairing"];
    
    // Main row: ["OK", "Scan", " "]
    options += ["OK", "Scan", " "];
    
    llDialog(llGetOwner(), msg, options, dialog_channel);
}

// In "ready" state
main_menu()
{
    string msg = llGetScriptName() + "\n\n"
            + "Minimum match threshold: " + (string)THRESHOLD
            + "\nSelf-Pair settings: " + short_self_pair_text(SELF_PAIR);
    if (MAGIC_NUMBER) msg += "\nMagic number: " + (string)MAGIC_NUMBER;
    else msg += "\nMagic number: NONE";
    if (SHOW_PERFECT) msg += "\nShowing PERFECT matches always";
    msg += "\nGrid NC loaded: " + grids_nc;
            
    // Extra row 4: "Show Grids", "Show Pairs", "Clear Pairs"
    list options = ["Show Grids"];
    if (matches_stored)
        options += ["Show Pairs", "Clear Pairs"];
    else
        options += [" ", " "];
            
    // Bottom row: settings "Auto ON/OFF", "Chat ON/OFF", "Show/Hide Perfect"
    if (AUTO) options += ["Auto OFF"]; else options += ["Auto ON"];
    if (CHAT) options += ["Chat OFF"]; else options += ["Chat ON"];
    if (SHOW_PERFECT) options += ["Hide Perfect"];
    else options += ["Show Perfect"];
            
    // Center row: "Magic Number", "Threshold", "Self-Pairing"
    options += ["Magic Number", "Threshold", "Self-Pairing"];
    
    // Top row: "Paste Grid", "Scan", "RESET"
    options += ["Paste Grid", "Scan", "RESET"];
        
    llDialog(llGetOwner(), msg, options, dialog_channel);
}    


// Settings sub-menu options
string self_pair_msg()
{
    return "Select what matches you would like the FrumpleBumper to show you when self-pairing will be the same or better:\n\n" + llDumpList2String(self_pair_text, "\n") + "\n\nCurrent choice: " + short_self_pair_text(SELF_PAIR);
}
string threshold_msg()
{ 
    string msg = "Select the minimum number of matches you are interested in:"
         + "\n\nCurrent Threshold: " + (string)THRESHOLD;
    if (SHOW_PERFECT)
         msg += "\n\n(NOTE: A PERFECT match to one of your frumple grids may be shown even if it doesn't meet your match threshold)";
    return msg;
}
string NEXT_BTN = "Next -->";
string PREV_BTN = "<-- Prev";
list page_one = ["10", "11", NEXT_BTN,
                  "7",  "8",  "9",
                  "4",  "5",  "6",
                  "1",  "2",  "3"];
list page_two = [PREV_BTN, "21", "22",
                 "18", "19", "20",
                 "15", "16", "17",
                 "12", "13", "14"];
string magic_number_msg()
{
    return "Select the current week's magic number, or NONE to ignore the magic number for now.";
}
list magic_number_options = ["19 ", "20 ", " ",
                             "16 ", "17 ", "18 ",
                             "13 ", "14 ", "15 ",
                             "NONE", "11 ", "12 "];
               
// Handle settings sub-menu the same in all states  
parse_settings_submenu(string message)
{
    integer index;
    
    if (message == " ") return;
    else if (message == "Chat ON") {
        CHAT = TRUE;
        llOwnerSay("Now showing feedback in local chat.");
    }
    else if (message == "Chat OFF") {
        CHAT = FALSE;
        llOwnerSay("Hiding local chat... starting NOW.");
    }
    else if (message == "Auto ON") {
        AUTO = TRUE;
        if (CHAT) llOwnerSay("Now showing pairs as they are found.");
    }
    else if (message == "Auto OFF") {
        AUTO = FALSE;
        if (CHAT) llOwnerSay("Now showing pairs only on request.");
    }
     
    // Self-pairing sub-menu
    else if (message == "Self-Pairing")
        llDialog(llGetOwner(), self_pair_msg(), 
                    ["Show All", "Show Some", "Show None"], dialog_channel);
    else if (message == "Show All")
        SELF_PAIR = SELF_PAIR_SHOW_ALL;
    else if (message == "Show Some")
        SELF_PAIR = SELF_PAIR_SHOW_SOME;
    else if (message == "Show None")
        SELF_PAIR = SELF_PAIR_SHOW_NONE;
    
    // Show perfect
    else if (message == "Show Perfect") {
        SHOW_PERFECT = TRUE;
        if (CHAT) llOwnerSay("PERFECT matches will now be shown regardless of Threshold.");
    }
    else if (message == "Hide Perfect") {
        SHOW_PERFECT = FALSE;
        if (CHAT) llOwnerSay("Your threshold setting will now be respected for all matches.");
    }
        
    // Magic number sub-menu
    else if (message == "Magic Number")
        llDialog(llGetOwner(), magic_number_msg(), magic_number_options, dialog_channel);
    else if (message == "NONE")
        MAGIC_NUMBER = 0;
    else if ((index = llListFindList(magic_number_options, [message])) != -1)
        MAGIC_NUMBER = (integer)llGetSubString(message, 0, -2);

    // Threshold sub-menu
    else if (message == "Threshold")
        llDialog(llGetOwner(), threshold_msg(), page_one, dialog_channel);
    else if (message == NEXT_BTN)
        llDialog(llGetOwner(), threshold_msg(), page_two, dialog_channel);
    else if (message == PREV_BTN)
        llDialog(llGetOwner(), threshold_msg(), page_one, dialog_channel);
    else {
        integer t = (integer)message;
        if (t > 0 && t <= 25) {
            THRESHOLD = t;
            if (CHAT)
                llOwnerSay("Now looking for matches of " 
                       + (string)THRESHOLD + " or better.");
        }
    }
}


// ***********************  USER INTERFACE  ***********************

// 4-pack of UI textures
key TEXTURE_KEY = "199bfdf8-70af-92c8-4048-cc9eca010ccb";

// Show RED "drop NC here" -- top right
set_ui_load_nc()
{ llSetPrimitiveParams([PRIM_TEXTURE, ALL_SIDES, TEXTURE_KEY,
                        <0.5, 0.5, 0.0>, <0.25, 0.25, 0.0>, 0.0]); }

// Show BLUE "ready" -- bottom left
set_ui_ready()
{ llSetPrimitiveParams([PRIM_TEXTURE, ALL_SIDES, TEXTURE_KEY,
                        <0.5, 0.5, 0.0>, <-0.25, -0.25, 0.0>, 0.0]); }

// Show BLACK "please wait" -- top left
set_ui_please_wait()
{ llSetPrimitiveParams([PRIM_TEXTURE, ALL_SIDES, TEXTURE_KEY,
                        <0.5, 0.5, 0.0>, <-0.25, 0.25, 0.0>, 0.0]); }

// Show GREEN "matches found" -- bottom right
set_ui_matches_found()
{ llSetPrimitiveParams([PRIM_TEXTURE, ALL_SIDES, TEXTURE_KEY,
                        <0.5, 0.5, 0.0>, <0.25, -0.25, 0.0>, 0.0]); }

// Flash for "match found"
start_flash()
{ 
    llSetAlpha(0.5, ALL_SIDES); 
    llSetTimerEvent(0.5);
}
end_flash()
{ 
    llSetAlpha(1.0, ALL_SIDES);
    llSetTimerEvent(0.0);
}
integer is_flash()
{ return llGetAlpha(0) == 0.5; }


// ***************************  STATES  ***************************

// Waiting for a list to match against
default
{
    // Prompt for my_pairables notecard (or read the first one found)
    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Rename on update
        if (llGetStartParameter() == script_startup)
            llSetObjectName(llGetScriptName());
            
        // Initialize
        llListen(update_channel, "", NULL_KEY, update_announcement);
        set_ui_load_nc();
        end_flash();
        
        // Look for retained settings (on menu RESET)
        string desc = llGetObjectDesc();
        if (llGetSubString(desc, 0, 9) == "SETTINGS: ") {
            list settings = llCSV2List(llGetSubString(desc, 10, -1));
            integer t = llList2Integer(settings, 0);
            if (t > 0 && t <=25) {
                integer len = llGetListLength(settings);
                THRESHOLD = t;
                DEBUG = llList2Integer(settings, 1);
                AUTO = llList2Integer(settings, 2);
                if (len >= 4)
                    CHAT = llList2Integer(settings, 3);
                if (len >= 5)
                    SELF_PAIR = llList2Integer(settings, 4);
                if (len >= 7) {
                    SHOW_PERFECT = llList2Integer(settings, 5);
                    MAGIC_NUMBER = llList2Integer(settings, 6);
                }
            }
                
        }
        llSetObjectDesc("");
          
        // Listen for menu commands
        dialog_channel = -2000000000 + (integer)llFrand(1000000000.0);
        llListen(dialog_channel, "", llGetOwner(), "");
        
        // Look for ready-made owner notecard
        if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0) {
            string nc = llGetInventoryName(INVENTORY_NOTECARD, 0);
            if (llGetInventoryCreator(nc) != llGetOwner())
                llDialog(llGetOwner(), "You didn't write this 
notecard!  Are you SURE it is the one that has YOUR frumple grids??\n\n" 
+ nc, ["Yes", "No"], dialog_channel);
            else {
                action_type = READ_NOTECARD;
                state processing;
            }
        }
       
        // Prompt user OR load saved data
        if (llGetStartParameter() == script_startup)
            llSetTimerEvent(6.0);  // wait to load saved data (update)
        else
            llSetTimerEvent(0.1);  // prompt user right away
    }
    
    timer()
    {
        llSetTimerEvent(0.0);
        if (CHAT) llOwnerSay("Drop in the notecard with YOUR frumple grids now, or touch to load nearby frumples automatically.");
    }
    
    // Re-prompt when rezzed/attached
    on_rez(integer start_param)
    {
        // Maintain incorrectly-set rename
        if (llGetSubString(llGetScriptName(), -4, -1) 
         == llGetSubString(llGetObjectName(), -4, -1))
            llSetObjectName(llGetScriptName());
    
        if (CHAT) llOwnerSay("Drop in the notecard with YOUR frumple grids now, or touch to load nearby frumples automatically.");
    }

    // Re-prompt on owner touch
    touch_start(integer total_number)
    {
        integer i;
        for (i=0; i<total_number; ++i) {
            key av = llDetectedKey(0);
            if (av == llGetOwner())
                preload_menu();
            else
                llRegionSayTo(av, 0, "Hi, I'm the FrumpleBumper!  I can 
do the eye-glazing work of matching up frumple grids for you!  Learn more 
at https://marketplace.secondlife.com/p/FrumpleBumper-HUD/5167856 and get your own today!");
        }
    }
    
    // Allow settings to change early
    listen(integer channel, string name, key id, string message)
    {
        // Allow updates
        if (channel == update_channel) {
            if (llGetOwnerKey(id) != llGetOwner()) return;
            llSetRemoteScriptAccessPin(pin);
            llRegionSayTo(id, response_channel, update_response);
            return;
        }
        
        // Respond to role call
        else if (channel == role_call_channel) {
            string name = llGetScriptName();
            llRegionSayTo(id, role_call_response_channel,
                          llList2CSV([role_call_response,
                                      llGetSubString(name, 0, -6),
                                      llGetSubString(name, -3, -1),
                                      llGetOwner()]));
            return;
        }
        
        // Wrong-creator sub-menu
        if (message == "Yes") {
            action_type = READ_NOTECARD;
            state processing;
        }
        else if (message == "No") {
            integer i = llGetInventoryNumber(INVENTORY_NOTECARD);
            for (--i; i>=0; --i)
                llRemoveInventory(llGetInventoryName(INVENTORY_NOTECARD, 
i));
            if (CHAT) llOwnerSay("Drop in the notecard with YOUR frumple grids now, or touch to load nearby frumples automatically.");
        }
        
        // Scan for local frumples
        else if (message == "Scan") {
            action_type = SCAN_LOCAL;
            state processing;
        }
        
        // Settings sub-menus
        else 
          parse_settings_submenu(message);
    }
    
    // Load notecard as soon as it's dropped
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
            reset();
            
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0) {
                string nc = llGetInventoryName(INVENTORY_NOTECARD, 0);
                if (llGetInventoryCreator(nc) != llGetOwner())
                    llDialog(llGetOwner(), "You didn't write this 
notecard!  Are you SURE it is the one that has YOUR frumple grids??\n\n" 
+ nc, ["Yes", "No"], dialog_channel);
                else {
                    action_type = READ_NOTECARD;
                    state processing;
                }
            }
        }
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        // Store data for update
        if (num == CLEAN && str == cleaner_start)
            save_settings();
    }
    
    state_exit()
    { 
        action_mine = TRUE;  // All read/scan events are for MY frumples
        llSetTimerEvent(0.0);
    }
}

// In the middle of reading/scanning/etc.
state processing
{
    // Reset on owner change
    changed(integer change)
    { if (change & CHANGED_OWNER) reset(); }

    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Trigger the action
        llSensor("Not Found", "NF Key", AGENT, 1.0, PI);
        
        // Allow a user override
        llListen(dialog_channel, "", llGetOwner(), "RESET");
    }
    
    touch_start(integer num)
    {
        integer i;
        for (i=0; i<num; ++i) {
            key av = llDetectedKey(0);
            if (av == llGetOwner())
                llDialog(av, llGetScriptName() + "\n\nHang on, I'm still working here!!", ["OK", "RESET"], dialog_channel);
            else
                llRegionSayTo(av, 0, "Hi, I'm the FrumpleBumper!  I can 
do the eye-glazing work of matching up frumple grids for you!  Learn more 
at https://marketplace.secondlife.com/p/FrumpleBumper-HUD/5167856 and get your own today!");
        }
    }
    
    no_sensor()
    {
        // Prepare the session
        matches_found = 0;
        set_ui_please_wait();
        
        // Handle feedback and details
        if (action_type == SCAN_LOCAL) {
            if (CHAT) {
                if (action_mine) llOwnerSay("Scanning your local frumples...");
                else llOwnerSay("Scanning local frumples to pair with...");
            }
            if (action_mine) grids_nc = "(Scanned " + llGetDate() + ")";
        }
        else if (action_type == READ_NOTECARD) {
            action_detail = llGetInventoryName(INVENTORY_NOTECARD, 0);
            if (CHAT) llOwnerSay("Reading " + action_detail);
            if (action_mine) grids_nc = action_detail;
        }
        
        // Send the initial request
        llMessageLinked(LINK_SET, action_type, action_detail,
                (key)llList2CSV([THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER, action_mine])); 
        
    }

    listen(integer channel, string name, key id, string message)
    {
        // Respond to role call
        if (channel == role_call_channel) {
            string name = llGetScriptName();
            llRegionSayTo(id, role_call_response_channel,
                          llList2CSV([role_call_response,
                                      llGetSubString(name, 0, -6),
                                      llGetSubString(name, -3, -1),
                                      llGetOwner()]));
            return;
        }
        
        // Allow reset w/removal of notecards
        else if (channel == dialog_channel) {
            reset_others();
            integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
            while (count > 0)
                llRemoveInventory(llGetInventoryName(INVENTORY_NOTECARD, --count));
            save_settings();
            llResetScript();
        }       
    }
    
    timer()
    { end_flash(); }

    link_message(integer sender, integer num, string str, key id)
    {
        // Count and flash for matches
        if (num == MATCH_FOUND) {
            start_flash();
            ++matches_found;
            matches_stored = TRUE;
        }
        else if (num == CLEAR_MATCHES)
            matches_stored = FALSE;
            
        // Type-specific action responses
        string verb = "";
        if (num == -SCAN_LOCAL)
            verb = "scanned";
        else if (num == -READ_NOTECARD) {
            verb = "read";
            llRemoveInventory(action_detail);
        }
        else if (num == -READ_PASTED)
            verb = "checked";
        else return;
        if (action_mine) verb += " for you";
        
        // Provide feedback
        integer grid_count = (integer)str;
        if (CHAT)
            llOwnerSay((string)grid_count + " frumple grids " + verb + "; "
                     + (string)matches_found + " matches found of "
                     + (string)THRESHOLD + " or better.");
        
        // Update UI
        if (matches_stored)
            set_ui_matches_found();
        else
            set_ui_ready();
        
        // Reading/scanning mine failed?
        if (action_mine && grid_count == 0)
            state default;  // re-validate ownership, etc
            
        // Check for additional notecards
        else if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0) {
            action_type = READ_NOTECARD;
            action_mine = FALSE;
            // Trigger read
            llSensor("Not Found", "NF Key", AGENT, 1.0, PI);
        }
        
        // Move on to ready state
        else {
            if (CHAT) llOwnerSay("Drop a fellow frumpler's notecard on me, or touch to enter a grid manually.");
            state ready;
        }
    }
    
    // Clean up flashes
    state_exit()
    { end_flash(); }
}

// Accept match requests
state ready
{    
    // Setup & prompt for pair requests
    state_entry()
    {
        // Listen for role call, updates, dialogs
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        llListen(update_channel, "", NULL_KEY, update_announcement);
        grid_channel   = -2000000000 + (integer)llFrand(1000000000.0);
        llListen(dialog_channel, "", llGetOwner(), "");
        llListen(grid_channel, "", llGetOwner(), "");
        
        // UI was set on the way out of processing

        // NC waiting already?
        if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0) {
            action_type = READ_NOTECARD;
            state processing;
        }
    }
    
    // Prompt for a grid on touch
    touch_start(integer num)
    {
        integer i;
        for (i=0; i<num; ++i) {
            key av = llDetectedKey(i);
            if (av == llGetOwner())
                main_menu();
            else
                llRegionSayTo(av, 0, "Hi, I'm the FrumpleBumper!  I can 
do the eye-glazing work of matching up frumple grids for you!  Learn more 
at https://marketplace.secondlife.com/p/FrumpleBumper-HUD/5167856 and get your own today!");
                
        }
    }
    
    // Catch inventory drops
    changed(integer change)
    {
        // Watch for owner change
        if (change & CHANGED_OWNER)
            reset();
            
        // New notecard dropped?
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0) {
                string nc = llGetInventoryName(INVENTORY_NOTECARD, 0);
                if (llGetInventoryCreator(nc) == llGetOwner())
                    llDialog(llGetOwner(), "This appears to be one of 
your notecards. Do you want to overwrite my saved grids, or do you want 
to compare this notecard to what I have loaded?", ["Overwrite", 
"Compare", "Delete"], dialog_channel);
                else {
                    action_type = READ_NOTECARD;
                    state processing;
                }
            }
        }
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        // Store data for update
        if (num == CLEAN && str == cleaner_start)
            save_settings();
        
        // Watch for a match clear
        else if (num == CLEAR_MATCHES)
            matches_stored = FALSE;
    }
    
    // Catch pasted grid(s)
    listen(integer channel, string name, key id, string message)
    {
        // Allow updates
        if (channel == update_channel) {
            if (llGetOwnerKey(id) != llGetOwner()) return;
            llSetRemoteScriptAccessPin(pin);
            llRegionSayTo(id, response_channel, update_response);
            return;
        }
        
        // Respond to role call
        else if (channel == role_call_channel) {
            string name = llGetScriptName();
            llRegionSayTo(id, role_call_response_channel,
                          llList2CSV([role_call_response,
                                      llGetSubString(name, 0, -6),
                                      llGetSubString(name, -3, -1),
                                      llGetOwner()]));
            return;
        }
        
        // Catch pasted grid(s)
        if (channel == grid_channel) {
            action_type = READ_PASTED;
            action_detail = message;
            state processing;
        }
        
        // Handle menu commands
        else if (message == "RESET" || message == "Overwrite") {
            save_settings();
            reset();
        }
        else if (message == "Paste Grid")
            llTextBox(llGetOwner(), "Paste your fellow frumpler's grid 
below, or drop their full notecard on me to check for pairs.", 
grid_channel);
        else if (message == "Show Grids")
            llMessageLinked(LINK_SET, PRINT_ALL, "", NULL_KEY);
        else if (message == "Show Pairs")
            llMessageLinked(LINK_SET, PRINT_MATCHES, "", NULL_KEY);
        else if (message == "Clear Pairs") {
            llMessageLinked(LINK_SET, CLEAR_MATCHES, "", NULL_KEY);
            set_ui_ready();
        }
        else if (message == "Scan") {
            action_type = SCAN_LOCAL;
            state processing;
         }
        
        // Same-owner sub-menu
        //else if (message == "Overwrite")  // above (RESET)
        else if (message == "Compare") {
            action_type = READ_NOTECARD;
            state processing;
        }
        else if (message == "Delete") {
            llRemoveInventory(llGetInventoryName(INVENTORY_NOTECARD, 0));
            if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0) {
                string nc = llGetInventoryName(INVENTORY_NOTECARD, 0);
                if (llGetInventoryCreator(nc) == llGetOwner())
                    llDialog(llGetOwner(), "This appears to be one of 
your notecards. Do you want to overwrite my saved grids, or do you want 
to compare this notecard to what I have loaded?", ["Overwrite", 
"Compare", "Delete"], dialog_channel);
                else {
                    action_type = READ_NOTECARD;
                    state processing;
                }
            }
        }
        
        // Settings sub-menus
        else
          parse_settings_submenu(message);
    }
    
    // Coming from here, we are reading someone else's grids...
    state_exit()
    {
        action_mine = FALSE;
    }
}