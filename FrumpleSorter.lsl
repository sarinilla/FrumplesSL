// As far as I know, I was the only one using this particular
// script, so it never reached the maturity level it might have.
// Nonetheless, if you find inspiration or help within, then
// help yourself.  ;)
//
// Author: Rini Rampal
// Written 2013
// Released under MIT License
// https://github.com/SariniLynn/FrumplesSL


// Scan and report on the owner's local frumples
//
// Change Log:
//   1.1  Fix minor sorting errors w/alphabetizing

float DELAY = 1.0;      // number of seconds to wait between

list found_frumples;    // full STATUS messages, to decode later
list sortable_frumples; // custom details, according to sort


// *************************  FRUMPLE API  ************************

integer to_frumple_channel = -853321960;
integer from_frumple_channel = -853321961;

string request_pair = "SAY_PAIR_STATUS_DATA";
string request_sale = "SAY_SELL_STATUS_DATA";
string request_all  = "SAY_STATUS_DATA";

sim_request(string request, key avatar, integer level)
{
    string text = request + "," + (string)avatar;
    if (level) text += "," + (string)level;
    llRegionSay(to_frumple_channel, text);
}


// ************************  ROLE CALL API  ***********************

// ROLE CALL: "Hey, who's out there?!" on 2847291301
integer role_call_channel = 2847291301;
string role_call_message = "Hey, who's out there?!";
// EVERYBODY: "HNE Frumpler", <base script name>, <version>, <owner key> on 938110239
integer role_call_response_channel = 938110239;
string role_call_response = "HNE Frumpler";


// *************************  UPDATE API  ************************

// Updater: "Frumple Sortin' University!" on 57824012
integer update_channel = 57824012;
string update_announcement = "Frumple Sortin' University!";
// Sorter:  <set pin to 23948>
integer pin = 23948;
// Sorter:  "You know the code, prof." on 39487213
integer response_channel = 39487213;
string update_response = "You know the code, prof.";
// Updater: <load cleaner script & new scripts as needed>


// ***********************  GRID PROCESSING  **********************

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

// Find the number of the next meal to eat
integer next_meal(integer current, integer known)
{
    // Look for first un-eaten favorite
    integer remaining = current ^ known;
    integer meal = (integer)llPow(2.0, 5) - 1;  // 5 1s in binary
    integer i;
    for (i=0; i<5; ++i) {
        if (remaining & meal) return i + 1;
        meal = meal << 5;
    }
    
    // If that fails, look for last eaten favorite
    for (i=5; i>0; --i) {
        meal = meal >> 5;
        if (current & meal) return i + 1;
    }
    
    // If all else fails, note the error
    return 0;
}


// *************************  GRID OUTPUT  ************************

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


// ***********************  MENUS & FILTERS  **********************

integer dialog_channel;

string looking_for_status;
integer looking_for_detail;
integer display_detail;
integer GRIDS = 16;

main_menu()
{
    llDialog(llGetOwner(), llGetScriptName() + "\n\nWhich local frumples would you like to view?", 
             ["Upcoming", "All Grids", "One Grid",
              "Pairing", "Fertilizing", "Feeding"], dialog_channel);
}

menu_response(string message)
{
    looking_for_status = "";
    looking_for_detail = 0;
    display_detail = 0;
    key search_key = llGetOwner();
    if (message == "Pairing" || message == "Fertilizing" 
                             || message == "Feeding")
        looking_for_status = message;
    else if (message == "Upcoming") {
        looking_for_status = "Feeding";
        looking_for_detail = 5;
    }
    else if (message == "All Grids") {
        display_detail = GRIDS;
    }
    else if (message == "One Grid") {
        llTextBox(llGetOwner(), llGetScriptName() + "\n\nEnter the ID of the frumple whose grid you'd like to view:", dialog_channel);
        return;
    }
    else {  // frumple ID
        looking_for_detail = (integer)message;
        search_key = NULL_KEY;
        display_detail = GRIDS;
    }
    
    found_frumples = [];
    sim_request(request_all, search_key, 0);
    llOwnerSay("Browsing local frumples...");
    llSetTimerEvent(DELAY);
}

