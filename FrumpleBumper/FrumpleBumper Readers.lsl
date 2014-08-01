// Handles reading notecards and scanning local frumples
//
// Change Log:
//   1.4  Self-pairing options
//   1.5  Full support for Cupido export
//   1.6  No update.

float SCAN_TIME = 2.5;  // seconds to wait between responses

// ********************  SCRIPT COMMUNICATION  ********************

integer MATCH_GRID    = 0713200308;  // GMTCH ++
    // string == "\n"[grid, ID, name, type, level, pairing_time, owner_key]
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR]
integer STORE_MY_GRID =   07192018;  //  GSTR ++
    // string == "\n"[grid, ID, name, type, level, pairing_time]
integer READ_NOTECARD =   18050104;  //  READ
    // string == notecard name
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER, mine]
    // -READ_NOTECARD when the read is complete
    //    string == number read
    //    key parroted
integer SCAN_LOCAL    =   19030114;  //  SCAN
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER, mine]
    // -SCAN_LOCAL when the scan is complete
    //    string == number found
    //    key parroted
integer READ_PASTED   = 1601192005;  // PASTE
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER, FALSE]   // never mine
    // -READ_PASTED when the read is complete
    //    string == number read
    //    key parroted


// **************************  STORAGE  ***************************

// Notecard reading
key qID;                 // dataserver query ID for notecard read
string loading_nc;       // current notecard being read
integer nc_line;         // current line being read from notecard

// Temporary storage from the request
string SETTINGS;         // CSV[THRESHOLD, AUTO, SELF_PAIR]
integer MINE;            // TRUE if we should store the grid

// Current frumple being scanned/read
integer grid_count;      // number of grids read in this request
key owner_key;           // owner of the current grid's frumple
integer partial_grid;    // current grid pattern being read
string  frumple_ID;      // expected ID of current grid's frumple
string  frumple_name;    // expected name of current grid's frumple
string  frumple_type;    // expected type of current grid's frumple
string  frumple_level;   // expected level of current grid's frumple
string  frumple_time;    // expected pairing time remaining

// Clear all data on the current frumple being read
clear_frumple()
{
    partial_grid = 0;
    frumple_ID = "??????";
    frumple_name = "";
    frumple_type = "Unknown";
    frumple_level = "?";
    frumple_time = "????";
}


// *************************  FRUMPLE API  ************************

integer to_frumple_channel = -853321960;
integer from_frumple_channel = -853321961;

string request_pair = "SAY_PAIR_STATUS_DATA";
string request_sale = "SAY_SELL_STATUS_DATA";
string request_all  = "SAY_STATUS_DATA";

// Ask for all pairable frumples for the given avatar / min level
sim_request(string request, key avatar, integer level)
{
    string text = request + "," + (string)avatar;
    if (level) text += "," + (string)level;
    llRegionSay(to_frumple_channel, text);
}


// *************************  FUNCTIONS  **************************

// Start a session with the given settings
start_session(key settings_given)
{
    // Clear storage
    grid_count = 0;
    clear_frumple();
    
    // Parse settings
    list settings = llCSV2List((string)settings_given);
    SETTINGS = llList2CSV(llList2List(settings, 0, -2)); // all but MINE
    MINE = llList2Integer(settings, -1);
}    

// Handle the stored frumple
finish_frumple()
{
    // Count the number of grids found
    ++grid_count;
    
    // Send the grid to be matched
    string data = llDumpList2String([partial_grid, frumple_ID,
        frumple_name, frumple_type, frumple_level, frumple_time,
        owner_key], "\n");
    llMessageLinked(LINK_SET, MATCH_GRID, data, SETTINGS);

    // Send the grid for storage
    if (MINE) {
        string data = llDumpList2String([partial_grid, frumple_ID,
            frumple_name, frumple_type, frumple_level, frumple_time],
            "\n");
        llMessageLinked(LINK_SET, STORE_MY_GRID, data, NULL_KEY);
    }
    
    // Reset storage for the next read/scan
    clear_frumple();
}


// ************************  GRID PARSING  ************************

