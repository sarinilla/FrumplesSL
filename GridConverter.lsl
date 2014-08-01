// This was the simplest form of the script to convert a grid pattern
//
// □■□■■
// □■■□□
// □□□□□
// ■■■■■
// ■□■■□
//
// into an integer suitable for script calculation.  Binary data
// management is always a useful skill!
//
// Author: Rini Rampal
// Written 2013
// Released under MIT License
// https://github.com/SariniLynn/FrumplesSL


integer channel;


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


// ************************  GRID PARSING  ************************

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

// Turn □ into False and ■ into True
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
        channel = 2000000000-(integer)llFrand(1000000000.0);
        llListen(channel, "", llGetOwner(), "");
        llTextBox(llGetOwner(), llGetScriptName() + "\n\nEnter a grid (visual or integer):", channel);
    }
    
    on_rez(integer start) { llResetScript(); }
    changed(integer change) { if (change & CHANGED_OWNER) llResetScript(); }

    touch_start(integer total_number)
    {
        llTextBox(llGetOwner(), llGetScriptName() + "\n\nEnter a grid (visual or integer):", channel);
    }
    
    listen(integer chan, string name, key id, string message)
    {
        integer index = llSubStringIndex(message, "1 - ");
        if (index == -1) {
            llOwnerSay(single_grid((integer)message));
            return;
        }
        
        string grid = llGetSubString(message, index, -1);
        list grid_lines = llParseString2List(grid, ["\n"], []);
        llOwnerSay((string)parse_grid(grid_lines));
    }   
}