integer filter_frumple(string detail)
{        
    // Parse & sanity check
    llSetTimerEvent(DELAY);
    list data = llParseStringKeepNulls(detail, ["\n"], []);
    if (llList2String(data, 0) != "STATUS") return FALSE;
    if (llList2String(data, 1) == "") return FALSE;
    
    // Filter by status
    if (looking_for_status)
        if (llList2String(data, 6) != looking_for_status)
            return FALSE;
    
    // Filter detail
    if (looking_for_detail) {
        // Next meal number
        if (looking_for_status == "Feeding") {
            integer current = llList2Integer(data, 7);
            integer known = llList2Integer(data, 8);
            if (next_meal(current, known) != looking_for_detail)
                return FALSE;
        }
        // Frumple ID
        else if (llList2Integer(data, 1) != looking_for_detail)
            return FALSE;
    }
    
    return TRUE;
}


//

show_grid(string object_name, string data_str)
{
    list data = llParseStringKeepNulls(data_str, ["\n"], []);
    
    // Frumple "name": Valentine Frumple@101545@23: Suzey
    string name = llList2String(data, 4);
    if (name == "") name = llList2String(data, 2);
    string output = object_name + ": " + name + "\n";
    
    // Type & level
    output += llList2String(data, 2) + " - Level " 
                + llList2String(data, 3) + "\n";
        
    // Time Remaining
    string status = llList2String(data, 6);
    if (status == "Pairing")
        output += "Pairing Time Left - " 
                + (string)(llList2Integer(data, 10) / 60) + "\n";
    else if (status == "Fertilizing")
        output += "Fertilization Time Left - " 
                + (string)(llList2Integer(data, 11) / 60) + "\n";
    else if (status == "Feeding") {
        integer seconds = llList2Integer(data, 9);
        if (seconds > 0) {
            integer current = llList2Integer(data, 7);
            integer known = llList2Integer(data, 8);
            output += "Next Meal - " + (string)next_meal(current, known) 
                     + "\nTime Left - "
                     + (string)(seconds / 60) + "\n";
        }
        else output += "Time Undefined\n";
    }
    else {
        output += "Status - " + status + "\n";
    }
        
    // Grid
    output += single_grid(llList2Integer(data, 8));
    
    // Egg Count
    output += "Eggs Remaining - " + llList2String(data, 12)
            + "(" + llList2String(data, 13) + ")\n\n";
    
    llOwnerSay(output);
}

show_text_frumples(integer count)
{
    
    // Print details on each frumple
    string last_status;
    integer i;
    for (i=0; i<count; ++i) {
        string data_str = llList2String(sortable_frumples, i);
        list data = llParseStringKeepNulls(data_str, ["\n"], []);
        string status = llList2String(data, 0);
        
        // Status header
        if (status != last_status) {
            llOwnerSay("-----  " + status + "  -----");
            last_status = status;
        }
        
        // Fertilizing
        if (status == "Fertilizing") {
            integer seconds = llList2Integer(data, 1);
            integer egg_no = 6 - llList2Integer(data, 2);
            float hours = seconds / 3600.0;
            string name = llList2String(data, 3);
            
            llOwnerSay(name + ": " + (string)hours + " hours remaining for egg #" + (string)egg_no);
        }
        
        // Pairing
        else if (status == "Pairing") {
            integer found = llList2Integer(data, 1);
            integer seconds = llList2Integer(data, 2);
            integer egg_no = 6 - llList2Integer(data, 3);
            float hours = seconds / 3600.0;
            string name = llList2String(data, 4);
            
            llOwnerSay(name + ": " + (string)hours + " hours remaining for egg #" + (string)egg_no + " (" + (string)found + " found)");
        }
        
        // Feeding
        else if (status == "Feeding") {
            integer meal_no = llList2Integer(data, 1);
            integer found = llList2Integer(data, 2);
            integer seconds = llList2Integer(data, 3);
            integer egg_no = 6 - llList2Integer(data, 4);
            float hours = seconds / 3600.0;
            string name = llList2String(data, 5);
            
            llOwnerSay(name + ": " + (string)found + " foods found; on meal " + (string)meal_no + " with " + (string)hours + " hours remaining for egg #" + (string)egg_no + ".");
        }
    }
}
    


