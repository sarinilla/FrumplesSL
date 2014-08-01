// The frumples breedable included a monthly contest in which
// you played games during the month to generate a number of
// five-by-five binary frumple grids.  Then three possible
// contest grids were generated, and you were to pick the grid
// you wished to use.  All of your game grids for the month
// were compared to this one and you won prizes based on how
// many squares matched.
//
// This script scraped the contest website (as pasted into a
// Second Life notecard) and automatically compared the grids
// for you to determine which of the three you would do best
// to choose.  As well as an introduction to Artificial
// Intelligence (in that it "scores" each of the three grids
// using weighted measurements to determine the best choice),
// I believe this script offers a solid example of state-
// driven LSL and ease-of-use.  For instance, if the user copies
// the entire website into the notecard at the first prompt, the
// script detects that and will not prompt for further data from
// the website.
//
// Author: Rini Rampal
// Written 2013
// Released under MIT License
// https://github.com/SariniLynn/FrumplesSL


integer dialog_channel;  // Randomized upon use
integer listener;        // Temporary listener storage

string reading_nc;     // Name of the notecard being read
integer nc_line;       // Current line to read
key nc_qID;            // Database query ID

list my_grids;         // All joker games entered by the player
list picked_grids;     // The three chosen grids for the month

integer best_index;    // (1-3) index of winning contest grid (or 0)
integer best_score;    // arbitrary value to compare by
string best_display;   // printable display of best contest grid
string total_display;  // printable display of all contest grids

string NON_OWNER_AD = "Hi! I'm The Grand Jester, and I can help you figure out which grid you should choose for the monthly joker contest! Get your own at http://maps.secondlife.com/secondlife/Huineng/134/152/750";


// ************************  ROLE CALL API  ***********************

// ROLE CALL: "Hey, who's out there?!" on 2847291301
integer role_call_channel = 2847291301;
string role_call_message = "Hey, who's out there?!";
// EVERYBODY: "HNE Frumpler", <base script name>, <version>, <owner key> on 938110239
integer role_call_response_channel = 938110239;
string role_call_response = "HNE Frumpler";


// ***************************  HELPERS  **************************

// Select a channel and open a listener
dialog_init(key avatar)
{
    dialog_cleanup();
    dialog_channel = -2000000000 + (integer)llFrand(1000000000.0);
    listener = llListen(dialog_channel, "", avatar, "");
}

// Clean up the active listener
dialog_cleanup()
{ llListenRemove(listener); }

// Determine if we are in the contest period
integer is_active_contest()
{
    llSetTimerEvent(21600.0);  // check again in 6 hours
    
    integer day = (integer)llGetSubString(llGetDate(), -2, -1);
    return (day >= 25 && day <= 28);
}


// 2/3 to 1/3 split face
set_ui_split(float hl, float vl, float hr, float vr)
{
    key TEXTURE_KEY = "4d83782b-97a3-77f4-d5f8-e50d968d46d0";
    llSetPrimitiveParams([PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT,
                          <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                          PRIM_TEXTURE, 0, TEXTURE_KEY,
                          <1.0/3, 0.25, 0.0>, 
                          <-2.0/6+hl/2, .375-vl/4, 0.0>,
                          0.0,
                          PRIM_TEXTURE, 2, TEXTURE_KEY,
                          <1.0/6, 0.25, 0.0>, 
                          <-1.0/12+hr/2, .375-vr/4, 0.0>,
                          -PI_BY_TWO]);
}

// Params are indices [0:1] horizontal, [0:3] vertical
set_ui(integer horizontal, integer vertical)
{
    set_ui_split(horizontal, vertical, horizontal, vertical);
}

// Set the UI for dormant or ready state
ui_ready()
{
    if (is_active_contest()) 
        set_ui(0, 0);  // top left
    else                     
        set_ui(1, 0);  // top right
}

// Set the UI for loading the player's entries
ui_load_mine()
{
    set_ui(0, 1);
}

ui_load_picked()
{
    set_ui(1, 1);
}

ui_please_wait()
{
    set_ui(0, 2);
}

ui_done()
{
    if (best_index == 1)
        set_ui(1, 2);
    else if (best_index == 2)
        set_ui_split(1.0, 2.0, 0.5, 3.0);
    else if (best_index == 3)
        set_ui_split(1.0, 2.0, 1.0, 3.0);
    else
        set_ui(0, 3);
}