// Try to find a frumple name or other identifier in the string
//   save to frumple_name if found
parse_detail(string line)
{
    // [09:01] Spain Frumple@84353@23: Matador
    integer index = llSubStringIndex(line, " Frumple@");
    if (index != -1) {

        // Get type
        integer bracket = llSubStringIndex(line, "]");
        frumple_type = llGetSubString(line, bracket + 1, index - 1);
        while (llGetSubString(frumple_type, 0, 0) == " ")
            frumple_type = llGetSubString(frumple_type, 1, -1);
        if (llGetSubString(frumple_type, 0, 5) == "LIARS ")
            frumple_type = llGetSubString(frumple_type, 6, -1);
        line = llGetSubString(line, index + 9, -1);

        // Get ID
        index = llSubStringIndex(line, "@");
        frumple_ID = llGetSubString(line, 0, index - 1);
        
        // Get name (or type repeats w/ level)
        index = llSubStringIndex(line, ":");
        if (index > -1)
            frumple_name = llGetSubString(line, index + 2, -1);
                    
        // Remove " - Level" from type
        index = llSubStringIndex(frumple_name, " - Level ");
        if (index != -1) {
            frumple_level = llGetSubString(frumple_name, index + 9, -1);
            frumple_name = llGetSubString(frumple_name, 0, index - 1);
        }
                    
        // Remove " - Base" from type
        index = llSubStringIndex(frumple_name, " - Base");
        if (index != -1) {
            frumple_level = "0";
            frumple_name = llGetSubString(frumple_name, 0, index - 1);
        }
        
        // Don't duplicate type as name
        if (frumple_name == frumple_type)
            frumple_name = "";
        return;
    }
            
    // Sudan - Level 3
    index = llSubStringIndex(line, " - Level ");
    if (index != -1) {
        frumple_level = llGetSubString(frumple_name, index + 9, -1);
        frumple_type = llGetSubString(line, 0, index - 1);
        return;
    }
    
    // Party - Base
    index = llSubStringIndex(line, " - Base");
    if (index != -1) {
        frumple_level = "0";
        frumple_type = llGetSubString(line, 0, index - 1);
    }
     
    // Cupido listings
    if (llGetSubString(line, 0, 2) == "ID ")
        frumple_ID = llGetSubString(line, 3, -1);
    else if (llGetSubString(line, 0, 4) == "Name ")
        frumple_name = llGetSubString(line, 5, -1);
    else if (llGetSubString(line, 0, 4) == "Type ")
        frumple_type = llGetSubString(line, 5, -1);

    // Pairing Time Left - 1234
    if (llGetSubString(line, 0, 19) == "Pairing Time Left - ") {
        frumple_time = llGetSubString(line, 20, -1);
        return;
    }
    
    // grid #1 - Charity(100848):
    if ((integer)frumple_ID) return;
    index = llSubStringIndex(line, "grid #");
    if (index != -1) {
        line = llGetSubString(line, index + 6, -1);
        index = llSubStringIndex(line, " - ");
        if (index != -1)
            frumple_name = llGetSubString(line, index + 3, -2);
    }
}

// Determine if this line is the first row of a grid
integer starts_grid(string line)
{ return ("1 - " == llGetSubString(line, 0, 3)); }

// Determine if this line is the last row of a grid
integer ends_grid(string line)
{ return ("5 - " == llGetSubString(line, 0, 3)); }

// Determine if this character is a box in a grid
integer is_box(string box)
{ return (box == "■" || box == "□"); }

// Determine if this line is part of a grid
integer is_grid(string line)
{
    if (llGetSubString(line, 1, 3) != " - ")
        return FALSE;
    integer line_no = (integer)llGetSubString(line, 0, 0);
    if (line_no < 1 || line_no > 5)
        return FALSE;
    return TRUE;
}

// Turn ? into False and ¦ into True
integer parse_grid_box(string box)
{ return box == "■"; }

// Parse a single grid line into a 5-bit integer
integer parse_grid_line(string line)
{
    return  parse_grid_box(llGetSubString(line, 4, 4))
         + (parse_grid_box(llGetSubString(line, 5, 5)) << 1)
         + (parse_grid_box(llGetSubString(line, 6, 6)) << 2)
         + (parse_grid_box(llGetSubString(line, 7, 7)) << 3)
         + (parse_grid_box(llGetSubString(line, 8, 8)) << 4);
}

// Parse a single grid line into a 25-bit integer to combine
integer parse_partial_grid(string line)
{
    integer line_no = (integer)llGetSubString(line, 0, 0);
    return parse_grid_line(line) << ((line_no - 1) * 5);
}