// ***************************  STATES  ***************************

default
{
    state_entry()
    {
        llSetTexture("f1d4041f-e858-95b5-c46b-e79dcf5c541e", ALL_SIDES);
        dialog_channel = -2000000000 + (integer)llFrand(1000000000.0);
        llListen(dialog_channel, "", llGetOwner(), "");
        llListen(from_frumple_channel, "", NULL_KEY, "");
        llListen(update_channel, "", NULL_KEY, update_announcement);
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        llOwnerSay("Touch me to sort your local frumples!");
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
            llResetScript();
    }
    
    on_rez(integer start_param)
    {
        llOwnerSay("Touch me to sort your local frumples!");
    }

    touch_start(integer total_number)
    {
        main_menu();
    }
    
    listen(integer channel, string name, key id, string message)
    {
        // Handle updates
        if (channel == update_channel) {
            if (llGetOwnerKey(id) != llGetOwner()) return;
            llSetRemoteScriptAccessPin(pin);
            llRegionSayTo(id, response_channel, update_response);
        }
        
        // Respond to role call
        else if (channel == role_call_channel) {
            string name = llGetScriptName();
            llRegionSayTo(id, role_call_response_channel,
                          llList2CSV([role_call_response,
                                      llGetSubString(name, 0, -6),
                                      llGetSubString(name, -3, -1),
                                      llGetOwner()]));
        }
        
        // Handle dialog box
        else if (channel == dialog_channel)
            menu_response(message);
        
        // Filter & store frumple responses
        else if (channel == from_frumple_channel) {
            if (filter_frumple(message)) {
                if (display_detail == GRIDS)
                    show_grid(name, message);
                else
                found_frumples += [message];
            }
        }
    }
    
    timer()
    {
        llSetTimerEvent(0.0);
        
        // Grids printed as they're found
        if (display_detail == GRIDS)
            return;
        
        // None found?
        if (found_frumples == []) {
            llOwnerSay("No local frumples found.");
            return;
        }
        
        // Re-organize data for easy sorting
        sortable_frumples = [];
        integer count = llGetListLength(found_frumples);
        integer i;
        for (i=0; i<count; ++i) {
        
            // Gather basic data
            string data_str = llList2String(found_frumples, i);
            list data = llParseStringKeepNulls(data_str, ["\n"], []);
            string status = llList2String(data, 6);
            string name = llList2String(data, 4);
            if (name == "")
                name = llList2String(data, 2); // type
            name += " (" + llList2String(data, 1) + ")";  // ID
            
            // Store info by state, in sortable order
            list storage = [];
            if (status == "Fertilizing") {
                integer time = llList2Integer(data, 11);
                string time_str = (string)time;
                if (time < 1000) time_str = "0" + time_str;
                if (time < 100)  time_str = "0" + time_str;
                if (time < 10)   time_str = "0" + time_str;
                storage += [status,
                            time_str,                   // sec remaining
                            llList2Integer(data, 12),   // eggs remaining
                            name];
            }
            else if (status == "Pairing") {
                integer grid = llList2Integer(data, 7);
                integer found = count_boxes(grid);
                string found_str = (string)found;
                if (found < 10) found_str = "0" + found_str;
                storage += [status,
                            found_str,                  // num found (w/0)
                            llList2Integer(data, 10),   // sec remaining
                            llList2Integer(data, 12),   // eggs remaining
                            name];
            }
            else if (status == "Feeding") {
                integer current = llList2Integer(data, 7);
                integer known = llList2Integer(data, 8);
                integer found = count_boxes(known);
                string found_str = (string)found;
                if (found < 10) found_str = "0" + found_str;
                storage += [status,
                            next_meal(current, known),  // next meal #
                            found_str,                  // num found (w/0)
                            llList2Integer(data,  9),   // sec remaining
                            llList2Integer(data, 12),   // eggs remaining
                            name];
            }
            sortable_frumples += [llDumpList2String(storage, "\n")];
        }
        found_frumples = [];
        
        // Sort frumples accordingly
        sortable_frumples = llListSort(sortable_frumples, 1, FALSE);
        
        // Show requested display
        show_text_frumples(count);
        sortable_frumples = [];
    }
        
}