// **************************  GRID MGMT  *************************

// Count the number of found/matched squares in a grid
integer count_boxes(integer grid)
{
    integer count = 0;
    while (grid > 0) {
        ++count;
        grid = grid & (grid - 1);
    }
    return count;
}

// Convert a boolean value to a box for print-out
string convert_bit(integer bit)
{
    if (bit) return "■";
    else return "□";
}

// Convert a 5-bit grid line to human-readable format
string convert_line(integer line, integer line_no)
{
    string grid = convert_bit(line & TRUE)
                + convert_bit((line >> 1) & TRUE)
                + convert_bit((line >> 2) & TRUE)
                + convert_bit((line >> 3) & TRUE)
                + convert_bit((line >> 4) & TRUE);
    return (string)line_no + " - " + grid;
}

// Print a grid in human-readable format
string single_grid(integer grid)
{
    return convert_line(grid, 1) + "\n"
         + convert_line(grid >>  5, 2) + "\n"
         + convert_line(grid >> 10, 3) + "\n"
         + convert_line(grid >> 15, 4) + "\n"
         + convert_line(grid >> 20, 5) + "\n";
}


// ***************************  STATES  ***************************

// Between contests / init
default
{
    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Set the UI (based on time of the month)
        ui_ready();
        
        // Clear any leftover notecards
        integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
        if (count) {
            integer i;
            for (i=count; i>0; --i)
                llRemoveInventory(
                        llGetInventoryName(INVENTORY_NOTECARD, i-1));
        }
        
        // Custom prompt based on time of the month
        if (!is_active_contest())
            llOwnerSay("Hi! There is no need to do anything until the Monthly Patterns are generated for the joker contest. Go play those Joker Games and earn more great entries!");
        else
            llOwnerSay("Touch me when you are ready to begin!");
    }
    
    // Watch for the contest to start/end
    timer()
    { ui_ready(); }
    
    // Check the date on each rez
    on_rez(integer start_param)
    { llResetScript(); }
    
    // Prompt new owner when sold
    changed(integer change)
    { 
        if (change & CHANGED_OWNER) 
            llResetScript(); 
            
        // Go ahead and start if they drop a notecard ON CONTEST DATES
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0) {
                if (is_active_contest())
                    state load_mine_nc;
                else
                    llRemoveInventory(llGetInventoryName(INVENTORY_NOTECARD, 0));
            }
        }
    }

    touch_start(integer total_number)
    {
        // Process every touch
        integer i;
        for (i=0; i<total_number; ++i) {
            key av = llDetectedKey(i);
            
            // Drop a link/advertisement to non-owners
            if (av != llGetOwner())
                llRegionSayTo(av, 0, NON_OWNER_AD);
            else {
                
                // Player sanity check based on time of month
                if (!is_active_contest()) {
                    dialog_init(av);
                    llDialog(av, llGetScriptName() + "\n\nI don't think it's time for the contest yet... You don't need to do ANYTHING with me until the monthly grids are chosen. Are you SURE you are ready to continue now?", ["Continue", "Cancel"], dialog_channel);
                }
                
                // Begin
                else
                    state load_mine;
            }
        }
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
        
        // Override player sanity check
        if (message == "Continue")
            state load_mine;
            
        // Clean up listener on Cancel
        dialog_cleanup();
    }
    
    state_exit()
    { llSetTimerEvent(0.0); }
}

