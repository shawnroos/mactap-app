{
	"patcher": {
		"fileversion": 1,
		"appversion": {
			"major": 8,
			"minor": 1,
			"revision": 2,
			"architecture": "x64",
			"modernui": 1
		},
		"classnamespace": "box",
		"rect": [
			65.0,
			399.0,
			960.0,
			560.0
		],
		"openrect": [
			0.0,
			0.0,
			0.0,
			169.0
		],
		"bglocked": 0,
		"openinpresentation": 1,
		"default_fontsize": 10.0,
		"default_fontface": 0,
		"default_fontname": "Arial Bold",
		"gridonopen": 1,
		"gridsize": [
			8.0,
			8.0
		],
		"gridsnaponopen": 1,
		"objectsnaponopen": 1,
		"statusbarvisible": 2,
		"toolbarvisible": 1,
		"lefttoolbarpinned": 0,
		"toptoolbarpinned": 0,
		"righttoolbarpinned": 0,
		"bottomtoolbarpinned": 0,
		"toolbars_unpinned_last_save": 0,
		"tallnewobj": 0,
		"boxanimatetime": 500,
		"enablehscroll": 1,
		"enablevscroll": 1,
		"devicewidth": 300.0,
		"description": "Knock the MacBook chassis to play notes. Needs mactap-midi running with --osc.",
		"digest": "MacBook chassis knocks as MIDI",
		"tags": "",
		"style": "",
		"subpatcher_template": "",
		"title": "MacTap",
		"boxes": [
			{
				"box": {
					"id": "obj-1",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						20.0,
						10.0,
						276.0,
						18.0
					],
					"text": "MIDI from Live passes straight through",
					"textjustification": 0
				}
			},
			{
				"box": {
					"id": "obj-2",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 1,
					"patching_rect": [
						20.0,
						34.0,
						40.0,
						20.0
					],
					"outlettype": [
						"int"
					],
					"text": "midiin",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-3",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						20.0,
						64.0,
						47.0,
						20.0
					],
					"text": "midiout",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-4",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						300.0,
						10.0,
						367.0,
						18.0
					],
					"text": "Knocks arrive from mactap-midi --osc 127.0.0.1:7400",
					"textjustification": 0
				}
			},
			{
				"box": {
					"id": "obj-5",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 1,
					"patching_rect": [
						300.0,
						34.0,
						100.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "udpreceive 7400",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-6",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 2,
					"patching_rect": [
						300.0,
						64.0,
						110.0,
						20.0
					],
					"outlettype": [
						"",
						""
					],
					"text": "route /mactap/hit",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-7",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 4,
					"patching_rect": [
						300.0,
						94.0,
						100.0,
						20.0
					],
					"outlettype": [
						"int",
						"int",
						"float",
						"float"
					],
					"text": "unpack i i f f",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-8",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 3,
					"patching_rect": [
						300.0,
						134.0,
						50.0,
						20.0
					],
					"outlettype": [
						"bang",
						"bang",
						""
					],
					"text": "sel 0 1",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-9",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						300.0,
						174.0,
						40.0,
						20.0
					],
					"outlettype": [
						"int"
					],
					"text": "int",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-10",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						360.0,
						174.0,
						40.0,
						20.0
					],
					"outlettype": [
						"int"
					],
					"text": "int",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-11",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						300.0,
						214.0,
						60.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "pack 0 0",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-12",
					"maxclass": "newobj",
					"numinlets": 3,
					"numoutlets": 2,
					"patching_rect": [
						300.0,
						244.0,
						100.0,
						20.0
					],
					"outlettype": [
						"int",
						"int"
					],
					"text": "makenote 100 30",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-13",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						300.0,
						274.0,
						60.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "pack 0 0",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-14",
					"maxclass": "newobj",
					"numinlets": 7,
					"numoutlets": 1,
					"patching_rect": [
						300.0,
						304.0,
						80.0,
						20.0
					],
					"outlettype": [
						"int"
					],
					"text": "midiformat",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-15",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						300.0,
						334.0,
						47.0,
						20.0
					],
					"text": "midiout",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-16",
					"maxclass": "button",
					"numinlets": 1,
					"numoutlets": 1,
					"patching_rect": [
						300.0,
						400.0,
						24.0,
						24.0
					],
					"outlettype": [
						"bang"
					],
					"presentation": 1,
					"presentation_rect": [
						236.0,
						22.0,
						24.0,
						24.0
					]
				}
			},
			{
				"box": {
					"id": "obj-17",
					"maxclass": "button",
					"numinlets": 1,
					"numoutlets": 1,
					"patching_rect": [
						340.0,
						400.0,
						24.0,
						24.0
					],
					"outlettype": [
						"bang"
					],
					"presentation": 1,
					"presentation_rect": [
						268.0,
						22.0,
						24.0,
						24.0
					]
				}
			},
			{
				"box": {
					"id": "obj-18",
					"maxclass": "number",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						400.0,
						400.0,
						40.0,
						20.0
					],
					"outlettype": [
						"",
						"bang"
					],
					"presentation": 1,
					"presentation_rect": [
						236.0,
						66.0,
						56.0,
						20.0
					],
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-19",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						24.0,
						18.0
					],
					"text": "L",
					"presentation": 1,
					"presentation_rect": [
						236.0,
						4.0,
						24.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-20",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						24.0,
						18.0
					],
					"text": "R",
					"presentation": 1,
					"presentation_rect": [
						268.0,
						4.0,
						24.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-21",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						56.0,
						18.0
					],
					"text": "velocity",
					"presentation": 1,
					"presentation_rect": [
						236.0,
						50.0,
						56.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-22",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						20.0,
						120.0,
						283.0,
						18.0
					],
					"text": "Dials set the bridge live over OSC 7401",
					"textjustification": 0
				}
			},
			{
				"box": {
					"id": "obj-23",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						20.0,
						480.0,
						130.0,
						20.0
					],
					"text": "udpsend 127.0.0.1 7401",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-24",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 3,
					"patching_rect": [
						20.0,
						150.0,
						90.0,
						20.0
					],
					"outlettype": [
						"bang",
						"int",
						"int"
					],
					"text": "live.thisdevice",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-25",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 8,
					"patching_rect": [
						20.0,
						180.0,
						120.0,
						20.0
					],
					"outlettype": [
						"bang",
						"bang",
						"bang",
						"bang",
						"bang",
						"bang",
						"bang",
						"bang"
					],
					"text": "t b b b b b b b b",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-26",
					"maxclass": "live.dial",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						20.0,
						220.0,
						44.0,
						48.0
					],
					"outlettype": [
						"",
						"float"
					],
					"varname": "sens",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						8.0,
						20.0,
						44.0,
						48.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Sensitivity",
							"parameter_shortname": "Sens",
							"parameter_type": 0,
							"parameter_mmin": 0.0,
							"parameter_mmax": 1.0,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								0.9
							],
							"parameter_unitstyle": 1
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-27",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						20.0,
						280.0,
						90.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/sensitivity",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-28",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						44.0,
						18.0
					],
					"text": "Sens",
					"presentation": 1,
					"presentation_rect": [
						8.0,
						68.0,
						44.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-29",
					"maxclass": "live.dial",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						110.0,
						220.0,
						44.0,
						48.0
					],
					"outlettype": [
						"",
						"float"
					],
					"varname": "floor",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						56.0,
						20.0,
						44.0,
						48.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Floor g",
							"parameter_shortname": "Floor",
							"parameter_type": 0,
							"parameter_mmin": 0.005,
							"parameter_mmax": 0.05,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								0.012
							],
							"parameter_unitstyle": 1
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-30",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						110.0,
						280.0,
						90.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/floor",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-31",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						44.0,
						18.0
					],
					"text": "Floor",
					"presentation": 1,
					"presentation_rect": [
						56.0,
						68.0,
						44.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-32",
					"maxclass": "live.dial",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						200.0,
						220.0,
						44.0,
						48.0
					],
					"outlettype": [
						"",
						"float"
					],
					"varname": "ceil",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						104.0,
						20.0,
						44.0,
						48.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Ceiling g",
							"parameter_shortname": "Ceil",
							"parameter_type": 0,
							"parameter_mmin": 0.02,
							"parameter_mmax": 0.2,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								0.09
							],
							"parameter_unitstyle": 1
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-33",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						200.0,
						280.0,
						90.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/ceil",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-34",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						44.0,
						18.0
					],
					"text": "Ceil",
					"presentation": 1,
					"presentation_rect": [
						104.0,
						68.0,
						44.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-35",
					"maxclass": "live.dial",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						290.0,
						220.0,
						44.0,
						48.0
					],
					"outlettype": [
						"",
						"float"
					],
					"varname": "curve",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						152.0,
						20.0,
						44.0,
						48.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Curve",
							"parameter_shortname": "Curve",
							"parameter_type": 0,
							"parameter_mmin": 0.2,
							"parameter_mmax": 2.0,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								0.6
							],
							"parameter_unitstyle": 1
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-36",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						290.0,
						280.0,
						90.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/curve",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-37",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						44.0,
						18.0
					],
					"text": "Curve",
					"presentation": 1,
					"presentation_rect": [
						152.0,
						68.0,
						44.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-38",
					"maxclass": "live.dial",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						380.0,
						220.0,
						44.0,
						48.0
					],
					"outlettype": [
						"",
						"float"
					],
					"varname": "gate",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						200.0,
						20.0,
						44.0,
						48.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Gate ms",
							"parameter_shortname": "Gate",
							"parameter_type": 0,
							"parameter_mmin": 5.0,
							"parameter_mmax": 200.0,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								30.0
							],
							"parameter_unitstyle": 2
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-39",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						380.0,
						280.0,
						110.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/gate",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-40",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						44.0,
						18.0
					],
					"text": "Gate",
					"presentation": 1,
					"presentation_rect": [
						200.0,
						68.0,
						44.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-41",
					"maxclass": "live.numbox",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						500.0,
						220.0,
						44.0,
						15.0
					],
					"outlettype": [
						"",
						"float"
					],
					"varname": "noteL",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						8.0,
						96.0,
						44.0,
						15.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Note Left",
							"parameter_shortname": "NoteL",
							"parameter_type": 1,
							"parameter_mmin": 0,
							"parameter_mmax": 127,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								36
							],
							"parameter_unitstyle": 0
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-42",
					"maxclass": "live.numbox",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						560.0,
						220.0,
						44.0,
						15.0
					],
					"outlettype": [
						"",
						"float"
					],
					"varname": "noteR",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						56.0,
						96.0,
						44.0,
						15.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Note Right",
							"parameter_shortname": "NoteR",
							"parameter_type": 1,
							"parameter_mmin": 0,
							"parameter_mmax": 127,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								38
							],
							"parameter_unitstyle": 0
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-43",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						500.0,
						280.0,
						110.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/note",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-44",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						620.0,
						280.0,
						140.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/note-right",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-45",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						44.0,
						18.0
					],
					"text": "note L",
					"presentation": 1,
					"presentation_rect": [
						8.0,
						114.0,
						44.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-46",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						44.0,
						18.0
					],
					"text": "note R",
					"presentation": 1,
					"presentation_rect": [
						56.0,
						114.0,
						44.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-47",
					"maxclass": "live.toggle",
					"numinlets": 1,
					"numoutlets": 1,
					"patching_rect": [
						780.0,
						220.0,
						15.0,
						15.0
					],
					"outlettype": [
						""
					],
					"varname": "sides",
					"parameter_enable": 1,
					"presentation": 1,
					"presentation_rect": [
						118.0,
						96.0,
						15.0,
						15.0
					],
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Sides",
							"parameter_shortname": "Sides",
							"parameter_type": 2,
							"parameter_mmin": 0,
							"parameter_mmax": 1,
							"parameter_initial_enable": 1,
							"parameter_initial": [
								1
							],
							"parameter_unitstyle": 0,
							"parameter_enum": [
								"off",
								"on"
							]
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-48",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						780.0,
						280.0,
						110.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend /mactap/sides",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-49",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						0.0,
						0.0,
						36.0,
						18.0
					],
					"text": "L/R",
					"presentation": 1,
					"presentation_rect": [
						108.0,
						114.0,
						36.0,
						18.0
					],
					"textjustification": 1,
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-50",
					"maxclass": "live.comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						20.0,
						340.0,
						493.0,
						18.0
					],
					"text": "Node starts mactap-midi from the device folder and stops it on unload",
					"textjustification": 0
				}
			},
			{
				"box": {
					"id": "obj-51",
					"maxclass": "newobj",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						20.0,
						364.0,
						300.0,
						20.0
					],
					"outlettype": [
						"",
						""
					],
					"text": "node.script mactap-launch.js @autostart 1 @watch 0",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-52",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 2,
					"patching_rect": [
						20.0,
						394.0,
						80.0,
						20.0
					],
					"outlettype": [
						"",
						""
					],
					"text": "route status",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-53",
					"maxclass": "newobj",
					"numinlets": 2,
					"numoutlets": 1,
					"patching_rect": [
						20.0,
						424.0,
						80.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "prepend set",
					"fontname": "Arial Bold",
					"fontsize": 10.0
				}
			},
			{
				"box": {
					"id": "obj-54",
					"maxclass": "comment",
					"numinlets": 1,
					"numoutlets": 0,
					"patching_rect": [
						20.0,
						454.0,
						280.0,
						18.0
					],
					"text": "bridge: starting",
					"presentation": 1,
					"presentation_rect": [
						8.0,
						140.0,
						290.0,
						18.0
					],
					"fontsize": 9.0
				}
			},
			{
				"box": {
					"id": "obj-55",
					"maxclass": "live.text",
					"numinlets": 1,
					"numoutlets": 2,
					"patching_rect": [
						340.0,
						424.0,
						52.0,
						15.0
					],
					"outlettype": [
						"",
						""
					],
					"text": "restart",
					"presentation": 1,
					"presentation_rect": [
						236.0,
						96.0,
						56.0,
						15.0
					],
					"texton": "restart",
					"mode": 0,
					"parameter_enable": 1,
					"varname": "restart",
					"saved_attribute_attributes": {
						"valueof": {
							"parameter_longname": "Restart bridge",
							"parameter_shortname": "Restart",
							"parameter_type": 2,
							"parameter_mmax": 1,
							"parameter_enum": [
								"off",
								"on"
							],
							"parameter_invisible": 1
						}
					}
				}
			},
			{
				"box": {
					"id": "obj-56",
					"maxclass": "message",
					"numinlets": 1,
					"numoutlets": 1,
					"patching_rect": [
						340.0,
						454.0,
						50.0,
						20.0
					],
					"outlettype": [
						""
					],
					"text": "restart"
				}
			}
		],
		"lines": [
			{
				"patchline": {
					"source": [
						"obj-2",
						0
					],
					"destination": [
						"obj-3",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-5",
						0
					],
					"destination": [
						"obj-6",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-6",
						0
					],
					"destination": [
						"obj-7",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-7",
						0
					],
					"destination": [
						"obj-8",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-8",
						0
					],
					"destination": [
						"obj-9",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-8",
						1
					],
					"destination": [
						"obj-10",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-7",
						1
					],
					"destination": [
						"obj-11",
						1
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-9",
						0
					],
					"destination": [
						"obj-11",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-10",
						0
					],
					"destination": [
						"obj-11",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-11",
						0
					],
					"destination": [
						"obj-12",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-12",
						0
					],
					"destination": [
						"obj-13",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-12",
						1
					],
					"destination": [
						"obj-13",
						1
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-13",
						0
					],
					"destination": [
						"obj-14",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-14",
						0
					],
					"destination": [
						"obj-15",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-8",
						0
					],
					"destination": [
						"obj-16",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-8",
						1
					],
					"destination": [
						"obj-17",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-7",
						1
					],
					"destination": [
						"obj-18",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-24",
						0
					],
					"destination": [
						"obj-25",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-26",
						0
					],
					"destination": [
						"obj-27",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-27",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-29",
						0
					],
					"destination": [
						"obj-30",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-30",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-32",
						0
					],
					"destination": [
						"obj-33",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-33",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-35",
						0
					],
					"destination": [
						"obj-36",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-36",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-38",
						0
					],
					"destination": [
						"obj-39",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-39",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-38",
						0
					],
					"destination": [
						"obj-12",
						2
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-41",
						0
					],
					"destination": [
						"obj-43",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-42",
						0
					],
					"destination": [
						"obj-44",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-43",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-44",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-41",
						0
					],
					"destination": [
						"obj-9",
						1
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-42",
						0
					],
					"destination": [
						"obj-10",
						1
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-47",
						0
					],
					"destination": [
						"obj-48",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-48",
						0
					],
					"destination": [
						"obj-23",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						7
					],
					"destination": [
						"obj-26",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						6
					],
					"destination": [
						"obj-29",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						5
					],
					"destination": [
						"obj-32",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						4
					],
					"destination": [
						"obj-35",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						3
					],
					"destination": [
						"obj-38",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						2
					],
					"destination": [
						"obj-41",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						1
					],
					"destination": [
						"obj-42",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-25",
						0
					],
					"destination": [
						"obj-47",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-51",
						0
					],
					"destination": [
						"obj-52",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-52",
						0
					],
					"destination": [
						"obj-53",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-53",
						0
					],
					"destination": [
						"obj-54",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-55",
						0
					],
					"destination": [
						"obj-56",
						0
					]
				}
			},
			{
				"patchline": {
					"source": [
						"obj-56",
						0
					],
					"destination": [
						"obj-51",
						0
					]
				}
			}
		],
		"dependency_cache": [],
		"latency": 0,
		"project": {
			"version": 1,
			"creationdate": 3872222627,
			"modificationdate": 3872222627,
			"viewrect": [
				0.0,
				0.0,
				300.0,
				500.0
			],
			"autoorganize": 1,
			"hideprojectwindow": 1,
			"showdependencies": 1,
			"autolocalize": 0,
			"contents": {
				"patchers": {}
			},
			"layout": {},
			"searchpath": {},
			"detailsvisible": 0,
			"amxdtype": 1835887981,
			"readonly": 0,
			"devpathtype": 0,
			"devpath": ".",
			"sortmode": 0,
			"viewmode": 0
		},
		"autosave": 0
	}
}