// Parse the grid into a 25-bit integer
integer parse_grid(list lines)
{
    return  parse_grid_line(llList2String(lines, 0))
         + (parse_grid_line(llList2String(lines, 1)) <<  5)
         + (parse_grid_line(llList2String(lines, 2)) << 10)
         + (parse_grid_line(llList2String(lines, 3)) << 15)
         + (parse_grid_line(llList2String(lines, 4)) << 20);
}


// ***************************  STATES  ***************************

default
{
    state_entry()
    {
    }

    link_message(integer sender, integer num, string str, key id)
    {
        // Start a scan for local frumples (mine or theirs)
        if (num == SCAN_LOCAL) {
            start_session(id);
            llListen(from_frumple_channel, "", NULL_KEY, "");
            if (MINE)
                sim_request(request_pair, llGetOwner(), 0);
            else
                sim_request(request_pair, NULL_KEY, 0);
            llSetTimerEvent(SCAN_TIME);
        }
        
        // Start reading a notecard (mine or theirs)
        else if (num == READ_NOTECARD) {
            start_session(id);
            loading_nc = str;
            nc_line = 0;
            owner_key = llGetInventoryCreator(loading_nc);
            qID = llGetNotecardLine(loading_nc, nc_line);
        }
        
        // Parse a pasted grid (always theirs)
        else if (num == READ_PASTED) {
            start_session(id);
            owner_key = NULL_KEY;
            
            // Allow multiple grids
            integer i = 0;
            while (TRUE) {
                clear_frumple();
                        
                // Find grid
                integer index = llSubStringIndex(str, "1 - ");
                if (index == -1) {
                    llMessageLinked(LINK_SET, -READ_PASTED, 
                                    (string)grid_count, 
                                    llList2CSV([SETTINGS, MINE]));
                    return;
                }
                
                // Parse name
                list header = llParseString2List(llGetSubString(str, 
0, index - 1), ["\n"], []);
                integer j;
                integer count = llGetListLength(header);
                for (j=0; j<count; ++j)
                    parse_detail(llList2String(header, j));
                if (frumple_ID == "??????") frumple_ID = "(Pasted)";
                
                // Parse grid
                string grid = llGetSubString(str, index, -1);
                list grid_lines = llParseString2List(grid, ["\n"], []);
                partial_grid = parse_grid(grid_lines);
                finish_frumple();
                
                // Look for next grid
                str = llGetSubString(str, index + 25, -1);
            }
            // cannot get here!!
        }
    }
    
    // Handle scan response
    listen(integer channel, string name, key id, string message)
    {
        llSetTimerEvent(SCAN_TIME);
        list data = llParseStringKeepNulls(message, ["\n"], []);
        
        // Verify response (sanity check)
        if (llList2String(data, 0) != "PAIR_STATUS") return;
        
        // Gather data
        frumple_ID = llList2String(data, 1);
        frumple_type = llList2String(data, 2);
        frumple_level = llList2String(data, 3);
        frumple_name = llList2String(data, 4);
        owner_key = llList2Key(data, 5);
        partial_grid = llList2Integer(data, 7);
        frumple_time = (string)(llList2Integer(data, 8) / 60);
        
        // Verify data (sanity check)
        if (frumple_ID == "") return;
        
        // Matchmake and/or store it
        finish_frumple();
    }
    
    // Finish scan when no more responses
    timer()
    {
        llSetTimerEvent(0.0);
        llMessageLinked(LINK_SET, -SCAN_LOCAL, 
                        (string)grid_count, 
                        llList2CSV([SETTINGS, MINE]));
    }
    
    // Handle line of notecard
    dataserver(key query_id, string data)
    {
        // Verify this is our notecard line
        if (query_id != qID) return;
        
        // Watch for the end of the notecard
        if (data == EOF) {
            llMessageLinked(LINK_SET, -READ_NOTECARD, 
                            (string)grid_count, 
                            llList2CSV([SETTINGS, MINE]));
            return;
        }

        // Go ahead and request the next bit.
        ++nc_line;
        qID = llGetNotecardLine(loading_nc, nc_line);
        
        // Skip to the grid, picking up details along the way
        if (!is_grid(data)) {
            parse_detail(data);  // stored to frumple_* if found
            return;
        }
            
        // Parse grid into partial
        partial_grid += parse_partial_grid(data);
        
        // Save when complete
        if (ends_grid(data))
            finish_frumple();
    }
}