// Get a notecard of player's entered joker grids
state load_mine
{
    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Set the UI with instructions
        ui_load_mine();
        
        // Clear any leftover notecards
        integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
        if (count) {
            integer i;
            for (i=count; i>0; --i)
                llRemoveInventory(
                        llGetInventoryName(INVENTORY_NOTECARD, i-1));
        }
        
        // Prompt the player
        dialog_init(llGetOwner());
        llOwnerSay("Copy and paste all of YOUR entered joker grids from the contest period into a notecard and load it now.");
    }
    
    // Re-prompt on touch (listener left open)
    touch_start(integer num)
    {
        integer i;
        for (i=0; i<num; ++i) {
            key av = llDetectedKey(i);
            if (av != llGetOwner())
                llRegionSayTo(av, 0, NON_OWNER_AD);
            else
                llDialog(llGetOwner(), llGetScriptName() + "\n\nCopy and paste all of YOUR entered joker grids from the contest period into a notecard and load it now.", ["OK", "Help", "Reset"], dialog_channel);
        }
    }
    
    // Handle dialog response (leave listener open)
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
        
        // Accept OK
        if (message == "OK")
            return;
            
        // Give Ann-proof instructions in local chat
        else if (message == "Help")
            llOwnerSay("Step 1 - Log in to YOUR profile page at http://2starsgames.com/frumples/pairables/UserData.php  If you've forgotten your password, you can get a new one at http://maps.secondlife.com/secondlife/Charmed%20Games/250/73/3036\n\nStep 2 - Click on the Joker Contest tab\n\nStep 3 - Select the WHOLE page (Ctrl-A if you are on Windows) -- you cannot select too much here, so just get the WHOLE thing!\n\nStep 4 - Copy and paste that WHOLE page into a notecard and save it -- it's okay if you don't see your grids in the notecard; I can still get them!\n\nStep 5 - Drop that notecard onto me now.");

        // Reset on command
        else if (message == "Reset")
            llResetScript();
    }
    
    changed(integer change)
    {
        // Reset if the owner changes
        if (change & CHANGED_OWNER)
            llResetScript();
            
        // Start reading any notecard we get
        if (change & CHANGED_INVENTORY)
            if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0)
                state load_mine_nc;
    }
}

// Actually read the notecard
state load_mine_nc
{
    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Set the UI for work-in-progress
        ui_please_wait();
        
        // Clear existing storage
        my_grids = [];
        picked_grids = [];
        
        // Start the read
        reading_nc = llGetInventoryName(INVENTORY_NOTECARD, 0);
        nc_line = 0;
        nc_qID = llGetNotecardLine(reading_nc, nc_line);
        llOwnerSay("Reading " + reading_nc + "; please wait...");
    }
    
    // Watch for critical changes
    changed (integer change)
    {
        if (change & CHANGED_OWNER)
            llResetScript();
            
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryType(reading_nc) != INVENTORY_NOTECARD) {
                llOwnerSay("Hey! Where'd my notecard go?!");
                state load_mine;
            }
        }
    }
    
    // Allow owner to reset / status update
    touch_start(integer num)
    {
        integer i;
        for (i=0; i<num; ++i) {
            key av = llDetectedKey(i);
            if (av != llGetOwner())
                llRegionSayTo(av, 0, NON_OWNER_AD);
            else {
                dialog_init(av);
                llDialog(av, llGetScriptName() + "\n\nI am still reading your notecard!  I know, I know, SL is a little slow here...  Just be patient, please!", ["OK", "Reset"], dialog_channel);
            }
        }
    }
    
    // Allow owner reset from dialog
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
        
        // Reset on command
        if (message == "Reset")
            llResetScript();
            
        // Close listener
        dialog_cleanup();
    }
    
    dataserver(key query_id, string data)
    {
        // Make sure it's our notecard line
        if (query_id != nc_qID)
            return;
        
        // Watch for the end of the notecard (or section)
        if (data == EOF || data == "Upcoming Contest Patterns  ") {
            llRemoveInventory(reading_nc);
            if (my_grids == [])
                state load_mine;
            else if (llGetListLength(picked_grids) == 3)
                state compare;
            else
                state load_picked;
        }
            
        // Go ahead and request the next one
        nc_qID = llGetNotecardLine(reading_nc, ++nc_line);
        
        // Check for a game grid
        string prefix = llGetSubString(data, 0, 2);
        if (prefix == "CP:") {
            integer grid = (integer)llGetSubString(data, 3, -1);
            if (grid > 0)
                my_grids += [grid];
        }
        
        // Check for a contest grid
        else if (prefix == "SP:") {
            integer end = llSubStringIndex(data, " ");
            integer grid = (integer)llGetSubString(data, 3, end);
            if (grid > 0)
                picked_grids += [grid];
        }
    }
    
    state_exit()
    {
        llOwnerSay((string)llGetListLength(my_grids) + " joker entries found.");
        integer picked = llGetListLength(picked_grids);
        if (picked == 3)
            llOwnerSay((string)picked + " selected contest patterns found.");
        else if (picked)
            llOwnerSay((string)picked + " selected contest patterns ignored.");
    }
}

