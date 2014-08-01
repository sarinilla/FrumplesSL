// Store owner's grids and match on command
//
// Extensible for memory reasons, simply by adding more copies
//
// Change History:
//   1.3  Self-pairing update (no matches <= found - 4)
//   1.4  Implement self-pairing options,
//        show perfect matches to my grids even below threshold
//   1.5  Don't show "perfect" matches of 0.  :p
//   1.6  Optional perfect matches,
//        check for magic number

integer BUFFER = 4000;  // number of bytes to leave for processing
integer SELF_PAIR_SIZE = 4;  // number reduced from found on self-pair


// ********************  SCRIPT COMMUNICATION  ********************

// Self-pairing options
integer SELF_PAIR_SHOW_ALL  = 0;  // show all matches
integer SELF_PAIR_SHOW_SOME = 1;  // show only == and >= matches
integer SELF_PAIR_SHOW_NONE = 2;  // hide all matches <= self-pair

// Link messages
integer STORE_MY_GRID =   07192018;  //  GSTR ++
    // string == "\n"[grid, ID, name, type, level, pairing_time]
integer PRINT_GRID    = 0716181420;  // GPRNT
    // string == "\n"[grid, ID, name, type, level, pairing_time]
integer PRINT_ALL     =   16011212;  // PALL ++
integer MATCH_GRID    = 0713200308;  // GMTCH ++
    // string == "\n"[grid, ID, name, type, level, pairing_time, owner_key]
    // key == CSV[THRESHOLD, AUTO, SELF_PAIR]
integer MATCH_FOUND   = 0615211404;  // FOUND
    // string == "\n"[2-digit score, 
    //                MY:    grid, ID, name, type, level, pairing_time,
    //                THEIR: grid, ID, name, type, level, pairing_time,
    //                         owner_name, owner_key]
    // key == CSV[AUTO]



// ***************************  STORAGE  **************************

// Actual grid storage
list grids_only;    // Grid integers only, for easy matching
list grids_data;    // Suitable for PRINT_GRID / MATCH_FOUND

// Temporary storage
list requests;      // Player name requests
key last_key;       // Last player name request
string last_name;   // Last player name request
key AUTO;           // Saved over for database MATCH_FOUND

// Check for additional storage
integer order = 0;  // my number in the storage chain
integer check_more_storage = FALSE;  // already checked?


// ***********************  GRID COMPARISON  **********************

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

// Determine the number of matches for a specific pairing
integer score_match(integer frumple1, integer frumple2)
{
    return count_boxes(frumple1 & frumple2);
}

// Determine the match expected from self-pairing
integer self_pair(integer frumple)
{
    return count_boxes(frumple) - SELF_PAIR_SIZE;
}

// Determine the minimum match required to outperform self-pairs
integer minimum_match(integer frumple1, integer frumple2, integer self_pair)
{
    // Skip self-pairing check on request
    if (self_pair == SELF_PAIR_SHOW_ALL) return 0;
    
    // Don't ever show where both can self-pair for the same
    integer self1 = self_pair(frumple1);
    integer self2 = self_pair(frumple2);
    if (self1 == self2)
        return self1 + 1;
        
    // Find the highest match threshold
    if (self1 < self2)
        self1 = self2;
        
    // We need to either meet or beat it
    if (self_pair == SELF_PAIR_SHOW_NONE)
        return self1 + 1;
    else
        return self1;
}

grid_compare(integer grid, integer my_grid, string data, string my_data,
             integer threshold, integer auto, integer self_pair, integer show_perfect,
             integer magic_number)
{
    // Skip duplicates
    if (grid == my_grid) {
        list d = llParseStringKeepNulls(data, ["\n"], []);
        integer ID = llList2Integer(d, 1);
        if (ID > 0) {
            list md = llParseStringKeepNulls(my_data, ["\n"], []);
            integer my_ID = llList2Integer(md, 1);
            if (ID == my_ID)
                return;
        }
    }
    
    // Check level?
    if (magic_number) {
        list d = llParseStringKeepNulls(data, ["\n"], []);
        integer level = llList2Integer(d, 4);
        if (magic_number - level > 10)
            return;
        list md = llParseStringKeepNulls(my_data, ["\n"], []);
        integer my_level = llList2Integer(md, 4);
        if (level + my_level != magic_number)
            return;
    }    

    // Match found?
    integer score = score_match(grid, my_grid);
    if (score == 0) return;
    if (score < threshold)
        if (!show_perfect || score < count_boxes(my_grid))
            return;
        
    // Check against self-pairing
    if (score < minimum_match(grid, my_grid, self_pair))
        return;
        
    // Parse match detail
    list d = llParseStringKeepNulls(data, ["\n"], []);
    key their_owner_key = llList2Key(d, -1);
    
    // Build MATCH_FOUND message (sans owner name)
    string match = llDumpList2String(
        [score, my_data, data], "\n");
    if (score < 10) match = "0" + match;

    // Try to find owner name
    string name = llKey2Name(their_owner_key);
    if (their_owner_key == last_key)
        name = last_name;
    else if (their_owner_key == NULL_KEY)
        name = "Unknown Owner";

    // Request name if not found
    if (name == "") {
        requests += [llRequestAgentData(their_owner_key,
            DATA_NAME), match];
        AUTO = (key)((string)auto);
        return;
    }

    // Report match
    //match = llInsertString(match, -36, name + "\n");
    list temp = llParseStringKeepNulls(match, ["\n"], []);
    temp = llListInsertList(temp, [name], -1);
    match = llDumpList2String(temp, "\n");
    llMessageLinked(LINK_SET, MATCH_FOUND, match, (key)((string)auto));
    // string == "\n"[2-digit score,
    //                MY:    grid, ID, name, type, level, pairing_time,
    //                THEIR: grid, ID, name, type, level, pairing_time,
    //                         owner_name, owner_key]
}


