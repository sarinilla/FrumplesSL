// Match storage, sorting, and printing.  Also handles requests to
// print a single grid on demand.

//   1.4  No change
//   1.6  Singularity-safe output (no, really!)


integer MAX_STORED = 50;

// ********************  SCRIPT COMMUNICATION  ********************

integer PRINT_GRID    = 0716181420;  // GPRNT
    // string == "\n"[grid, ID, name, type, level, pairing_time]
integer MATCH_FOUND   = 0615211404;  // FOUND
    // string == "\n"[2-digit score, 
    //                MY:    grid, ID, name, type, level, pairing_time,
    //                THEIR: grid, ID, name, type, level, pairing_time,
    //                         owner_name, owner_key]
    // key == CSV[AUTO]
integer PRINT_MATCHES = 1613200308;  // PMTCH
integer CLEAR_MATCHES = 0313200308;  // CMTCH


// ***************************  STORAGE  **************************

list matches_found;
    // "\n"[2-digit score, 
    //      MY:    grid, name, type, level, pairing_time,
    //      THEIR: grid, name, type, level, pairing_time,
    //               owner_name, owner_key]
string owner_name;


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

// Print two grids side-by-side
string double_grid(integer grid1, integer grid2)
{

    return convert_line(grid1, 1) + "\t"
         + convert_line(grid2, 1) + "\n"
         + convert_line(grid1 >>  5, 2) + "\t"
         + convert_line(grid2 >>  5, 2) + "\n"
         + convert_line(grid1 >> 10, 3) + "\t"
         + convert_line(grid2 >> 10, 3) + "\n"
         + convert_line(grid1 >> 15, 4) + "\t"
         + convert_line(grid2 >> 15, 4) + "\n"
         + convert_line(grid1 >> 20, 5) + "\t"
         + convert_line(grid2 >> 20, 5);
}

// ************************  PRINT FORMATS  ***********************

// Re-readable single grid listing
print_grid(string data_str)
{
    // data_str == "\n"[grid, ID, name, type, level, pairing_time]
    list data = llParseStringKeepNulls(data_str, ["\n"], []);
    integer grid = llList2Integer(data, 0);
    string ID = llList2String(data, 1);
    string name = llList2String(data, 2);
    string type = llList2String(data, 3);
    string level = llList2String(data, 4);
    integer minutes = llList2Integer(data, 5);

    // Frumple "name": Valentine Frumple@101545@: Suzey
    string output = type + " Frumple@" + ID + "@??: ";
    if (name == "") output += type;
    else output += name;
    output += "\n";

    // Type & level in readable form
    output += type + " - Level " + level + "\n\n";

    // Pairing time (if known)
    if (minutes) {
        output += "Pairing Time Left - "
                + (string)minutes + "\n\n";
    }

    // Grid
    output += single_grid(grid) + "\n";

    llOwnerSay(output);
}

// Frumple info to print above grid
string grid_ref(string ID, string name, string type)
{
    string ref = "(" + ID + ")";
    if (name)
        if (name != ID && name != type)
            ref = name + " " + ref;
    return ref;
}

// Easy, copy/paste printout for a match
print_match(string match_data)
{
    // string == "\n"[2-digit score, 
    //                MY:    grid, ID, name, type, level, pairing_time,
    //                THEIR: grid, ID, name, type, level, pairing_time,
    //                         owner_name, owner_key]
    list data = llParseStringKeepNulls(match_data, ["\n"], []);
    integer score = llList2Integer(data, 0);
    integer mine_grid = llList2Integer(data, 1);
    string mine_ID = llList2String(data, 2);
    string mine_name = llList2String(data, 3);
    string mine_type = llList2String(data, 4);
    string mine_time = llList2String(data, 6);
    integer theirs_grid = llList2Integer(data, 7);
    string theirs_ID = llList2String(data, 8);
    string theirs_name = llList2String(data, 9);
    string theirs_type = llList2String(data, 10);
    string theirs_time = llList2String(data, 12);
    string theirs_owner_name = llList2String(data, 13);
    key theirs_owner_key = llList2Key(data, 14);
    
    // IM link
    string output = "";
    if (theirs_owner_key != NULL_KEY)
        if (theirs_owner_key != llGetOwner())
            output += "Click here to IM " + theirs_owner_name
                    + ":\n  secondlife:///app/agent/" 
                    + (string)theirs_owner_key 
                    + "/im\n\n";

    // Match size    
    output += "YAY! My FrumpleBumper found us a match of " 
               + (string)score + "!\n\n";

    // Headers
    output += grid_ref(mine_ID, mine_name, mine_type) + "\t"
            + grid_ref(theirs_ID, theirs_name, theirs_type) + "\n"
            + mine_type + "\t" + theirs_type + "\n"
            //+ mine_time + " min\t" + theirs_time + " min\n"
            + owner_name + "\t" + theirs_owner_name + "\n";

    // Grids
    output += double_grid(mine_grid, theirs_grid) + "\n";
    
    // Footer
    output += "\t" + mine_time + " min\t\t" + theirs_time + " min\n\n";

    llOwnerSay(output);
}


// ***************************  STATES  ***************************

default
{
    state_entry()
    {
        owner_name = llKey2Name(llGetOwner());
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        // Store a newly-found match
        if (num == MATCH_FOUND) {
            // string == "\n"[2-digit score, 
            //                MY:    grid, ID, name, type, level, pairing_time,
            //                THEIR: grid, ID, name, type, level, pairing_time,
            //                         owner_name, owner_key]
            // key == CSV[AUTO]
            integer index = llListFindList(matches_found, [str]);
            if (index == -1)
                matches_found += [str];

            // Automatic printing
            list settings = llCSV2List((string)id);
            if (llList2Integer(settings, 0))
                print_match(str);

            // Limit storage space
            if (llGetListLength(matches_found) > MAX_STORED)
                matches_found = llList2List(matches_found, -MAX_STORED, -1);
        }

        // Print all stored matches (highest match to lowest)
        else if (num == PRINT_MATCHES) {
            matches_found = llListSort(matches_found, 1, TRUE);
            integer count = llGetListLength(matches_found);
            integer i;
            for (i=0; i<count; ++i)
                print_match(llList2String(matches_found, i));
        }

        // Clear all stored matches
        else if (num == CLEAR_MATCHES) {
            matches_found = [];
        }

        // Print a single grid, on request
        else if (num == PRINT_GRID) {
            // string == "\n"[grid, ID, name, type, level, pairing_time]
            print_grid(str);
        }
            
    }
}