// Get a notecard with the three chosen patterns
state load_picked
{
    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Set the UI with instructions
        ui_load_picked();
        
        // Clear any leftover notecards
        integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
        if (count) {
            integer i;
            for (i=count; i>0; --i)
                llRemoveInventory(
                        llGetInventoryName(INVENTORY_NOTECARD, i-1));
        }
        
        // Prompt the player
        dialog_init(llGetOwner());
        llOwnerSay("Copy and paste all THREE of the chosen contest patterns into a notecard and load it now.");
    }
    
    // Re-prompt on touch (listener left open)
    touch_start(integer num)
    {
        integer i;
        for (i=0; i<num; ++i) {
            key av = llDetectedKey(i);
            if (av != llGetOwner())
                llRegionSayTo(av, 0, NON_OWNER_AD);
            else
                llDialog(llGetOwner(), llGetScriptName() + "\n\nCopy and paste all THREE of the chosen contest patterns into a notecard and load it now.", ["OK", "Help", "Reset"], dialog_channel);
        }
    }
    
    // Handle dialog response (leave listener open)
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
        
        // Accept OK
        if (message == "OK")
            return;
            
        // Give Ann-proof instructions in local chat
        else if (message == "Help")
            llOwnerSay("Step 1 - Log in to YOUR profile page at http://2starsgames.com/frumples/pairables/UserData.php  If you've forgotten your password, you can get a new one at http://maps.secondlife.com/secondlife/Charmed%20Games/250/73/3036\n\nStep 2 - Click on the Joker Contest tab\n\nStep 3 - Select the TOP part of the page, where the patterns you are trying to match are -- start from the phrase Monthly Pattern and go all the way to the right.  Make sure you get those SP codes at the bottom!\n\nStep 4 - Copy and paste those grids into a notecard and save it -- it's okay if you don't see your grids in the notecard; I can still get them!\n\nStep 5 - Drop that notecard onto me now.");

        else if (message == "Reset")
            llResetScript();
    }
    
    changed(integer change)
    {
        // Reset if the owner changes
        if (change & CHANGED_OWNER)
            llResetScript();
            
        // Start reading any notecard we get
        if (change & CHANGED_INVENTORY)
            if (llGetInventoryNumber(INVENTORY_NOTECARD) > 0)
                state load_picked_nc;
    }
}

// Read the three chosen contest patterns
state load_picked_nc
{
    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Set the UI for work-in-progress
        ui_please_wait();
        
        // Check for a read in progress
        if (llGetInventoryType(reading_nc) == INVENTORY_NOTECARD) {
            nc_qID = llGetNotecardLine(reading_nc, ++nc_line);
            return;
        }
        
        // Clear existing storage
        picked_grids = [];
        
        // Start the read
        reading_nc = llGetInventoryName(INVENTORY_NOTECARD, 0);
        nc_line = 0;
        nc_qID = llGetNotecardLine(reading_nc, nc_line);
        llOwnerSay("Reading " + reading_nc + "; please wait...");
    }
    
    // Watch for critical changes
    changed (integer change)
    {
        if (change & CHANGED_OWNER)
            llResetScript();
            
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryType(reading_nc) != INVENTORY_NOTECARD) {
                llOwnerSay("Hey! Where'd my notecard go?!");
                state load_picked;
            }
        }
    }
    
    // Allow owner to reset / status update
    touch_start(integer num)
    {
        integer i;
        for (i=0; i<num; ++i) {
            key av = llDetectedKey(i);
            if (av != llGetOwner())
                llRegionSayTo(av, 0, NON_OWNER_AD);
            else {
                dialog_init(av);
                llDialog(av, llGetScriptName() + "\n\nI am still reading your notecard!  I know, I know, SL is a little slow here...  Just be patient, please!", ["OK", "Reset"], dialog_channel);
            }
        }
    }
    
    // Allow owner reset from dialog
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
        
        // Reset on command
        if (message == "Reset")
            llResetScript();
           
        // Close listener 
        dialog_cleanup();
    }
    
    dataserver(key query_id, string data)
    {
        // Make sure it's our notecard line
        if (query_id != nc_qID)
            return;
        
        // Watch for the end of the notecard
        if (data == EOF) {
            llRemoveInventory(reading_nc);
            if (llGetListLength(picked_grids) == 3)
                state compare;
            else
                state load_picked;
        }
            
        // Go ahead and request the next one
        nc_qID = llGetNotecardLine(reading_nc, ++nc_line);
        
        // Check for a grid
        if (llGetSubString(data, 0, 2) == "SP:") {
            integer end = llSubStringIndex(data, " ");
            integer grid = (integer)llGetSubString(data, 3, end);
            if (grid > 0)
                picked_grids += [grid];
        }
    }
    
    state_exit()
    {
        llOwnerSay((string)llGetListLength(picked_grids) + " selected contest patterns found.");
    }
        
}