// ***************************  STATES  ***************************

default
{
    state_entry()
    {
        // Determine my link order
        string name = llGetScriptName();
        order = 0;
        if (llGetSubString(name, -2, -2) == " ")
            order = (integer)llGetSubString(name, -1, -1);
        else if (llGetSubString(name, -3, -3) == " ")
            order = (integer)llGetSubString(name, -2, -1);

        // Look for my own targeted link messages
        STORE_MY_GRID += order;
        MATCH_GRID += order;
        PRINT_ALL += order;
    }

    link_message(integer sender, integer num, string str, key id)
    {
        // New owner grid to store
        if (num == STORE_MY_GRID) {
            // string == "\n"[grid, ID, name, type, level, pairing_time]
            
            // Check for duplicate
            integer index = llListFindList(grids_data, [str]);
            if (index != -1)
                return;

            // Offload if full
            if (llGetFreeMemory() <= BUFFER) {
                // Check for next script
                if (!check_more_storage) {
                    string base_script = llGetScriptName();
                    if (order == 0) {}
                    else if (order < 10)
                        base_script = llGetSubString(base_script, 0, -3);
                    else
                        base_script = llGetSubString(base_script, 0, -4);
                    string next = base_script + " " + (string)(order+1);
                    if (llGetInventoryType(next) != INVENTORY_SCRIPT) {
                        llOwnerSay("Uh-oh!  I ran out of storage for your frumples!  Here, drop this script on me and then try again!");
                        llGiveInventory(llGetOwner(), base_script);
                    }
                    check_more_storage = TRUE;
                }
                
                // Send it on
                llMessageLinked(LINK_THIS, num + 1, str, id);
                return;
            }

            // Parse out grid pattern for easy matching
            list data = llParseStringKeepNulls(str, ["\n"], []);
            grids_only += [llList2Integer(data, 0)];
            grids_data += [str];
        }

        // Match against all stored grids
        else if (num == MATCH_GRID) {
            // string == "\n"[grid, ID, name, type, level, pairing_time, owner_key]
            // key == CSV[THRESHOLD, AUTO, SELF_PAIR, SHOW_PERFECT, MAGIC_NUMBER]

            // Parse out grid
            list data = llParseStringKeepNulls(str, ["\n"], []);
            integer grid = llList2Integer(data, 0);

            // Parse out match threshold
            list settings = llCSV2List((string)id);
            integer threshold = llList2Integer(settings, 0);
            integer auto = llList2Integer(settings, 1);
            integer self_pair = llList2Integer(settings, 2);
            integer show_perfect = llList2Integer(settings, 3);
            integer magic_number = llList2Integer(settings, 4);

            // Look for matches
            integer count = llGetListLength(grids_only);
            integer i;
            for (i=0; i<count; ++i) {
                integer my_grid = llList2Integer(grids_only, i);
                string my_data = llList2String(grids_data, i);
                grid_compare(grid, my_grid, str, my_data, 
                             threshold, auto, self_pair, 
                             show_perfect, magic_number);
            }

            // Pass along
            llMessageLinked(LINK_THIS, num + 1, str, id);
        }

        // Print all stored grids
        else if (num == PRINT_ALL) {
            integer count = llGetListLength(grids_data);
            integer i;
            for (i=0; i<count; ++i) {
                llMessageLinked(LINK_SET, PRINT_GRID,
                    llList2String(grids_data, i), NULL_KEY);
                llSleep(0.1); // let it keep up!
            }

            // Pass along
            llMessageLinked(LINK_THIS, num + 1, str, id);
        }
    }

    dataserver(key requested, string data)
    {
        // Locate match for this request
        integer index = llListFindList(requests, [requested]);
        if (index == -1) return;
        string match = llList2String(requests, index + 1);

        // Report match
        //match = llInsertString(match, -36, data + "\n");
        list temp = llParseStringKeepNulls(match, ["\n"], []);
        temp = llListInsertList(temp, [data], -1);
        match = llDumpList2String(temp, "\n");
        llMessageLinked(LINK_SET, MATCH_FOUND, match, AUTO);

        // Save last request
        if (data != last_name) {
            last_key = (key)llGetSubString(match, -36, -1);
            last_name = data;
        }

        // Remove request
        requests = llDeleteSubList(requests, index, index + 1);
    }
}