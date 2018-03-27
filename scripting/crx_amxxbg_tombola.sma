#include <amxmodx>
#include <amxmisc>

#define PLUGIN_VERSION "1.0"
#define HUDMSG_EFFECTS 2
#define HUDMSG_FXTIME 1.5
#define HUDMSG_FADEINTIME 0.03
#define HUDMSG_FADEOUTTIME 1.0
#define TEGLENE_DELAY 10.0
#define ITEMS_PER_PAGE 7
#define TASK_TEGLENE 123321

enum
{
	SECTION_NONE = 0,
	SECTION_NAGRADI,
	SECTION_ZAPISANI
}

new Array:g_aNagradi,
	Array:g_aZapisani,
	Array:g_aTeglene,
	Array:g_aIztegleni,
	Array:g_aDoubles,
	Trie:g_tDoubles,
	Float:g_fChance,
	bool:g_bActive,
	g_szConfigsName[256],
	g_szFilename[256],
	g_iMainMenu,
	g_iNagradiMenu,
	g_iZapisaniMenu,
	g_iDoublesMenu,
	g_iZapisani,
	g_iNagradi,
	g_iTeglene,
	g_iIztegleni,
	g_iDoubles

public plugin_init()
{
	register_plugin("AMXXBG Tombola", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXTombola", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_clcmd("say /tombola", "GlavnoMenu", ADMIN_ALL, "-- menu za tombola")
	register_clcmd("say_team /tombola", "GlavnoMenu", ADMIN_ALL, "-- menu za tombola")
	
	g_aNagradi = ArrayCreate(64)
	g_aZapisani = ArrayCreate(32)
	g_aIztegleni = ArrayCreate(32)
	g_aTeglene = ArrayCreate(32)
	g_aDoubles = ArrayCreate(32)
	g_tDoubles = TrieCreate()
	
	suzdai_glavni_menuta()
	get_configsdir(g_szConfigsName, charsmax(g_szConfigsName))
	formatex(g_szFilename, charsmax(g_szFilename), "%s/AMXXBGTombola.ini", g_szConfigsName)
	ReadFile(true)
}

public plugin_end()
{
	ArrayDestroy(g_aNagradi)
	ArrayDestroy(g_aZapisani)
	ArrayDestroy(g_aIztegleni)
	ArrayDestroy(g_aTeglene)
	ArrayDestroy(g_aDoubles)
	TrieDestroy(g_tDoubles)
}
	
ReadFile(bool:bFirstTime)
{
	if(!bFirstTime)
	{
		menu_destroy(g_iZapisaniMenu)
		menu_destroy(g_iNagradiMenu)
		
		if(g_iDoubles)
			menu_destroy(g_iDoublesMenu)
			
		ArrayClear(g_aNagradi)
		ArrayClear(g_aZapisani)
		ArrayClear(g_aDoubles)
		TrieClear(g_tDoubles)
		g_iNagradi = 0
		g_iZapisani = 0
		g_iDoubles = 0
		
		suzdai_glavni_menuta()
	}
	
	new iFilePointer = fopen(g_szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[64], iSection, iTimes
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS: continue
				case '#':
				{
					switch(szData[2])
					{
						case 'S', 's', 'N', 'n': iSection = SECTION_NAGRADI
						case 'Z', 'z', 'P', 'p': iSection = SECTION_ZAPISANI
					}
				}
				default:
				{
					switch(iSection)
					{
						case SECTION_NONE: continue
						case SECTION_NAGRADI:
						{
							g_iNagradi++
							ArrayPushString(g_aNagradi, szData)
							menu_additem(g_iNagradiMenu, szData)
						}
						case SECTION_ZAPISANI:
						{
							if(ArrayFindString(g_aZapisani, szData) != -1)
							{							
								if(TrieKeyExists(g_tDoubles, szData))
								{
									TrieGetCell(g_tDoubles, szData, iTimes)
									TrieSetCell(g_tDoubles, szData, iTimes + 1)
								}
								else
								{
									g_iDoubles++
									TrieSetCell(g_tDoubles, szData, 2)
									ArrayPushString(g_aDoubles, szData)
								}
							}
							
							g_iZapisani++
							ArrayPushString(g_aZapisani, szData)
							menu_additem(g_iZapisaniMenu, szData)
						}
					}
				}
			}
		}
		
		fclose(iFilePointer)
	}
	
	g_fChance = float(g_iNagradi) / float(g_iZapisani) * 100
	menu_setprop(g_iNagradiMenu, MPROP_TITLE, fmt("\r[AMXXBG] \yТомбола^n\wНагради: \d%i%s", g_iNagradi, g_iNagradi > ITEMS_PER_PAGE ? "^n\wСтраница:\d" : ""))
	menu_setprop(g_iZapisaniMenu, MPROP_TITLE, fmt("\r[AMXXBG] \yТомбола^n\wЗаписани потребители: \d%i%s", g_iZapisani, g_iZapisani > ITEMS_PER_PAGE ? "^n\wСтраница:\d" : ""))
	
	if(g_iDoubles)
	{
		g_iDoublesMenu = kirilizirano_menu(fmt("\r[AMXXBG] \yТомбола^n\rВНИМАНИЕ!^n^n\wНякои потребители са записани повече пъти.^nДали искате да продължите?%s",\
		g_iDoubles > ITEMS_PER_PAGE ? "^nСтраница:\d" : ""), "Doubles_Handler")
		
		menu_additem(g_iDoublesMenu, "\yДа")
		menu_additem(g_iDoublesMenu, "\rНе")
		
		for(new i, iTimes, szName[32]; i < g_iDoubles; i++)
		{
			ArrayGetString(g_aDoubles, i, szName, charsmax(szName))
			TrieGetCell(g_tDoubles, szName, iTimes)
			menu_additem(g_iDoublesMenu, fmt("%s \d[%i пъти]", szName, iTimes))
		}
	}
}