// Do the actual comparison && show the results (as often as needed)
state compare
{
    // Reset if owner changes
    changed (integer change)
    {
        if (change & CHANGED_OWNER)
            llResetScript();
    }
    
    state_entry()
    {
        // Watch for role call
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        
        // Show "please wait" until done calculating
        ui_please_wait();
        dialog_init(llGetOwner());
        
        // Set a timer to watch for end of contest (ONLY if active)
        if (!is_active_contest())
            llSetTimerEvent(0.0);
        
        // Compare each selected grid to each stored grid
        integer count = llGetListLength(my_grids);
        integer i;
        for (i=0; i<3; ++i) {
            integer picked = llList2Integer(picked_grids, i);
            
            // Clear temporary storage
            integer match15 = 0;
            integer match14 = 0;
            integer match13 = 0;
            integer match12 = 0;
            integer match11 = 0;
            
            integer j;
            for (j=0; j<count; ++j) {
                integer grid = llList2Integer(my_grids, j);
                
                // Count the matches
                integer match = count_boxes(grid & picked);
                if (match == 15)
                    ++match15;
                else if (match == 14)
                    ++match14;
                else if (match == 13)
                    ++match13;
                else if (match == 12)
                    ++match12;
                else if (match == 11)
                    ++match11;
            }
            
            // Calculate a score for this selected grid
            integer score = match15 + match14 + match13 + match12 + match11;
            if (match15) score += 5;
            if (match14) score += 4;
            if (match13) score += 3;
            if (match12) score += 2;
            if (match11) score += 1;
            
            // Build the display for this grid
            string display = "\nContest Grid #" + (string)(i+1) + ":\n"
                    + single_grid(picked);
            if (match15) display += "\nMatches 15 with " 
                    + (string)match15 + " of your grids";
            if (match14) display += "\nMatches 14 with " 
                    + (string)match14 + " of your grids";
            if (match13) display += "\nMatches 13 with "
                    + (string)match13 + " of your grids";
            if (match12) display += "\nMatches 12 with "
                    + (string)match12 + " of your grids";
            if (match11) display += "\nMatches 11 with "
                    + (string)match11 + " of your grids";
            display += "\n";
            
            // Compare to the best found score
            if (score > best_score) {
                best_index = i + 1;
                best_score = score;
                best_display = display;
            }
            
            total_display += display;
        }
        
        // Go ahead and print the results
        ui_done();
        if (best_score)
            llOwnerSay("Your best match is:\n" + best_display);
        else
            llOwnerSay("I'm sorry!  You don't have any good matches this month.  :(  Don't select a grid, and perhaps you can try again next month!");
    }
    
    touch_start(integer num)
    {
        integer i;
        for (i=0; i<num; ++i) {
            key av = llDetectedKey(i);
            if (av != llGetOwner())
                llRegionSayTo(av, 0, NON_OWNER_AD);
            else if (best_score == 0)
                llDialog(av, llGetScriptName() + "\n\nI'm sorry! You don't have a winning game this month.  :(  Don't select a grid, and perhaps you can try again next month!", ["Done"], dialog_channel);
            else
                llDialog(av, llGetScriptName() + "\n\nYour best match is grid #" + (string)(best_index) + ":\n\n" + single_grid(llList2Integer(picked_grids, best_index-1)), ["Show Best", "Show All", "Done"], dialog_channel);
        }
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
        
        // Handle menu
        if (message == "Done")
            llResetScript();
            
        else if (message == "Show Best")
            llOwnerSay("Your best match is:\n" + best_display);
            
        else if (message == "Show All")
            llOwnerSay(total_display);
    }
    
    timer()
    {
        // Back to WAITING when contest ends
        if (!is_active_contest())
            state default;
    }
    
    state_exit()
    { llSetTimerEvent(0.0); }
} 