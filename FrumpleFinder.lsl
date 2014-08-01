// This was given out as a freebie to all Frumple players, to help
// locate a specific frumple in-world.  After locating the object
// using the Frumples API, it would create a "yellow-brick road"
// leading the player to the item.  In theory, at least, this has
// plenty of useful applications outside of Frumples, and at the
// very least, it's another particle example!
//
// Author: Rini Rampal
// Written 2013
// Released under MIT License
// https://github.com/SariniLynn/FrumplesSL




// Change prim color to control particle colors (side 0)

float DELAY = 1.0;  // between responses
integer dialog_channel;
list looking_for = [];
integer HOLD;  // path open

find_next()
{
    HOLD = FALSE;
    if (looking_for) {
        integer ID = llList2Integer(looking_for, 0);
        sim_request(request_all, NULL_KEY, -1, ID);
        llSetTimerEvent(DELAY);
        llOwnerSay("Looking for #" + (string)ID);
    }
}

next_ID()
{
    if (llGetListLength(looking_for) == 1)
        looking_for = [];
    else
        looking_for = llList2List(looking_for, 1, -1);
}

// *************************  FRUMPLE API  ************************

integer to_frumple_channel = -853321960;
integer from_frumple_channel = -853321961;

string request_pair = "SAY_PAIR_STATUS_DATA";
string request_sale = "SAY_SELL_STATUS_DATA";
string request_all  = "SAY_STATUS_DATA";

sim_request(string request, key avatar, integer level, integer ID)
{
    string text = request + "," + (string)avatar + "," + (string)level;
    if (ID) text += "," + (string)ID;
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

// Updater: "Frumple Findin' University!" on 86535496
integer update_channel = 86535496;
string update_announcement = "Frumple Findin' University!";
// Sorter:  <set pin to 864531>
integer pin = 864531;
// Sorter:  "You know the code, prof." on 984625984
integer response_channel = 984625984;
string update_response = "You know the code, prof.";
// Updater: <load cleaner script & new scripts as needed>


// ***************************  STATES  ***************************

default
{
    state_entry()
    {
        llListen(update_channel, "", NULL_KEY, update_announcement);
        llListen(role_call_channel, "", NULL_KEY, role_call_message);
        llListen(from_frumple_channel, "", NULL_KEY, "");
        dialog_channel = -2000000000 + (integer)llFrand(1000000000.0);
        llListen(dialog_channel, "", llGetOwner(), "");
        llOwnerSay("Touch me to find a local frumple...");
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
            llResetScript();
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }

    touch_start(integer total_number)
    {
        integer i;
        for (i=0; i<total_number; ++i) {
            key av = llDetectedKey(i);
            if (av != llGetOwner()) return;
            llParticleSystem([]);
            if (looking_for) {
                next_ID();
                find_next();
            }
            else
                llTextBox(av, llGetScriptName() + "\n\nEnter the ID of a frumple to find:", dialog_channel);
        }
    }
    
    timer()
    {
        llSetTimerEvent(0.0);
        llOwnerSay("No frumple found on this sim with ID " + 
                   llList2String(looking_for, 0));
        next_ID();
        find_next();
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == dialog_channel) {
            if (message == "OK") {
                llParticleSystem([]);
                next_ID();
                find_next();
            }
                
            else {
                looking_for += llCSV2List(message);
                find_next();
            }
        }
        
        else if (channel == from_frumple_channel) {
            if (looking_for == [] || HOLD == TRUE) {
                llSetTimerEvent(0.0);
                return;
            }
            
            llSetTimerEvent(DELAY);
            list data = llParseStringKeepNulls(message, ["\n"], []);
            if (llList2String(data, 0) != "STATUS")
                return;
            if (llList2String(data, 1) != llList2String(looking_for, 0)) 
                return;
            
            llSetTimerEvent(0.0);
            llOwnerSay("Follow the yellow brick road to " + name);
            llParticleSystem([PSYS_PART_FLAGS, PSYS_PART_FOLLOW_SRC_MASK
                                             | PSYS_PART_TARGET_LINEAR_MASK
                                             | PSYS_PART_TARGET_POS_MASK,
                              PSYS_SRC_TARGET_KEY, id,
                              PSYS_PART_START_COLOR, llGetColor(0),
                              PSYS_PART_MAX_AGE, 2.0,
                              PSYS_SRC_BURST_RATE, 0.001]);
            HOLD = TRUE;
            llDialog(llGetOwner(), llGetScriptName() + "\n\nPress OK or touch me again to clear the path.", ["OK"], dialog_channel);
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
        
        // Respond to update request
        else if (channel == update_channel) {
            llSetRemoteScriptAccessPin(pin);
            llRegionSayTo(id, response_channel, update_response);
        }
    }
}
