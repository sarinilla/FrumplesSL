// This was used to rez Joker Games arranged in groups of four
// to easily play multiples. It could be a useful reference for
// rezzing objects in a known formation, perhaps.
//
// Author: Rini Rampal
// Written 2013
// Released under MIT License
// https://github.com/SariniLynn/FrumplesSL


vector FIRST_POSITION = <9, 242, 1036>;
float LAST_X = 66;
integer JOKERS_PER_ROW = 40;

integer dialog_channel;
integer dialog_listener;


rez_four(vector pos)
{
    llSetRegionPos(pos);
    llRezObject(llGetInventoryName(INVENTORY_OBJECT, 0),
        pos, ZERO_VECTOR, ZERO_ROTATION, 0);
    llSleep(0.1);
    llRezObject(llGetInventoryName(INVENTORY_OBJECT, 0),
        pos + <3, 0, -1>, ZERO_VECTOR, ZERO_ROTATION, 0);
    llSleep(0.1);
    llRezObject(llGetInventoryName(INVENTORY_OBJECT, 0),
        pos + <0, 0, -3>, ZERO_VECTOR, ZERO_ROTATION, 0);
    llSleep(0.1);
    llRezObject(llGetInventoryName(INVENTORY_OBJECT, 0),
        pos + <3, 0, -4>, ZERO_VECTOR, ZERO_ROTATION, 0);
    llSleep(0.1);
}

rez_row(vector pos)
{
    while (pos.x < LAST_X) {
        rez_four(pos);
        pos.x += 6;
    }
}

default
{
    changed(integer change)
    {
        if (change & CHANGED_OWNER) llResetScript();
    }
    
    state_entry()
    {
        llSetText("Rini's Joker Rezzer", <1, 1, 1>, 1);
        
        dialog_channel = -2000000000 + (integer)llFrand(1000000000.0);
        dialog_listener = llListen(dialog_channel, "", llGetOwner(), "");
        llListenControl(dialog_listener, FALSE);
        llOwnerSay("Ready!");
    }

    touch_start(integer total_number)
    {
        key av = llDetectedKey(0);
        if (av != llGetOwner())
            llRegionSayTo(av, 0, "I'm used to rez joker games in a special pattern for easy play. Please don't delete me!");
        else {
            llListenControl(dialog_listener, TRUE);
            llDialog(av, llGetScriptName() + "\n\n" + (string)llGetInventoryNumber(INVENTORY_OBJECT) + " jokers in inventory. How many should I rez for you?",
                     [(string)JOKERS_PER_ROW, (string)(2 * JOKERS_PER_ROW), "Cancel",
                      "4", "8", "12"], dialog_channel);
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        llListenControl(dialog_listener, FALSE);
        integer num = (integer)message;
        if (llGetInventoryNumber(INVENTORY_OBJECT) < num) {
            llOwnerSay("Sorry!  I need more jokers first!");
            return;
        }
    
        vector start_pos = llGetPos();
        
        if (num == 4)
            rez_four(FIRST_POSITION);
        else if (num == JOKERS_PER_ROW)
            rez_row(FIRST_POSITION);
            
        else if (num < JOKERS_PER_ROW) {
            vector pos = FIRST_POSITION;
            while (num >= 4) {
                rez_four(pos);
                pos.x += 6;
                num -= 4;
            }
                
            if (num) llOwnerSay("Rezzed " + (string)((integer)message - num));
        }
        else {
            vector pos = FIRST_POSITION;
            while (num >= JOKERS_PER_ROW) {
                rez_row(pos);
                pos.z -= 9;
                num -= JOKERS_PER_ROW;
            }
            
            if (num) llOwnerSay("Rezzed " + (string)((integer)message - num));
        }
        
        llSetRegionPos(start_pos);
    }
}
