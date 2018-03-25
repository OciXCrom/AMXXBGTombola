#include <amxmodx>
#include <amxmisc>

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
	bool:g_bActive,
	bool:g_bWasStarted,
	g_iMainMenu,
	g_iNagradiMenu,
	g_iZapisaniMenu,
	g_iZapisani,
	g_iNagradi,
	g_iTeglene,
	g_iIztegleni

public plugin_init()
{
	register_plugin("AMXXBG Tombola", "1.0", "OciXCrom")
	register_clcmd("say /tombola", "GlavnoMenu", ADMIN_RCON, "-- menu za tombola")
	register_clcmd("say_team /tombola", "GlavnoMenu", ADMIN_RCON, "-- menu za tombola")
	
	g_iMainMenu = kirilizirano_menu("\r[AMXXBG] \yТомбола^n\wГлавно меню", "GlavnoMenu_Handler")
	g_iNagradiMenu = kirilizirano_menu("", "Submenu_Handler")
	g_iZapisaniMenu = kirilizirano_menu("", "Submenu_Handler")
	
	menu_additem(g_iMainMenu, "\yСтартирай томболата")
	menu_additem(g_iMainMenu, "Виж списъка със записани")
	menu_additem(g_iMainMenu, "Виж списъка с награди")
	menu_additem(g_iMainMenu, "\rСпри томболата")
	
	g_aNagradi = ArrayCreate(64)
	g_aZapisani = ArrayCreate(32)
	g_aIztegleni = ArrayCreate(32)
	ReadFile()
}

public plugin_end()
{
	ArrayDestroy(g_aNagradi)
	ArrayDestroy(g_aZapisani)
	ArrayDestroy(g_aIztegleni)
	
	if(g_bWasStarted)
		ArrayDestroy(g_aTeglene)
}
	
ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/AMXXBGTombola.ini", szConfigsName)
	
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[64], iSection
		
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
	
	if(!g_iNagradi)
	{
		log_amx("Nqma namereni nagradi. Pluginut se spira.")
		pause("ad")
	}
	
	if(!g_iZapisani)
	{
		log_amx("Nqma zapisani potrebiteli. Pluginut se spira.")
		pause("ad")
	}
	
	menu_setprop(g_iNagradiMenu, MPROP_TITLE, fmt("\r[AMXXBG] \yТомбола^n\wНагради: \d%i%s", g_iNagradi, g_iNagradi > ITEMS_PER_PAGE ? "^n\wСтраница:\d" : ""))
	menu_setprop(g_iZapisaniMenu, MPROP_TITLE, fmt("\r[AMXXBG] \yТомбола^n\wЗаписани потребители: \d%i%s", g_iZapisani, g_iZapisani > ITEMS_PER_PAGE ? "^n\wСтраница:\d" : ""))
}

public GlavnoMenu(id, iLevel, iCid)
{
	cmd_access(id, iLevel, iCid, 1) ? menu_display(id, g_iMainMenu) : send_dhudmessage(id, 255, 0, 0, -1.0, 0.7, 3.0, "Нямаш достъп до тази команда!")
	return PLUGIN_HANDLED
}

public GlavnoMenu_Handler(id, iMenu, iItem)
{
	if(iItem == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(iItem)
	{
		case 0: g_bActive ? send_dhudmessage(id, 255, 0, 0, -1.0, 0.7, 3.0, "Томболата вече е била стартирана!") : startirai_tombolata(id)
		case 1: menu_display(id, g_iZapisaniMenu)
		case 2: menu_display(id, g_iNagradiMenu)
		case 3: g_bActive ? spri_tombolata(id) : send_dhudmessage(id, 255, 0, 0, -1.0, 0.7, 3.0, "Томболата не е активна в момента!")
	}
	
	return PLUGIN_HANDLED
}

public Submenu_Handler(id, iMenu, iItem)
{
	menu_display(id, g_iMainMenu)
	return PLUGIN_HANDLED
}

startirai_tombolata(id)
{
	g_bActive = true
	g_bWasStarted = true
	g_aTeglene = ArrayClone(g_aZapisani)
	g_iTeglene = g_iZapisani
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	send_dhudmessage(0, 0, 255, 0, -1.0, 0.3, 3.0, "%s стартира томболата!", szName)
	send_dhudmessage(0, 80, 140, 190, -1.0, 0.35, 3.0, "Първият потребител ще бъде изтеглен след %.0f секунди...", TEGLENE_DELAY)
	zadai_sledvashto_teglene()
}

zadai_sledvashto_teglene()
	set_task(TEGLENE_DELAY, "iztegli_potrebitel", TASK_TEGLENE)

public iztegli_potrebitel()
{
	new szIzteglen[32], iIzteglen = random(g_iTeglene)
	ArrayGetString(g_aTeglene, iIzteglen, szIzteglen, charsmax(szIzteglen))
	send_dhudmessage(0, 80, 190, 120, -1.0, 0.3, 5.0, "%s бе избран да получи награда", szIzteglen)
	send_dhudmessage(0, 255, 255, 0, -1.0, 0.35, 5.0, "%a", ArrayGetStringHandle(g_aNagradi, g_iIztegleni))
	
	ArrayDeleteItem(g_aTeglene, iIzteglen)
	ArrayPushString(g_aIztegleni, szIzteglen)
	g_iIztegleni++
	g_iTeglene--
	
	if(g_iIztegleni < g_iNagradi)
	{
		send_dhudmessage(0, 80, 140, 190, -1.0, 0.40, 5.0, "Следващият потребител ще бъде изтеглен след %.0f секунди...", TEGLENE_DELAY)
		zadai_sledvashto_teglene()
	}
	else krai_na_tombolata(false)
}	

spri_tombolata(id)
{
	krai_na_tombolata(true)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	send_dhudmessage(0, 255, 0, 0, -1.0, 0.6, 3.0, "%s спря томболата!", szName)
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
			
		send_dhudmessage(0, 0, 255, 0, -1.0, 0.45, 8.0, "Томболата успешно приключи!")
		send_dhudmessage(0, 0, 150, 255, -1.0, 0.5, 8.0, "Спсиъкът с изтеглени потребители е изписан в конзолата.")
	}
	
	ArrayClear(g_aIztegleni)
	g_iIztegleni = 0
	g_bActive = false
}

kirilizirano_menu(szTitle[128], szHandler[32])
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