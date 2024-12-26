import std::ascii;
import std::collections;
import std::io;

fault CommandError {
	NO_SUCH_ITEM
}

struct Condition {
	String name;
	bool value;
}

struct Description {
	String text;
	Condition[] conditions;
}

struct Flag
{
	String name;
	bool value;
}

struct Item
{
	String name;
	Description[] descriptions;
	Flag[] flags;
	String location; // initial location
}

fn bool Item.is(Item* this, String flagName)
{
	foreach (flag : this.flags)
	{
		if (flag.name == flagName)
		{
			return flag.value;
		}
	}
	return false;
}

fn String Item.describe(Item* this)
{
	foreach (desc : this.descriptions)
	{
		bool allTrue = true;
		foreach (cond : desc.conditions)
		{
			if (cond.value != this.is(cond.name))
			{
				allTrue = false;
				break;
			}
		}
		if (allTrue)
		{
			return desc.text;
		}
	}
	return "You see nothing special.";
}

def ListItem = List(<Item>);

struct Room
{
	String name;
	String description;
	int[4] doors;
	ListItem items;
}

const Room[] ROOMS =
{
	{
		"The Void",
		"You should not be able to get here",
		{0, 0, 0, 0},
		{}
	},
	{
		"Room 1",
		"There is a door to the north.",
		{2, 0, 0, 0},
		{}
	},
	{
		"Room 2",
		"There is a door to the south.",
		{0, 1, 0, 0},
		{}
	}
};

const Item[] ROOM_ITEMS = {
	{"key", {{"A rusty old key", {}}}, { {"portable", true} }, "Room 1"},
	{"torchlight",
		{
			{"A neat torchlight shining bright", {{ "on", true}}},
			{"A neat torchlight that is currently turned off", {{ "on", false}}}
		},
		{ {"portable", true}, {"on", true} },
		"Room 1"
	},
	{"switch",
	{
		{"An electrical switch that emits a buzzing sound", { { "on", true } }},
		{"An electrical switch that is currently turned osff", { { "on", false } }}
	}, {{"on", false}}, "Room 2"}
};

int current_room = 1;
ListItem inventory;

fn void initialize_world()
{
	foreach (item : ROOM_ITEMS)
	{
		Room* room = get_room(item.location);
		room.items.push(item);
	}
}

fn Room* get_room(String name)
{
	foreach (&room : ROOMS)
	{
		if (room.name == name)
		{
			return room;
		}
	}
	return null;
}

fn void enter_room(int room)
{
	current_room = room;
	describe_room();
}

fn void describe_room()
{
	Room* room = &ROOMS[current_room];
	io::printfn("You are in %s", room.name);
	io::printn(room.description);
	ListItem items = room.items;
	if (items.len() > 0)
	{
		io::printn("You see:");
		for (int i = 0; i < items.len(); i++)
		{
			io::printfn("  %s", items[i].name);
		}
	} else {
		io::printn("There is nothing here.");
	}
}

fn void enter_door(int direction)
{
	Room* room = &ROOMS[current_room];
	int door = room.doors[direction];
	if (door != 0)
	{
		enter_room(door);
	}
	else
	{
		io::printn("You can't go that way.");
	}
}

fn Item*! get_item(String name)
{
	foreach (&item : inventory)
	{
		if (item.name == name)
		{
			return item;
		}
	}
	Room* room = &ROOMS[current_room];
	foreach (&item : room.items)
	{
		if (item.name == name)
		{
			return item;
		}
	}
	return CommandError.NO_SUCH_ITEM?;
}

fn void take_item(String name)
{
	Room* room = &ROOMS[current_room];
	foreach (i, item : room.items)
	{
		if (item.name == name)
		{
			if (!item.is("portable"))
			{
				io::printn("You can't take that.");
				return;
			}
			inventory.push(item);
			room.items.remove_at(i);
			io::printfn("You take the %s", name);
			return;
		}
	}
	io::printfn("There is no %s here.", name);
}

fn void examine_item(String name) {
	Item*! item = get_item(name);
	if (catch excuse = item)
	{
		io::printfn("There is no %s", name);
		return;
	}
	io::printn(item.describe());
}

fn void drop_item(String name) {
	foreach (i, item : inventory)
	{
		if (item.name == name)
		{
			Room* room = &ROOMS[current_room];
			room.items.push(item);

			inventory.remove_at(i);
			io::printfn("You drop the %s", name);
			return;
		}
	}
	io::printfn("You are not carrying a %s.", name);
}

fn void toggle_item(String name, String flagName, bool value)
{
	Item*! item = get_item(name);
	if (catch excuse = item)
	{
		io::printfn("There is no %s", name);
		return;
	}
	foreach (&flag : item.flags)
	{
		if (flag.name == flagName)
		{
			flag.value = value;
			io::printfn("You turn the %s %s.", name, value ? "on" : "off");
			return;
		}
	}
	io::printfn("The %s does not have a %s flag.", name, flagName);
	return;
}

fn void describe_inventory()
{
	if (inventory.len() == 0)
	{
		io::printn("You are not carrying anything.");
	}
	else
	{
		io::printn("You are carrying:");
		for (int i = 0; i < inventory.len(); i++)
		{
			io::printfn("  %s", inventory[i].name);
		}
	}
}

fn void help()
{
	io::printn("Available Commands: go <direction>, north, south, east, west, look, examine, take <item>, drop <item>, turn <item> <on/off>, inventory, exit");
}

fn bool! next_cmd()
{
	io::print("> ");
    String command = io::treadline()!;
    // todo: figure out how to convert command to lowercase
    String[] tokens = command.tsplit(" ");
    for (int i = 0; i < tokens.len; i++)
	{
	    switch (tokens[i])
		{
			case "help":
				help();
			case "go":
				continue;
			case "north":
				enter_door(0);
			case "south":
				enter_door(1);
			case "east":
				enter_door(2);
			case "west":
				enter_door(3);
			case "look":
				describe_room();
			case "examine":
				if (tokens.len < i + 2)
				{
					io::printn("You must specify an item to examine.");
					continue;
				}
				examine_item(tokens[i + 1]);
				i++;
			case "take":
				if (tokens.len < i + 2)
				{
					io::printn("You must specify an item to take.");
					continue;
				}
				take_item(tokens[i + 1]);
				i++;
			case "drop":
				if (tokens.len < i + 2)
				{
					io::printn("You must specify an item to drop.");
					continue;
				}
				drop_item(tokens[i + 1]);
				i++;
			case "inventory":
				describe_inventory();
			case "turn":
				if (tokens.len < i + 3)
				{
					io::printn("You must specify an item and a direction to turn it.");
					continue;
				}
				String a = tokens[i + 1];
				String b = tokens[i + 2];
				i+=2;
				if (a == "on" || a == "off")
				{
					toggle_item(b, "on", a == "on");
				}
				else if (b == "on" || b == "off")
				{
					toggle_item(a, "on", b == "on");
				}
				else
				{
					io::printn("You must specify 'on' or 'off' and the item.");
				}
			case "exit":
			case "quit":
			case "bye":
				io::printn("Goodbye!");
				return false;
			default:
				io::printn("I don't understand that command.");
		}
	}
    return true;
}

fn void! main()
{
	//mem::@report_heap_allocs_in_scope()
	{
		io::printn("Welcome to the Adventure Game!");

		initialize_world();
		enter_room(1);

		bool running = true;
		while (running)
		{
			@pool()
			{
				running = next_cmd()!;
			};
		}

		inventory.free();
		foreach (&room : ROOMS)
		{
			room.items.free();
		}
	};
 }