public GlavnoMenu(id, iLevel, iCid)
{
	cmd_access(id, iLevel, iCid, 1) ? menu_display(id, g_iMainMenu) : send_dhudmessage(id, 245, 30, 100, -1.0, 0.7, 3.0, "Нямаш достъп до тази команда!")
	return PLUGIN_HANDLED
}

public GlavnoMenu_Handler(id, iMenu, iItem)
{
	switch(iItem)
	{
		case 0: g_bActive ? send_dhudmessage(id, 245, 30, 100, -1.0, 0.7, 3.0, "Томболата вече е била стартирана!") : startirai_tombolata(id, true)
		case 1: g_bActive ? spri_tombolata(id) : send_dhudmessage(id, 245, 30, 100, -1.0, 0.7, 3.0, "Томболата не е активна в момента!")
		case 2: g_iZapisani ? menu_display(id, g_iZapisaniMenu) : send_dhudmessage(id, 245, 30, 100, -1.0, 0.7, 3.0, "Няма записани потребители!")
		case 3: g_iNagradi ? menu_display(id, g_iNagradiMenu) : send_dhudmessage(id, 245, 30, 100, -1.0, 0.7, 3.0, "Няма въведено награди!")
		case 4:
		{
			if(g_bActive)
				spri_tombolata(id)
				
			ReadFile(false)
			send_dhudmessage(id, 60, 200, 170, -1.0, 0.7, 3.0, "Конфигурацията е успешно презаредена!")
		}
	}
	
	return PLUGIN_HANDLED
}

public Submenu_Handler(id, iMenu, iItem)
{
	menu_display(id, g_iMainMenu)
	return PLUGIN_HANDLED
}

public Doubles_Handler(id, iMenu, iItem)
{
	iItem == 0 ? startirai_tombolata(id, false) : menu_display(id, g_iMainMenu)	
	return PLUGIN_HANDLED
}

startirai_tombolata(id, bool:bCheckDoubles)
{
	if(!g_iNagradi)
		send_dhudmessage(id, 245, 30, 100, -1.0, 0.7, 3.0, "Томболата не може да бъде стартирана, тъй като няма въведено никакви награди!")
	else if(!g_iZapisani)
		send_dhudmessage(id, 245, 30, 100, -1.0, 0.7, 3.0, "Томболата не може да бъде стартирана, тъй като няма записани потребители!")
	else if(bCheckDoubles && g_iDoubles)
		menu_display(id, g_iDoublesMenu)
	else
	{
		g_bActive = true
		g_aTeglene = ArrayClone(g_aZapisani)
		g_iTeglene = g_iZapisani
		
		new szName[32]
		get_user_name(id, szName, charsmax(szName))
		send_dhudmessage(0, 0, 225, 20, -1.0, 0.3, 5.0, "%s стартира томболата!", szName)
		send_dhudmessage(0, 30, 210, 230, -1.0, 0.35, 5.0, "Има общо %i записани потребители и %i награди. Шансът за печалба е %.2f%%", g_iZapisani, g_iNagradi, g_fChance)
		
		new Float:fPos = 0.40
		
		if(g_iDoubles)
		{
			fPos += 0.05
			send_dhudmessage(0, 160, 100, 220, -1.0, 0.40, 5.0, "Някои потребители са записани повече от веднъж.")
		}
		
		send_dhudmessage(0, 220, 150, 110, -1.0, fPos, 5.0, "Първият потребител ще бъде изтеглен след %.0f секунди...", TEGLENE_DELAY)
		zadai_sledvashto_teglene()
	}
}

zadai_sledvashto_teglene()
	set_task(TEGLENE_DELAY, "iztegli_potrebitel", TASK_TEGLENE)

public iztegli_potrebitel()
{
	new szIzteglen[32], iIzteglen = random(g_iTeglene)
	ArrayGetString(g_aTeglene, iIzteglen, szIzteglen, charsmax(szIzteglen))
	send_dhudmessage(0, 80, 190, 120, -1.0, 0.3, 5.0, "%s бе избран да получи награда", szIzteglen)
	send_dhudmessage(0, 240, 240, 60, -1.0, 0.35, 5.0, "%a", ArrayGetStringHandle(g_aNagradi, g_iIztegleni))
	
	ArrayDeleteItem(g_aTeglene, iIzteglen)
	ArrayPushString(g_aIztegleni, szIzteglen)
	g_iIztegleni++
	g_iTeglene--
	
	if(g_iIztegleni < g_iNagradi)
	{
		send_dhudmessage(0, 220, 150, 110, -1.0, 0.40, 5.0, "Следващият потребител ще бъде изтеглен след %.0f секунди...", TEGLENE_DELAY)
		zadai_sledvashto_teglene()
	}
	else krai_na_tombolata(false)
}	

spri_tombolata(id)
{
	krai_na_tombolata(true)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	send_dhudmessage(0, 245, 30, 100, -1.0, 0.6, 3.0, "%s спря томболата!", szName)
}

krai_na_tombolata(bool:bForced)
{
	remove_task(TASK_TEGLENE)
	ArrayClear(g_aTeglene)
	g_iTeglene = 0
	
	if(!bForced)
	{
		client_print(0, print_console, "=============== [ ИЗТЕГЛЕНИ ] ===============")
		
		for(new i; i < g_iIztegleni; i++)
			client_print(0, print_console, "%a: %a", ArrayGetStringHandle(g_aNagradi, i), ArrayGetStringHandle(g_aIztegleni, i))
			
		send_dhudmessage(0, 60, 200, 170, -1.0, 0.45, 8.0, "Томболата успешно приключи!")
		send_dhudmessage(0, 0, 150, 255, -1.0, 0.5, 8.0, "Спсиъкът с изтеглени потребители е изписан в конзолата.")
	}
	
	ArrayClear(g_aIztegleni)
	g_iIztegleni = 0
	g_bActive = false
}

suzdai_glavni_menuta()
{
	g_iMainMenu = kirilizirano_menu("\r[AMXXBG] \yТомбола^n\wГлавно меню", "GlavnoMenu_Handler")
	g_iNagradiMenu = kirilizirano_menu("", "Submenu_Handler")
	g_iZapisaniMenu = kirilizirano_menu("", "Submenu_Handler")
	
	menu_additem(g_iMainMenu, "\yСтартирай томболата", .paccess = ADMIN_RCON)
	menu_additem(g_iMainMenu, "\rСпри томболата", .paccess = ADMIN_RCON)
	menu_additem(g_iMainMenu, "Виж списъка със записани")
	menu_additem(g_iMainMenu, "Виж списъка с награди")
	menu_additem(g_iMainMenu, "Презареди конфигурацията", .paccess = ADMIN_RCON)
}

kirilizirano_menu(szTitle[], szHandler[])
{
	new iMenu = menu_create(szTitle, szHandler)
	menu_setprop(iMenu, MPROP_NEXTNAME, "\yСледваща")
	menu_setprop(iMenu, MPROP_BACKNAME, "\yПредишна")
	menu_setprop(iMenu, MPROP_EXITNAME, "\rЗатвори")
	return iMenu
}

send_dhudmessage(id, R, G, B, Float:X, Float:Y, Float:D, szInput[], any:...)
{
	static szMessage[128]
	vformat(szMessage, charsmax(szMessage), szInput, 9)
	set_dhudmessage(R, G, B, X, Y, HUDMSG_EFFECTS, HUDMSG_FXTIME, D, HUDMSG_FADEINTIME, HUDMSG_FADEOUTTIME)
	show_dhudmessage(id, szMessage)
}